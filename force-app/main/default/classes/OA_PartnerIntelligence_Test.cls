@IsTest
private class OA_PartnerIntelligence_Test {
    private class Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse(); res.setStatusCode(200);
            res.setBody('{"model":"openai/gpt-4o-mini","choices":[{"message":{"content":"===SUMMARY===\nCloud partner.\n===STRENGTHS===\n- cloud\n===WEAKNESSES===\n- w\n===GAPS===\n- missing past performance"}}],"usage":{"prompt_tokens":40,"completion_tokens":20,"total_tokens":60}}');
            return res;
        }
    }

    @IsTest
    static void investmentIsDistinctThirdLayer() {
        OA_Opportunity_Signal__c hi = new OA_Opportunity_Signal__c(Source__c='SAM.gov', Type__c='Contract', Review_Status__c='Pending',
            Qualification_Decision__c='GO', Fit_Score__c=80, Effort_Score__c=30, Urgency_Score__c=80, Estimated_Value__c=2000000, Canonical_Key__c='i:hi');
        OA_Opportunity_Signal__c lo = new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant', Review_Status__c='Pending',
            Qualification_Decision__c='NO-GO', Fit_Score__c=5, Effort_Score__c=90, Urgency_Score__c=30, Canonical_Key__c='i:lo');
        insert new List<OA_Opportunity_Signal__c>{ hi, lo };
        Test.startTest();
        OA_PursuitInvestment.evaluate(new List<Id>{ hi.Id, lo.Id });
        Test.stopTest();
        Map<Id,OA_Opportunity_Signal__c> m = new Map<Id,OA_Opportunity_Signal__c>([SELECT Investment_Level__c, Win_Probability__c,
            Investment_Rationale__c, Review_Status__c FROM OA_Opportunity_Signal__c WHERE Id IN (:hi.Id,:lo.Id)]);
        System.assertEquals('HIGH', m.get(hi.Id).Investment_Level__c, 'strong GO + value -> HIGH investment');
        System.assertEquals('LOW', m.get(lo.Id).Investment_Level__c, 'NO-GO -> LOW investment (do not spend)');
        System.assert(m.get(hi.Id).Win_Probability__c > m.get(lo.Id).Win_Probability__c, 'win prob differentiated');
        System.assertEquals('Pending', m.get(hi.Id).Review_Status__c, 'advisory — human-gated');
    }

    @IsTest
    static void partnerAiEnrichmentGrounded() {
        OA_Company_Profile__c partner = new OA_Company_Profile__c(Organization_Name__c='CloudCo', Profile_Type__c='Partner',
            Status__c='Active', Capabilities__c='cloud infrastructure; data analytics');
        insert partner;
        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter','openai/gpt-4o-mini','Anthropic','claude-sonnet-4-6',256) };
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        OA_Company_Profile__c enriched = OA_PartnerIntelligence.enrichProfile(partner.Id);
        Test.stopTest();
        OA_Company_Profile__c saved = [SELECT AI_Company_Summary__c, Last_AI_Refresh__c FROM OA_Company_Profile__c WHERE Id = :partner.Id];
        System.assertNotEquals(null, saved.AI_Company_Summary__c, 'partner AI summary written through the gateway');
        System.assertNotEquals(null, saved.Last_AI_Refresh__c, 'enrichment executed + refresh timestamp set');
    }
}