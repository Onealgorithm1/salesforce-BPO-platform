@isTest
private class OA_DiscoveryQualificationEngine_Test {

    private static void seedRule() {
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            new OA_Qualification_Rule__mdt(Ruleset__c='TEST', Criterion_Type__c='Active',
                Source_Field__c='Registration_Status', Operator__c='equals', Compare_Value__c='Active',
                Weight__c=1, Required__c=true, Ruleset_Threshold__c=1, Active__c=true) };
    }

    private static OA_CanonicalOrg org(String name, String regStatus) {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.organizationName = name;
        o.attributes.put('Registration_Status', regStatus);
        return o;
    }

    @isTest
    static void testQualifiedNoMatchDoesNotCreate() {
        seedRule();
        OA_DiscoveryQualificationEngine.Recommendation rec =
            OA_DiscoveryQualificationEngine.evaluate(org('ZZUniqueDiscoCo', 'Active'), 'TEST');
        System.assertEquals('Qualified', rec.qualificationStatus, 'Qualified');
        System.assertEquals(null, rec.matchedRecordId, 'No CRM match');
        System.assertEquals('CREATE_LEAD_CANDIDATE', rec.recommendedAction, 'Recommend candidate');
        System.assert(!rec.wouldCreate, 'Auto-create dormant -> would not create');
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Company = 'ZZUniqueDiscoCo'],
            'No Lead was created by the engine');
    }

    @isTest
    static void testAutoCreateOverrideWouldCreate() {
        seedRule();
        OA_DiscoveryQualificationEngine.autoCreateEnabledOverride = true;
        OA_DiscoveryQualificationEngine.Recommendation rec =
            OA_DiscoveryQualificationEngine.evaluate(org('ZZUniqueDiscoCo2', 'Active'), 'TEST');
        System.assert(rec.autoCreateEnabled, 'Override on');
        System.assert(rec.wouldCreate, 'Would create when enabled + qualified + unmatched');
        // still no actual insert
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Company = 'ZZUniqueDiscoCo2'], 'Still no insert');
    }

    @isTest
    static void testMatchExistingLead() {
        seedRule();
        insert new Lead(LastName='T', Company='MatchDiscoCo', Email='m@example.com');
        OA_DiscoveryQualificationEngine.Recommendation rec =
            OA_DiscoveryQualificationEngine.evaluate(org('MatchDiscoCo', 'Active'), 'TEST');
        System.assertNotEquals(null, rec.matchedRecordId, 'Matched a Lead');
        System.assertEquals('Lead', rec.matchedObject, 'Matched object');
        System.assertEquals('ENRICH_EXISTING', rec.recommendedAction, 'Enrich existing');
        System.assertEquals('MEDIUM', rec.confidenceBand, 'Name match -> MEDIUM');
    }

    @isTest
    static void testMatchExistingAccountAndNotQualified() {
        seedRule();
        insert new Account(Name='AcctDiscoCo');
        OA_DiscoveryQualificationEngine.Recommendation rec =
            OA_DiscoveryQualificationEngine.evaluate(org('AcctDiscoCo', 'Active'), 'TEST');
        System.assertEquals('Account', rec.matchedObject, 'Matched an Account');

        OA_DiscoveryQualificationEngine.Recommendation nq =
            OA_DiscoveryQualificationEngine.evaluate(org('ZZNotQualCo', 'Inactive'), 'TEST');
        System.assertEquals('NotQualified', nq.qualificationStatus, 'Required rule fails');
        System.assertEquals('RETAIN_DISCOVERY', nq.recommendedAction, 'Retain');
    }
}