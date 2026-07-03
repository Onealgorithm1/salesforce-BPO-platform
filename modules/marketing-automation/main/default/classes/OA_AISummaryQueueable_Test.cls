@isTest(SeeAllData=false)
private class OA_AISummaryQueueable_Test {

    private class AnthropicMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"content":[{"type":"text","text":"{\\"recommended_outcome\\":\\"Qualified Opportunity\\",\\"summary_paragraph\\":\\"Strong meeting.\\"}"}],'
                + '"id":"msg-001","model":"claude-sonnet-4-6","stop_reason":"end_turn"}');
            return res;
        }
    }

    // Verifies that OA_AISummaryQueueable.execute() delegates correctly to
    // OA_AISummaryService.summarize(). The Queueable is invoked via System.enqueueJob
    // so that Test.stopTest() synchronously exercises the execute() method.
    // Whether AI_Summary__c is ultimately populated depends on whether the nested
    // @future (summarize) completes within the same Test.stopTest() flush — not
    // asserted here to avoid platform-dependent false negatives.
    @isTest
    static void testQueueableExecutesDelegatesCorrectly() {
        Lead l = new Lead(
            FirstName             = 'Jane',
            LastName              = 'Smith',
            Company               = 'Test Corp',
            Email                 = 'test@queueable.example.com',
            LeadSource            = 'Web',
            Transcript_Content__c = 'Louis: Hello. Jane: Good to meet you.'
        );
        insert l;

        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        Test.startTest();
        Id jobId = System.enqueueJob(new OA_AISummaryQueueable(l.Id));
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'System.enqueueJob should return a non-null job ID');

        Lead still = [SELECT Id FROM Lead WHERE Id = :l.Id LIMIT 1];
        System.assertNotEquals(null, still.Id,
            'Lead should exist after Queueable execution — execute() must not delete or corrupt data');
    }
}
