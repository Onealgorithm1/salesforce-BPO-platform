@isTest(SeeAllData=true)
private class OA_EmailSender_Test {

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

    private static List<Lead> makeLeads(Integer count) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            leads.add(new Lead(
                FirstName = 'Bulk',
                LastName = 'Lead' + i,
                Company = 'Test Company',
                Email = 'bulk-email-sender-' + i + '@example.com',
                Status = 'Open - Not Contacted'
            ));
        }
        insert leads;
        return leads;
    }

    private static List<OA_EmailSender.EmailRequest> makeRequests(
        List<Lead> leads,
        String templateName,
        String owaId
    ) {
        List<OA_EmailSender.EmailRequest> requests = new List<OA_EmailSender.EmailRequest>();
        for (Lead lead : leads) {
            OA_EmailSender.EmailRequest req = new OA_EmailSender.EmailRequest();
            req.leadId = lead.Id;
            req.templateApiName = templateName;
            req.orgWideEmailAddressId = owaId;
            requests.add(req);
        }
        return requests;
    }

    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owas = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = 'lrubino@onealgorithm.com'
            LIMIT 1
        ];
        return owas.isEmpty() ? null : owas[0].Id;
    }

    private static Boolean templateExists(String developerName) {
        return [
            SELECT COUNT()
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
        ] > 0;
    }

    @isTest
    static void testBulkSendFiftyRequestsDoesNotHitCpuLimit() {
        String templateName = 'EDWOSB_Sub_Prospect_Email_1';
        Id owaId = getOrgWideEmailAddressId();
        if (owaId == null || !templateExists(templateName)) return;

        setSendCap(200, 0);
        List<Lead> leads = makeLeads(50);
        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, templateName, String.valueOf(owaId));

        Test.startTest();
        Integer cpuBefore = Limits.getCpuTime();
        Map<String, Boolean> results = OA_EmailSender.sendEmailToLeadWithResults(requests);
        Integer cpuUsed = Limits.getCpuTime() - cpuBefore;
        Test.stopTest();

        System.assertEquals(50, results.size(), 'Every request should have a send result');
        System.assert(cpuUsed < Limits.getLimitCpuTime(), 'Bulk send must complete below Apex CPU limit');
    }

    @isTest
    static void testInvocableRejectsOversizedBatchBeforeReserve() {
        setSendCap(200, 0);
        List<Lead> leads = makeLeads(51);
        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'EDWOSB_Sub_Prospect_Email_1', '0D2Pn00000013wjKAA');

        Boolean threw = false;
        try {
            OA_EmailSender.sendEmailToLead(requests);
        } catch (OA_EmailSender.EmailSendException e) {
            threw = true;
        }

        System.assert(threw, 'Invocable path must fail fast above safe synchronous batch size');
        System.assertEquals(0, (Integer) OA_Campaign_Settings__c.getOrgDefaults().Sends_Today__c,
            'Oversized invocable batches must not reserve daily send capacity');
    }

    @isTest
    static void testInvocableSucceedsWhenEveryRequestSends() {
        OA_EmailSender.bypassActualSendForTest = true;
        setSendCap(200, 0);
        List<Lead> leads = makeLeads(1);
        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'EDWOSB_Sub_Prospect_Email_1', '0D2Pn00000013wjKAA');

        Test.startTest();
        OA_EmailSender.sendEmailToLead(requests);
        Test.stopTest();

        System.assertEquals(1, (Integer) OA_Campaign_Settings__c.getOrgDefaults().Sends_Today__c,
            'Successful invocable send should reserve one daily send slot');
    }

    @isTest
    static void testInvocableFailsClosedWhenTemplateIsMissing() {
        setSendCap(200, 0);
        List<Lead> leads = makeLeads(1);
        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'Missing_Template_For_Test', '0D2Pn00000013wjKAA');

        Boolean threw = false;
        try {
            OA_EmailSender.sendEmailToLead(requests);
        } catch (OA_EmailSender.EmailSendException e) {
            threw = true;
        }

        System.assert(threw, 'Invocable path must fail closed when any requested email is not sent');
    }

    @isTest
    static void testResultMapMarksSkippedRequestsWhenCapIsPartial() {
        OA_EmailSender.bypassActualSendForTest = true;
        setSendCap(3, 0);

        List<Lead> leads = makeLeads(5);
        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'EDWOSB_Sub_Prospect_Email_1', '0D2Pn00000013wjKAA');

        Test.startTest();
        Map<String, Boolean> results = OA_EmailSender.sendEmailToLeadWithResults(requests);
        Test.stopTest();

        Integer sent = 0;
        Integer skipped = 0;
        for (Boolean result : results.values()) {
            if (result == true) sent++;
            else skipped++;
        }

        System.assertEquals(5, results.size(), 'All requests must receive a result');
        System.assertEquals(3, sent, 'Only remaining send capacity should be marked sent');
        System.assertEquals(2, skipped, 'Requests beyond remaining capacity must stay false');
    }

    @isTest
    static void testTransientUnsubscribeInjectionMintsTokenAndReplacesPlaceholder() {
        Id owaId = getOrgWideEmailAddressId();
        if (owaId == null) return;
        setSendCap(200, 0);

        Lead ld = new Lead(FirstName = 'Inj', LastName = 'Tester', Company = 'Inj Co',
            Email = 'inj.tester@example.com', Status = 'Open - Not Contacted');
        insert ld;
        Campaign c = new Campaign(Name = 'Inj Campaign', IsActive = true);
        insert c;
        CampaignMember cm = new CampaignMember(CampaignId = c.Id, LeadId = ld.Id, Status = 'Sent');
        insert cm;

        OA_EmailSender.EmailRequest req = new OA_EmailSender.EmailRequest();
        req.leadId = ld.Id;
        req.templateApiName = 'SeamIgnored';
        req.orgWideEmailAddressId = String.valueOf(owaId);
        req.campaignId = c.Id;
        req.campaignMemberId = cm.Id;

        OA_EmailSender.testSubjectOverride = 'Subject';
        OA_EmailSender.testHtmlOverride = '<p>hi</p><a href="%%OA_UNSUBSCRIBE_URL%%">unsubscribe</a>';
        OA_EmailSender.testTextOverride = 'unsubscribe: %%OA_UNSUBSCRIBE_URL%%';

        Test.startTest();
        Map<String, Boolean> res =
            OA_EmailSender.sendEmailToLeadWithResults(new List<OA_EmailSender.EmailRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, res.get(ld.Id), 'Send should succeed');
        System.assertEquals(1, [
            SELECT COUNT() FROM OA_Communication_Preference_Token__c WHERE Lead__c = :ld.Id
        ], 'Exactly one campaign-scoped token should be minted');
        String html = OA_EmailSender.lastBuiltEmails[0].getHtmlBody();
        System.assert(html.contains('/oa/unsubscribe?t='), 'HTML must contain tokenized HTTPS link: ' + html);
        System.assert(!html.contains('%%OA_UNSUBSCRIBE_URL%%'), 'Placeholder must be replaced in HTML');
        System.assert(!html.contains('mailto:lrubino'), 'Should not fall back to mailto when context present');
        String text = OA_EmailSender.lastBuiltEmails[0].getPlainTextBody();
        System.assert(text.contains('/oa/unsubscribe?t='), 'Plain text must contain tokenized link');
    }

    @isTest
    static void testLegacyFallbackWhenCampaignContextMissing() {
        Id owaId = getOrgWideEmailAddressId();
        if (owaId == null) return;
        setSendCap(200, 0);

        Lead ld = new Lead(FirstName = 'Fb', LastName = 'Tester', Company = 'Fb Co',
            Email = 'fb.tester@example.com', Status = 'Open - Not Contacted');
        insert ld;

        OA_EmailSender.EmailRequest req = new OA_EmailSender.EmailRequest();
        req.leadId = ld.Id;
        req.templateApiName = 'SeamIgnored';
        req.orgWideEmailAddressId = String.valueOf(owaId);
        // campaignId / campaignMemberId intentionally omitted

        OA_EmailSender.testHtmlOverride = '<a href="%%OA_UNSUBSCRIBE_URL%%">unsubscribe</a>';

        Test.startTest();
        OA_EmailSender.sendEmailToLeadWithResults(new List<OA_EmailSender.EmailRequest>{ req });
        Test.stopTest();

        String html = OA_EmailSender.lastBuiltEmails[0].getHtmlBody();
        System.assert(html.contains('mailto:lrubino'), 'Missing campaign context must fall back to mailto: ' + html);
        System.assertEquals(0, [
            SELECT COUNT() FROM OA_Communication_Preference_Token__c WHERE Lead__c = :ld.Id
        ], 'No token should be minted without campaign context');
    }

    /**
     * The compliance guard: an opted-out Lead must never be emailed by ANY send path, and
     * must not burn daily send capacity. It is dropped from the result map rather than
     * marked true/false, so the follow-up scheduler neither advances its CampaignMember to
     * a "Sent" status it never earned nor retries it forever.
     */
    @isTest
    static void testOptedOutLeadIsSuppressedAtTheChokePoint() {
        OA_EmailSender.bypassActualSendForTest = true;
        setSendCap(100, 0);

        List<Lead> leads = makeLeads(2);
        leads[0].HasOptedOutOfEmail = true;
        update leads[0];

        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'EDWOSB_Sub_Prospect_Email_1', getOrgWideEmailAddressId());

        Test.startTest();
        Map<String, Boolean> results = OA_EmailSender.sendEmailToLeadWithResults(requests);
        Test.stopTest();

        System.assert(!results.containsKey(leads[0].Id),
            'Opted-out Lead must be dropped from the result map, not reported sent or failed');
        System.assertEquals(true, results.get(leads[1].Id),
            'A sendable Lead in the same batch must still be sent');
        System.assertEquals(1, results.size(), 'Only the sendable Lead should have a result');
        System.assertEquals(1, (Integer) OA_Campaign_Settings__c.getOrgDefaults().Sends_Today__c,
            'Suppressed Lead must not consume daily send capacity');
    }

    /** A batch that is entirely opted out must send nothing and reserve nothing. */
    @isTest
    static void testAllOptedOutBatchSendsNothingAndThrowsNothing() {
        OA_EmailSender.bypassActualSendForTest = true;
        setSendCap(100, 0);

        List<Lead> leads = makeLeads(2);
        for (Lead l : leads) l.HasOptedOutOfEmail = true;
        update leads;

        List<OA_EmailSender.EmailRequest> requests =
            makeRequests(leads, 'EDWOSB_Sub_Prospect_Email_1', getOrgWideEmailAddressId());

        Test.startTest();
        // Invocable path: suppression is a deliberate skip, so it must NOT raise.
        OA_EmailSender.sendEmailToLead(requests);
        Test.stopTest();

        System.assertEquals(0, (Integer) OA_Campaign_Settings__c.getOrgDefaults().Sends_Today__c,
            'A fully opted-out batch must reserve no send capacity');
    }
}