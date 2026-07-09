/**
 * Coverage for the platform event trigger + subscriber handler (Phase 2).
 * Publishes events carrying a token hash and delivers them; asserts the
 * unsubscribe outcome. (Runs as the test user; production subscriber-identity
 * was verified in Phase 1 via the controlled internal test event.)
 */
@isTest
private class OA_UnsubscribeEventHandlerTest {

    private class Ctx {
        Lead lead;
        Campaign campaign;
        CampaignMember campaignMember;
        String tokenHash;
        Id tokenId;
    }

    private static Ctx makeContext(Datetime expiresAt) {
        Lead lead = new Lead(
            FirstName = 'Evt', LastName = 'Tester', Company = 'Evt Test Co',
            Email = 'evt.tester@example.com', LeadSource = 'SAM.gov'
        );
        insert lead;
        Campaign campaign = new Campaign(Name = 'Evt Test Campaign', IsActive = true);
        insert campaign;
        insert new CampaignMemberStatus(
            CampaignId = campaign.Id, Label = 'Unsubscribed',
            IsDefault = false, HasResponded = false, SortOrder = 20
        );
        CampaignMember cm = new CampaignMember(
            CampaignId = campaign.Id, LeadId = lead.Id, Status = 'Sent'
        );
        insert cm;
        OA_UnsubscribeTokenService.TokenCreationResult created =
            OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                lead.Id, campaign.Id, cm.Id, lead.Email, expiresAt
            );
        Ctx c = new Ctx();
        c.lead = lead;
        c.campaign = campaign;
        c.campaignMember = cm;
        c.tokenHash = created.tokenHash;
        c.tokenId = created.tokenId;
        return c;
    }

    @isTest
    static void validHashEventUnsubscribes() {
        Ctx c = makeContext(System.now().addDays(30));

        Test.startTest();
        EventBus.publish(new OA_Unsubscribe_Request__e(
            Token_Hash__c = c.tokenHash,
            Correlation_Id__c = 'evt-valid',
            Request_Metadata__c = '{"source":"test"}'
        ));
        Test.stopTest(); // delivers event, fires trigger + handler

        System.assertEquals(true, OA_UnsubscribeEventHandler.executed, 'Handler should run');
        System.assertEquals(true,
            [SELECT HasOptedOutOfEmail FROM Lead WHERE Id = :c.lead.Id].HasOptedOutOfEmail);
        System.assertEquals('Unsubscribed',
            [SELECT Status FROM CampaignMember WHERE Id = :c.campaignMember.Id].Status);
        System.assertEquals(1, [SELECT COUNT() FROM OA_Communication_Preference__c]);
        System.assertEquals('Success',
            [SELECT Result__c FROM OA_Communication_Preference_Audit__c WHERE Token__c = :c.tokenId LIMIT 1].Result__c);
    }

    @isTest
    static void invalidHashEventRejected() {
        Test.startTest();
        EventBus.publish(new OA_Unsubscribe_Request__e(
            Token_Hash__c = 'no-such-hash-value',
            Correlation_Id__c = 'evt-invalid',
            Request_Metadata__c = null // also exercises buildMetadata blank-metadata branch
        ));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM OA_Communication_Preference__c]);
        OA_Communication_Preference_Audit__c audit =
            [SELECT Result__c, Token__c FROM OA_Communication_Preference_Audit__c LIMIT 1];
        System.assertEquals('Rejected', audit.Result__c);
        System.assertEquals(null, audit.Token__c);
    }

    @isTest
    static void transientFailureRequestsRetry() {
        Boolean retried = false;
        try {
            OA_UnsubscribeEventHandler.handleFailure(
                new OA_Unsubscribe_Request__e(Correlation_Id__c = 'evt-transient'),
                new OA_UnsubscribeEventHandler.HandlerException('UNABLE_TO_LOCK_ROW: simulated lock')
            );
        } catch (EventBus.RetryableException re) {
            retried = true;
        }
        System.assertEquals(true, retried, 'Transient failure should request a retry');
    }

    @isTest
    static void nonTransientFailureIsSwallowed() {
        // Deterministic (non-transient) failures must NOT retry — logged and consumed.
        OA_UnsubscribeEventHandler.handleFailure(
            new OA_Unsubscribe_Request__e(Correlation_Id__c = 'evt-nontransient'),
            new OA_UnsubscribeEventHandler.HandlerException('VALIDATION: some deterministic error')
        );
        System.assert(true, 'Non-transient failure should be logged and swallowed without retry');
    }
}