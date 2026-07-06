/**
 * OA_SAM_Connector_Test — unit tests (mocked callouts) + an INTEGRATION test proving the SAM
 * connector plugs into the existing enrichment platform (policy engine, qualification engine,
 * exception routing) with NO changes to the foundation.
 */
@isTest
private class OA_SAM_Connector_Test {

    private class SamMock implements HttpCalloutMock {
        Integer status; String body;
        SamMock(Integer s, String b) { status = s; body = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(status);
            r.setBody(body);
            return r;
        }
    }
    private class ThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) { throw new CalloutException('simulated callout failure'); }
    }

    private static String sampleBody() {
        return JSON.serialize(new Map<String, Object>{
            'totalRecords' => 1,
            'entityData' => new List<Object>{
                new Map<String, Object>{
                    'entityRegistration' => new Map<String, Object>{
                        'ueiSAM' => 'ABC123DEF456', 'cageCode' => '1AB23',
                        'legalBusinessName' => 'ACME DEFENSE LLC',
                        'registrationStatus' => 'Active', 'registrationExpirationDate' => '2027-03-15' },
                    'coreData' => new Map<String, Object>{
                        'entityInformation' => new Map<String, Object>{ 'entityURL' => 'https://acme.example.com' },
                        'physicalAddress' => new Map<String, Object>{ 'stateOrProvinceCode' => 'VA' } } } } });
    }

    private static List<OA_Connector_Registry__mdt> samRegistry() {
        return new List<OA_Connector_Registry__mdt>{
            new OA_Connector_Registry__mdt(Source_System__c='SAM', Named_Credential__c='OA_SAM',
                Endpoint_Path__c='/entity-information/v3/entities', Enabled__c=false, Status__c='Draft') };
    }

    @isTest
    static void testFetchSuccessNoRawPayloadByDefault() {
        OA_SAM_Connector.registryOverride = samRegistry();
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        Test.startTest();
        OA_SAM_Connector.Result r = new OA_SAM_Connector().fetch('ABC123DEF456');
        Test.stopTest();
        System.assertEquals(1, r.parsed, 'One entity parsed');
        System.assertEquals(1, r.organizations.size(), 'Canonical org produced');
        System.assertEquals('ABC123DEF456', r.organizations[0].uei, 'UEI mapped');
        System.assertEquals(0, r.httpErrors, 'No http errors');
        System.assertEquals(200, r.lastStatus, 'Status recorded');
        System.assertEquals(null, r.rawPayload, 'Raw payload OFF by default');
    }

    @isTest
    static void testRawPayloadDebugOn() {
        OA_SAM_Connector.registryOverride = samRegistry();
        OA_SAM_Connector.debugStoreRawPayload = true;
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        Test.startTest();
        OA_SAM_Connector.Result r = new OA_SAM_Connector().fetch('ABC123DEF456');
        Test.stopTest();
        System.assert(String.isNotBlank(r.rawPayload), 'Raw payload captured only when debug enabled');
    }

    @isTest
    static void testNon2xxAndMalformedAndCalloutException() {
        OA_SAM_Connector.registryOverride = samRegistry();

        Test.setMock(HttpCalloutMock.class, new SamMock(429, '{"error":"rate limited"}'));
        OA_SAM_Connector.Result rate = new OA_SAM_Connector().fetch('ABC123DEF456');
        System.assertEquals(1, rate.httpErrors, 'Non-2xx recorded');
        System.assertEquals(0, rate.parsed, 'Nothing parsed on non-2xx');

        Test.setMock(HttpCalloutMock.class, new SamMock(200, 'not-json'));
        OA_SAM_Connector.Result bad = new OA_SAM_Connector().fetch('ABC123DEF456');
        System.assertEquals(1, bad.parseErrors, 'Malformed body -> parse error');

        Test.setMock(HttpCalloutMock.class, new ThrowMock());
        OA_SAM_Connector.Result thrown = new OA_SAM_Connector().fetch('ABC123DEF456');
        System.assertEquals(1, thrown.httpErrors, 'Callout exception recorded, not swallowed');
        System.assert(!thrown.messages.isEmpty(), 'Failure message captured');
    }

    @isTest
    static void testConfigResolvedViaQueryWhenNoOverride() {
        // No registryOverride -> config() runs the SOQL (0 rows here) -> request falls back to defaults.
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        Test.startTest();
        OA_SAM_Connector.Result r = new OA_SAM_Connector().fetch('ABC123DEF456');
        Test.stopTest();
        System.assertEquals(1, r.parsed, 'Works with default endpoint when no registry record present');
    }

    // ---- INTEGRATION: SAM output flows through the UNCHANGED platform engines ----
    @isTest
    static void testEndToEndReusesPlatform() {
        // 1. SAM connector -> canonical org
        OA_SAM_Connector.registryOverride = samRegistry();
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        OA_SAM_Connector.Result r = new OA_SAM_Connector().fetch('ABC123DEF456');
        OA_CanonicalOrg org = r.organizations[0];

        // 2. Mapper -> field proposals (SAM-specific mapping only)
        List<OA_EnrichmentWriter.FieldProposal> proposals = new OA_SAM_Mapper().toLeadProposals(org);
        System.assert(!proposals.isEmpty(), 'SAM mapped proposals');

        // 3. Policy engine + Enrichment writer (platform, unchanged) — fill-empty Website
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            new OA_Field_Write_Policy__mdt(Target_Object__c='Lead', Target_Field__c='Website',
                Source_System__c='SAM', Write_Mode__c='FillEmptyOnly', Confidence_Floor__c='HIGH',
                Conflict_Behavior__c='Review', Trusted__c=true, Active__c=true) };
        Lead l = new Lead(LastName='T', Company='ACME DEFENSE LLC', Email='s@example.com', Website=null);
        insert l;
        OA_EnrichmentWriter.Result wr = OA_EnrichmentWriter.preview(l, proposals, null);
        System.assertEquals('WRITE', wr.outcomeByField.get('Website'), 'Platform write policy invoked for SAM data');

        // 4. Qualification engine (platform, unchanged) — SAM ICP ruleset
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            new OA_Qualification_Rule__mdt(Ruleset__c='SAM_ICP', Criterion_Type__c='Active_SAM',
                Source_Field__c='Registration_Status', Operator__c='equals', Compare_Value__c='Active',
                Weight__c=1, Required__c=true, Ruleset_Threshold__c=1, Active__c=true) };
        OA_DiscoveryQualificationEngine.Recommendation rec =
            OA_DiscoveryQualificationEngine.evaluate(org, 'SAM_ICP');
        System.assertEquals('Qualified', rec.qualificationStatus, 'SAM canonical qualifies via platform engine');

        // 5. Exception routing (platform, unchanged) — a fill-empty conflict routes an exception
        Lead filled = new Lead(LastName='T2', Company='ACME DEFENSE LLC', Email='s2@example.com',
            Website='https://old.example.com');
        insert filled;
        OA_EnrichmentWriter.Result cw = OA_EnrichmentWriter.preview(filled, proposals, null);
        System.assertEquals(1, cw.conflicts, 'Conflict detected by platform');
        System.assertEquals('SourceConflict', cw.exceptions[0].Exception_Type__c, 'Routed via platform exception service');
    }
}
