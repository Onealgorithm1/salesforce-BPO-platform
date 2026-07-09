@isTest
private class OA_QualificationRuleEngine_Test {

    private static OA_Qualification_Rule__mdt rule(String field, String op, String cmp,
            Decimal weight, Boolean required, Decimal thr) {
        return new OA_Qualification_Rule__mdt(
            Ruleset__c='TEST', Criterion_Type__c=field, Source_Field__c=field, Operator__c=op,
            Compare_Value__c=cmp, Weight__c=weight, Required__c=required,
            Ruleset_Threshold__c=thr, Active__c=true);
    }

    private static OA_CanonicalOrg org(String regStatus, String bizTypes) {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.organizationName = 'Acme';
        if (regStatus != null) { o.attributes.put('Registration_Status', regStatus); }
        if (bizTypes != null)  { o.attributes.put('Business_Types', bizTypes); }
        return o;
    }

    @isTest
    static void testQualified() {
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            rule('Registration_Status', 'equals', 'Active', 1, true, 2),
            rule('Business_Types', 'contains', 'EDWOSB', 2, false, 2)
        };
        OA_QualificationRuleEngine.Result r = OA_QualificationRuleEngine.evaluate('TEST', org('Active', 'WOSB,EDWOSB'));
        System.assert(r.qualified, 'All required pass + score >= threshold');
        System.assertEquals(3, r.score, 'Weights summed');
    }

    @isTest
    static void testRequiredFailAndNeedsData() {
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            rule('Registration_Status', 'equals', 'Active', 1, true, 0) };
        System.assert(!OA_QualificationRuleEngine.evaluate('TEST', org('Inactive', null)).qualified,
            'Required equals fails');

        OA_QualificationRuleEngine.Result nd = OA_QualificationRuleEngine.evaluate('TEST', org(null, null));
        System.assert(!nd.qualified && nd.needsData, 'Missing required source data -> needsData');
    }

    @isTest
    static void testThresholdNotMet() {
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            rule('Registration_Status', 'equals', 'Active', 0, true, 5) };  // passes required, weight 0
        OA_QualificationRuleEngine.Result r = OA_QualificationRuleEngine.evaluate('TEST', org('Active', null));
        System.assert(!r.qualified, 'Score 0 below threshold 5');
    }

    @isTest
    static void testEmptyRuleset() {
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>();
        OA_QualificationRuleEngine.Result r = OA_QualificationRuleEngine.evaluate('TEST', org('Active', null));
        System.assert(!r.qualified, 'No rules -> not qualified');
        System.assert(!r.reasons.isEmpty(), 'Reason recorded');
    }

    @isTest
    static void testOperators() {
        System.assert(OA_QualificationRuleEngine.applyOperator('exists', 'x', null), 'exists true');
        System.assert(!OA_QualificationRuleEngine.applyOperator('exists', '', null), 'exists blank false');
        System.assert(OA_QualificationRuleEngine.applyOperator('equals', 'VA', 'va'), 'equals ci');
        System.assert(OA_QualificationRuleEngine.applyOperator('contains', 'WOSB,EDWOSB', 'edwosb'), 'contains');
        System.assert(OA_QualificationRuleEngine.applyOperator('in', 'VA', 'MD,VA,DC'), 'in list');
        System.assert(!OA_QualificationRuleEngine.applyOperator('in', 'CA', 'MD,VA,DC'), 'not in list');
        System.assert(OA_QualificationRuleEngine.applyOperator('gte', '10', '5'), 'gte');
        System.assert(OA_QualificationRuleEngine.applyOperator('lte', '3', '5'), 'lte');
        System.assert(OA_QualificationRuleEngine.applyOperator('between', '7', '5,10'), 'between');
        System.assert(!OA_QualificationRuleEngine.applyOperator('between', '20', '5,10'), 'between out');
        System.assert(!OA_QualificationRuleEngine.applyOperator('bogus', 'x', 'y'), 'unknown op false');
        System.assert(!OA_QualificationRuleEngine.applyOperator('gte', 'abc', '5'), 'non-numeric false');
    }
}