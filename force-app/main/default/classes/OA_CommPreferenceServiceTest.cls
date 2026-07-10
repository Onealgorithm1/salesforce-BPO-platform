@IsTest(SeeAllData=false)
private class OA_CommPreferenceServiceTest {
    private class TestContext {
        Lead lead;
        Campaign campaign;
        CampaignMember campaignMember;
        String rawToken;
        Id tokenId;
    }

    private static TestContext makeContext(Datetime expiresAt) {
        Lead lead = new Lead(
            FirstName = 'Comm',
            LastName = 'Tester',
            Company = 'Comm Test Co',
            Email = 'Comm.Tester@Example.com',
            LeadSource = 'SAM.gov'
        );
        insert lead;

        Campaign campaign = new Campaign(Name = 'Comm Preference Test Campaign', IsActive = true);
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
    static void testValidTokenUnsubscribesLeadAndCampaignMember() {
        TestContext ctx = makeContext(System.now().addDays(30));

        Test.startTest();
        OA_CommPreferenceService.UnsubscribeResult result =
            OA_CommPreferenceService.unsubscribeByToken(ctx.rawToken, '{"source":"unit-test"}');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Valid token should process successfully.');
        System.assertEquals(false, result.noChange, 'First valid request should change state.');

        Lead updatedLead = [
            SELECT HasOptedOutOfEmail
            FROM Lead
            WHERE Id = :ctx.lead.Id
        ];
        System.assertEquals(true, updatedLead.HasOptedOutOfEmail, 'Lead should be globally opted out.');

        CampaignMember updatedCm = [
            SELECT Status
            FROM CampaignMember
            WHERE Id = :ctx.campaignMember.Id
        ];
        System.assertEquals('Unsubscribed', updatedCm.Status, 'CampaignMember should be unsubscribed.');

        OA_Communication_Preference__c pref = [
            SELECT Lead__c, Campaign__c, CampaignMember__c, Normalized_Email__c,
                   Channel__c, Scope__c, Preference_Status__c, Source__c
            FROM OA_Communication_Preference__c
            WHERE Lead__c = :ctx.lead.Id
            LIMIT 1
        ];
        System.assertEquals(ctx.campaign.Id, pref.Campaign__c);
        System.assertEquals(String.valueOf(ctx.campaignMember.Id), pref.CampaignMember__c);
        System.assertEquals('comm.tester@example.com', pref.Normalized_Email__c);
        System.assertEquals('Email', pref.Channel__c);
        System.assertEquals('Campaign', pref.Scope__c);
        System.assertEquals('Unsubscribed', pref.Preference_Status__c);
        System.assertEquals('HTTPS Link', pref.Source__c);

        OA_Communication_Preference_Audit__c audit = [
            SELECT Preference__c, Token__c, Event_Type__c, Result__c,
                   Prior_Lead_Opt_Out__c, New_Lead_Opt_Out__c,
                   Prior_CampaignMember_Status__c, New_CampaignMember_Status__c
            FROM OA_Communication_Preference_Audit__c
            WHERE Id = :result.auditId
        ];
        System.assertEquals(pref.Id, audit.Preference__c);
        System.assertEquals(ctx.tokenId, audit.Token__c);
        System.assertEquals('Unsubscribe Requested', audit.Event_Type__c);
        System.assertEquals('Success', audit.Result__c);
        System.assertEquals(false, audit.Prior_Lead_Opt_Out__c);
        System.assertEquals(true, audit.New_Lead_Opt_Out__c);
        System.assertEquals('Sent', audit.Prior_CampaignMember_Status__c);
        System.assertEquals('Unsubscribed', audit.New_CampaignMember_Status__c);

        OA_Communication_Preference_Token__c token = [
            SELECT Status__c, Use_Count__c, Last_Audit__c, Last_Used_At__c
            FROM OA_Communication_Preference_Token__c
            WHERE Id = :ctx.tokenId
        ];
        System.assertEquals('Used', token.Status__c);
        System.assertEquals(1, token.Use_Count__c);
        System.assertEquals(result.auditId, token.Last_Audit__c);
        System.assertNotEquals(null, token.Last_Used_At__c);
    }

    @IsTest
    static void testRepeatedClickIsIdempotent() {
        TestContext ctx = makeContext(System.now().addDays(30));

        OA_CommPreferenceService.unsubscribeByToken(ctx.rawToken, '{"attempt":1}');
        OA_CommPreferenceService.UnsubscribeResult secondResult =
            OA_CommPreferenceService.unsubscribeByToken(ctx.rawToken, '{"attempt":2}');

        System.assertEquals(true, secondResult.success);
        System.assertEquals(true, secondResult.noChange, 'Repeated click should be a no-op state change.');
        System.assertEquals(1, [
            SELECT COUNT()
            FROM OA_Communication_Preference__c
            WHERE Lead__c = :ctx.lead.Id
        ], 'Repeated click should not create duplicate preference records.');
        System.assertEquals(2, [
            SELECT COUNT()
            FROM OA_Communication_Preference_Audit__c
            WHERE Lead__c = :ctx.lead.Id
        ], 'Repeated click should still create a second audit event.');

        OA_Communication_Preference_Token__c token = [
            SELECT Status__c, Use_Count__c
            FROM OA_Communication_Preference_Token__c
            WHERE Id = :ctx.tokenId
        ];
        System.assertEquals('Used', token.Status__c);
        System.assertEquals(2, token.Use_Count__c);
    }

    @IsTest
    static void testExpiredTokenWritesRejectedAuditWithoutStateChange() {
        TestContext ctx = makeContext(System.now().addMinutes(-5));

        OA_CommPreferenceService.UnsubscribeResult result =
            OA_CommPreferenceService.unsubscribeByToken(ctx.rawToken, '{"expired":true}');

        System.assertEquals(false, result.success);
        System.assertEquals(true, result.noChange);

        Lead lead = [
            SELECT HasOptedOutOfEmail
            FROM Lead
            WHERE Id = :ctx.lead.Id
        ];
        System.assertEquals(false, lead.HasOptedOutOfEmail, 'Expired token must not opt out Lead.');

        CampaignMember cm = [
            SELECT Status
            FROM CampaignMember
            WHERE Id = :ctx.campaignMember.Id
        ];
        System.assertEquals('Sent', cm.Status, 'Expired token must not update CampaignMember.');

        OA_Communication_Preference_Audit__c audit = [
            SELECT Event_Type__c, Result__c, Token__c
            FROM OA_Communication_Preference_Audit__c
            WHERE Id = :result.auditId
        ];
        System.assertEquals('Expired Token', audit.Event_Type__c);
        System.assertEquals('Rejected', audit.Result__c);
        System.assertEquals(ctx.tokenId, audit.Token__c);

        OA_Communication_Preference_Token__c token = [
            SELECT Status__c, Use_Count__c, Last_Audit__c
            FROM OA_Communication_Preference_Token__c
            WHERE Id = :ctx.tokenId
        ];
        System.assertEquals('Expired', token.Status__c);
        System.assertEquals(1, token.Use_Count__c);
        System.assertEquals(result.auditId, token.Last_Audit__c);
    }

    @IsTest
    static void testInvalidTokenWritesRejectedAudit() {
        OA_CommPreferenceService.UnsubscribeResult result =
            OA_CommPreferenceService.unsubscribeByToken('invalid-token-value', '{"invalid":true}');

        System.assertEquals(false, result.success);
        System.assertEquals(true, result.noChange);

        OA_Communication_Preference_Audit__c audit = [
            SELECT Event_Type__c, Result__c, Token__c, Message__c
            FROM OA_Communication_Preference_Audit__c
            WHERE Id = :result.auditId
        ];
        System.assertEquals('Invalid Token', audit.Event_Type__c);
        System.assertEquals('Rejected', audit.Result__c);
        System.assertEquals(null, audit.Token__c);
        System.assert(audit.Message__c.contains('No matching token'), 'Audit should explain invalid token.');
    }

    @IsTest
    static void testUnsubscribeByHashValidAndInvalid() {
        TestContext ctx = makeContext(System.now().addDays(30));
        String tokenHash = OA_UnsubscribeTokenService.hashToken(ctx.rawToken);

        OA_CommPreferenceService.UnsubscribeResult valid =
            OA_CommPreferenceService.unsubscribeByHash(tokenHash, '{"source":"hash-test"}');
        System.assertEquals(true, valid.success, 'Valid hash should process successfully.');
        System.assertEquals(true, [
            SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :ctx.lead.Id
        ].HasOptedOutOfEmail);
        System.assertEquals('Unsubscribed', [
            SELECT Status FROM CampaignMember WHERE Id = :ctx.campaignMember.Id
        ].Status);

        OA_CommPreferenceService.UnsubscribeResult invalid =
            OA_CommPreferenceService.unsubscribeByHash('no-such-hash', '{"source":"hash-test"}');
        System.assertEquals(false, invalid.success, 'Unknown hash should be rejected.');
        System.assertEquals(null, invalid.tokenId);
    }
}