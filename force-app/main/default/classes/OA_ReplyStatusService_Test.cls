@isTest(SeeAllData=false)
private class OA_ReplyStatusService_Test {

    private static Campaign makeTestCampaign() {
        Campaign c = new Campaign(Name = 'Reply Status Test', IsActive = true, Status = 'Planning');
        insert c;
        insert new List<CampaignMemberStatus>{
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 1 Sent', IsDefault = false, HasResponded = false, SortOrder = 3),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Replied',    IsDefault = false, HasResponded = true,  SortOrder = 4),
            new CampaignMemberStatus(CampaignId = c.Id, Label = 'Meeting Booked', IsDefault = false, HasResponded = true, SortOrder = 5)
        };
        return c;
    }

    private static Lead makeLead(String email) {
        Lead l = new Lead(
            FirstName = 'Test', LastName = 'Lead', Company = 'Test Co',
            Email = email, LeadSource = 'SAM.gov'
        );
        insert l;
        return l;
    }

    private static void sendInbound(String fromAddress) {
        sendInbound(fromAddress, 'RE: Teaming');
    }

    private static void sendInbound(String fromAddress, String subject) {
        insert new EmailMessage(
            Incoming    = true,
            FromAddress = fromAddress,
            ToAddress   = 'lrubino@onealgorithm.com',
            Subject     = subject,
            TextBody    = 'Interested, call me.',
            Status      = '3'
        );
    }

    @isTest
    static void testInboundReplyFlipsMemberToReplied() {
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        Lead l = makeLead('prospect@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('prospect@example.com');
        Test.stopTest();

        System.assertEquals('Replied',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'Inbound email from a campaign lead must flip the member to Replied');
    }

    @isTest
    static void testStopStatusIsNotDowngraded() {
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        Lead l = makeLead('booked@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Meeting Booked');

        Test.startTest();
        sendInbound('booked@example.com');
        Test.stopTest();

        System.assertEquals('Meeting Booked',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'A member already in a stop status must not be changed');
    }

    @isTest
    static void testUnrelatedInboundAndOutgoingAreIgnored() {
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        Lead l = makeLead('quiet@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('stranger@elsewhere.com');            // inbound, no matching lead
        insert new EmailMessage(                          // outgoing from the lead's address
            Incoming = false, FromAddress = 'quiet@example.com',
            ToAddress = 'x@example.com', Subject = 'out', Status = '3'
        );
        Test.stopTest();

        System.assertEquals('Day 1 Sent',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'Non-matching inbound and outgoing messages must not change member status');
    }

    @isTest
    static void testDomainFallbackFlagsUnverifiedNotReplied() {
        Campaign c = makeTestCampaign();
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Reply - Unverified',
            HasResponded = false, SortOrder = 6);
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Lead l = makeLead('named.person@acmecorp.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('info@acmecorp.com');   // colleague at same company, different mailbox
        Test.stopTest();

        System.assertEquals('Reply - Unverified',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'A domain-only inbound match must be flagged Reply - Unverified, never auto-confirmed Replied');
        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Reply — unverified domain match%'],
            'A visible alert must accompany the unverified flag');
    }

    @isTest
    static void testExactReplyRaisesAlert() {
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Lead l = makeLead('hot.prospect@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('hot.prospect@example.com');
        Test.stopTest();

        System.assertEquals('Replied',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'Exact-address inbound must still flip the member to Replied');
        // The regression this guards: alerts fired only on the domain-fallback branch, so
        // confirmed replies were silently logged and sat unanswered.
        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Reply received%'],
            'An exact-match reply must raise a visible alert, not just log activity');
    }

    @isTest
    static void testUnsubscribeSetsStatusAndOptsLeadOut() {
        Campaign c = makeTestCampaign();
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Unsubscribed',
            HasResponded = false, SortOrder = 7);
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Lead l = makeLead('done@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('done@example.com', 'Please UNSUBSCRIBE me');
        Test.stopTest();

        // The compliance hole: Apex set 'Replied' first, which made the OA_Reply_Detection Flow
        // take its "already terminal" exit before reaching its own unsubscribe branch — so
        // HasOptedOutOfEmail stayed false and a second campaign would still have emailed them.
        System.assertEquals('Unsubscribed',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'An unsubscribe request must set Unsubscribed, never Replied');
        System.assertEquals(true,
            [SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :l.Id].HasOptedOutOfEmail,
            'An unsubscribe request must opt the Lead out org-wide, not just stop this campaign');
        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Unsubscribe request%'],
            'An unsubscribe must raise a visible alert');
    }

    @isTest
    static void testUnsubscribeAfterAReplyStillOptsLeadOut() {
        // The case the first version of this fix missed, and the one that actually happens:
        // the prospect replies normally (-> 'Replied'), then later asks to unsubscribe. The old
        // query filtered terminal statuses out entirely, so the opt-out never ran and the Lead
        // stayed emailable by any other campaign.
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Lead l = makeLead('changed.mind@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Replied');

        Test.startTest();
        sendInbound('changed.mind@example.com', 'Please UNSUBSCRIBE me');
        Test.stopTest();

        System.assertEquals(true,
            [SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :l.Id].HasOptedOutOfEmail,
            'An unsubscribe must opt the Lead out even when the member is already terminal');
        System.assertEquals('Replied',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'A terminal status is reporting data and must not be overwritten by the opt-out');
        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Unsubscribe request%'],
            'The unsubscribe must still raise a visible alert');
    }

    @isTest
    static void testSecondReplyFromTerminalMemberStillAlerts() {
        // A prospect chasing for the second time was previously invisible: already 'Replied',
        // so excluded by the query and no alert raised — silence for the person most owed a reply.
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        OA_AlertService.testRecipientOverride = UserInfo.getUserId();

        Lead l = makeLead('chasing@example.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Replied');

        Test.startTest();
        sendInbound('chasing@example.com', 'RE: Teaming - following up again');
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Reply received%'],
            'A follow-up message from an already-Replied member must still alert');
        System.assertEquals('Replied',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'Alerting must not change an existing terminal status');
    }

    @isTest
    static void testFreemailInboundStaysSilent() {
        Campaign c = makeTestCampaign();
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;
        Lead l = makeLead('prospect@gmail.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        Test.startTest();
        sendInbound('someone.else@gmail.com');   // shared consumer domain — must not match
        Test.stopTest();

        System.assertEquals('Day 1 Sent',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'A freemail domain must never trigger an unverified flag');
    }
}
