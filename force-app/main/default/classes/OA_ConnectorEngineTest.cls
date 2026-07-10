/**
 * OA_ConnectorEngineTest — proves the Connector SDK foundation end-to-end.
 *
 * Fully mocked (OA_ConnectorMock) — NEVER calls a live endpoint, and asserts the
 * engine performs NO DML. Exercises success, non-200, empty-result, and forced
 * parse-error paths through the generic fake connector, plus the small support
 * classes (context, row, run result, http wrapper, exception).
 */
@isTest
private class OA_ConnectorEngineTest {

    @isTest
    static void testSuccessMapsRowsInMemoryWithNoDml() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, OA_ConnectorTestBase.resultsJson(2)));

        Integer dmlBefore = Limits.getDmlStatements();
        OA_ConnectorRunResult result;

        Test.startTest();
        OA_ConnectorEngine engine = new OA_ConnectorEngine();
        result = engine.run(OA_ConnectorTestBase.fakeConnector(),
                            OA_ConnectorTestBase.newContext(),
                            new List<Object>{ 'acme' });
        Test.stopTest();

        Integer dmlAfter = Limits.getDmlStatements();

        System.assertEquals(1, result.requested, 'One input requested');
        System.assertEquals(2, result.parsed, 'Two rows parsed');
        System.assertEquals(2, result.mapped, 'Two staging records mapped in memory');
        System.assertEquals(0, result.httpErrors, 'No HTTP errors');
        System.assertEquals(0, result.parseErrors, 'No parse errors');
        System.assert(result.isClean(), 'Run is clean');
        System.assertEquals(2, result.stagingRecords.size(), 'Two in-memory staging records returned');

        // Proof of no DML / no staging write:
        System.assertEquals(dmlBefore, dmlAfter, 'Engine performed zero DML statements');
        System.assertEquals(0, [SELECT COUNT() FROM Account], 'No Account records were inserted');

        Account first = (Account) result.stagingRecords[0];
        System.assertEquals('Row 0', first.Name, 'Mapper populated the record in memory');
        System.assert(first.Description.contains('TEST-RUN-0001'), 'Run id stamped by mapper via context');
    }

    @isTest
    static void testNon200RecordsHttpError() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(500, '{"detail":"server error"}'));

        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(),
            new List<Object>{ 'acme' });
        Test.stopTest();

        System.assertEquals(1, result.httpErrors, 'Non-200 recorded as an HTTP error');
        System.assertEquals(0, result.mapped, 'Nothing mapped on a non-200');
        System.assert(!result.isClean(), 'Run is not clean');
        System.assert(result.messages.size() > 0 && result.messages[0].contains('HTTP 500'),
            'Diagnostic message captured the status');
    }

    @isTest
    static void testEmptyResultsParsesZero() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, '{"results":[]}'));

        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(),
            new List<Object>{ 'nomatch' });
        Test.stopTest();

        System.assertEquals(0, result.parsed, 'No rows parsed');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(result.isClean(), 'Empty result is still a clean run');
    }

    @isTest
    static void testMissingResultsKeyParsesZero() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, '{"meta":{"count":0}}'));

        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(),
            new List<Object>{ 'nomatch' });
        Test.stopTest();

        System.assertEquals(0, result.mapped, 'Missing results key yields zero mapped');
        System.assert(result.isClean(), 'Still clean');
    }

    @isTest
    static void testForcedParseErrorRecorded() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, 'FORCE_PARSE_ERROR'));

        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(),
            new List<Object>{ 'acme' });
        Test.stopTest();

        System.assertEquals(1, result.parseErrors, 'Parser exception recorded as a parse error');
        System.assertEquals(0, result.mapped, 'Nothing mapped when parsing fails');
        System.assert(!result.isClean(), 'Run is not clean');
    }

    @isTest
    static void testForcedMapErrorRecorded() {
        // A row named 'BOOM' makes the fake mapper throw — proves one bad row is
        // recorded without aborting the run.
        String body = JSON.serialize(new Map<String, Object>{
            'results' => new List<Object>{ new Map<String, Object>{ 'name' => 'BOOM' } }
        });
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, body));

        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(),
            new List<Object>{ 'acme' });
        Test.stopTest();

        System.assertEquals(1, result.parseErrors, 'Mapper exception recorded');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
    }

    @isTest
    static void testNoInputsIsCleanNoWork() {
        Test.startTest();
        OA_ConnectorRunResult result = new OA_ConnectorEngine().run(
            OA_ConnectorTestBase.fakeConnector(), OA_ConnectorTestBase.newContext(), null);
        Test.stopTest();

        System.assertEquals(0, result.requested, 'No inputs');
        System.assert(result.isClean(), 'Empty run is clean');
    }

    @isTest
    static void testNullConnectorThrows() {
        Boolean threw = false;
        try {
            new OA_ConnectorEngine().run(null, OA_ConnectorTestBase.newContext(), new List<Object>{ 'x' });
        } catch (OA_ConnectorException e) {
            threw = true;
        }
        System.assert(threw, 'Null connector is rejected');
    }

    @isTest
    static void testNullContextThrows() {
        Boolean threw = false;
        try {
            new OA_ConnectorEngine().run(OA_ConnectorTestBase.fakeConnector(), null, new List<Object>{ 'x' });
        } catch (OA_ConnectorException e) {
            threw = true;
        }
        System.assert(threw, 'Null context is rejected');
    }

    @isTest
    static void testContextRequiresRunId() {
        Boolean threw = false;
        try {
            OA_ConnectorContext bad = new OA_ConnectorContext('   ');
        } catch (OA_ConnectorException e) {
            threw = true;
        }
        System.assert(threw, 'Blank run id is rejected');
    }

    @isTest
    static void testRowAccessors() {
        OA_ConnectorRow row = new OA_ConnectorRow();
        row.put('name', 'Widget').put('amount', 42);
        System.assertEquals('Widget', row.getString('name'), 'String accessor');
        System.assertEquals(42, row.getDecimal('amount'), 'Decimal accessor');
        System.assert(row.has('name'), 'has() true for present key');
        System.assert(!row.has('missing'), 'has() false for absent key');
        System.assertEquals(null, row.getString('missing'), 'Absent string is null');
        System.assertEquals(2, row.asMap().size(), 'asMap returns all values');
    }

    @isTest
    static void testHttpWrapperNullRequestThrows() {
        Boolean threw = false;
        try {
            new OA_ConnectorHttp().send(null);
        } catch (OA_ConnectorException e) {
            threw = true;
        }
        System.assert(threw, 'Null request is rejected by the HTTP wrapper');
    }
}