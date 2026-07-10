/**
 * OA_OpportunityIntelligence_Test — proves the OI engine end-to-end with a mocked gateway callout.
 * Verifies: deterministic scores populate, AI narrative is captured, exactly one Draft record is written,
 * telemetry is aggregated, and the Opportunity is never modified (governance).
 */
@IsTest
private class OA_OpportunityIntelligence_Test {

    private class MockOR implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"model":"openai/gpt-4o-mini","choices":[{"message":{"content":"Grounded narrative from the provided facts."}}],"usage":{"prompt_tokens":40,"completion_tokens":20,"total_tokens":60}}');
            return res;
        }
    }

    @IsTest
    static void generatesGovernedDraftAssessment() {
        Account a = new Account(Name = 'Pilot Co');
        insert a;
        Campaign c = new Campaign(Name = 'Pilot Campaign', IsActive = true);
        insert c;
        Opportunity opp = new Opportunity(
            Name = 'Pilot Teaming Opportunity', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(45), Probability = 10,
            LeadSource = 'SAM.gov', AccountId = a.Id, CampaignId = c.Id
        );
        insert opp;
        insert new OpportunityContactRole(OpportunityId = opp.Id,
            ContactId = insertContact(a.Id), Role = 'Decision Maker', IsPrimary = true);

        // Force a known route and mock the provider callout
        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'openai/gpt-4o-mini', 'Anthropic', 'claude-sonnet-4-6', 256)
        };
        Test.setMock(HttpCalloutMock.class, new MockOR());

        Test.startTest();
        OA_Opportunity_Intelligence__c oi = OA_OpportunityIntelligence.generate(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, oi.Id, 'assessment inserted');
        System.assertEquals('Draft', [SELECT Status__c FROM OA_Opportunity_Intelligence__c WHERE Id = :oi.Id].Status__c, 'system writes Draft only');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Opportunity_Intelligence__c WHERE Opportunity__c = :opp.Id], 'exactly one record');
        System.assert(oi.Composite_Score__c != null && oi.Composite_Score__c > 0, 'deterministic composite computed');
        System.assert(oi.Source_Quality__c >= 80, 'SAM.gov scored as governed federal source');
        System.assertNotEquals(null, oi.AI_Executive_Brief__c, 'AI narrative captured');
        System.assert(oi.AI_Total_Tokens__c > 0, 'telemetry aggregated across gateway calls');
        System.assertNotEquals(null, oi.Recommended_Action__c, 'recommended action set');

        // Governance: Opportunity untouched
        Opportunity after = [SELECT StageName, Amount, Probability FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Prospecting', after.StageName, 'Opportunity stage never changed by OI');
    }

    @IsTest
    static void requiresOpportunityId() {
        Boolean threw = false;
        try { OA_OpportunityIntelligence.generate(null); } catch (OA_OpportunityIntelligence.OIException e) { threw = true; }
        System.assert(threw, 'null opportunityId rejected');
    }

    private static Id insertContact(Id accountId) {
        Contact ct = new Contact(LastName = 'Pilot', AccountId = accountId);
        insert ct;
        return ct.Id;
    }
}