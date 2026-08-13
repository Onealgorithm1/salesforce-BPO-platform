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
        sendInbound(fromAddress, subject, 'Interested, call me.');
    }

    private static void sendInbound(String fromAddress, String subject, String body) {
        insert new EmailMessage(
            Incoming    = true,
            FromAddress = fromAddress,
            ToAddress   = 'lrubino@onealgorithm.com',
            Subject     = subject,
            TextBody    = body,
            Status      = '3'
        );
    }

    // The quoted footer every outbound template carries. Any reply that quotes the thread
    // brings this back to us, which is why the body scan must never match a bare
    // "unsubscribe". See OA_ReplyStatusService.OPT_OUT_PHRASES.
    private static final String QUOTED_FOOTER =
        '\n\nOn Tue, Aug 12, 2026 at 9:04 AM One Algorithm LLC wrote:\n' +
        '> Hello, following up on federal teaming.\n' +
        '> If you no longer wish to receive further emails from One Algorithm LLC,\n' +
        '> click here to unsubscribe\n';

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

    // ---- body-text opt-out detection -------------------------------------------------
    // Most people who want out write a polite sentence; they do not type UNSUBSCRIBE into
    // the subject line. Detecting only the subject left that whole population marked
    // 'Replied' with HasOptedOutOfEmail still false, mailable by every other campaign.

    @isTest
    static void testPlainEnglishOptOutInBodyIsHonoured() {
        Campaign c = makeTestCampaign();
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Unsubscribed',
            IsDefault = false, HasResponded = true, SortOrder = 6);
        Lead l = makeLead('polite@primecontractor.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;

        Test.startTest();
        sendInbound('polite@primecontractor.com', 'RE: Teaming',
            'Thanks but please remove me from your list.' + QUOTED_FOOTER);
        Test.stopTest();

        System.assertEquals(true,
            [SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :l.Id].HasOptedOutOfEmail,
            'A plain-English removal request in the body must set the org-wide opt-out');
        System.assertEquals('Unsubscribed',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'A body opt-out must also stop this campaign');
    }

    @isTest
    static void testQuotedUnsubscribeFooterIsNotAnOptOut() {
        Campaign c = makeTestCampaign();
        Lead l = makeLead('keen@primecontractor.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');
        OA_ReplyStatusService.testCampaignIdOverride = c.Id;

        Test.startTest();
        // A genuinely interested reply that simply quotes the thread. The quoted footer
        // contains "click here to unsubscribe" and "no longer wish to receive" — matching
        // either would opt out everyone who replies and look like it worked.
        sendInbound('keen@primecontractor.com', 'RE: Teaming',
            'Yes, very interested. Are you free Thursday?' + QUOTED_FOOTER);
        Test.stopTest();

        System.assertEquals(false,
            [SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :l.Id].HasOptedOutOfEmail,
            'A quoted unsubscribe footer must NEVER opt the prospect out');
        System.assertEquals('Replied',
            [SELECT Status FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id].Status,
            'An interested reply quoting the footer is a reply, not an unsubscribe');
    }

    @isTest
    static void testNewTextOfTruncatesAtQuoteMarkers() {
        System.assertEquals(false,
            OA_ReplyStatusService.newTextOf('No thanks.' + QUOTED_FOOTER).contains('UNSUBSCRIBE'),
            'Quoted text must be stripped before the opt-out phrase scan');
        System.assertEquals(true,
            OA_ReplyStatusService.newTextOf('Please TAKE ME OFF the list.').contains('TAKE ME OFF'),
            'Text the human actually typed must survive truncation');
        System.assertEquals('', OA_ReplyStatusService.newTextOf(null),
            'A null body must be treated as empty, not throw');
    }
}
