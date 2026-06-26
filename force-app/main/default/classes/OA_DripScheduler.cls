public class OA_DripScheduler implements Schedulable {

    private static final String  CAMPAIGN_ID = '701Pn00001ZOyj8IAD';
    private static final Integer BATCH_SIZE  = 10;

    @TestVisible private static String testCampaignIdOverride;

    public void execute(SchedulableContext sc) {
        addLeadsToCampaign();
    }

    public static void addLeadsToCampaign() {
        String activeCampaignId = testCampaignIdOverride != null
            ? testCampaignIdOverride : CAMPAIGN_ID;

        List<Lead> toAdd = [
            SELECT Id
            FROM Lead
            WHERE LeadSource          =  'SAM.gov'
              AND Outreach_Cohort__c  =  'Pilot Batch 1'
              AND Is_Test_Lead__c     =  false
              AND HasOptedOutOfEmail  =  false
              AND IsConverted         =  false
              AND Email               != null
              AND Id NOT IN (
                  SELECT LeadId FROM CampaignMember
                  WHERE CampaignId = :activeCampaignId
                  AND LeadId       != null
              )
            ORDER BY CreatedDate ASC
            LIMIT :BATCH_SIZE
        ];

        if (toAdd.isEmpty()) {
            System.debug('[OA_DripScheduler] No Pilot Batch 1 leads remaining to enroll.');
            return;
        }

        List<CampaignMember> members = new List<CampaignMember>();
        for (Lead l : toAdd) {
            members.add(new CampaignMember(
                CampaignId = activeCampaignId,
                LeadId     = l.Id
            ));
        }

        insert members;
        System.debug('[OA_DripScheduler] Enrolled ' + members.size()
            + ' Pilot Batch 1 lead(s). Campaign: ' + activeCampaignId);
    }
}