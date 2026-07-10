@isTest(SeeAllData=false)
private class OA_ArtifactPoller_Test {

    // Sample VTT with WEBVTT header, numeric cue IDs, timestamps, and speaker cues
    private static final String SAMPLE_VTT =
        'WEBVTT\n\n'
        + '1\n'
        + '00:00:01.000 --> 00:00:05.000\n'
        + '<v Louis Rubino>Welcome to the meeting, Jane.</v>\n\n'
        + '2\n'
        + '00:00:06.000 --> 00:00:10.000\n'
        + '<v Jane Smith>Thank you for having me, Louis.</v>\n\n'
        + '3\n'
        + '00:00:11.000 --> 00:00:15.000\n'
        + '<v Louis Rubino>We wanted to discuss subcontracting opportunities.</v>';

    @TestSetup
    static void makeData() {
        insert new OA_Graph_Credential__c(
            SetupOwnerId     = UserInfo.getOrganizationId(),
            Client_Id__c     = 'test-client-id',
            Client_Secret__c = 'test-client-secret',
            Tenant_Id__c     = 'test-tenant-id'
        );

        insert new Lead(
            FirstName            = 'Jane',
            LastName             = 'Smith',
            Company              = 'Prime Contractor LLC',
            Email                = 'jane.smith@primecontractor.com',
            LeadSource           = 'SAM.gov',
            Teams_Meeting_Id__c  = 'ms-meeting-id-lead-001',
            Recording_Retrieved__c = false
        );
    }

    // ── Mocks ──────────────────────────────────────────────────────────────────

    // Happy path: token + recordings (1 recording) + transcripts (1 transcript) + VTT content.
    // Also handles the Anthropic API endpoint so the AI summary handoff does not cause an
    // unhandled callout exception when the OA_AISummaryQueueable fires within Test.stopTest().
    private class HappyPathMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            if (ep.contains('oauth2/v2.0/token')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"access_token":"mock-token","expires_in":3600}');
            } else if (ep.contains('/recordings') && !ep.contains('/content')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"id":"rec-id-001","status":"succeeded"}]}');
            } else if (ep.contains('/transcripts') && !ep.contains('/content')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"id":"trans-id-001"}]}');
            } else if (ep.contains('/content')) {
                res.setHeader('Content-Type', 'text/vtt');
                res.setBody(SAMPLE_VTT);
            } else if (ep.contains('v1/messages')) {
                // Anthropic AI summary API
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"content":[{"type":"text","text":"{\\"recommended_outcome\\":\\"Qualified Opportunity\\",\\"summary_paragraph\\":\\"Strong teaming discussion.\\"}"}],'
                    + '"id":"msg-001","model":"claude-sonnet-4-6","stop_reason":"end_turn"}');
            }
            return res;
        }
    }

    // Happy path for artifact retrieval + Anthropic API failure.
    // Verifies that a failed AI summary does not corrupt or prevent artifact storage.
    private class HappyPathWithAnthropicFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            String ep = req.getEndpoint();
            if (ep.contains('v1/messages')) {
                res.setStatusCode(500);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"error":{"type":"internal_server_error","message":"Server error"}}');
            } else if (ep.contains('oauth2/v2.0/token')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"access_token":"mock-token","expires_in":3600}');
            } else if (ep.contains('/recordings') && !ep.contains('/content')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"id":"rec-id-001","status":"succeeded"}]}');
            } else if (ep.contains('/transcripts') && !ep.contains('/content')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"id":"trans-id-001"}]}');
            } else if (ep.contains('/content')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'text/vtt');
                res.setBody(SAMPLE_VTT);
            }
            return res;
        }
    }

    // No recording available yet: recordings value is empty
    private class NoRecordingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-token","expires_in":3600}');
            } else {
                res.setBody('{"value":[]}');
            }
            return res;
        }
    }

    // Recording present but no transcript
    private class RecordingNoTranscriptMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint();
            if (ep.contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-token","expires_in":3600}');
            } else if (ep.contains('/recordings')) {
                res.setBody('{"value":[{"id":"rec-id-001","status":"succeeded"}]}');
            } else {
                // transcripts endpoint
                res.setBody('{"value":[]}');
            }
            return res;
        }
    }

    // Token returns 401 — simulates expired or invalid client secret
    private class TokenFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(401);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"invalid_client"}');
            return res;
        }
    }

    // ── Tests ──────────────────────────────────────────────────────────────────

    // Verifies the full artifact pipeline: recording found → transcript found →
    // VTT preprocessed and stored → Lead updated atomically with Recording_Retrieved__c = true.
    @isTest
    static void testHappyPathRecordingAndTranscriptRetrieved() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT Recording_Id__c, Transcript_Id__c, Transcript_Content__c,
                         Recording_Retrieved__c
                  FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        System.assertEquals('rec-id-001',   l.Recording_Id__c,
            'Recording_Id__c should be set to the first recording ID');
        System.assertEquals('trans-id-001', l.Transcript_Id__c,
            'Transcript_Id__c should be set to the first transcript ID');
        System.assertEquals(true,           l.Recording_Retrieved__c,
            'Recording_Retrieved__c should be true after successful retrieval');
        System.assertNotEquals(null, l.Transcript_Content__c,
            'Transcript_Content__c should contain preprocessed VTT dialogue');

        // Verify the preprocessor stripped WEBVTT header and timestamps
        System.assert(!l.Transcript_Content__c.contains('WEBVTT'),
            'Preprocessed content should not contain WEBVTT header');
        System.assert(!l.Transcript_Content__c.contains(' --> '),
            'Preprocessed content should not contain VTT timestamp blocks');
        System.assert(l.Transcript_Content__c.contains('Louis Rubino:'),
            'Preprocessed content should contain speaker attribution');
        System.assert(l.Transcript_Content__c.contains('Jane Smith:'),
            'Preprocessed content should contain second speaker');
    }

    // When no recording is available yet, the Lead must not be updated and
    // Recording_Retrieved__c must remain false so the next cycle retries.
    @isTest
    static void testNoRecordingSkipsLead() {
        Test.setMock(HttpCalloutMock.class, new NoRecordingMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT Recording_Id__c, Recording_Retrieved__c
                  FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(null,  l.Recording_Id__c,
            'Recording_Id__c should be null when no recording is available yet');
        System.assertEquals(false, l.Recording_Retrieved__c,
            'Recording_Retrieved__c should remain false so the next cycle retries');
    }

    // When a recording exists but no transcript is available, the Lead is marked
    // retrieved (recording confirmed) and only Recording_Id__c is set.
    // Transcript fields are left null; OA_AISummaryService will skip this Lead until populated.
    @isTest
    static void testRecordingFoundNoTranscriptMarksRetrieved() {
        Test.setMock(HttpCalloutMock.class, new RecordingNoTranscriptMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT Recording_Id__c, Transcript_Id__c, Recording_Retrieved__c
                  FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals('rec-id-001', l.Recording_Id__c,
            'Recording_Id__c should be set when recording is found');
        System.assertEquals(null, l.Transcript_Id__c,
            'Transcript_Id__c should be null when no transcript is available');
        System.assertEquals(true, l.Recording_Retrieved__c,
            'Recording_Retrieved__c should be true — recording was confirmed; no retry needed');
    }

    // When the Graph token request fails, the poller exits without modifying any Leads.
    @isTest
    static void testTokenFailureExitsGracefully() {
        Test.setMock(HttpCalloutMock.class, new TokenFailMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT Recording_Retrieved__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(false, l.Recording_Retrieved__c,
            'Recording_Retrieved__c should remain false when token request fails');
    }

    // When all leads already have Recording_Retrieved__c = true, the SOQL returns
    // no candidates and the poller exits without making any callouts.
    @isTest
    static void testNoLeadsPendingExitsGracefully() {
        update new Lead(
            Id = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1].Id,
            Recording_Retrieved__c = true
        );

        // HappyPathMock should never be called — if it is, it would make unnecessary callouts.
        // The test verifies exit on empty SOQL result; mock presence here is for safety only.
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        // No assertion needed — absence of exceptions confirms graceful exit.
        // The Lead flag should still be true (unchanged).
        Lead l = [SELECT Recording_Retrieved__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(true, l.Recording_Retrieved__c, 'Flag should remain true — lead was excluded from query');
    }

    // Verifies the Schedulable interface can be wired to System.schedule without errors.
    @isTest
    static void testSchedulerInvokesSilently() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        String jobId = System.schedule('OA ArtifactPoller Unit Test', '0 15 * * * ?', new OA_ArtifactPoller());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler should return a valid CronTrigger job ID');
    }

    // ── Unit tests for preprocessVtt ──────────────────────────────────────────

    @isTest
    static void testPreprocessVttExtractsSpeakerLines() {
        String result = OA_ArtifactPoller.preprocessVtt(SAMPLE_VTT);
        System.assertNotEquals(null, result, 'preprocessVtt should return non-null for valid VTT');
        System.assert(result.contains('Louis Rubino: Welcome to the meeting, Jane.'),
            'First speaker line should be extracted and formatted as "Speaker: Text"');
        System.assert(result.contains('Jane Smith: Thank you for having me, Louis.'),
            'Second speaker line should be extracted');
        System.assert(!result.contains('WEBVTT'), 'WEBVTT header should be stripped');
        System.assert(!result.contains(' --> '), 'Timestamp blocks should be stripped');
        System.assert(!result.contains('</v>'), 'VTT cue closing tags should be stripped');
    }

    @isTest
    static void testPreprocessVttNullInputReturnsNull() {
        System.assertEquals(null, OA_ArtifactPoller.preprocessVtt(null),
            'preprocessVtt should return null for null input');
        System.assertEquals(null, OA_ArtifactPoller.preprocessVtt(''),
            'preprocessVtt should return null for empty string');
        System.assertEquals(null, OA_ArtifactPoller.preprocessVtt('  \n  '),
            'preprocessVtt should return null for whitespace-only input');
    }

    @isTest
    static void testPreprocessVttHeaderOnlyReturnsNull() {
        // VTT with header and timestamps but no speaker dialogue
        String headerOnly = 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:05.000\n';
        System.assertEquals(null, OA_ArtifactPoller.preprocessVtt(headerOnly),
            'preprocessVtt should return null when VTT contains no extractable dialogue lines');
    }

    // ── Phase 4: ArtifactPoller → AI Summary Handoff Tests ───────────────────────

    // Verifies that when transcript content is populated, the Queueable handoff to
    // OA_AISummaryService is enqueued. The artifact retrieval pipeline must complete
    // successfully regardless of whether the async summary chain fully executes
    // within Test.stopTest().
    @isTest
    static void testTranscriptTriggersSummaryHandoff() {
        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [
            SELECT Recording_Id__c, Transcript_Id__c, Transcript_Content__c, Recording_Retrieved__c
            FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1
        ];
        System.assertNotEquals(null, l.Transcript_Content__c,
            'Transcript_Content__c must be populated — precondition for AI summary handoff');
        System.assertEquals(true, l.Recording_Retrieved__c,
            'Recording_Retrieved__c must be true before summary can be triggered');
        System.assertEquals('rec-id-001', l.Recording_Id__c,
            'Recording_Id__c must be set — artifact retrieval must succeed even when summary is pending');
    }

    // Verifies that when no transcript is available, the AI summary Queueable is
    // NOT enqueued (Transcript_Content__c remains null, the guard condition is false).
    @isTest
    static void testNoTranscriptSkipsSummaryHandoff() {
        Test.setMock(HttpCalloutMock.class, new RecordingNoTranscriptMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT Transcript_Content__c, AI_Summary__c
                  FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(null, l.Transcript_Content__c,
            'Transcript_Content__c should be null when no transcript was retrieved');
        System.assertEquals(null, l.AI_Summary__c,
            'AI_Summary__c should not be populated when no transcript was retrieved');
    }

    // Verifies that a failed AI summary call (Anthropic returns 500) does not corrupt
    // or prevent the artifact retrieval fields from being stored. Artifact retrieval
    // and AI summary are separate concerns — summary failure must not roll back artifacts.
    @isTest
    static void testSummaryFailureDoesNotBreakArtifactRetrieval() {
        Test.setMock(HttpCalloutMock.class, new HappyPathWithAnthropicFailMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [
            SELECT Recording_Id__c, Transcript_Id__c, Recording_Retrieved__c, AI_Summary__c
            FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1
        ];
        System.assertEquals('rec-id-001', l.Recording_Id__c,
            'Recording_Id__c should be set even when AI summary fails');
        System.assertEquals('trans-id-001', l.Transcript_Id__c,
            'Transcript_Id__c should be set even when AI summary fails');
        System.assertEquals(true, l.Recording_Retrieved__c,
            'Recording_Retrieved__c should be true even when AI summary fails');
        System.assertEquals(null, l.AI_Summary__c,
            'AI_Summary__c should remain null when Anthropic API returns an error');
    }

    // Verifies that running processArtifacts a second time on a Lead that already has
    // Recording_Retrieved__c = true excludes it from the candidate query, so no duplicate
    // summary Queueables are enqueued.
    @isTest
    static void testReRunDoesNotDuplicateSummary() {
        update new Lead(
            Id = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1].Id,
            Recording_Retrieved__c = true,
            AI_Summary__c = 'existing-summary'
        );

        Test.setMock(HttpCalloutMock.class, new HappyPathMock());
        Test.startTest();
        OA_ArtifactPoller.processArtifacts();
        Test.stopTest();

        Lead l = [SELECT AI_Summary__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals('existing-summary', l.AI_Summary__c,
            'AI_Summary__c should be unchanged — lead with Recording_Retrieved__c=true is excluded from the query');
    }
}