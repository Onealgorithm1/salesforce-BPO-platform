/**
 * OA_GrantsConnector_Test — proves the dormant Grants.gov connector on the SDK.
 *
 * FULLY MOCKED (OA_ConnectorMock) — NEVER calls the live Grants.gov endpoint, asserts the
 * connector performs NO DML (nothing written to staging), and asserts the request carries
 * NO API key / Authorization header of any kind (Grants.gov Search2 is a public, keyless
 * API). Covers success + mapping, POST routing, non-200, empty, missing-data-key, and
 * malformed responses.
 */
@isTest
private class OA_GrantsConnector_Test {

    private static final String BASE = 'callout:OA_Grants/v1/api/search2';

    // Build a Search2-shaped response body with `count` opportunity hits.
    private static String search2Json(Integer count, Boolean firstRowNulls) {
        List<Object> hits = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> hit = new Map<String, Object>{
                'id'         => '35800' + i,
                'number'     => 'ABC-2026-00' + i,
                'title'      => 'Rural Broadband Opportunity ' + i,
                'agencyCode' => 'HHS-ACF',
                'agency'     => 'Administration for Children and Families',
                'oppStatus'  => 'posted',
                'docType'    => 'synopsis',
                'openDate'   => '01/15/2026',
                'closeDate'  => '03/15/2026',
                'cfdaList'   => new List<Object>{ '93.123', '93.456' }
            };
            if (firstRowNulls && i == 0) {
                hit.put('closeDate', null);
                hit.put('cfdaList', null);
                hit.put('docType', null);
            }
            hits.add(hit);
        }
        return JSON.serialize(new Map<String, Object>{
            'errorcode' => 0,
            'msg'       => 'SUCCESS',
            'data'      => new Map<String, Object>{ 'hitCount' => count, 'oppHits' => hits }
        });
    }

    private static OA_ConnectorRunResult runWith(Integer status, String body, Object input) {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(status, body));
        return new OA_ConnectorEngine().run(
            new OA_GrantsConnector(),
            new OA_ConnectorContext('GRANTS-RUN-01'),
            new List<Object>{ input });
    }

    @isTest
    static void testSuccessMapsStagingInMemoryNoDml() {
        Integer dmlBefore = Limits.getDmlStatements();

        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, search2Json(2, true), 'broadband');
        Test.stopTest();

        System.assertEquals(1, result.requested, 'One input');
        System.assertEquals(2, result.parsed, 'Two opportunities parsed');
        System.assertEquals(2, result.mapped, 'Two staging records mapped in memory');
        System.assert(result.isClean(), 'Run is clean');

        // Proof of no DML / no staging write:
        System.assertEquals(dmlBefore, Limits.getDmlStatements(), 'Zero DML statements');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Grants_Opportunity_Staging__c],
            'No staging records were inserted');

        // Row 0 exercises the null branches.
        OA_Grants_Opportunity_Staging__c s0 = (OA_Grants_Opportunity_Staging__c) result.stagingRecords[0];
        System.assertEquals('ABC-2026-000', s0.Opportunity_Number__c, 'Opportunity number mapped');
        System.assertEquals('Rural Broadband Opportunity 0', s0.Opportunity_Title__c, 'Title mapped');
        System.assertEquals('HHS-ACF', s0.Agency_Code__c, 'Agency code mapped');
        System.assertEquals('posted', s0.Opportunity_Status__c, 'Status mapped');
        System.assertEquals(Date.newInstance(2026, 1, 15), s0.Open_Date__c, 'Open date (MM/DD/YYYY) parsed');
        System.assertEquals(null, s0.Close_Date__c, 'Null close date handled');
        System.assertEquals(null, s0.CFDA_Numbers__c, 'Null CFDA list handled');
        System.assertEquals(null, s0.Doc_Type__c, 'Null docType handled');
        System.assertEquals('https://www.grants.gov/search-results-detail/358000', s0.Opportunity_URL__c,
            'Opportunity URL built from id');

        // Framework-managed fields + review gate.
        System.assertEquals('Pending', s0.Review_Status__c, 'Review gate defaulted to Pending');
        System.assertEquals('GRANTS-RUN-01', s0.Source_Run_ID__c, 'Run id stamped');
        System.assert(String.isNotBlank(s0.Source_Endpoint__c), 'Source endpoint stamped');
        System.assertEquals(200, s0.HTTP_Status__c, 'HTTP status stamped');
        System.assertEquals(Date.today(), s0.Query_Date__c, 'Query date stamped');
        System.assert(String.isNotBlank(s0.Source_Payload_Ref__c), 'Payload hash ref stamped');
        System.assert(String.isNotBlank(s0.Dedupe_Key__c), 'Dedupe key stamped');
        System.assertEquals('broadband', s0.Search_Term__c, 'Search term stamped');

        // Row 1 exercises full mapping incl. close date + CFDA join.
        OA_Grants_Opportunity_Staging__c s1 = (OA_Grants_Opportunity_Staging__c) result.stagingRecords[1];
        System.assertEquals(Date.newInstance(2026, 3, 15), s1.Close_Date__c, 'Close date parsed');
        System.assertEquals('93.123,93.456', s1.CFDA_Numbers__c, 'CFDA numbers joined');
        System.assertEquals('synopsis', s1.Doc_Type__c, 'Doc type mapped');
    }

    @isTest
    static void testConnectorMetadata() {
        OA_GrantsConnector c = new OA_GrantsConnector();
        System.assertEquals('Grants', c.sourceKey(), 'Source key');
        System.assertEquals('callout:OA_Grants', c.namedCredential(), 'Named credential declared');
        System.assertEquals(OA_Grants_Opportunity_Staging__c.SObjectType, c.stagingType(), 'Staging type');
        System.assert(c.requestBuilder() instanceof OA_GrantsRequest, 'Request builder wired');
        System.assert(c.parser() instanceof OA_GrantsParser, 'Parser wired');
        System.assert(c.mapper() instanceof OA_GrantsMapper, 'Mapper wired');
    }

    @isTest
    static void testRequestIsKeylessPost() {
        OA_ConnectorMock mock = new OA_ConnectorMock(200, search2Json(1, false));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new OA_ConnectorEngine().run(new OA_GrantsConnector(),
            new OA_ConnectorContext('R2'), new List<Object>{ 'cybersecurity' });
        Test.stopTest();

        HttpRequest sent = mock.lastRequest;
        System.assertEquals(BASE, sent.getEndpoint(), 'Routes through OA_Grants Named Credential');
        System.assertEquals('POST', sent.getMethod(), 'Search2 is a POST');
        // Public API — no key/secret anywhere in the request.
        System.assertEquals(null, sent.getHeader('Authorization'), 'No Authorization header');
        System.assertEquals(null, sent.getHeader('X-Api-Key'), 'No X-Api-Key header');
        String body = sent.getBody();
        System.assert(body.contains('cybersecurity'), 'Keyword sent in body');
        System.assert(body.containsIgnoreCase('posted'), 'Defaults to open (posted) opportunities');
        System.assert(!body.containsIgnoreCase('api_key'), 'No api_key in body');
    }

    @isTest
    static void testConfigOverridesStatusAndPageSize() {
        OA_ConnectorMock mock = new OA_ConnectorMock(200, search2Json(1, false));
        Test.setMock(HttpCalloutMock.class, mock);

        OA_ConnectorContext ctx = new OA_ConnectorContext('R-CFG',
            new Map<String, Object>{ 'oppStatuses' => 'forecasted', 'pageSize' => 5 });

        Test.startTest();
        new OA_ConnectorEngine().run(new OA_GrantsConnector(), ctx, new List<Object>{ 'energy' });
        Test.stopTest();

        String body = mock.lastRequest.getBody();
        System.assert(body.contains('forecasted'), 'oppStatuses override honored');
        System.assert(body.contains('"rows":5'), 'pageSize override honored');
    }

    @isTest
    static void testNon200RecordsHttpError() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(429, '{"error":"rate limited"}', 'broadband');
        Test.stopTest();

        System.assertEquals(1, result.httpErrors, 'Non-200 recorded');
        System.assertEquals(0, result.mapped, 'Nothing mapped on non-200');
        System.assert(!result.isClean(), 'Run not clean');
    }

    @isTest
    static void testEmptyOppHitsParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200,
            '{"errorcode":0,"data":{"hitCount":0,"oppHits":[]}}', 'nomatch');
        Test.stopTest();

        System.assertEquals(0, result.parsed, 'No opportunities parsed');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(result.isClean(), 'Empty result is a clean run');
    }

    @isTest
    static void testMissingDataKeyParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, '{"errorcode":0,"msg":"SUCCESS"}', 'nomatch');
        Test.stopTest();

        System.assertEquals(0, result.mapped, 'Missing data/oppHits key yields zero mapped');
        System.assert(result.isClean(), 'Still clean');
    }

    @isTest
    static void testMalformedResponseHandledSafely() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, 'this-is-not-json', 'broadband');
        Test.stopTest();

        System.assertEquals(1, result.parseErrors, 'Malformed body recorded as a parse error');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(!result.isClean(), 'Run not clean');
    }
}
