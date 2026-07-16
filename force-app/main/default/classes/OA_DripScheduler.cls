public class OA_DripScheduler implements Schedulable {

    private static final String  CAMPAIGN_ID    = '701Pn00001ZOyj8IAD';
    private static final Integer MAX_SYNC_BATCH = 50;

    // ICP targeting: exclusion list. Unclassified leads (Industry = null or 'Other')
    // ARE enrolled — only clearly off-target industries are blocked.
    private static final List<String> EXCLUDED_INDUSTRIES = new List<String>{
        'Construction', 'Hospitality', 'Transportation', 'Healthcare'
    };

    @TestVisible private static String testCampaignIdOverride;

    public void execute(SchedulableContext sc) {
        if (!OA_SendGovernor.isBusinessDay()) {
            System.debug('[OA_DripScheduler] Skipping - not a business day.');
            return;
        }
        addLeadsToCampaign();
    }

    public static void addLeadsToCampaign() {
        String activeCampaignId = testCampaignIdOverride != null ? testCampaignIdOverride : CAMPAIGN_ID;

        Integer batchSize = Math.min(MAX_SYNC_BATCH, OA_SendGovernor.remainingToday());
        if (batchSize <= 0) {
            System.debug('[OA_DripScheduler] Daily send cap consumed; no Wave 1 leads enrolled.');
            return;
        }

        List<Lead> toAdd = [
            SELECT Id
            FROM Lead
            WHERE LeadSource         =  'SAM.gov'
              AND Outreach_Cohort__c =  'Wave 1'
              AND Is_Test_Lead__c    =  false
              AND HasOptedOutOfEmail =  false
              AND EmailBouncedDate   =  null
              AND IsConverted        =  false
              AND Email              != null
              AND (Industry = null OR Industry NOT IN :EXCLUDED_INDUSTRIES)
              AND Id NOT IN (
                  SELECT LeadId FROM CampaignMember
                  WHERE CampaignId = :activeCampaignId
                    AND LeadId     != null
              )
            ORDER BY CreatedDate ASC
            LIMIT :batchSize
        ];

        if (toAdd.isEmpty()) {
            System.debug('[OA_DripScheduler] No Wave 1 leads remaining to enroll.');
            return;
        }

        List<CampaignMember> members = new List<CampaignMember>();
        for (Lead l : toAdd) {
            members.add(new CampaignMember(CampaignId = activeCampaignId, LeadId = l.Id));
        }
        insert members;
        System.debug('[OA_DripScheduler] Enrolled ' + members.size()
            + ' Wave 1 lead(s). Campaign: ' + activeCampaignId);
    }
}
