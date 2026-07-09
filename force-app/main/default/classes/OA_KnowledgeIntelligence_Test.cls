/**
 * OA_KnowledgeIntelligence_Test — proves the knowledge service builds a governed Company Profile
 * (deterministic completeness + AI narrative + telemetry) via a mocked gateway, upserts one per
 * account, and never modifies the Account.
 */
@IsTest
private class OA_KnowledgeIntelligence_Test {

    private class MockOR implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"model":"openai/gpt-4o-mini","choices":[{"message":{"content":"===SUMMARY===\\nProfile.\\n===STRENGTHS===\\n- s\\n===WEAKNESSES===\\n- w\\n===GAPS===\\n- missing past performance"}}],"usage":{"prompt_tokens":50,"completion_tokens":30,"total_tokens":80}}');
            return res;
        }
    }

    @IsTest
    static void buildsGovernedProfileAndUpserts() {
        Account a = new Account(Name = 'Partner Co', Industry = 'Professional Services');
        insert a;

        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'openai/gpt-4o-mini', 'Anthropic', 'claude-sonnet-4-6', 256)
        };
        Test.setMock(HttpCalloutMock.class, new MockOR());

        // Pre-existing profile proves upsert-dedup with a single gateway call
        // (one gateway call per transaction: the gateway logs after its callout).
        insert new OA_Company_Profile__c(Account__c = a.Id, Organization_Name__c = 'stale');

        Test.startTest();
        OA_Company_Profile__c p1 = OA_KnowledgeIntelligence.profile(a.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM OA_Company_Profile__c WHERE Account__c = :a.Id], 'upsert — still exactly one profile per account');
        OA_Company_Profile__c saved = [SELECT AI_Company_Summary__c, AI_Gaps__c, Knowledge_Completeness__c, Knowledge_Confidence__c,
            AI_Total_Tokens__c, Profile_Type__c, Organization_Name__c FROM OA_Company_Profile__c WHERE Id = :p1.Id];
        System.assertNotEquals(null, saved.AI_Company_Summary__c, 'AI summary captured');
        System.assert(saved.AI_Gaps__c != null && saved.AI_Gaps__c.contains('past performance'), 'gaps parsed');
        System.assertEquals('Low', saved.Knowledge_Confidence__c, 'sparse profile -> Low confidence');
        System.assert(saved.AI_Total_Tokens__c > 0, 'telemetry captured');
        System.assertEquals('Partner', saved.Profile_Type__c, 'inferred partner');
        System.assertEquals('Partner Co', saved.Organization_Name__c, 'identity reused from account');

        System.assertEquals('Professional Services',
            [SELECT Industry FROM Account WHERE Id = :a.Id].Industry, 'Account never modified by knowledge service');
    }

    @IsTest
    static void infersSelfProfileAndRequiresId() {
        Account us = new Account(Name = 'One Algorithm LLC');
        insert us;
        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'openai/gpt-4o-mini', 'Anthropic', 'claude-sonnet-4-6', 256)
        };
        Test.setMock(HttpCalloutMock.class, new MockOR());
        Test.startTest();
        OA_Company_Profile__c p = OA_KnowledgeIntelligence.profile(us.Id);
        Boolean threw = false;
        try { OA_KnowledgeIntelligence.profile(null); } catch (OA_KnowledgeIntelligence.KnowledgeException e) { threw = true; }
        Test.stopTest();
        System.assertEquals('Self', p.Profile_Type__c, 'One Algorithm inferred as Self');
        System.assert(threw, 'null accountId rejected');
    }
}
