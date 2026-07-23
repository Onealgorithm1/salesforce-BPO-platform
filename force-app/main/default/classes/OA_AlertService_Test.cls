@isTest(SeeAllData=false)
private class OA_AlertService_Test {

    @isTest
    static void testRaiseCreatesAuditTaskAndNotifies() {
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Test.startTest();
        OA_AlertService.raise('OA test alert title', 'OA test alert body', UserInfo.getUserId());
        Test.stopTest();

        List<Task> t = [SELECT Id, OwnerId, Priority FROM Task WHERE Subject = 'OA test alert title'];
        System.assertEquals(1, t.size(), 'raise() must create exactly one audit Task');
        System.assertEquals(UserInfo.getUserId(), t[0].OwnerId, 'Task owner must be the resolved recipient');
        System.assertEquals('High', t[0].Priority);
    }

    @isTest
    static void testRaiseWithNullTargetStillRecords() {
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Test.startTest();
        OA_AlertService.raise('OA null-target alert', 'body', null);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject = 'OA null-target alert'],
            'A null target must still record the audit Task');
    }
}
