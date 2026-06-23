@isTest(SeeAllData=false)
private class OA_DripScheduler_Test {

    @isTest
    static void testNoCampaignMembers() {
        Test.startTest();
        OA_DripScheduler.addLeadsToCampaign();
        Test.stopTest();
    }

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        System.schedule('OA Drip Test Job', '0 0 9 * * ?', new OA_DripScheduler());
        Test.stopTest();
    }
}