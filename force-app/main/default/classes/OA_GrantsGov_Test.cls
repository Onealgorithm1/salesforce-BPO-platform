/**
 * OA_GrantsGov_Test — unit tests for the Grants.gov opportunity connector.
 *
 * All HTTP is mocked (OA_ConnectorMock) — NO live callout. Proves the Phase 1
 * safety guarantees: preview is 0-DML; commit writes STAGING ONLY; no Lead/CRM
 * record is ever created; upsert is idempotent; anomalies route to human review.
 */
@isTest
private class OA_GrantsGov_Test {

    private static String okBody() {
        return JSON.serialize(new Map<String, Object>{
            'errorcode' => 0, 'msg' => 'success',
            'data' => new Map<String, Object>{
                'hitCount' => 2,
                'oppHits' => new List<Object>{
                    new Map<String, Object>{
                        'id' => '362903', 'number' => 'OFOP0002813',
                        'title' => 'US-Algeria Innovation Collaboration',
                        'agencyCode' => 'DOS-DZA', 'agency' => 'U.S. Mission to Algeria',
                        'openDate' => '06/22/2026', 'closeDate' => '08/08/2026',
                        'oppStatus' => 'posted', 'docType' => 'synopsis',
                        'cfdaList' => new List<Object>{ '19.040' }
                    },
                    new Map<String, Object>{
                        'id' => '111', 'number' => 'NSF-2026-1',
                        'title' => 'Research Forecast',
                        'agencyCode' => 'NSF', 'agency' => 'National Science Foundation',
                        'openDate' => '01/01/2026', 'closeDate' => '12/31/2026',
                        'oppStatus' => 'forecasted', 'docType' => 'forecast',
                        'cfdaList' => new List<Object>{ '47.041', '47.049' }
                    }
                }
            }
        });
    }

    @isTest
    static void testRequestBuild() {
        OA_ConnectorContext ctx = new OA_ConnectorContext('t-1',
            new Map<String, Object>{ 'namedCredential' => 'OA_GrantsGov', 'endpointPath' => '/v1/api/search2', 'rows' => 5 });
        HttpRequest req = new OA_GrantsGovRequest().build(ctx, 'small business');
        System.assertEquals('POST', req.getMethod(), 'POST method');
        System.assert(req.getEndpoint().startsWith('callout:OA_GrantsGov/v1/api/search2'), 'routes via NC + path');
        System.assert(req.getBody().contains('small business'), 'keyword in body');
        System.assert(req.getBody().contains('"rows":5'), 'rows honored');
        // default config path when ctx config empty
        HttpRequest d = new OA_GrantsGovRequest().build(new OA_ConnectorContext('t-2'), null);
        System.assert(d.getEndpoint().startsWith('callout:OA_GrantsGov'), 'default NC');
    }

    @isTest
    static void testParserValidAndEdgeCases() {
        List<OA_ConnectorRow> rows = new OA_GrantsGovParser().parse(okBody());
        System.assertEquals(2, rows.size(), 'two opp hits');
        System.assertEquals('OFOP0002813', rows[0].getString('number'), 'number parsed');
        System.assertEquals('19.040', rows[0].getString('cfda'), 'single cfda');
        System.assertEquals('47.041, 47.049', rows[1].getString('cfda'), 'joined cfda');
        // blank -> empty
        System.assertEquals(0, new OA_GrantsGovParser().parse('').size(), 'blank -> empty');
        System.assertEquals(0, new OA_GrantsGovParser().parse('   ').size(), 'whitespace -> empty');
        // no data block -> empty
        System.assertEquals(0, new OA_GrantsGovParser().parse('{"errorcode":0}').size(), 'no data -> empty');
        // empty oppHits
        System.assertEquals(0, new OA_GrantsGovParser().parse('{"data":{"oppHits":[]}}').size(), 'empty hits');
    }

    @isTest
    static void testParserErrorPayloadThrows() {
        try {
            new OA_GrantsGovParser().parse('{"errorcode":1,"msg":"bad request"}');
            System.assert(false, 'error payload should throw');
        } catch (OA_ConnectorException e) {
            System.assert(e.getMessage().contains('bad request'), 'surfaces msg');
        }
    }

    @isTest
    static void testParserMalformedThrows() {
        try {
            new OA_GrantsGovParser().parse('not json');
            System.assert(false, 'malformed should throw');
        } catch (OA_ConnectorException e) {
            System.assert(e.getMessage().contains('unparseable') || e.getMessage().contains('unexpected'), 'framework error');
        }
        try {
            new OA_GrantsGovParser().parse('[1,2,3]'); // valid JSON, wrong top-level
            System.assert(false, 'array top-level should throw');
        } catch (OA_ConnectorException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testMapper() {
        OA_ConnectorRow row = new OA_ConnectorRow()
            .put('id', '362903').put('number', 'OFOP0002813').put('title', 'T')
            .put('agency', 'DOS').put('agencyCode', 'DOS-DZA')
            .put('openDate', '06/22/2026').put('closeDate', '08/08/2026')
            .put('oppStatus', 'posted').put('docType', 'synopsis').put('cfda', '19.040');
        OA_Opportunity_Signal__c s = (OA_Opportunity_Signal__c) new OA_GrantsGovMapper()
            .toStaging(row, new OA_ConnectorContext('run-9'));
        System.assertEquals('GRANTS:OFOP0002813', s.Canonical_Key__c, 'source-scoped key');
        System.assertEquals('Grants.gov', s.Source__c);
        System.assertEquals('Grant', s.Type__c);
        System.assertEquals('Pending', s.Review_Status__c, 'lands in review queue');
        System.assertEquals('Active', s.Status__c, 'posted -> Active');
        System.assertEquals(Date.newInstance(2026, 8, 8), s.Response_Deadline__c, 'US date parsed');
        System.assertEquals('run-9', s.Source_Run_ID__c, 'run correlation');
        System.assert(s.URL__c.endsWith('/362903'), 'detail url');
        // edge cases for coverage
        System.assertEquals(null, new OA_GrantsGovMapper().toStaging(null, null), 'null row skipped');
        OA_Opportunity_Signal__c noId = (OA_Opportunity_Signal__c) new OA_GrantsGovMapper()
            .toStaging(new OA_ConnectorRow().put('title', 'x'), null);
        System.assertEquals(null, noId, 'no identity skipped');
        // status derivations + bad date
        OA_Opportunity_Signal__c closed = (OA_Opportunity_Signal__c) new OA_GrantsGovMapper()
            .toStaging(new OA_ConnectorRow().put('number', 'A').put('oppStatus', 'closed').put('closeDate', 'bad'), null);
        System.assertEquals('Expired', closed.Status__c, 'closed -> Expired');
        System.assertEquals(null, closed.Response_Deadline__c, 'bad date -> null');
    }

    @isTest
    static void testConnectorIdentity() {
        OA_GrantsGovConnector c = new OA_GrantsGovConnector();
        System.assertEquals('GrantsGov', c.sourceKey());
        System.assertEquals('callout:OA_GrantsGov', c.namedCredential());
        System.assertEquals(OA_Opportunity_Signal__c.SObjectType, c.stagingType());
        System.assertNotEquals(null, c.requestBuilder());
        System.assertNotEquals(null, c.parser());
        System.assertNotEquals(null, c.mapper());
    }

    @isTest
    static void testServicePreviewZeroDml() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, okBody()));
        Test.startTest();
        OA_GrantsGovService.Outcome out = OA_GrantsGovService.preview(
            new List<String>{ 'small business' }, null);
        Test.stopTest();
        System.assertEquals(2, out.signals.size(), 'signals built in memory');
        System.assertEquals(false, out.committed, 'preview never commits');
        System.assertEquals(0, out.persisted, 'nothing persisted');
        System.assertEquals(0, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c'), 'ZERO staging rows (0 DML preview)');
        System.assertEquals(0, Database.countQuery('SELECT count() FROM OA_Connector_Run__c WHERE Source_System__c = \'GrantsGov\''), 'no telemetry on preview');
    }

    /**
     * Test-only user granted the OA_Opportunity_Intelligence_Runtime permission set,
     * so the new object's fields are accessible for the idempotent upsert. NO real user
     * is assigned the permission set (it ships dormant/unassigned).
     */
    private static User runtimeUser() {
        User u = new User(
            Alias = 'oaoi',
            Email = 'oa.oi.test@example.com.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'OIRuntimeTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = 'oa.oi.' + UserInfo.getOrganizationId() + '@example.com.invalid'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'OA_Opportunity_Intelligence_Runtime' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    @isTest
    static void testServiceCommitStagingOnlyAndIdempotent() {
        User u = runtimeUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, okBody()));
        System.runAs(u) {
            Test.startTest();
            OA_GrantsGovService.Outcome first = OA_GrantsGovService.run(new List<String>{ 'a' }, null, true);
            OA_GrantsGovService.run(new List<String>{ 'a' }, null, true); // re-run (idempotency)
            Test.stopTest();

            System.assertEquals(true, first.committed, 'committed');
            System.assertEquals(2, first.persisted, 'two signals upserted');
            System.assertEquals(2, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c'),
                'idempotent: re-run UPSERTS, still 2 rows');
            // STAGING ONLY — no CRM writes
            System.assertEquals(0, Database.countQuery('SELECT count() FROM Lead'), 'NO Lead created (no CRM write)');
            // telemetry recorded for the committed runs
            System.assert(Database.countQuery('SELECT count() FROM OA_Connector_Run__c WHERE Source_System__c = \'GrantsGov\'') >= 1,
                'telemetry persisted on commit');
            // all signals in review queue
            System.assertEquals(2, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c WHERE Review_Status__c = \'Pending\''),
                'every signal Pending (human gate)');
        }
    }

    @isTest
    static void testServiceHttpErrorRoutesException() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(500, '{"errorcode":9,"msg":"server error"}'));
        Test.startTest();
        OA_GrantsGovService.Outcome out = OA_GrantsGovService.run(new List<String>{ 'x' }, null, true);
        Test.stopTest();
        System.assertEquals(1, out.httpErrors, 'non-2xx recorded');
        System.assertEquals(0, out.persisted, 'no signals on http error');
        System.assertEquals('PartialErrors', out.telemetry.Status__c, 'telemetry reflects partial');
        System.assert(Database.countQuery('SELECT count() FROM OA_Enrichment_Exception__c WHERE Source_System__c = \'GrantsGov\'') >= 1,
            'anomaly routed to human-review exception queue');
    }
}
