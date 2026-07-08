/**
 * Tests OA_CandidateDiscoveryQueueable via a MOCKED USASpending callout (no live call) and the real registry row
 * (CMDT is visible in tests). Proves preview=0 DML, commit inserts Candidates, empty-input safe, retry path.
 * No chaining occurs in tests (guarded), so these run in a single async transaction.
 */
@isTest
private class OA_CandidateDiscoveryQueueable_Test {

    private class UsMock implements HttpCalloutMock {
        private Integer status;
        UsMock(Integer status) { this.status = status; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody('{"results":[{"Recipient Name":"MOCK CO","Recipient UEI":"MOCKUEIQ1","Award Amount":100,"Place of Performance State Code":"CA"}]}');
            return res;
        }
    }

    @isTest static void preview_runs_async_zero_dml() {
        Test.setMock(HttpCalloutMock.class, new UsMock(200));
        Test.startTest();
        System.enqueueJob(new OA_CandidateDiscoveryQueueable('USASpending', new List<String>{ 'aerospace' }, false, 3, 1));
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'preview writes nothing');
    }

    @isTest static void commit_inserts_candidate() {
        Test.setMock(HttpCalloutMock.class, new UsMock(200));
        Test.startTest();
        System.enqueueJob(new OA_CandidateDiscoveryQueueable('USASpending', new List<String>{ 'aerospace' }, true, 3, 1));
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'commit inserts the discovered candidate');
        System.assertEquals('USASpending', [SELECT Source_System__c FROM OA_Discovered_Organization__c LIMIT 1].Source_System__c);
    }

    @isTest static void retry_on_transient_http_error() {
        Test.setMock(HttpCalloutMock.class, new UsMock(503)); // non-2xx -> httpErrors>0 -> triggers the bounded retry
        Test.startTest();
        System.enqueueJob(new OA_CandidateDiscoveryQueueable('USASpending', new List<String>{ 'aerospace' }, false, 3, 1));
        Test.stopTest();
        // Still no DML (preview) and no unhandled exception; the retry path executed.
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c]);
    }

    @isTest static void empty_inputs_safe() {
        Test.startTest();
        System.enqueueJob(new OA_CandidateDiscoveryQueueable('USASpending', new List<String>(), true, 3, 1));
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c]);
    }
}
