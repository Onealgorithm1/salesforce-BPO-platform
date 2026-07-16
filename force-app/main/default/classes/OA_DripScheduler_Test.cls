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

    private static Lead makeWaveLead(String email) {
        return makeLead(email, 'Wave 1', false);
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
            HasOptedOutOfEmail = false,
            Industry           = 'Technology'   // ICP industry so positive-path tests enroll
        );
        insert l;
        return l;
    }

    private static void setSendCap(Integer cap, Integer used) {
        OA_Campaign_Settings__c cfg = OA_Campaign_Settings__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new OA_Campaign_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        cfg.Daily_Send_Cap__c = cap;
        cfg.Sends_Today__c = used;
        cfg.Cap_Reset_Date__c = Date.today();
        upsert cfg;
    }

    @isTest
    static void testNoWaveLeads_zeroEnrolled() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'No leads should be enrolled when no Wave 1 leads exist');
    }

    @isTest
    static void testWaveLeads_areEnrolled() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeWaveLead('wave1@example.com');
        makeWaveLead('wave2@example.com');
        makeWaveLead('wave3@example.com');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            '3 Wave 1 leads must be enrolled');
    }

    @isTest
    static void testTestLeads_areExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeLead('test@example.com', 'Wave 1', true); // Is_Test_Lead__c = true

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
            'Non-Wave 1 cohort values must not enroll');
    }

    @isTest
    static void testBatchLimit_capsAt50() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;
        setSendCap(200, 0);

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 60; i++) {
            leads.add(new Lead(
                FirstName          = 'Wave',
                LastName           = 'Lead' + i,
                Company            = 'Test Co',
                Email              = 'wave' + i + '@example.com',
                LeadSource         = 'SAM.gov',
                Outreach_Cohort__c = 'Wave 1',
                Is_Test_Lead__c    = false,
                HasOptedOutOfEmail = false,
                Industry           = 'Technology'
            ));
        }
        insert leads;

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(50, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'MAX_SYNC_BATCH = 50 must cap enrollment even when 60 eligible leads exist');
    }

    @isTest
    static void testBatchLimit_respectsRemainingDailyCap() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;
        setSendCap(50, 45);

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 20; i++) {
            leads.add(new Lead(
                FirstName          = 'Cap',
                LastName           = 'Lead' + i,
                Company            = 'Test Co',
                Email              = 'cap' + i + '@example.com',
                LeadSource         = 'SAM.gov',
                Outreach_Cohort__c = 'Wave 1',
                Is_Test_Lead__c    = false,
                HasOptedOutOfEmail = false,
                Industry           = 'Technology'
            ));
        }
        insert leads;

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Enrollment must not exceed remaining daily send capacity');
    }

    @isTest
    static void testAlreadyEnrolled_notDuplicated() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Lead l = makeWaveLead('already@example.com');
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

        Lead l = makeWaveLead('optout@example.com');
        update new Lead(Id = l.Id, HasOptedOutOfEmail = true);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'HasOptedOutOfEmail = true must be excluded');
    }

    @isTest
    static void testBounced_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        Lead l = makeWaveLead('bounced@example.com');
        update new Lead(Id = l.Id, EmailBouncedDate = System.now(), EmailBouncedReason = 'Test bounce');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'EmailBouncedDate != null must be excluded');
    }

    private static Lead makeWaveLeadInIndustry(String email, String industry) {
        Lead l = new Lead(
            FirstName          = 'Test',
            LastName           = 'Lead',
            Company            = 'Test Co',
            Email              = email,
            LeadSource         = 'SAM.gov',
            Outreach_Cohort__c = 'Wave 1',
            Is_Test_Lead__c    = false,
            HasOptedOutOfEmail = false,
            Industry           = industry
        );
        insert l;
        return l;
    }

    @isTest
    static void testNonIcpIndustry_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeWaveLeadInIndustry('construction@example.com', 'Construction');
        makeWaveLeadInIndustry('healthcare@example.com',   'Healthcare');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Non-ICP industries (Construction, Healthcare) must not enroll');
    }

    @isTest
    static void testOtherIndustry_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeWaveLeadInIndustry('other@example.com', 'Other');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Industry = Other (unclassified) must be excluded until NAICS work is done');
    }

    @isTest
    static void testNullIndustry_isExcluded() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        makeWaveLeadInIndustry('nullindustry@example.com', null);

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Null Industry must not enroll (IN clause excludes null)');
    }

    @isTest
    static void testIcpIndustries_enrollOnlyIcp() {
        Campaign c = makeTestCampaign();
        OA_DripScheduler.testCampaignIdOverride = c.Id;

        // 4 ICP + 2 non-ICP; only the 4 ICP should enroll.
        makeWaveLeadInIndustry('tech@example.com',    'Technology');
        makeWaveLeadInIndustry('consult@example.com', 'Consulting');
        makeWaveLeadInIndustry('eng@example.com',     'Engineering');
        makeWaveLeadInIndustry('telecom@example.com', 'Telecommunications');
        makeWaveLeadInIndustry('constr@example.com',  'Construction');
        makeWaveLeadInIndustry('other2@example.com',  'Other');

        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();

        System.assertEquals(4, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id],
            'Exactly the 4 ICP-industry Wave 1 leads must enroll');
    }

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        System.schedule('OA Drip Test', '0 0 9 ? * MON-FRI', new OA_DripScheduler());
        Test.stopTest();
    }
}
