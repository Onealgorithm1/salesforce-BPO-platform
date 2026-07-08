/**
 * OA_SAMOpportunities_Test — unit tests for the SAM Get Opportunities connector.
 *
 * All HTTP is mocked (OA_ConnectorMock) — NO live callout (SAM needs a gated key).
 * Proves the Phase 2 safety guarantees: preview is 0-DML; commit writes STAGING
 * ONLY; no Lead/CRM record is created; upsert is idempotent; pagination loops and
 * caps; anomalies route to human review.
 */
@isTest
private class OA_SAMOpportunities_Test {

    private static String body(Integer count, Integer total) {
        List<Object> data = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            data.add(new Map<String, Object>{
                'noticeId' => 'N' + i,
                'title' => 'Opportunity ' + i,
                'solicitationNumber' => 'SOL-' + i,
                'fullParentPathName' => 'DEPT OF DEFENSE.ARMY',
                'naicsCode' => '541512',
                'classificationCode' => 'D307',
                'typeOfSetAside' => 'SBA',
                'typeOfSetAsideDescription' => 'Total Small Business Set-Aside',
                'placeOfPerformance' => new Map<String, Object>{
                    'city' => new Map<String, Object>{ 'name' => 'Fort Bragg' },
                    'state' => new Map<String, Object>{ 'code' => 'NC' } },
                'postedDate' => '2026-06-01',
                'responseDeadLine' => '2026-08-01T17:00:00-04:00',
                'award' => new Map<String, Object>{ 'amount' => '250000' },
                'active' => 'Yes',
                'uiLink' => 'https://sam.gov/opp/N' + i + '/view'
            });
        }
        return JSON.serialize(new Map<String, Object>{
            'totalRecords' => total, 'limit' => 100, 'offset' => 0, 'opportunitiesData' => data });
    }

    private static Map<String, Object> cfg(Integer lim, Integer maxPages) {
        return new Map<String, Object>{
            'postedFrom' => '01/01/2026', 'postedTo' => '12/31/2026',
            'ncode' => '541512', 'typeOfSetAside' => 'SBA',
            'limit' => lim, 'maxPages' => maxPages };
    }

    private static User runtimeUser() {
        User u = new User(
            Alias = 'oaoi2', Email = 'oa.sam.test@example.com.invalid',
            EmailEncodingKey = 'UTF-8', LastName = 'SAMRuntimeTest',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(), TimeZoneSidKey = 'America/New_York',
            Username = 'oa.sam.' + UserInfo.getOrganizationId() + '@example.com.invalid');
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'OA_Opportunity_Intelligence_Runtime' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    @isTest
    static void testRequestBuild() {
        OA_ConnectorContext ctx = new OA_ConnectorContext('t-1', cfg(50, 5));
        HttpRequest req = new OA_SAMOpportunities_Request().build(ctx, 0);
        System.assertEquals('GET', req.getMethod());
        String ep = req.getEndpoint();
        System.assert(ep.startsWith('callout:OA_SAM_Opportunities/opportunities/v2/search'), 'routes via NC + path');
        System.assert(ep.contains('postedFrom='), 'window set');
        System.assert(ep.contains('limit=50') && ep.contains('offset=0'), 'paging set');
        System.assert(ep.contains('ncode=541512'), 'NAICS filter');
        System.assert(!ep.containsIgnoreCase('api_key') && !ep.containsIgnoreCase('x-api-key'),
            'NO key in the URL (EC header only)');
        // offset from input overrides cfg
        System.assert(new OA_SAMOpportunities_Request().build(ctx, 100).getEndpoint().contains('offset=100'), 'input offset');
        // limit cap at 1000
        System.assert(new OA_SAMOpportunities_Request().build(
            new OA_ConnectorContext('t-2', new Map<String,Object>{'limit'=>5000}), 0).getEndpoint().contains('limit=1000'), 'limit capped');
    }

    @isTest
    static void testParser() {
        List<OA_ConnectorRow> rows = new OA_SAMOpportunities_ResponseParser().parse(body(2, 2));
        System.assertEquals(2, rows.size());
        System.assertEquals('N0', rows[0].getString('noticeId'));
        System.assertEquals('541512', rows[0].getString('naics'));
        System.assertEquals('D307', rows[0].getString('psc'));
        System.assertEquals('Total Small Business Set-Aside', rows[0].getString('setAside'));
        System.assertEquals('Fort Bragg, NC', rows[0].getString('placeOfPerformance'), 'nested PoP');
        System.assertEquals('2', rows[0].getString('totalRecords'), 'total carried for pagination');
        // naicsCodes[] fallback
        String multi = JSON.serialize(new Map<String,Object>{ 'opportunitiesData' => new List<Object>{
            new Map<String,Object>{ 'noticeId'=>'x', 'naicsCodes'=>new List<Object>{'111','222'} } } });
        System.assertEquals('111, 222', new OA_SAMOpportunities_ResponseParser().parse(multi)[0].getString('naics'));
        // edges
        System.assertEquals(0, new OA_SAMOpportunities_ResponseParser().parse('').size(), 'blank -> empty');
        System.assertEquals(0, new OA_SAMOpportunities_ResponseParser().parse('{"totalRecords":0}').size(), 'no data -> empty');
    }

    @isTest
    static void testParserErrorAndMalformed() {
        try { new OA_SAMOpportunities_ResponseParser().parse('{"error":{"message":"invalid key"}}'); System.assert(false); }
        catch (OA_ConnectorException e) { System.assert(e.getMessage().contains('error')); }
        try { new OA_SAMOpportunities_ResponseParser().parse('not json'); System.assert(false); }
        catch (OA_ConnectorException e) { System.assert(e.getMessage().contains('unparseable')); }
        try { new OA_SAMOpportunities_ResponseParser().parse('[1,2]'); System.assert(false); }
        catch (OA_ConnectorException e) { System.assert(true); }
    }

    @isTest
    static void testMapper() {
        OA_ConnectorRow row = new OA_SAMOpportunities_ResponseParser().parse(body(1, 1))[0];
        OA_Opportunity_Signal__c s = (OA_Opportunity_Signal__c) new OA_SAMOpportunities_Mapper()
            .toStaging(row, new OA_ConnectorContext('run-1'));
        System.assertEquals('SAM:N0', s.Canonical_Key__c, 'source-scoped key');
        System.assertEquals('SAM.gov', s.Source__c);
        System.assertEquals('Contract', s.Type__c);
        System.assertEquals('Pending', s.Review_Status__c, 'lands in review queue');
        System.assertEquals('Active', s.Status__c, 'active=Yes -> Active');
        System.assertEquals(Date.newInstance(2026, 8, 1), s.Response_Deadline__c, 'ISO date parsed');
        System.assertEquals(250000, s.Estimated_Value__c, 'award amount');
        System.assertEquals('D307', s.PSC__c);
        System.assertEquals('Fort Bragg, NC', s.Place_of_Performance__c);
        // edge: no noticeId -> skip; null row -> null
        System.assertEquals(null, new OA_SAMOpportunities_Mapper().toStaging(
            new OA_ConnectorRow().put('title', 'x'), null), 'no noticeId skipped');
        System.assertEquals(null, new OA_SAMOpportunities_Mapper().toStaging(null, null));
    }

    @isTest
    static void testConnectorIdentity() {
        OA_SAMOpportunities_Connector c = new OA_SAMOpportunities_Connector();
        System.assertEquals('SAMOpportunities', c.sourceKey());
        System.assertEquals('callout:OA_SAM_Opportunities', c.namedCredential());
        System.assertEquals(OA_Opportunity_Signal__c.SObjectType, c.stagingType());
        System.assertNotEquals(null, c.requestBuilder());
        System.assertNotEquals(null, c.parser());
        System.assertNotEquals(null, c.mapper());
    }

    @isTest
    static void testServicePreviewZeroDml() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, body(2, 2)));
        Test.startTest();
        OA_SAMOpportunitiesService.Outcome out = OA_SAMOpportunitiesService.preview(cfg(100, 5));
        Test.stopTest();
        System.assertEquals(2, out.signals.size(), 'signals built in memory');
        System.assertEquals(false, out.committed, 'preview never commits');
        System.assertEquals(0, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c'), 'ZERO staging rows (0 DML preview)');
    }

    @isTest
    static void testServiceCommitStagingOnlyAndIdempotent() {
        User u = runtimeUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, body(2, 2)));
        System.runAs(u) {
            Test.startTest();
            OA_SAMOpportunitiesService.Outcome first = OA_SAMOpportunitiesService.run(cfg(100, 5), true);
            OA_SAMOpportunitiesService.run(cfg(100, 5), true); // re-run (idempotency)
            Test.stopTest();

            System.assertEquals(true, first.committed);
            System.assertEquals(2, first.persisted, 'two signals upserted');
            System.assertEquals(2, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c'),
                'idempotent: re-run UPSERTS, still 2 rows');
            System.assertEquals(0, Database.countQuery('SELECT count() FROM Lead'), 'NO Lead created (no CRM write)');
            System.assert(Database.countQuery('SELECT count() FROM OA_Connector_Run__c WHERE Source_System__c = \'SAMOpportunities\'') >= 1,
                'telemetry persisted on commit');
            System.assertEquals(2, Database.countQuery('SELECT count() FROM OA_Opportunity_Signal__c WHERE Review_Status__c = \'Pending\''),
                'every signal Pending (human gate)');
        }
    }

    @isTest
    static void testPaginationLoopAndCap() {
        // full page each call (2 records == limit 2) -> loop continues, capped at maxPages=2
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, body(2, 10)));
        Test.startTest();
        OA_SAMOpportunitiesService.Outcome out = OA_SAMOpportunitiesService.preview(cfg(2, 2));
        Test.stopTest();
        System.assertEquals(2, out.pages, 'looped and capped at maxPages');
        System.assertEquals(4, out.mapped, '2 pages x 2 records');
    }

    @isTest
    static void testServiceHttpErrorRoutesException() {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(403, '{"error":{"message":"forbidden"}}'));
        Test.startTest();
        OA_SAMOpportunitiesService.Outcome out = OA_SAMOpportunitiesService.run(cfg(100, 5), true);
        Test.stopTest();
        System.assertEquals(1, out.httpErrors, 'non-2xx recorded');
        System.assertEquals(0, out.persisted, 'no signals on http error');
        System.assertEquals('PartialErrors', out.telemetry.Status__c);
        System.assert(Database.countQuery('SELECT count() FROM OA_Enrichment_Exception__c WHERE Source_System__c = \'SAMOpportunities\'') >= 1,
            'anomaly routed to human-review exception queue');
    }
}
