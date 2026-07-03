@IsTest(SeeAllData=false)
private class OA_UnsubscribeEndpointTest {
    private class TestContext {
        Lead lead;
        Campaign campaign;
        CampaignMember campaignMember;
        String rawToken;
        Id tokenId;
    }

    private static TestContext makeContext(Datetime expiresAt) {
        Lead lead = new Lead(
            FirstName = 'Endpoint',
            LastName = 'Tester',
            Company = 'Endpoint Test Co',
            Email = 'Endpoint.Tester@Example.com',
            LeadSource = 'SAM.gov'
        );
        insert lead;

        Campaign campaign = new Campaign(Name = 'Endpoint Test Campaign', IsActive = true);
        insert campaign;

        insert new CampaignMemberStatus(
            CampaignId = campaign.Id,
            Label = 'Unsubscribed',
            IsDefault = false,
            HasResponded = false,
            SortOrder = 20
        );

        CampaignMember cm = new CampaignMember(
            CampaignId = campaign.Id,
            LeadId = lead.Id,
            Status = 'Sent'
        );
        insert cm;

        OA_UnsubscribeTokenService.TokenCreationResult created =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                lead.Id,
                campaign.Id,
                cm.Id,
                lead.Email,
                expiresAt
            );

        TestContext ctx = new TestContext();
        ctx.lead = lead;
        ctx.campaign = campaign;
        ctx.campaignMember = cm;
        ctx.rawToken = created.rawToken;
        ctx.tokenId = created.tokenId;
        return ctx;
    }

    @IsTest
    static void getDoesNotMutate() {
        TestContext ctx = makeContext(System.now().addDays(30));
        setRequest('GET', ctx.rawToken);

        Test.startTest();
        OA_UnsubscribeEndpoint.doGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(false, [
            SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :ctx.lead.Id
        ].HasOptedOutOfEmail);
        System.assertEquals('Sent', [
            SELECT Status FROM CampaignMember WHERE Id = :ctx.campaignMember.Id
        ].Status);
        System.assertEquals(0, [
            SELECT Use_Count__c FROM OA_Communication_Preference_Token__c WHERE Id = :ctx.tokenId
        ].Use_Count__c);
        System.assertEquals(0, [SELECT COUNT() FROM OA_Communication_Preference__c]);
        System.assertEquals(0, [SELECT COUNT() FROM OA_Communication_Preference_Audit__c]);
    }

    @IsTest
    static void postValidTokenPublishesThenUnsubscribes() {
        TestContext ctx = makeContext(System.now().addDays(30));
        setRequest('POST', ctx.rawToken);

        OA_UnsubscribeEndpoint.doPost();

        // Endpoint accepts and publishes; NO synchronous business mutation.
        System.assertEquals(202, RestContext.response.statusCode, 'POST should return 202 Accepted');
        System.assertEquals(false, [
            SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :ctx.lead.Id
        ].HasOptedOutOfEmail, 'No synchronous Lead mutation');

        Test.getEventBus().deliver(); // async subscriber applies the unsubscribe

        System.assertEquals(true, [
            SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :ctx.lead.Id
        ].HasOptedOutOfEmail);
        System.assertEquals('Unsubscribed', [
            SELECT Status FROM CampaignMember WHERE Id = :ctx.campaignMember.Id
        ].Status);
        System.assertEquals(1, [SELECT COUNT() FROM OA_Communication_Preference__c]);

        OA_Communication_Preference_Audit__c audit = [
            SELECT Request_Metadata__c, Result__c
            FROM OA_Communication_Preference_Audit__c
            WHERE Token__c = :ctx.tokenId
            LIMIT 1
        ];
        System.assertEquals('Success', audit.Result__c);
        System.assert(!audit.Request_Metadata__c.contains(ctx.rawToken), 'Raw token must not be stored.');
    }

    @IsTest
    static void postRepeatedTokenIsIdempotent() {
        TestContext ctx = makeContext(System.now().addDays(30));

        setRequest('POST', ctx.rawToken);
        OA_UnsubscribeEndpoint.doPost();
        Test.getEventBus().deliver();

        setRequest('POST', ctx.rawToken);
        OA_UnsubscribeEndpoint.doPost();
        Test.getEventBus().deliver();

        System.assertEquals(202, RestContext.response.statusCode);
        System.assertEquals(1, [SELECT COUNT() FROM OA_Communication_Preference__c]);
        System.assertEquals(2, [SELECT COUNT() FROM OA_Communication_Preference_Audit__c]);
        System.assertEquals(2, [
            SELECT Use_Count__c FROM OA_Communication_Preference_Token__c WHERE Id = :ctx.tokenId
        ].Use_Count__c);
    }

    @IsTest
    static void postExpiredTokenRejectsAsync() {
        TestContext ctx = makeContext(System.now().addMinutes(-5));
        setRequest('POST', ctx.rawToken);

        OA_UnsubscribeEndpoint.doPost();
        System.assertEquals(202, RestContext.response.statusCode, 'Endpoint accepts; validity decided async');

        Test.getEventBus().deliver();

        System.assertEquals(false, [
            SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :ctx.lead.Id
        ].HasOptedOutOfEmail);
        System.assertEquals('Sent', [
            SELECT Status FROM CampaignMember WHERE Id = :ctx.campaignMember.Id
        ].Status);
        System.assertEquals('Rejected', [
            SELECT Result__c FROM OA_Communication_Preference_Audit__c WHERE Token__c = :ctx.tokenId
        ].Result__c);
    }

    @IsTest
    static void postInvalidTokenRejectsAsync() {
        String rawToken = 'not-a-real-token';
        setRequest('POST', rawToken);

        OA_UnsubscribeEndpoint.doPost();
        System.assertEquals(202, RestContext.response.statusCode);

        Test.getEventBus().deliver();

        OA_Communication_Preference_Audit__c audit = [
            SELECT Request_Metadata__c, Result__c, Token__c
            FROM OA_Communication_Preference_Audit__c
            LIMIT 1
        ];
        System.assertEquals('Rejected', audit.Result__c);
        System.assertEquals(null, audit.Token__c);
        System.assert(!audit.Request_Metadata__c.contains(rawToken), 'Raw token must not be stored.');
    }

    @IsTest
    static void postBlankTokenReturns400() {
        setRequest('POST', null);
        OA_UnsubscribeEndpoint.doPost();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM OA_Communication_Preference_Audit__c]);
    }

    private static void setRequest(String method, String token) {
        RestRequest request = new RestRequest();
        request.httpMethod = method;
        request.requestURI = '/services/apexrest/oa/unsubscribe';
        if (token != null) {
            request.params.put('t', token);
        }
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }
}
