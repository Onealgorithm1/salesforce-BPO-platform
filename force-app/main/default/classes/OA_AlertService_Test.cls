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

    @isTest
    static void testRaiseWithCampaignMemberTargetResolvesProspectAndEmails() {
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Campaign c = new Campaign(Name = 'Alert Test Campaign', IsActive = true, Status = 'Planning');
        insert c;
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 1 Sent', HasResponded = false, SortOrder = 3);
        Lead l = new Lead(FirstName = 'Pat', LastName = 'Prospect', Company = 'Acme Federal LLC',
            Email = 'pat@acmefederal.com', LeadSource = 'SAM.gov');
        insert l;
        CampaignMember cm = new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');
        insert cm;

        Test.startTest();
        // targetId is a CampaignMember (00v) — exercises prospectLabel + record URL + email channel.
        OA_AlertService.raise('Booking — unverified domain match (review required)', 'body detail', cm.Id);
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject = 'Booking — unverified domain match (review required)'],
            'raise() with a CampaignMember target must still record the audit Task (email/notification are fire-and-forget)');
    }
}
