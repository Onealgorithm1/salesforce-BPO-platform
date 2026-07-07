/**
 * OA_MetaConnector_Test — minimal tests for the DORMANT Meta connector foundation (INT-011).
 *
 * Validates connector construction, registry-facing metadata (source key, named credential),
 * dormant state, SDK-context reuse, and that the unimplemented sync path throws — WITHOUT any
 * authentication, HTTP callout, or Meta API interaction. No mocks are used.
 */
@IsTest
private class OA_MetaConnector_Test {

    @IsTest
    static void connector_exposes_expected_metadata() {
        OA_MetaConnector c = new OA_MetaConnector();
        System.assertEquals('Meta', c.sourceKey(), 'Source key must be Meta.');
        System.assertEquals('OA_Meta', c.namedCredential(), 'Named Credential must be OA_Meta.');
        System.assertEquals(false, c.isImplemented(), 'Connector must be dormant (not implemented).');
    }

    @IsTest
    static void buildContext_reuses_sdk_context() {
        OA_MetaConnector c = new OA_MetaConnector();
        OA_ConnectorContext ctx = c.buildContext('META-TEST-RUN-1');
        System.assertEquals('META-TEST-RUN-1', ctx.runId, 'Context must carry the supplied run id.');
        System.assertNotEquals(null, ctx.queryDate, 'SDK context should stamp a query date.');
    }

    @IsTest
    static void sync_is_not_implemented_and_throws() {
        OA_MetaConnector c = new OA_MetaConnector();
        OA_ConnectorContext ctx = c.buildContext('META-TEST-RUN-2');
        Boolean threw = false;
        Test.startTest();
        try {
            c.sync(ctx);
        } catch (OA_ConnectorException e) {
            threw = true;
            System.assert(e.getMessage().contains('dormant'), 'Message should state the connector is dormant.');
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'sync() must throw until implemented in a future sprint.');
    }
}
