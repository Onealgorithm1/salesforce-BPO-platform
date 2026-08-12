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

    /** Trigger entry point — bulk-safe, no-op for outgoing or non-matching messages. */
    public static void markReplied(List<EmailMessage> messages) {
        // addr -> did any inbound message from that address ask to unsubscribe?
        Map<String, Boolean> unsubByAddress = new Map<String, Boolean>();
        for (EmailMessage m : messages) {
            if (m.Incoming != true || String.isBlank(m.FromAddress)) continue;
            String  addr    = m.FromAddress.toLowerCase();
            Boolean isUnsub = String.isNotBlank(m.Subject)
                              && m.Subject.toUpperCase().contains(UNSUBSCRIBE_TOKEN);
            unsubByAddress.put(addr, unsubByAddress.get(addr) == true || isUnsub);
        }
        if (unsubByAddress.isEmpty()) return;

        Set<String> fromAddresses = unsubByAddress.keySet();
        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        // Exact-address match — the primary, auto-confirmed path.
        List<CampaignMember>        toUpdate         = new List<CampaignMember>();
        List<Lead>                  optOuts          = new List<Lead>();
        List<OA_AlertService.Alert> alerts           = new List<OA_AlertService.Alert>();
        Set<String>                 matchedAddresses = new Set<String>();

        for (CampaignMember cm : [
            SELECT Id, LeadId, Lead.Email
            FROM CampaignMember
            WHERE CampaignId = :activeCampaignId
              AND LeadId != null
              AND Status NOT IN :STOP_STATUSES
              AND Lead.Email IN :fromAddresses
        ]) {
            String addr = cm.Lead.Email != null ? cm.Lead.Email.toLowerCase() : null;
            if (addr != null) matchedAddresses.add(addr);

            if (addr != null && unsubByAddress.get(addr) == true) {
                cm.Status = 'Unsubscribed';
                optOuts.add(new Lead(Id = cm.LeadId, HasOptedOutOfEmail = true));
                alerts.add(new OA_AlertService.Alert(
                    'Unsubscribe request — ' + addr,
                    'Inbound email from ' + addr + ' asked to unsubscribe (subject contains "' +
                    UNSUBSCRIBE_TOKEN + '").\nCampaignMember ' + cm.Id + ' set to "Unsubscribed" and ' +
                    'Lead ' + cm.LeadId + ' opted out of email org-wide.',
                    cm.Id
                ));
            } else {
                cm.Status = 'Replied';
                alerts.add(new OA_AlertService.Alert(
                    'Reply received — ' + addr,
                    'Inbound email from ' + addr + ' matched CampaignMember ' + cm.Id +
                    ' (Lead ' + cm.LeadId + ') by EXACT address.\n' +
                    'Status set to "Replied" — the sequence is halted. This prospect is waiting ' +
                    'on a human response.',
                    cm.Id
                ));
            }
            toUpdate.add(cm);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!optOuts.isEmpty())  update optOuts;

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
