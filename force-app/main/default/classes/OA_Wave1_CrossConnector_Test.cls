/**
 * OA_Wave1_CrossConnector_Test — proves SAM, USASpending, Census, and IRS all execute through the
 * SAME OA_ConnectorRunner with zero source-specific dispatch and zero platform changes, and that
 * cross-source entity resolution works using the existing platform (canonical key, confidence,
 * source precedence). Also exercises qualification, policy evaluation, and exception routing.
 */
@isTest
private class OA_Wave1_CrossConnector_Test {

    private static final String SHARED_UEI = 'SHAREDUEI123';

    // Routes each mocked callout to the right body by Named-Credential in the endpoint.
    private class MultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            if (url.contains('OA_SAM')) { r.setBody(samBody()); }
            else if (url.contains('OA_USASpending')) { r.setBody(usaBody()); }
            else if (url.contains('OA_Census')) { r.setBody(censusBody()); }
            else { r.setBody('{}'); }
            return r;
        }
    }

    private static String samBody() {
        return JSON.serialize(new Map<String, Object>{ 'entityData' => new List<Object>{
            new Map<String, Object>{
                'entityRegistration' => new Map<String, Object>{
                    'ueiSAM' => SHARED_UEI, 'legalBusinessName' => 'ACME DEFENSE LLC', 'registrationStatus' => 'Active' },
                'coreData' => new Map<String, Object>{
                    'entityInformation' => new Map<String, Object>{ 'entityURL' => 'https://acme.example.com' } } } } });
    }
    private static String usaBody() {
        return JSON.serialize(new Map<String, Object>{ 'results' => new List<Object>{
            new Map<String, Object>{ 'Recipient UEI' => SHARED_UEI, 'Recipient Name' => 'ACME DEFENSE LLC',
                'Award Amount' => 500, 'Awarding Agency' => 'DoD', 'Start Date' => '2026-01-01' } } });
    }
    private static String censusBody() {
        return JSON.serialize(new List<Object>{
            new List<Object>{ 'ESTAB', 'EMP', 'state' },
            new List<Object>{ '100', '2000', '51' } });
    }
    private static String irsCsv() {
        return 'EIN,NAME,STATE,SUBSECTION\n123456789,ACME FOUNDATION,VA,03\n';
    }

    private static OA_Connector_Registry__mdt reg(String src, String cls, String nc, String path) {
        return new OA_Connector_Registry__mdt(Source_System__c=src, Connector_Class__c=cls, Named_Credential__c=nc,
            Endpoint_Path__c=path, Enabled__c=true, Category__c='Entity', Version__c='1.0.0');
    }
    private static void registerAll() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{
            reg('SAM', 'OA_SAM_Connector', 'OA_SAM', '/entity-information/v3/entities'),
            reg('USASpending', 'OA_USASpending_Connector', 'OA_USASpending', '/api/v2/search/spending_by_award/'),
            reg('Census', 'OA_Census_Connector', 'OA_Census', '/data/2021/cbp'),
            reg('IRS', 'OA_IRS_Connector', 'OA_IRS', '/bulk') };
    }

    @isTest
    static void testAllFourDispatchThroughOneRunner() {
        registerAll();
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        OA_ConnectorRunner runner = new OA_ConnectorRunner();

        Test.startTest();
        OA_ConnectorRunner.RunOutcome sam = runner.run('SAM', SHARED_UEI);
        OA_ConnectorRunner.RunOutcome usa = runner.run('USASpending', 'ACME DEFENSE');
        OA_ConnectorRunner.RunOutcome census = runner.run('Census', '51');
        OA_ConnectorRunner.RunOutcome irs = runner.run('IRS', irsCsv());
        Test.stopTest();

        // Every source executed through the SAME runner, metadata-driven, no source-specific dispatch.
        for (OA_ConnectorRunner.RunOutcome o : new List<OA_ConnectorRunner.RunOutcome>{ sam, usa, census, irs }) {
            System.assert(o.executed, o.sourceKey + ' executed via runner');
            System.assertEquals('Succeeded', o.status, o.sourceKey + ' succeeded');
            System.assertEquals(1, o.recordsProcessed, o.sourceKey + ' produced a canonical record');
            System.assertNotEquals(null, o.runRecord, o.sourceKey + ' telemetry generated');
        }
    }

    @isTest
    static void testCrossSourceEntityResolution() {
        registerAll();
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        OA_ConnectorRunner runner = new OA_ConnectorRunner();

        OA_CanonicalOrg samOrg = runner.run('SAM', SHARED_UEI).organizations[0];
        OA_CanonicalOrg usaOrg = runner.run('USASpending', 'ACME').organizations[0];
        OA_CanonicalOrg censusOrg = runner.run('Census', '51').organizations[0];
        OA_CanonicalOrg irsOrg = new OA_IRS_ResponseParser().parse(irsCsv())[0];

        // Deterministic match: SAM + USASpending share a UEI -> identical canonical key.
        System.assertEquals('UEI:' + SHARED_UEI, samOrg.canonicalKey(), 'SAM canonical key by UEI');
        System.assertEquals(samOrg.canonicalKey(), usaOrg.canonicalKey(), 'SAM + USASpending resolve to one entity');
        // Confidence scoring via the existing engine.
        System.assertEquals('HIGH', OA_ConfidenceEvaluator.evaluate(true, false, 0).band, 'Exact id match -> HIGH');
        // IRS keyed by EIN (deterministic).
        System.assert(irsOrg.canonicalKey().startsWith('EIN:'), 'IRS resolves by EIN');
        // Census is context only — no identity, so it never identity-matches.
        System.assert(!censusOrg.hasDeterministicId(), 'Census has no organization identity');
        System.assertEquals('NONE', censusOrg.sourceConfidence, 'Census is context, not an entity');

        // Duplicate handling / survivorship uses source precedence (SAM outranks USASpending).
        OA_SourcePrecedenceEngine.sourceOverride = new List<OA_Enrichment_Source__mdt>{
            new OA_Enrichment_Source__mdt(Source_System__c='SAM', Precedence__c=10, Trusted__c=true, Active__c=true),
            new OA_Enrichment_Source__mdt(Source_System__c='USASpending', Precedence__c=50, Trusted__c=true, Active__c=true) };
        System.assertEquals('SAM', OA_SourcePrecedenceEngine.winner('SAM', 'USASpending'),
            'Duplicate resolved to higher-precedence source');
    }

    @isTest
    static void testSharedPlatformQualifyPolicyException() {
        registerAll();
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        OA_ConnectorRunner runner = new OA_ConnectorRunner();

        // Qualification invoked generically by the runner (SAM org has Registration_Status=Active).
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            new OA_Qualification_Rule__mdt(Ruleset__c='ICP', Source_Field__c='Registration_Status',
                Operator__c='equals', Compare_Value__c='Active', Weight__c=1, Required__c=true,
                Ruleset_Threshold__c=1, Active__c=true) };
        OA_ConnectorRunner.RunOutcome q = runner.run('SAM', SHARED_UEI, 'ICP');
        System.assertEquals(1, q.recordsQualified, 'Qualification engine invoked via runner');

        OA_CanonicalOrg samOrg = q.organizations[0];

        // Policy evaluation + writer (platform) on the shared canonical model.
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            new OA_Field_Write_Policy__mdt(Target_Object__c='Lead', Target_Field__c='Website',
                Source_System__c='SAM', Write_Mode__c='FillEmptyOnly', Confidence_Floor__c='HIGH',
                Conflict_Behavior__c='Review', Trusted__c=true, Active__c=true) };
        List<OA_EnrichmentWriter.FieldProposal> proposals = new OA_SAM_Mapper().toLeadProposals(samOrg);
        Lead l = new Lead(LastName='T', Company='ACME DEFENSE LLC', Email='c@example.com', Website=null);
        insert l;
        OA_EnrichmentWriter.Result wr = OA_EnrichmentWriter.preview(l, proposals, null);
        System.assertEquals('WRITE', wr.outcomeByField.get('Website'), 'Policy evaluated for cross-connector data');

        // Exception routing (platform) on a conflict.
        Lead filled = new Lead(LastName='T2', Company='ACME DEFENSE LLC', Email='c2@example.com', Website='https://old.example.com');
        insert filled;
        OA_EnrichmentWriter.Result cw = OA_EnrichmentWriter.preview(filled, proposals, null);
        System.assertEquals(1, cw.conflicts, 'Conflict routed by platform');
        System.assertEquals('SourceConflict', cw.exceptions[0].Exception_Type__c, 'Exception routing reused');
    }
}
