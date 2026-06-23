public class OA_DripScheduler implements Schedulable {

    private static final String CAMPAIGN_ID = '701Pn00001ZOyj8IAD';

    public void execute(SchedulableContext sc) {
        addLeadsToCampaign();
    }

    public static void addLeadsToCampaign() {
        Integer existing = [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :CAMPAIGN_ID];

        // Auto-ramp based on how many are already in campaign
        Integer batchSize;
        if      (existing < 500)  batchSize = 50;
        else if (existing < 2000) batchSize = 100;
        else if (existing < 5000) batchSize = 150;
        else                      batchSize = 200;

        List<Lead> toAdd = [
            SELECT Id
            FROM Lead
            WHERE LeadSource = 'SAM.gov'
              AND HasOptedOutOfEmail = false
              AND IsConverted = false
              AND Email != null
              AND Id NOT IN (
                  SELECT LeadId FROM CampaignMember
                  WHERE CampaignId = :CAMPAIGN_ID
                  AND LeadId != null
              )
            ORDER BY CreatedDate ASC
            LIMIT :batchSize
        ];

        if (toAdd.isEmpty()) {
            System.debug('OA_DripScheduler: No leads remaining to add.');
            return;
        }

        List<CampaignMember> members = new List<CampaignMember>();
        for (Lead l : toAdd) {
            members.add(new CampaignMember(
                CampaignId = CAMPAIGN_ID,
                LeadId     = l.Id
            ));
        }

        insert members;
        System.debug('OA_DripScheduler: Added ' + members.size() + ' leads. Total in campaign: ' + (existing + members.size()));
    }
}