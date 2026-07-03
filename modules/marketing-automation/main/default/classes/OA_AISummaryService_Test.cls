@isTest(SeeAllData=false)
private class OA_AISummaryService_Test {

    private static final String SAMPLE_TRANSCRIPT =
        'Louis Rubino: Welcome to the meeting, Jane.\nJane Smith: Thank you for having me.';

    @TestSetup
    static void makeData() {
        insert new Lead(
            FirstName              = 'Jane',
            LastName               = 'Smith',
            Company                = 'Prime Contractor LLC',
            Email                  = 'jane.smith@primecontractor.com',
            LeadSource             = 'SAM.gov',
            Transcript_Content__c  = SAMPLE_TRANSCRIPT,
            Recording_Retrieved__c = true
        );
    }

    private static final String ANTHROPIC_SUCCESS_BODY =
        '{"content":[{"type":"text","text":"{\\"customer_needs\\":[\\"Subcontracting opportunities\\"],'
        + '\\"recommended_outcome\\":\\"Qualified Opportunity\\",\\"confidence\\":\\"High\\",'
        + '\\"summary_paragraph\\":\\"Strong teaming meeting.\\"}"}],'
        + '"id":"msg-001","model":"claude-sonnet-4-6","stop_reason":"end_turn"}';

    // ── Mocks ──────────────────────────────────────────────────────────────────────

    private class AnthropicMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(ANTHROPIC_SUCCESS_BODY);
            return res;
        }
    }

    private class AnthropicServerErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":{"type":"internal_server_error","message":"Something went wrong."}}');
            return res;
        }
    }

    // ── Tests ──────────────────────────────────────────────────────────────────────

    // Verifies that a Lead with transcript content gets AI_Summary__c populated.
    @isTest
    static void testSummarizePopulatesAISummary() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        Test.startTest();
        OA_AISummaryService.summarize(l.Id);
        Test.stopTest();

        Lead updated = [SELECT AI_Summary__c FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, updated.AI_Summary__c,
            'AI_Summary__c should be populated after a successful Anthropic API call');
        System.assert(updated.AI_Summary__c.contains('Qualified Opportunity'),
            'AI_Summary__c should contain the summarized JSON content from the API response');
    }

    // Verifies idempotency: summarize must not overwrite an existing AI_Summary__c.
    @isTest
    static void testSummarizeIsIdempotent() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        update new Lead(Id = l.Id, AI_Summary__c = 'existing-summary');

        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        Test.startTest();
        OA_AISummaryService.summarize(l.Id);
        Test.stopTest();

        Lead updated = [SELECT AI_Summary__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('existing-summary', updated.AI_Summary__c,
            'AI_Summary__c must not be overwritten when already populated — idempotency guard');
    }

    // Verifies that summarize exits without callout when Transcript_Content__c is blank.
    @isTest
    static void testSummarizeSkipsLeadWithNoTranscript() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        update new Lead(Id = l.Id, Transcript_Content__c = null);

        Test.setMock(HttpCalloutMock.class, new AnthropicMock());
        Test.startTest();
        OA_AISummaryService.summarize(l.Id);
        Test.stopTest();

        Lead updated = [SELECT AI_Summary__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, updated.AI_Summary__c,
            'AI_Summary__c should remain null when transcript content is blank');
    }

    // Verifies that a 500 error from the Anthropic API does not throw and leaves
    // AI_Summary__c null.
    @isTest
    static void testSummarizeApiFailureDoesNotThrow() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new AnthropicServerErrorMock());
        Test.startTest();
        OA_AISummaryService.summarize(l.Id);
        Test.stopTest();

        Lead updated = [SELECT AI_Summary__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, updated.AI_Summary__c,
            'AI_Summary__c should remain null when the Anthropic API returns a server error');
    }

    // ── Unit tests for @TestVisible helpers ───────────────────────────────────────

    @isTest
    static void testBuildRequestContainsCompanyAndTranscript() {
        Lead l = new Lead(
            FirstName = 'Jane', LastName = 'Smith',
            Company   = 'Test Corp',
            Transcript_Content__c = 'Louis: Hello.'
        );
        String body = OA_AISummaryService.buildRequest(l);
        System.assert(body.contains('Test Corp'),
            'Request body should include the Lead Company');
        System.assert(body.contains('claude-sonnet-4-6'),
            'Request body should reference the configured model');
        System.assert(body.contains('Louis'),
            'Request body should include transcript content');
    }

    @isTest
    static void testExtractContentParsesResponseBlock() {
        String rawResponse = '{"content":[{"type":"text","text":"summary-text"}],"id":"msg-001"}';
        String extracted = OA_AISummaryService.extractContent(rawResponse);
        System.assertEquals('summary-text', extracted,
            'extractContent should return the text value from the first content block');
    }

    @isTest
    static void testExtractContentHandlesMalformedResponse() {
        String result = OA_AISummaryService.extractContent('not-valid-json');
        System.assertEquals(null, result,
            'extractContent should return null on JSON parse failure');
    }

    @isTest
    static void testExtractContentHandlesEmptyContentArray() {
        String result = OA_AISummaryService.extractContent('{"content":[],"id":"msg-001"}');
        System.assertEquals(null, result,
            'extractContent should return null when content array is empty');
    }
}
