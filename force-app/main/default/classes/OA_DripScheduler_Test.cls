@isTest(SeeAllData=false)
private class OA_DripScheduler_Test {

    // OA_EDWOSB_Outreach_Sequence flow hardcodes campaign ID 701Pn00001ZOyj8IAD.
    // All tests use a freshly-created campaign with a different ID, so the flow
    // never fires and email sending is not exercised here.
    private static Campaign makeTestCampaign() {
        Campaign c = new Campaign(Name = 'Drip Scheduler Test', IsActive = true, Status = 'Planning');
        insert c;
        return c;
    }

    private static Lead makePilotLead(String email) {
        return makeLead(email, 'Pilot Batch 1', false);
    }

    private static Lead makeLead(String email, String cohort, Boolean isTest) {
        Lead l = new Lead(
            FirstName          = 'Test',
            LastName           = 'Lead',
            Company            = 'Test Co',
            Email              = email,
            LeadSource         = 'SAM.gov',
            Outreach_Cohort__c = cohort,
            Is_Test_Lead__c    = isTest,
            HasOptedOutOfEmail = false
        );
        insert l;
        return l;
    }

    @isTest
    static void testNoPilotBatchLeads_zeroEnrolled() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'No leads should be enrolled when no Pilot Batch 1 leads exist');
    }

    @isTest
    static void testPilotBatchLeads_areEnrolled() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makePilotLead('pilot1@example.com');
        makePilotLead('pilot2@example.com');
        makePilotLead('pilot3@example.com');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            '3 Pilot Batch 1 leads must be enrolled');
    }

    @isTest
    static void testTestLeads_areExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeLead('test@example.com', 'Pilot Batch 1', true); // Is_Test_Lead__c = true

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Is_Test_Lead__c = true must be excluded regardless of cohort');
    }

    @isTest
    static void testNullCohort_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeLead('nocohort@example.com', null, false);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Null Outreach_Cohort__c must not enroll');
    }

    @isTest
    static void testWrongCohort_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeLead('wrongcohort@example.com', 'Test / Validation', false);
        makeLead('othercohort@example.com', 'Batch 2', false);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Non-Pilot Batch 1 cohort values must not enroll');
    }

    @isTest
    static void testBatchLimit_capsAt10() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 15; i++) {
            leads.add(new Lead(
                FirstName          = 'Pilot',
                LastName           = 'Lead' + i,
                Company            = 'Test Co',
                Email              = 'pilot' + i + '@example.com',
                LeadSource         = 'SAM.gov',
                Outreach_Cohort__c = 'Pilot Batch 1',
                Is_Test_Lead__c    = false,
                HasOptedOutOfEmail = false
            ));
        }
        insert leads;

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(10, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'BATCH_SIZE = 10 must cap enrollment even when 15 eligible leads exist');
    }

    @isTest
    static void testAlreadyEnrolled_notDuplicated() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Lead l = makePilotLead('already@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id],
            'Already-enrolled lead must not be inserted a second time');
    }

    @isTest
    static void testOptedOut_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Lead l = makePilotLead('optout@example.com');
        update new Lead(Id = l.Id, HasOptedOutOfEmail = true);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'HasOptedOutOfEmail = true must be excluded');
    }

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        System.schedule('OA Drip Test', '0 0 9 ? * MON-FRI', new OA_DripScheduler());
        Test.stopTest();
    }
}