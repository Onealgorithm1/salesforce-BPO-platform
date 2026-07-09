/**
 * OA_Wave2_Integration_Test — proves SAM, USASpending, Census, IRS, and SEC all run through the
 * IDENTICAL OA_ConnectorRunner lifecycle with zero source-specific dispatch and zero platform change.
 */
@isTest
private class OA_Wave2_Integration_Test {

    private class MultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            if (url.contains('OA_SAM')) { r.setBody(samBody()); }
            else if (url.contains('OA_USASpending')) { r.setBody(usaBody()); }
            else if (url.contains('OA_Census')) { r.setBody(censusBody()); }
            else if (url.contains('OA_SEC')) { r.setBody(secBody()); }
            else { r.setBody('{}'); }
            return r;
        }
    }

    private static String samBody() {
        return JSON.serialize(new Map<String, Object>{ 'entityData' => new List<Object>{
            new Map<String, Object>{ 'entityRegistration' => new Map<String, Object>{
                'ueiSAM' => 'SHAREDUEI123', 'legalBusinessName' => 'ACME DEFENSE LLC', 'registrationStatus' => 'Active' } } } });
    }
    private static String usaBody() {
        return JSON.serialize(new Map<String, Object>{ 'results' => new List<Object>{
            new Map<String, Object>{ 'Recipient UEI' => 'SHAREDUEI123', 'Recipient Name' => 'ACME DEFENSE LLC',
                'Award Amount' => 500, 'Awarding Agency' => 'DoD', 'Start Date' => '2026-01-01' } } });
    }
    private static String censusBody() {
        return JSON.serialize(new List<Object>{ new List<Object>{ 'ESTAB', 'state' }, new List<Object>{ '100', '51' } });
    }
    private static String secBody() {
        return JSON.serialize(new Map<String, Object>{ 'cik' => '320193', 'name' => 'APPLE INC',
            'tickers' => new List<Object>{ 'AAPL' }, 'sic' => '3571', 'sicDescription' => 'Electronic Computers' });
    }
    private static String irsCsv() { return 'EIN,NAME,STATE\n123456789,ACME FOUNDATION,VA\n'; }

    private static OA_Connector_Registry__mdt reg(String src, String cls, String nc, String path) {
        return new OA_Connector_Registry__mdt(Source_System__c=src, Connector_Class__c=cls, Named_Credential__c=nc,
            Endpoint_Path__c=path, Enabled__c=true, Category__c='Entity', Version__c='1.0.0');
    }

    @isTest
    static void testFiveConnectorsIdenticalLifecycle() {
        OA_ConnectorRunner.registryOverride = new List<OA_Connector_Registry__mdt>{
            reg('SAM', 'OA_SAM_Connector', 'OA_SAM', '/entity-information/v3/entities'),
            reg('USASpending', 'OA_USASpending_Connector', 'OA_USASpending', '/api/v2/search/spending_by_award/'),
            reg('Census', 'OA_Census_Connector', 'OA_Census', '/data/2021/cbp'),
            reg('IRS', 'OA_IRS_Connector', 'OA_IRS', '/bulk'),
            reg('SEC', 'OA_SEC_Connector', 'OA_SEC', '/submissions') };
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        OA_ConnectorRunner runner = new OA_ConnectorRunner();

        Test.startTest();
        List<OA_ConnectorRunner.RunOutcome> outs = new List<OA_ConnectorRunner.RunOutcome>{
            runner.run('SAM', 'SHAREDUEI123'),
            runner.run('USASpending', 'ACME DEFENSE'),
            runner.run('Census', '51'),
            runner.run('IRS', irsCsv()),
            runner.run('SEC', '320193') };
        Test.stopTest();

        System.assertEquals(5, outs.size(), 'Five connectors dispatched');
        for (OA_ConnectorRunner.RunOutcome o : outs) {
            System.assert(o.executed, o.sourceKey + ' executed via the same runner');
            System.assertEquals('Succeeded', o.status, o.sourceKey + ' succeeded');
            System.assertEquals(1, o.recordsProcessed, o.sourceKey + ' produced a canonical record');
            System.assertNotEquals(null, o.runRecord, o.sourceKey + ' telemetry generated');
            System.assert(o.durationMs != null && o.durationMs >= 0, o.sourceKey + ' timing captured');
        }
    }
}