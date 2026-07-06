@isTest
private class OA_FieldWritePolicyEngine_Test {

    private static OA_Field_Write_Policy__mdt pol(String field, String src, String mode,
            String floor, Boolean trusted, Boolean active) {
        return new OA_Field_Write_Policy__mdt(
            Target_Object__c='Lead', Target_Field__c=field, Source_System__c=src,
            Write_Mode__c=mode, Confidence_Floor__c=floor, Conflict_Behavior__c='Review',
            Trusted__c=trusted, Active__c=active);
    }

    private static OA_FieldWritePolicyEngine.Outcome eval(String field, String band,
            Object cur, Object proposed) {
        return OA_FieldWritePolicyEngine.evaluate('Lead', field, 'SAM', band, cur, proposed).outcome;
    }

    @isTest
    static void testNoAndInactivePolicy() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>();
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_NO_POLICY,
            eval('Website', 'HIGH', null, 'x'), 'No policy');

        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'SAM', 'FillEmptyOnly', 'HIGH', true, false) };  // inactive
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_NO_POLICY,
            eval('Website', 'HIGH', null, 'x'), 'Inactive policy ignored');
    }

    @isTest
    static void testTrustNeverFloor() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'SAM', 'FillEmptyOnly', 'HIGH', false, true) };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_NOT_TRUSTED,
            eval('Website', 'HIGH', null, 'x'), 'Untrusted');

        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Company', 'SAM', 'Never', 'HIGH', true, true) };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_NEVER,
            eval('Company', 'HIGH', null, 'x'), 'Never');

        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'SAM', 'FillEmptyOnly', 'HIGH', true, true) };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_BELOW_FLOOR,
            eval('Website', 'LOW', null, 'x'), 'Below floor');
    }

    @isTest
    static void testFillEmpty() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'SAM', 'FillEmptyOnly', 'HIGH', true, true) };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.WRITE,
            eval('Website', 'HIGH', null, 'https://a.com'), 'Blank -> write');
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.SKIP_FILLED,
            eval('Website', 'HIGH', 'https://a.com', 'https://a.com'), 'Same value filled');
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.ROUTE_CONFLICT,
            eval('Website', 'HIGH', 'https://old.com', 'https://new.com'), 'Different filled -> conflict');
    }

    @isTest
    static void testOverwrite() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Rating', 'SAM', 'Overwrite', 'HIGH', true, true) };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.WRITE,
            eval('Rating', 'HIGH', 'Hot', 'Warm'), 'Overwrite different');
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.NO_CHANGE,
            eval('Rating', 'HIGH', 'Hot', 'Hot'), 'Overwrite same -> no change');
    }

    @isTest
    static void testSourceSpecificPreferredOverAnySource() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', null, 'Never', 'HIGH', true, true),        // any-source
            pol('Website', 'SAM', 'FillEmptyOnly', 'HIGH', true, true) // source-specific
        };
        System.assertEquals(OA_FieldWritePolicyEngine.Outcome.WRITE,
            eval('Website', 'HIGH', null, 'x'), 'Source-specific SAM policy wins over any-source');
    }
}
