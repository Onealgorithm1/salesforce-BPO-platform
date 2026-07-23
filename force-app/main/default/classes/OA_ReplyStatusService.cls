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
 */
public with sharing class OA_ReplyStatusService {

    private static final String CAMPAIGN_ID = '701Pn00001ZOyj8IAD';

    @TestVisible private static String testCampaignIdOverride;

    // Never downgrade a member that already reached a terminal/engaged state.
    private static final Set<String> STOP_STATUSES = new Set<String>{
        'Replied', 'Meeting Booked', 'Interested', 'Not Interested', 'Unsubscribed', 'Call Completed',
        'Reply - Unverified'
    };

    /** Trigger entry point — bulk-safe, no-op for outgoing or non-matching messages. */
    public static void markReplied(List<EmailMessage> messages) {
        Set<String> fromAddresses = new Set<String>();
        for (EmailMessage m : messages) {
            if (m.Incoming == true && String.isNotBlank(m.FromAddress)) {
                fromAddresses.add(m.FromAddress.toLowerCase());
            }
        }
        if (fromAddresses.isEmpty()) return;

        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        // Exact-address match — the primary, auto-confirmed path.
        List<CampaignMember> toUpdate = new List<CampaignMember>();
        Set<String> matchedAddresses = new Set<String>();
        for (CampaignMember cm : [
            SELECT Id, LeadId, Lead.Email
            FROM CampaignMember
            WHERE CampaignId = :activeCampaignId
              AND LeadId != null
              AND Status NOT IN :STOP_STATUSES
              AND Lead.Email IN :fromAddresses
        ]) {
            cm.Status = 'Replied';
            toUpdate.add(cm);
            if (cm.Lead.Email != null) matchedAddresses.add(cm.Lead.Email.toLowerCase());
        }
        if (!toUpdate.isEmpty()) update toUpdate;

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
