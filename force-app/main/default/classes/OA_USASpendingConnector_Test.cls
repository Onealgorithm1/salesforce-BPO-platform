/**
 * OA_USASpendingConnector_Test — proves the USASpending connector on the SDK.
 *
 * Fully mocked (OA_ConnectorMock) — NEVER calls the live USASpending.gov endpoint,
 * and asserts the connector performs NO DML (nothing written to the staging object).
 * Covers success + field mapping, non-200, empty result, and malformed response.
 */
@isTest
private class OA_USASpendingConnector_Test {

    private static final String ENDPOINT =
        'callout:OA_USASpending/api/v2/search/spending_by_award/';

    // Build a USASpending-shaped response body with `count` award rows.
    private static String awardsJson(Integer count, Boolean firstRowNulls) {
        List<Object> rows = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> row = new Map<String, Object>{
                'Award ID'                        => 'CONT_AWD_' + i,
                'Recipient Name'                  => 'ACME DEFENSE LLC ' + i,
                'recipient_uei'                   => 'UEI' + i + 'ABCDE',
                'Award Amount'                    => 100000 + i,
                'Awarding Agency'                 => 'Department of Defense',
                'Awarding Sub Agency'             => 'Department of the Navy',
                'Contract Award Type'             => 'DEFINITIVE CONTRACT',
                'Place of Performance State Code' => 'VA',
                'Description'                     => 'IT SUPPORT SERVICES ' + i
            };
            if (firstRowNulls && i == 0) {
                row.put('Award Amount', null);
                row.put('Description', null);
            }
            rows.add(row);
        }
        return JSON.serialize(new Map<String, Object>{ 'results' => rows });
    }

    private static OA_ConnectorRunResult runWith(Integer status, String body, Object input) {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(status, body));
        return new OA_ConnectorEngine().run(
            new OA_USASpendingConnector(),
            new OA_ConnectorContext('USASPEND-RUN-01'),
            new List<Object>{ input });
    }

    @isTest
    static void testSuccessMapsStagingInMemoryNoDml() {
        Integer dmlBefore = Limits.getDmlStatements();

        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, awardsJson(2, true), 'ACME DEFENSE LLC');
        Test.stopTest();

        System.assertEquals(1, result.requested, 'One input');
        System.assertEquals(2, result.parsed, 'Two rows parsed');
        System.assertEquals(2, result.mapped, 'Two staging records mapped in memory');
        System.assert(result.isClean(), 'Run is clean');

        // Proof of no DML / no staging write:
        System.assertEquals(dmlBefore, Limits.getDmlStatements(), 'Zero DML statements');
        System.assertEquals(0, [SELECT COUNT() FROM OA_USASpending_Staging__c],
            'No staging records were inserted');

        // Row 0 exercises the null branches.
        OA_USASpending_Staging__c s0 = (OA_USASpending_Staging__c) result.stagingRecords[0];
        System.assertEquals('CONT_AWD_0', s0.Award_ID__c, 'Award ID mapped');
        System.assertEquals('ACME DEFENSE LLC 0', s0.Recipient_Name__c, 'Recipient mapped');
        System.assertEquals('UEI0ABCDE', s0.Recipient_UEI__c, 'UEI mapped');
        System.assertEquals(null, s0.Award_Amount__c, 'Null amount handled');
        System.assertEquals(null, s0.Award_Description__c, 'Null description handled');
        System.assertEquals('VA', s0.Performance_State__c, 'State mapped');

        // Framework-managed fields + review gate.
        System.assertEquals('Pending', s0.Review_Status__c, 'Review gate defaulted to Pending');
        System.assertEquals('USASPEND-RUN-01', s0.Enrichment_Run_ID__c, 'Run id stamped');
        System.assertEquals(ENDPOINT, s0.Source_Endpoint__c, 'Source endpoint stamped');
        System.assertEquals(200, s0.HTTP_Status__c, 'HTTP status stamped');
        System.assertEquals(Date.today(), s0.Query_Date__c, 'Query date stamped');
        System.assertEquals('ACME DEFENSE LLC', s0.Search_Term__c, 'Search term stamped');

        // Row 1 exercises full mapping incl. amount + contract type.
        OA_USASpending_Staging__c s1 = (OA_USASpending_Staging__c) result.stagingRecords[1];
        System.assertEquals(100001, s1.Award_Amount__c, 'Amount mapped to Decimal');
        System.assertEquals('Department of Defense', s1.Awarding_Agency__c, 'Agency mapped');
        System.assertEquals('Department of the Navy', s1.Awarding_Sub_Agency__c, 'Sub-agency mapped');
        System.assertEquals('DEFINITIVE CONTRACT', s1.Contract_Type__c, 'Contract type mapped');
    }

    @isTest
    static void testConnectorMetadata() {
        OA_USASpendingConnector c = new OA_USASpendingConnector();
        System.assertEquals('USASpending', c.sourceKey(), 'Source key');
        System.assertEquals('callout:OA_USASpending', c.namedCredential(), 'Named credential declared (used in 1C-2)');
        System.assertEquals(OA_USASpending_Staging__c.SObjectType, c.stagingType(), 'Staging type');
        System.assert(c.requestBuilder() instanceof OA_USASpendingRequest, 'Request builder wired');
        System.assert(c.parser() instanceof OA_USASpendingParser, 'Parser wired');
        System.assert(c.mapper() instanceof OA_USASpendingMapper, 'Mapper wired');
    }

    @isTest
    static void testRequestBuiltCorrectly() {
        OA_ConnectorMock mock = new OA_ConnectorMock(200, awardsJson(1, false));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new OA_ConnectorEngine().run(new OA_USASpendingConnector(),
            new OA_ConnectorContext('R2'), new List<Object>{ 'BOEING' });
        Test.stopTest();

        System.assertEquals(ENDPOINT, mock.lastRequest.getEndpoint(), 'Public endpoint used (NC deferred)');
        System.assertEquals('POST', mock.lastRequest.getMethod(), 'POST method');
        System.assert(mock.lastRequest.getBody().contains('BOEING'),
            'Request body carries the recipient search text');
    }

    @isTest
    static void testDescriptionAbbreviatedTo500() {
        String longDesc = 'X'.repeat(900);
        String body = JSON.serialize(new Map<String, Object>{
            'results' => new List<Object>{
                new Map<String, Object>{ 'Award ID' => 'A1', 'Description' => longDesc }
            }
        });

        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, body, 'anyone');
        Test.stopTest();

        OA_USASpending_Staging__c s = (OA_USASpending_Staging__c) result.stagingRecords[0];
        System.assertEquals(500, s.Award_Description__c.length(), 'Description abbreviated to 500');
    }

    @isTest
    static void testNon200RecordsHttpError() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(500, '{"detail":"server error"}', 'ACME');
        Test.stopTest();

        System.assertEquals(1, result.httpErrors, 'Non-200 recorded');
        System.assertEquals(0, result.mapped, 'Nothing mapped on non-200');
        System.assert(!result.isClean(), 'Run not clean');
    }

    @isTest
    static void testEmptyResultsParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, '{"results":[]}', 'NoMatchCo');
        Test.stopTest();

        System.assertEquals(0, result.parsed, 'No rows parsed');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(result.isClean(), 'Empty result is a clean run');
    }

    @isTest
    static void testMissingResultsKeyParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, '{"page_metadata":{"count":0}}', 'NoMatchCo');
        Test.stopTest();

        System.assertEquals(0, result.mapped, 'Missing results key yields zero mapped');
        System.assert(result.isClean(), 'Still clean');
    }

    @isTest
    static void testMalformedResponseHandledSafely() {
        // The new parser guards malformed bodies: engine records a parse error,
        // does not throw uncaught (retires the old-client tech debt).
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, 'this-is-not-json', 'ACME');
        Test.stopTest();

        System.assertEquals(1, result.parseErrors, 'Malformed body recorded as a parse error');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(!result.isClean(), 'Run not clean');
    }
}