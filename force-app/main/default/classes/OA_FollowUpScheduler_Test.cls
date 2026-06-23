@isTest(SeeAllData=false)
private class OA_FollowUpScheduler_Test {

    @TestSetup
    static void makeData() {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'SchedulerLead',
            Company = 'Test Co',
            Email = 'test-scheduler@example.com'
        );
        insert l;
    }

    @isTest
    static void testSendFollowUpsNoEligibleMembers() {
        // With no CampaignMembers, sendFollowUps should return safely
        Test.startTest();
        OA_FollowUpScheduler.sendFollowUps();
        Test.stopTest();
        // No exception = pass
    }

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        String cronExpr = '0 0 8 * * ?';
        System.schedule('OA Follow Up Test Job', cronExpr, new OA_FollowUpScheduler());
        Test.stopTest();
        // Job scheduled without error = pass
    }
}