@isTest(SeeAllData=false)
private class OA_FollowUpScheduler_Test {

    private static Campaign makeTestCampaign() {
        Campaign c = new Campaign(Name = 'OA FollowUp Test Campaign', IsActive = true, Status = 'Planning');
        insert c;

        // Add Day-N statuses so CampaignMember insert accepts them
        List<CampaignMemberStatus> statuses = new List<CampaignMemberStatus>{
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 1 Sent',  IsDefault = false, HasResponded = false, SortOrder = 3),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 3 Sent',  IsDefault = false, HasResponded = false, SortOrder = 4),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 5 Sent',  IsDefault = false, HasResponded = false, SortOrder = 5),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Call Completed', IsDefault = false, HasResponded = true, SortOrder = 6)
        };
        insert statuses;

        return c;
    }

    private static Lead makeTestLead(String email) {
        Lead l = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Co', Email = email);
        insert l;
        return l;
    }

    @isTest
    static void testSendFollowUpsNoEligibleMembers() {
        Test.startTest();
        OA_FollowUpScheduler.sendFollowUps();
        Test.stopTest();
    }

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        System.schedule('OA Follow Up Test Job', '0 0 8 * * ?', new OA_FollowUpScheduler());
        Test.stopTest();
    }

    @isTest
    static void testDay1SentAdvancesToDay3() {
        // Proves the follow-up pipeline runs end-to-end for a Day 1 Sent member.
        // nowOverride pushes "today" 30 days forward so any CM created now meets
        // the CreatedDate <= day3Cutoff (3 days before "now") condition.
        Campaign c   = makeTestCampaign();
        Lead    lead = makeTestLead('day1-test@example.com');

        CampaignMember cm = new CampaignMember(CampaignId = c.Id, LeadId = lead.Id, Status = 'Day 1 Sent');
        insert cm;

        OA_FollowUpScheduler.testCampaignIdOverride = c.Id;
        OA_FollowUpScheduler.nowOverride            = DateTime.now().addDays(30);
        OA_EmailSender.bypassActualSendForTest      = true;

        Test.startTest();
        OA_FollowUpScheduler.sendFollowUps();
        Test.stopTest();

        CampaignMember updated = [SELECT Status FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('Day 3 Sent', updated.Status,
            'Day 1 Sent CM should advance to Day 3 Sent after follow-up runs');
    }

    @isTest
    static void testCallCompletedIsNotAdvanced() {
        // Proves that a Call Completed CampaignMember is excluded by STOP_STATUSES.
        // Even with nowOverride making dates eligible, the NOT IN filter stops processing.
        Campaign c   = makeTestCampaign();
        Lead    lead = makeTestLead('call-completed-test@example.com');

        CampaignMember cm = new CampaignMember(CampaignId = c.Id, LeadId = lead.Id, Status = 'Call Completed');
        insert cm;

        OA_FollowUpScheduler.testCampaignIdOverride = c.Id;
        OA_FollowUpScheduler.nowOverride            = DateTime.now().addDays(30);

        Test.startTest();
        OA_FollowUpScheduler.sendFollowUps();
        Test.stopTest();

        CampaignMember notChanged = [SELECT Status FROM CampaignMember WHERE Id = :cm.Id];
        System.assertEquals('Call Completed', notChanged.Status,
            'Call Completed must be in STOP_STATUSES; status must not change');
    }

    @isTest
    static void testStopStatusesPreventAllFollowUp() {
        // Verifies every declared STOP_STATUS prevents advancement.
        // Creates one CM per stop status; sendFollowUps should produce zero DML updates.
        Campaign c = makeTestCampaign();

        // Add extra statuses for the ones not already in the default set
        insert new List<CampaignMemberStatus>{
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Replied',        IsDefault = false, HasResponded = true, SortOrder = 7),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Meeting Booked', IsDefault = false, HasResponded = true, SortOrder = 8),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Interested',     IsDefault = false, HasResponded = true, SortOrder = 9),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Not Interested', IsDefault = false, HasResponded = true, SortOrder = 10),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Unsubscribed',   IsDefault = false, HasResponded = true, SortOrder = 11)
        };

        List<String> stopStatuses = new List<String>{
            'Replied', 'Meeting Booked', 'Interested', 'Not Interested', 'Unsubscribed', 'Call Completed'
        };
        List<CampaignMember> members = new List<CampaignMember>();
        Integer i = 0;
        for (String s : stopStatuses) {
            Lead l = makeTestLead('stop-test-' + i + '@example.com');
            members.add(new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = s));
            i++;
        }
        insert members;

        OA_FollowUpScheduler.testCampaignIdOverride = c.Id;
        OA_FollowUpScheduler.nowOverride            = DateTime.now().addDays(30);

        Test.startTest();
        OA_FollowUpScheduler.sendFollowUps();
        Test.stopTest();

        // All CMs should remain unchanged; none matched Day-N patterns.
        Integer unchanged = [SELECT COUNT() FROM CampaignMember
                             WHERE CampaignId = :c.Id
                             AND Status IN ('Replied','Meeting Booked','Interested','Not Interested','Unsubscribed','Call Completed')];
        System.assertEquals(stopStatuses.size(), unchanged,
            'All STOP_STATUS members must remain unmodified');
    }
}
