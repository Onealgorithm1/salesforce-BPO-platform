/**
 * OA_ReplyStatusService — flips EDWOSB campaign members to 'Replied' when an inbound
 * email arrives from a campaign lead's address, so the drip/follow-up schedulers
 * (which honor stop statuses) never email someone mid-conversation.
 *
 * Root cause it fixes: reply detection previously required a manual status change
 * (2026-07-16: a live prospect thread was one day from receiving the automated
 * Day 10 send).
 *
 * ponytail: exact FromAddress-to-Lead.Email match only. A reply sent from a
 * different mailbox at the same company (it happened once: adminasst@ replying
 * for sti@) is NOT caught — domain-level matching risks false positives on
 * shared domains. Upgrade path: maintain a per-lead alternate-address list.
 *
 * UNSUBSCRIBE handling lives here, NOT only in the OA_Reply_Detection Flow.
 * Both run after-save on EmailMessage insert and Apex goes first. The Flow's entry
 * gate (OA_Reply_Detection.flow-meta.xml:5-54) requires Status != 'Replied' BEFORE it
 * reaches its unsubscribe check at line 77 — so once this class set 'Replied', the Flow
 * took its "Already Terminal" exit and Lead.HasOptedOutOfEmail was never set. This
 * campaign still stopped mailing them ('Replied' is a stop status), which is why it went
 * unnoticed, but the org-wide opt-out flag stayed false — so a SECOND campaign would have
 * emailed people who explicitly asked to be removed. Setting 'Unsubscribed' here makes the
 * Flow's gate exclude the record for the right reason, with no change to that protected Flow.
 *
 * Alerting: every exact match raises an alert. Previously only the domain-fallback branch
 * did, so confirmed replies sat unanswered (11 prospects up to 19 days, 2026-08 audit).
 */
public with sharing class OA_ReplyStatusService {

    private static final String CAMPAIGN_ID       = '701Pn00001ZOyj8IAD';
    private static final String UNSUBSCRIBE_TOKEN = 'UNSUBSCRIBE';

    @TestVisible private static String testCampaignIdOverride;

    // Never downgrade a member that already reached a terminal/engaged state.
    private static final Set<String> STOP_STATUSES = new Set<String>{
        'Replied', 'Meeting Booked', 'Interested', 'Not Interested', 'Unsubscribed', 'Call Completed',
        'Reply - Unverified'
    };

    // Phrases a human actually writes when they want out. Checked against the NEW text of a
    // reply only — see newTextOf. The bare word UNSUBSCRIBE is deliberately NOT in this list
    // for the body path: every outbound template ends "click here to unsubscribe", so a reply
    // that quotes the thread carries that word back to us. Matching it in the body would opt
    // out every single person who replies and look like it worked.
    private static final List<String> OPT_OUT_PHRASES = new List<String>{
        'UNSUBSCRIBE ME', 'REMOVE ME', 'TAKE ME OFF', 'OPT OUT', 'OPT-OUT',
        'STOP EMAILING', 'NO LONGER WISH TO RECEIVE', 'DO NOT EMAIL', 'DON\'T EMAIL'
    };

    // Where a mail client starts quoting the message being replied to. Everything from the
    // first of these onward is THEIR words, not the sender's, and must not be scanned.
    private static final List<String> QUOTE_MARKERS = new List<String>{
        '-----ORIGINAL MESSAGE-----', '________________________________',
        'FROM:', 'SENT FROM MY', 'WROTE:', 'ON MON', 'ON TUE', 'ON WED', 'ON THU',
        'ON FRI', 'ON SAT', 'ON SUN'
    };

    /**
     * The portion of a reply the human actually typed, upper-cased.
     *
     * ponytail: truncates at the first quote marker or the first quoted ('>') line, whichever
     * comes first. Ceiling — a client that quotes with none of these markers (rare; most use
     * "On <date> ... wrote:" or the Outlook divider) would have its quoted text scanned. The
     * phrase list is specific enough that a quoted footer still will not match, so the failure
     * mode is a missed opt-out, never a false one. Upgrade path is a proper MIME/reply parser.
     */
    @TestVisible
    private static String newTextOf(String body) {
        if (String.isBlank(body)) return '';
        String up  = body.toUpperCase();
        Integer cut = up.length();
        for (String marker : QUOTE_MARKERS) {
            Integer i = up.indexOf(marker);
            if (i >= 0 && i < cut) cut = i;
        }
        Integer gt = up.indexOf('\n>');
        if (gt >= 0 && gt < cut) cut = gt;
        return up.substring(0, cut);
    }

    /**
     * Did this inbound message ask to be removed?
     *
     * Subject keeps the original bare-token rule — a subject is written by the replier and is
     * not quoted back. The body uses explicit phrases against the new text only, because the
     * word "unsubscribe" arrives in every quoted footer.
     */
    @TestVisible
    private static Boolean asksToOptOut(EmailMessage m) {
        if (String.isNotBlank(m.Subject) && m.Subject.toUpperCase().contains(UNSUBSCRIBE_TOKEN)) {
            return true;
        }
        String newText = newTextOf(m.TextBody);
        if (String.isBlank(newText)) return false;
        for (String phrase : OPT_OUT_PHRASES) {
            if (newText.contains(phrase)) return true;
        }
        return false;
    }

    /** Trigger entry point — bulk-safe, no-op for outgoing or non-matching messages. */
    public static void markReplied(List<EmailMessage> messages) {
        // addr -> did any inbound message from that address ask to unsubscribe?
        Map<String, Boolean> unsubByAddress = new Map<String, Boolean>();
        for (EmailMessage m : messages) {
            if (m.Incoming != true || String.isBlank(m.FromAddress)) continue;
            String  addr    = m.FromAddress.toLowerCase();
            Boolean isUnsub = asksToOptOut(m);
            unsubByAddress.put(addr, unsubByAddress.get(addr) == true || isUnsub);
        }
        if (unsubByAddress.isEmpty()) return;

        Set<String> fromAddresses = unsubByAddress.keySet();
        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        // Exact-address match — the primary, auto-confirmed path.
        List<CampaignMember>        toUpdate         = new List<CampaignMember>();
        Map<Id, Lead>               optOuts          = new Map<Id, Lead>();
        List<OA_AlertService.Alert> alerts           = new List<OA_AlertService.Alert>();
        Set<String>                 matchedAddresses = new Set<String>();

        // NOTE the absence of a STOP_STATUSES filter here. Matching and status advancement are
        // deliberately separate concerns: this query finds everyone who wrote to us, and the
        // branches below decide what (if anything) to change. Filtering terminal members out of
        // the QUERY — as this class used to — silently dropped two cases that matter:
        //   * someone who replied normally and LATER asked to unsubscribe was already 'Replied',
        //     so the opt-out never happened. That is the common real sequence, and it is the
        //     compliance hole this class is supposed to close.
        //   * a prospect chasing a second time was already 'Replied', so no alert was raised —
        //     silence for exactly the person most deserving of a response.
        for (CampaignMember cm : [
            SELECT Id, LeadId, Status, Lead.Email
            FROM CampaignMember
            WHERE CampaignId = :activeCampaignId
              AND LeadId != null
              AND Lead.Email IN :fromAddresses
        ]) {
            String  addr        = cm.Lead.Email != null ? cm.Lead.Email.toLowerCase() : null;
            String  wasStatus   = cm.Status;                        // captured before any mutation
            Boolean inSequence  = !STOP_STATUSES.contains(wasStatus);
            Boolean alreadyOut  = (wasStatus == 'Unsubscribed');
            Boolean isUnsub     = addr != null && unsubByAddress.get(addr) == true;
            if (addr != null) matchedAddresses.add(addr);

            if (isUnsub) {
                // Opting the Lead out is UNCONDITIONAL — an explicit request outranks whatever
                // state the campaign happens to be in, and this flag is what actually stops
                // future sends (OA_EmailSender suppresses on it) across every campaign.
                optOuts.put(cm.LeadId, new Lead(Id = cm.LeadId, HasOptedOutOfEmail = true));

                // The campaign status is a reporting field, so a terminal one is left alone —
                // overwriting 'Meeting Booked' with 'Unsubscribed' would erase a real outcome.
                if (inSequence) {
                    cm.Status = 'Unsubscribed';
                    toUpdate.add(cm);
                }
                // No second alert for someone already marked Unsubscribed — there is nothing
                // left for a human to do. Every other case still alerts.
                if (!alreadyOut) {
                    alerts.add(new OA_AlertService.Alert(
                        'Unsubscribe request — ' + addr,
                        'Inbound email from ' + addr + ' asked to unsubscribe (subject contains "' +
                        UNSUBSCRIBE_TOKEN + '").\nLead ' + cm.LeadId + ' opted out of email org-wide.\n' +
                        (inSequence
                            ? 'CampaignMember ' + cm.Id + ' set to "Unsubscribed".'
                            : 'CampaignMember ' + cm.Id + ' left at "' + wasStatus +
                              '" so the outcome is not erased — the opt-out still applies.'),
                        cm.Id
                    ));
                }
            } else {
                if (inSequence) {
                    cm.Status = 'Replied';
                    toUpdate.add(cm);
                }
                alerts.add(new OA_AlertService.Alert(
                    'Reply received — ' + addr,
                    'Inbound email from ' + addr + ' matched CampaignMember ' + cm.Id +
                    ' (Lead ' + cm.LeadId + ') by EXACT address.\n' +
                    (inSequence
                        ? 'Status set to "Replied" — the sequence is halted. This prospect is ' +
                          'waiting on a human response.'
                        : 'Member is already at "' + wasStatus + '"; status unchanged. This is a ' +
                          'FOLLOW-UP message on an existing thread and still needs a reply.'),
                    cm.Id
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        // Partial-save, deliberately. An all-or-none `update` here rolls back the CampaignMember
        // suppression above whenever a Lead validation rule, trigger or record lock rejects the
        // opt-out — leaving someone who just asked to be removed sitting at 'Day 1 Sent' with the
        // follow-up scheduler still serving them. That is the precise failure this class exists to
        // prevent, so a failed org-wide opt-out must not undo the campaign-level stop.
        if (!optOuts.isEmpty()) {
            List<Lead> optOutList = optOuts.values();
            Database.SaveResult[] results = Database.update(optOutList, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) continue;
                String errs = '';
                for (Database.Error e : results[i].getErrors()) errs += e.getMessage() + '; ';
                alerts.add(new OA_AlertService.Alert(
                    'OPT-OUT WRITE FAILED — Lead ' + optOutList[i].Id,
                    'A prospect asked to be removed but Lead.HasOptedOutOfEmail could NOT be set.\n' +
                    'Errors: ' + errs + '\n' +
                    'This campaign has still stopped mailing them (the CampaignMember status was ' +
                    'saved), but EVERY OTHER campaign will keep sending. Set the flag by hand.',
                    optOutList[i].Id
                ));
            }
        }

        // Raised AFTER the status DML so a notification failure can never roll back detection.
        // OA_AlertService.raiseAll swallows its own errors for the same reason.
        if (!alerts.isEmpty()) OA_AlertService.raiseAll(alerts);

        // Domain fallback for inbound addresses that matched no campaign lead exactly.
        // ponytail: one SOQL + up to one DML per unmatched address. Ceiling — the mailbox sync
        // ingests inbound emails one at a time, so Trigger.new is effectively size 1. A future
        // bulk backfill of EmailMessages would want this collapsed into a single bulk query.
        for (String addr : fromAddresses) {
            if (matchedAddresses.contains(addr)) continue;
            handleDomainFallback(addr, activeCampaignId);
        }
    }

    /**
     * Domain-only match for an inbound address with no exact campaign lead.
     * Inbound email is noisy (newsletters, vendors), so we act ONLY when a sendable campaign
     * member actually shares the domain — freemail and no-candidate cases stay silent.
     * A single candidate is flagged 'Reply - Unverified' (never auto-confirmed) and alerted;
     * multiple candidates are alert-only.
     */
    private static void handleDomainFallback(String fromAddress, Id campaignId) {
        List<CampaignMember> cands = OA_MatchFallback.candidatesByDomain(fromAddress, campaignId, STOP_STATUSES);
        if (cands.isEmpty()) return;

        if (cands.size() == 1) {
            cands[0].Status = OA_MatchFallback.UNVERIFIED_STATUS;
            update cands[0];
            OA_AlertService.raise(
                'Reply — unverified domain match (review)',
                'Inbound email from ' + fromAddress + ' matched CampaignMember ' + cands[0].Id +
                ' (Lead ' + cands[0].LeadId + ', ' + cands[0].Lead.Email + ') by DOMAIN only.\n' +
                'Status set to "Reply - Unverified" — the sequence is halted. Confirm this is the ' +
                'same person/opportunity before treating it as a genuine reply.',
                cands[0].Id
            );
        } else {
            OA_AlertService.raise(
                'Reply — ambiguous domain match (' + cands.size() + ' candidates)',
                'Inbound email from ' + fromAddress + ' shares a domain with ' + cands.size() +
                ' sendable campaign members. Not auto-flagged (ambiguous) — review and set status manually.',
                null
            );
        }
    }
}
