/**
 * OA_ConnectorRunner_Test — proves registry-driven dispatch, the connector lifecycle, telemetry,
 * graceful failure, coexistence, and skipping — all without any source-specific test logic.
 */
@isTest
private class OA_ConnectorRunner_Test {

    private class SamMock implements HttpCalloutMock {
        Integer s; String b;
        SamMock(Integer s, String b) { this.s = s; this.b = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse h = new HttpResponse();
            h.setStatusCode(s);
            h.setBody(b);
            return h;
        }
    }

    private static String sampleBody() {
        return JSON.serialize(new Map<String, Object>{
            'totalRecords' => 1,
            'entityData' => new List<Object>{
                new Map<String, Object>{
                    'entityRegistration' => new Map<String, Object>{
                        'ueiSAM' => 'ABC123DEF456', 'legalBusinessName' => 'ACME DEFENSE LLC',
                        'registrationStatus' => 'Active' } } } });
    }

    private static OA_Connector_Registry__mdt reg(String src, String cls, Boolean enabled) {
        return new OA_Connector_Registry__mdt(Source_System__c=src, Connector_Class__c=cls,
            Enabled__c=enabled, Category__c='Entity', Version__c='1.0.0');
    }

    @isTest
    static void testResolvesAndExecutesFromRegistry() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_SAM_Connector', true) };
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        Test.startTest();
        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner().run('SAM', 'ABC123DEF456');
        Test.stopTest();
        System.assert(o.executed, 'Executed');
        System.assertEquals('Succeeded', o.status, 'Clean run');
        System.assertEquals(1, o.recordsProcessed, 'One canonical org parsed');
        System.assertEquals(1, o.organizations.size(), 'Canonical org returned');
        System.assertEquals('1.0.0', o.connectorVersion, 'Version from registry');
    }

    @isTest
    static void testTelemetryGenerated() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_SAM_Connector', true) };
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner().run('SAM', 'ABC123DEF456');
        System.assertNotEquals(null, o.startedAt, 'start time');
        System.assertNotEquals(null, o.finishedAt, 'finish time');
        System.assert(o.durationMs != null && o.durationMs >= 0, 'duration');
        System.assertNotEquals(null, o.runRecord, 'in-memory telemetry record built');
        System.assertEquals('SAM', o.runRecord.Source_System__c, 'run record source');
        System.assertEquals('Succeeded', o.runRecord.Status__c, 'run record status');
        System.assert(o.runRecord.Messages__c.contains('duration_ms='), 'telemetry captured in message');
    }

    @isTest
    static void testQualificationCountsViaPlatform() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_SAM_Connector', true) };
        OA_QualificationRuleEngine.ruleOverride = new List<OA_Qualification_Rule__mdt>{
            new OA_Qualification_Rule__mdt(Ruleset__c='SAM_ICP', Source_Field__c='Registration_Status',
                Operator__c='equals', Compare_Value__c='Active', Weight__c=1, Required__c=true,
                Ruleset_Threshold__c=1, Active__c=true) };
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner().run('SAM', 'ABC123DEF456', 'SAM_ICP');
        System.assertEquals(1, o.recordsQualified, 'Qualified via platform qualification engine');
        System.assertEquals(0, o.recordsRejected, 'None rejected');
    }

    @isTest
    static void testDisabledConnectorSkipped() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_SAM_Connector', false) };
        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner().run('SAM', 'x');
        System.assert(o.skipped, 'Disabled -> skipped');
        System.assertEquals('Skipped', o.status);
        System.assert(!o.executed, 'Not executed');
    }

    @isTest
    static void testUnknownSourceAndClassFailGracefully() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>();
        System.assertEquals('Unresolved', new OA_ConnectorRunner().run('NOPE', 'x').status, 'Unknown source');

        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_DoesNotExistXYZ', true) };
        OA_ConnectorRunner.RunOutcome missing = new OA_ConnectorRunner().run('SAM', 'x');
        System.assertEquals('Unresolved', missing.status, 'Missing class graceful (no exception)');

        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{ reg('SAM', 'OA_NameNormalizer', true) };
        OA_ConnectorRunner.RunOutcome wrong = new OA_ConnectorRunner().run('SAM', 'x');
        System.assertEquals('Unresolved', wrong.status, 'Non-implementing class graceful');
        System.assert(String.join(wrong.messages, ' ').contains('does not implement'), 'Reason recorded');
    }

    @isTest
    static void testMultipleConnectorsCoexistAndRunAll() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{
            reg('SAM', 'OA_SAM_Connector', true),
            reg('SAM2', 'OA_SAM_Connector', true),
            reg('OFF', 'OA_SAM_Connector', false) };
        Test.setMock(HttpCalloutMock.class, new SamMock(200, sampleBody()));
        Test.startTest();
        List<OA_ConnectorRunner.RunOutcome> outs = new OA_ConnectorRunner().runAll('ABC123DEF456', null);
        Test.stopTest();
        System.assertEquals(2, outs.size(), 'Only the 2 enabled connectors run');
        for (OA_ConnectorRunner.RunOutcome o : outs) {
            System.assert(o.executed, 'Each enabled connector executed');
        }
    }
}
