@IsTest(SeeAllData=false)
private class OA_UnsubscribeTokenServiceTest {
    private class TestContext {
        Lead lead;
        Campaign campaign;
        CampaignMember campaignMember;
    }

    private static TestContext makeContext() {
        Lead lead = new Lead(
            FirstName = 'Token',
            LastName = 'Tester',
            Company = 'Token Test Co',
            Email = ' Token.Tester@Example.com ',
            LeadSource = 'SAM.gov'
        );
        insert lead;

        Campaign campaign = new Campaign(Name = 'Token Test Campaign', IsActive = true);
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

        TestContext ctx = new TestContext();
        ctx.lead = lead;
        ctx.campaign = campaign;
        ctx.campaignMember = cm;
        return ctx;
    }

    @IsTest
    static void testCreateTokenStoresHashOnlyAndValidates() {
        TestContext ctx = makeContext();

        OA_UnsubscribeTokenService.TokenCreationResult created =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                ctx.lead.Id,
                ctx.campaign.Id,
                ctx.campaignMember.Id,
                ctx.lead.Email,
                System.now().addDays(30)
            );

        System.assertNotEquals(null, created.rawToken, 'Raw token should be returned to the caller.');
        System.assertNotEquals(null, created.tokenId, 'Token record should be inserted.');
        System.assertNotEquals(created.rawToken, created.tokenHash, 'Stored hash must not equal raw token.');

        OA_Communication_Preference_Token__c token = [
            SELECT Token_Hash__c, Normalized_Email__c, Status__c, Use_Count__c
            FROM OA_Communication_Preference_Token__c
            WHERE Id = :created.tokenId
        ];
        System.assertEquals(created.tokenHash, token.Token_Hash__c, 'Token hash should be stored.');
        System.assertEquals('token.tester@example.com', token.Normalized_Email__c);
        System.assertEquals('Active', token.Status__c);
        System.assertEquals(0, token.Use_Count__c);

        OA_UnsubscribeTokenService.TokenValidationResult validation =
            OA_UnsubscribeTokenService.validateToken(created.rawToken);
        System.assertEquals(true, validation.isValid, 'Fresh token should validate.');
        System.assertEquals('Unsubscribe Requested', validation.eventType);
        System.assertEquals(created.tokenId, validation.token.Id);
    }

    @IsTest
    static void testValidateRejectsBlankAndUnknownToken() {
        OA_UnsubscribeTokenService.TokenValidationResult blankResult =
            OA_UnsubscribeTokenService.validateToken(null);
        System.assertEquals(false, blankResult.isValid);
        System.assertEquals('Invalid Token', blankResult.eventType);

        OA_UnsubscribeTokenService.TokenValidationResult unknownResult =
            OA_UnsubscribeTokenService.validateToken('not-a-real-token');
        System.assertEquals(false, unknownResult.isValid);
        System.assertEquals('Invalid Token', unknownResult.eventType);
        System.assertEquals(null, unknownResult.token);
    }

    @IsTest
    static void testValidateRejectsExpiredAndRevokedTokens() {
        TestContext ctx = makeContext();

        OA_UnsubscribeTokenService.TokenCreationResult expired =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                ctx.lead.Id,
                ctx.campaign.Id,
                ctx.campaignMember.Id,
                ctx.lead.Email,
                System.now().addMinutes(-5)
            );
        OA_UnsubscribeTokenService.TokenValidationResult expiredResult =
            OA_UnsubscribeTokenService.validateToken(expired.rawToken);
        System.assertEquals(false, expiredResult.isValid);
        System.assertEquals('Expired Token', expiredResult.eventType);

        OA_UnsubscribeTokenService.TokenCreationResult revoked =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                ctx.lead.Id,
                ctx.campaign.Id,
                ctx.campaignMember.Id,
                ctx.lead.Email,
                System.now().addDays(30)
            );
        update new OA_Communication_Preference_Token__c(
            Id = revoked.tokenId,
            Status__c = 'Revoked'
        );

        OA_UnsubscribeTokenService.TokenValidationResult revokedResult =
            OA_UnsubscribeTokenService.validateToken(revoked.rawToken);
        System.assertEquals(false, revokedResult.isValid);
        System.assertEquals('Revoked Token', revokedResult.eventType);
    }

    @IsTest
    static void testValidateTokenByHashMatchesRawTokenPath() {
        TestContext ctx = makeContext();

        OA_UnsubscribeTokenService.TokenCreationResult created =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                ctx.lead.Id,
                ctx.campaign.Id,
                ctx.campaignMember.Id,
                ctx.lead.Email,
                System.now().addDays(30)
            );

        OA_UnsubscribeTokenService.TokenValidationResult byHash =
            OA_UnsubscribeTokenService.validateTokenByHash(created.tokenHash);
        System.assertEquals(true, byHash.isValid, 'Hash of a fresh token should validate.');
        System.assertEquals('Unsubscribe Requested', byHash.eventType);
        System.assertEquals(created.tokenId, byHash.token.Id);

        OA_UnsubscribeTokenService.TokenValidationResult blank =
            OA_UnsubscribeTokenService.validateTokenByHash(null);
        System.assertEquals(false, blank.isValid, 'Blank hash should not validate.');

        OA_UnsubscribeTokenService.TokenValidationResult unknown =
            OA_UnsubscribeTokenService.validateTokenByHash('no-such-hash');
        System.assertEquals(false, unknown.isValid, 'Unknown hash should not validate.');
        System.assertEquals(null, unknown.token);
    }
}