/**
 * Tests the generic driver via an injected fake connector — NO live callout, NO real registry dependency.
 * Verifies: maxResults cap, preview=0 DML, commit inserts Candidates, connector-agnostic execution, error paths.
 */
@isTest
private class OA_CandidateDiscovery_Test {

    // A source-agnostic fake connector returning a canned canonical-org list.
    private class FakeConnector implements OA_IEnrichmentConnector {
        private Integer n;
        FakeConnector(Integer n) { this.n = n; }
        public String sourceKey() { return 'FAKE'; }
        public OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg) {
            OA_ConnectorResult r = new OA_ConnectorResult('FAKE');
            r.requested = 1; r.lastStatus = 200;
            for (Integer i = 0; i < n; i++) {
                OA_CanonicalOrg c = new OA_CanonicalOrg();
                c.organizationName = 'Fake Org ' + i;
                c.uei = 'UEIFAKE' + i;
                c.state = 'CA';
                c.sourceSystem = 'FAKE';
                c.sourceConfidence = 'HIGH';
                r.organizations.add(c);
            }
            r.parsed = r.organizations.size();
            return r;
        }
    }

    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(DeveloperName = 'FAKE', Connector_Class__c = 'FakeConnector');
    }

    @isTest static void preview_caps_and_writes_nothing() {
        Test.startTest();
        OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run(new FakeConnector(5), cfg(), 'q', false, 3);
        Test.stopTest();
        System.assertEquals(5, r.parsed, 'connector parsed 5');
        System.assertEquals(3, r.capped, 'maxResults capped to 3');
        System.assertEquals(0, r.candidates.inserted, 'preview inserts nothing');
        System.assertEquals(3, r.candidates.wouldInsert, '3 unique would insert');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'no DML in preview');
    }

    @isTest static void commit_inserts_capped_candidates() {
        Test.startTest();
        OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run(new FakeConnector(5), cfg(), 'q', true, 3);
        Test.stopTest();
        System.assertEquals(3, r.candidates.inserted, 'commit inserts exactly the capped 3');
        System.assertEquals(3, [SELECT COUNT() FROM OA_Discovered_Organization__c]);
    }

    @isTest static void null_maxResults_processes_all() {
        OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run(new FakeConnector(4), cfg(), 'q', false, null);
        System.assertEquals(4, r.capped, 'null cap = all');
    }

    @isTest static void unknown_connector_name_throws() {
        try {
            OA_CandidateDiscovery.run('NOPE_NOT_A_CONNECTOR', 'q', false, 3);
            System.assert(false, 'should have thrown');
        } catch (OA_CandidateDiscovery.DiscoveryException e) {
            System.assert(e.getMessage().contains('No connector registry entry'), e.getMessage());
        }
    }

    // Exercises the real name-resolution path (lookup + Type.forName + instantiate + real connector) with a mocked
    // HTTP callout — NO live call. Uses the real USASpending registry row (CMDT is visible in tests).
    private class UsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"Recipient Name":"MOCK AEROSPACE","Recipient UEI":"MOCKUEI0001","Award Amount":100,"Place of Performance State Code":"CA"}]}');
            return res;
        }
    }

    @isTest static void resolves_real_connector_by_name_preview() {
        Test.setMock(HttpCalloutMock.class, new UsMock());
        Test.startTest();
        OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run('USASpending', 'aerospace', false, 2);
        Test.stopTest();
        System.assertEquals(200, r.lastStatus, 'mocked HTTP 200');
        System.assertEquals('USASpending', r.connectorName);
        System.assert(r.capped <= 2, 'respects maxResults');
        System.assertEquals(0, r.candidates.inserted, 'preview writes nothing');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'no DML in preview');
    }

    @isTest static void blank_name_throws() {
        try {
            OA_CandidateDiscovery.run('', 'q', false, 3);
            System.assert(false, 'should have thrown');
        } catch (OA_CandidateDiscovery.DiscoveryException e) {
            System.assert(e.getMessage().contains('required'), e.getMessage());
        }
    }
}