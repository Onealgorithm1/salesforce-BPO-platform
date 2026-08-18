public class OA_FollowUpScheduler implements Schedulable {

    private static final String CAMPAIGN_ID    = '701Pn00001ZOyj8IAD';
    private static final String OWA_ID         = '0D2Pn00000013wjKAA';
    private static final Integer MAX_SYNC_BATCH = 50;

    @TestVisible private static String   testCampaignIdOverride;
    @TestVisible private static DateTime nowOverride;

    private static final Set<String> STOP_STATUSES = new Set<String>{
        'Replied', 'Meeting Booked', 'Interested', 'Not Interested', 'Unsubscribed', 'Call Completed',
        'Reply - Unverified'
    };

    public void execute(SchedulableContext sc) {
        if (!OA_SendGovernor.isBusinessDay()) {
            System.debug('[OA_FollowUpScheduler] Skipping - not a business day.');
            return;
        }
        sendFollowUps();
    }

    public static void sendFollowUps() {
        DateTime now = nowOverride != null ? nowOverride : DateTime.now();
        DateTime day3Cutoff  = now.addDays(-3);
        DateTime day5Cutoff  = now.addDays(-5);
        DateTime day10Cutoff = now.addDays(-10);

        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        if (!OA_SendGovernor.isCampaignSendable((Id) activeCampaignId)) {
            System.debug('[OA_FollowUpScheduler] Campaign inactive or past EndDate; no follow-ups sent.');
            return;
        }

        Integer queryLimit = Math.min(MAX_SYNC_BATCH, OA_SendGovernor.remainingToday());
        if (queryLimit <= 0) return;

        // ponytail: Status DESC drains the latest-stage cohort first, then oldest-waiting within it.
        // LastModifiedDate ASC alone inverted priority: Day-1 rows have not been written since July
        // enrollment while Day-3/5 rows were written at their last touch, so all 1,852 cold Day-1
        // members sorted ahead of every in-flight member (~9+ days before anyone at Day 3 got Day 5),
        // starving the cohort closest to converting.
        // ⚠️ CEILING — this rides a lexicographic coincidence:
        //   'Day 5 Sent' > 'Day 3 Sent' > 'Day 1 Sent', but 'Day 10 Sent' < 'Day 3 Sent'.
        // 'Day 10 Sent' is a terminal status today, so it never appears in this WHERE clause. The
        // moment it becomes a driver status (a Day-15 touch, or the proposed Day-90 re-entry) the
        // ordering silently inverts again.
        // Upgrade path: a real sequence-position field, or the Last_Touch_Sent__c datetime stamped
        // by OA_EmailSender, and order on that instead of on the status string.
        List<CampaignMember> members = [
            SELECT Id, LeadId, Status, CreatedDate, LastModifiedDate
            FROM CampaignMember
            WHERE CampaignId = :activeCampaignId
              AND LeadId != null
              AND Lead.EmailBouncedDate = null
              AND Status NOT IN :STOP_STATUSES
              AND (
                  (Status = 'Day 1 Sent'  AND CreatedDate      <= :day3Cutoff)  OR
                  (Status = 'Day 3 Sent'  AND LastModifiedDate <= :day5Cutoff)  OR
                  (Status = 'Day 5 Sent'  AND LastModifiedDate <= :day10Cutoff)
              )
            ORDER BY Status DESC, LastModifiedDate ASC
            LIMIT :queryLimit
        ];

        if (members.isEmpty()) return;

        List<OA_EmailSender.EmailRequest> emailRequests = new List<OA_EmailSender.EmailRequest>();
        Map<String, CampaignMember>       cmByLeadId    = new Map<String, CampaignMember>();
        Map<String, String>               newStatusMap  = new Map<String, String>();

        for (CampaignMember cm : members) {
            String templateName;
            String newStatus;

            if      (cm.Status == 'Day 1 Sent') { templateName = 'Follow_Up_Day3';  newStatus = 'Day 3 Sent'; }
            else if (cm.Status == 'Day 3 Sent') { templateName = 'Follow_Up_Day5';  newStatus = 'Day 5 Sent'; }
            else if (cm.Status == 'Day 5 Sent') { templateName = 'Follow_Up_Day10'; newStatus = 'Day 10 Sent'; }
            else { continue; }

            OA_EmailSender.EmailRequest req = new OA_EmailSender.EmailRequest();
            req.leadId                = cm.LeadId;
            req.templateApiName       = templateName;
            req.orgWideEmailAddressId = OWA_ID;
            req.campaignId            = activeCampaignId;
            req.campaignMemberId      = cm.Id;
            emailRequests.add(req);

            cmByLeadId.put(cm.LeadId, cm);
            newStatusMap.put(cm.LeadId, newStatus);
        }

        if (emailRequests.isEmpty()) return;

        Map<String, Boolean> sendResults = OA_EmailSender.sendEmailToLeadWithResults(emailRequests);

        // Only advance status for leads whose send succeeded
        List<CampaignMember> toUpdate = new List<CampaignMember>();
        for (String leadId : sendResults.keySet()) {
            if (sendResults.get(leadId) == true && cmByLeadId.containsKey(leadId)) {
                CampaignMember cm = cmByLeadId.get(leadId);
                cm.Status = newStatusMap.get(leadId);
                toUpdate.add(cm);
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}