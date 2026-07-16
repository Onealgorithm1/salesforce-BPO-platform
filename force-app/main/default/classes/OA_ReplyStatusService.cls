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
        'Replied', 'Meeting Booked', 'Interested', 'Not Interested', 'Unsubscribed', 'Call Completed'
    };

    /** Trigger entry point — bulk-safe, no-op for outgoing or non-matching messages. */
    public static void markReplied(List<EmailMessage> messages) {
        Set<String> fromAddresses = new Set<String>();
        for (EmailMessage m : messages) {
            if (m.Incoming == true && String.isNotBlank(m.FromAddress)) {
                fromAddresses.add(m.FromAddress);
            }
        }
        if (fromAddresses.isEmpty()) return;

        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        List<CampaignMember> toUpdate = [
            SELECT Id
            FROM CampaignMember
            WHERE CampaignId = :activeCampaignId
              AND LeadId != null
              AND Status NOT IN :STOP_STATUSES
              AND Lead.Email IN :fromAddresses
        ];
        if (toUpdate.isEmpty()) return;

        for (CampaignMember cm : toUpdate) {
            cm.Status = 'Replied';
        }
        update toUpdate;
    }
}
