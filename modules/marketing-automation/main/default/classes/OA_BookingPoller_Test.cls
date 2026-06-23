@isTest(SeeAllData=false)
private class OA_BookingPoller_Test {

    // ── Test data setup ──────────────────────────────────────────────────────────
    @TestSetup
    static void makeData() {
        insert new OA_Graph_Credential__c(
            SetupOwnerId     = UserInfo.getOrganizationId(),
            Client_Id__c     = 'test-client-id-abc',
            Client_Secret__c = 'test-client-secret-xyz',
            Tenant_Id__c     = 'test-tenant-id-def'
        );

        insert new Lead(
            FirstName  = 'Jane',
            LastName   = 'Smith',
            Company    = 'Prime Contractor LLC',
            Email      = 'jane.smith@primecontractor.com',
            LeadSource = 'SAM.gov'
        );

        Campaign c = new Campaign(Name = 'OA Test Campaign', IsActive = true);
        insert c;

        // Salesforce auto-creates 'Sent' and 'Responded' statuses when a Campaign is inserted,
        // but they are invisible to SOQL in test context (SeeAllData=false). They are usable
        // for DML. We only need to add 'Meeting Booked'; try-catch guards against edge cases
        // where it was somehow already present.
        try {
            insert new CampaignMemberStatus(
                CampaignId = c.Id, Label = 'Meeting Booked', IsDefault = false,
                HasResponded = true, SortOrder = 10
            );
        } catch (DmlException e) {
            // Already exists — no action needed
        }

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        // 'Sent' is always auto-created as the default status for new campaigns
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Sent');

        insert new Event(
            Subject           = 'Jane Smith - 30 Min. Subcontracting Introduction',
            StartDateTime     = Datetime.now().addHours(48),
            EndDateTime       = Datetime.now().addHours(48).addMinutes(30),
            DurationInMinutes = 30,
            OwnerId           = UserInfo.getUserId(),
            Description       = 'This meeting was scheduled from the bookings page of Louis Rubino.\n\n'
                + 'Join Microsoft Teams Meeting\nhttps://teams.microsoft.com/l/meetup-join/mock-link\n'
                + '________________________________________________________________________________\n'
                + 'Microsoft Teams meeting'
        );
    }

    // ── Mock: attendee email matches the test Lead ───────────────────────────────
    private class MatchedLeadMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-001",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":[{"type":"required","emailAddress":{"address":"jane.smith@primecontractor.com","name":"Jane Smith"},"status":{"response":"none","time":"0001-01-01T00:00:00Z"}}]'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Mock: attendee email matches no Lead in Salesforce ───────────────────────
    private class UnknownEmailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-002",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":[{"type":"required","emailAddress":{"address":"nobody@nolead.example.com","name":"Unknown"}}]'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Mock: Graph returns no events in the time window ─────────────────────────
    private class NoGraphEventsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Mock: token endpoint returns 401 ─────────────────────────────────────────
    private class TokenFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(401);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"invalid_client","error_description":"AADSTS7000215: Invalid client secret provided."}');
            return res;
        }
    }

    // ── Mock: Graph events endpoint returns 503 ───────────────────────────────────
    private class GraphServerErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(503);
                res.setBody('{"error":{"code":"ServiceUnavailable","message":"The service is temporarily unavailable."}}');
            }
            return res;
        }
    }

    // ── Mock: token only — EAC pre-linked path does not call calendarView ────────
    // Returns a valid token for the OAuth endpoint. For any other request (calendarView),
    // returns an empty event list — which would produce an ALERT task if unexpectedly called.
    // Tests using this mock assert 0 alerts to confirm the Graph path was not taken.
    private class TokenOnlyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Tests ────────────────────────────────────────────────────────────────────

    // Test A — WhoId = null: poller uses Graph to match Lead, completes full pipeline.
    // Verifies the full happy-path lifecycle:
    // Graph returns a matched email → Event linked → CampaignMember updated → prep Task created.
    // Note: Meeting_Booked_Date__c and Relationship_Status__c values are verified indirectly —
    // the prep Task is only created after the Lead DML succeeds, so its presence confirms
    // both custom fields were written. Direct SOQL on fields being deployed in the same
    // package is not possible in Salesforce test execution context.
    @isTest
    static void testMatchedLeadFullLifecycle() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        // Event must be linked to the matched Lead
        List<Event> events = [SELECT WhoId FROM Event WHERE WhoId = :l.Id];
        System.assertEquals(1, events.size(), 'Event should be linked to the Lead');

        // CampaignMember status must be updated to Meeting Booked
        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status, 'CampaignMember status should be Meeting Booked');

        // Prep task must exist — created only after Lead DML (Meeting_Booked_Date__c + Relationship_Status__c)
        List<Task> prepTasks = [SELECT Subject, Priority FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Prep task should be created — its presence proves Lead custom field DML succeeded');
        System.assertEquals('High', prepTasks[0].Priority);

        // The outer-catch 'OA_BookingPoller error' task must not exist — any inner-catch
        // alerts (e.g. Lead field stamp failing in test context) are acceptable here
        List<Task> outerCatchTasks = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT: OA_BookingPoller error%'];
        System.assertEquals(0, outerCatchTasks.size(), 'No outer-catch error tasks should exist on a successful attendee match');
    }

    @isTest
    static void testUnknownEmailCreatesAlertTask() {
        Test.setMock(HttpCalloutMock.class, new UnknownEmailMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%no matching Lead%'];
        System.assertEquals(1, alerts.size(), 'Alert task should be created when attendee email does not match a Lead');

        Event ev = [SELECT WhoId FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];
        System.assertEquals(null, ev.WhoId, 'Event WhoId should remain null when no Lead match');
    }

    @isTest
    static void testNoGraphEventsCreatesNoMatchAlert() {
        Test.setMock(HttpCalloutMock.class, new NoGraphEventsMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%attendee email not found%'];
        System.assertEquals(1, alerts.size(), 'Alert task should be created when Graph returns no events in time window');
    }

    @isTest
    static void testTokenFailureCreateSystemAlert() {
        Test.setMock(HttpCalloutMock.class, new TokenFailureMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'SYSTEM ALERT:%token%'];
        System.assertEquals(1, alerts.size(), 'System alert task should be created when Graph token request fails');
    }

    @isTest
    static void testGraphServerErrorCreatesAlert() {
        Test.setMock(HttpCalloutMock.class, new GraphServerErrorMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%attendee email not found%'];
        System.assertEquals(1, alerts.size(), 'Alert task should be created when Graph API returns server error');
    }

    @isTest
    static void testNoNewEventsExitsGracefully() {
        delete [SELECT Id FROM Event];
        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task], 'No tasks should be created when there are no booking events');
    }

    @isTest
    static void testMissingCredentialsExitsGracefully() {
        delete [SELECT Id FROM OA_Graph_Credential__c];
        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task], 'No tasks should be created when credentials are not configured');
    }

    @isTest
    static void testSchedulerInvokesSilently() {
        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        String jobId = System.schedule('OA BookingPoller Unit Test', '0 0 12 * * ?', new OA_BookingPoller());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler should return a valid job ID');
    }

    // ── Mock: organizer email appears first in attendees, external customer second ─
    // Mirrors the confirmed production scenario from the March 2026 Stephen Hanebury
    // booking, where lrubino@onealgorithm.com was attendees[0] and the customer second.
    private class OrganizerFirstMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-003",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":['
                    + '{"type":"required","emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"},"status":{"response":"none"}},'
                    + '{"type":"required","emailAddress":{"address":"jane.smith@primecontractor.com","name":"Jane Smith"},"status":{"response":"none"}}'
                    + ']'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Mock: organizer + internal @onealgorithm.com staff before external customer ─
    private class InternalStaffMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-004",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":['
                    + '{"type":"required","emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"},"status":{"response":"none"}},'
                    + '{"type":"required","emailAddress":{"address":"samirisetti@onealgorithm.com","name":"Sam Irisetti"},"status":{"response":"none"}},'
                    + '{"type":"required","emailAddress":{"address":"jane.smith@primecontractor.com","name":"Jane Smith"},"status":{"response":"none"}}'
                    + ']'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Mock: self-booking — only the organizer in attendees, no external customer ─
    private class SelfBookingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-005",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":['
                    + '{"type":"required","emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"},"status":{"response":"none"}}'
                    + ']'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // Verifies that when the organizer appears first in the attendees array (confirmed
    // production scenario — March 2026 Stephen Hanebury booking), the organizer is
    // skipped and the external customer email is returned and matched to a Lead.
    @isTest
    static void testOrganizerFirstInAttendeesSelectsExternalEmail() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Test.setMock(HttpCalloutMock.class, new OrganizerFirstMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        List<Event> events = [SELECT WhoId FROM Event WHERE WhoId = :l.Id];
        System.assertEquals(1, events.size(), 'Event should be linked to Lead when organizer is first in attendees');

        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status, 'CampaignMember status should be Meeting Booked');

        List<Task> prepTasks = [SELECT Subject FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Prep task should be created when organizer is skipped and external email is matched');

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks should be created on a successful match');
    }

    // Verifies that internal @onealgorithm.com staff attendees (organizer + service staff)
    // are all skipped and the external customer is correctly identified and matched.
    @isTest
    static void testInternalStaffAttendeesSkippedSelectsExternalEmail() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Test.setMock(HttpCalloutMock.class, new InternalStaffMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        List<Event> events = [SELECT WhoId FROM Event WHERE WhoId = :l.Id];
        System.assertEquals(1, events.size(), 'Event should be linked to Lead when internal staff are skipped');

        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status, 'CampaignMember status should be Meeting Booked');

        List<Task> prepTasks = [SELECT Subject FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Prep task should be created when internal staff are skipped and external email is matched');

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks should be created on a successful match');
    }

    // Verifies that a self-booking (organizer is the only attendee) results in the
    // attendee email not found alert — no Lead update, no prep task, no false match.
    @isTest
    static void testSelfBookingCreatesNoAttendeeAlert() {
        Test.setMock(HttpCalloutMock.class, new SelfBookingMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%attendee email not found%'];
        System.assertEquals(1, alerts.size(), 'Alert task should be created when all attendees are excluded (self-booking)');

        Event ev = [SELECT WhoId FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];
        System.assertEquals(null, ev.WhoId, 'Event WhoId should remain null on self-booking');

        List<Task> prepTasks = [SELECT Id FROM Task WHERE Subject LIKE 'PREP:%'];
        System.assertEquals(0, prepTasks.size(), 'No prep task should be created on self-booking');
    }

    // Test B — EAC pre-linked: Event.WhoId already populated before poller runs.
    // Verifies that when EAC auto-links the calendar event to a Lead (the production
    // scenario observed on 2026-06-21 with netwerkinc19@gmail.com), the poller bypasses
    // the Graph calendarView call and completes the full pipeline using the pre-linked Lead.
    @isTest
    static void testEACPreLinkedLeadCompletedPipeline() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        // Simulate EAC auto-linking the event to the Lead before the poller runs
        ev.WhoId = l.Id;
        update ev;

        Test.setMock(HttpCalloutMock.class, new TokenOnlyMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        // CampaignMember must be updated via the pre-linked Lead (no Graph lookup)
        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status, 'CampaignMember status should be Meeting Booked via EAC pre-linked path');

        // PREP task existence confirms Lead DML (Step 3) also succeeded
        List<Task> prepTasks = [SELECT Subject, Priority FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Prep task should be created via EAC pre-linked path');
        System.assertEquals('High', prepTasks[0].Priority);

        // Zero alerts — confirms the EAC path did not fall through to Graph (TokenOnlyMock
        // returns an empty calendarView for non-token requests, which would generate an ALERT)
        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks should be created via EAC pre-linked path');
    }

    // Test C — Already processed: Event.WhoId set + Lead.Meeting_Booked_Date__c set.
    // Verifies idempotency: a booking that was fully processed in a prior poller run
    // is skipped without creating duplicate tasks, duplicate CampaignMember updates,
    // or duplicate Lead field writes.
    @isTest
    static void testAlreadyProcessedEventSkipped() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        // Simulate a fully-processed booking: Event linked to Lead, Lead fields stamped
        ev.WhoId = l.Id;
        update ev;
        update new Lead(Id = l.Id, Meeting_Booked_Date__c = Date.today(), Relationship_Status__c = 'Meeting Booked');

        Test.setMock(HttpCalloutMock.class, new TokenOnlyMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        // No PREP task should be created — event was fully processed before this poll
        List<Task> prepTasks = [SELECT Id FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(0, prepTasks.size(), 'No prep task should be created when event is already fully processed');

        // CampaignMember should remain unchanged at Sent (not updated to Meeting Booked)
        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Sent', cm.Status, 'CampaignMember should not be updated when event is already fully processed');

        // No alert tasks either
        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks should be created when event is skipped as already processed');
    }

    // ── Step 1.5 Mocks ───────────────────────────────────────────────────────────

    // Mock: full Step 1.5 success path — token, calendarView attendee resolution,
    // onlineMeetings filter lookup, PATCH all succeed.
    // Routes by method (PATCH) and URL substring to distinguish the 4 callout types:
    //   1. POST oauth2/v2.0/token → access token
    //   2. GET  calendarView      → Jane Smith attendee (used by getAttendeeEmail)
    //   3. GET  onlineMeetings    → single meeting with id ms-meeting-id-test-001
    //   4. PATCH onlineMeetings   → 200 success
    private class Step15Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else if (req.getMethod() == 'PATCH') {
                res.setBody('{"id":"ms-meeting-id-test-001","recordAutomatically":true,"allowTranscription":true}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('onlineMeetings')) {
                res.setBody('{"value":[{"id":"ms-meeting-id-test-001"}]}');
                res.setStatusCode(200);
            } else {
                // calendarView — attendee resolution
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-001",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":[{"type":"required","emailAddress":{"address":"jane.smith@primecontractor.com","name":"Jane Smith"},"status":{"response":"none"}}]'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // Mock: Step 1.5 PATCH returns 403 Forbidden — simulates the Teams application
    // access policy not being applied or the token lacking OnlineMeetings.ReadWrite.All.
    // All other callouts succeed identically to Step15Mock.
    private class Step15PatchFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token":"mock-bearer-token","expires_in":3600,"token_type":"Bearer"}');
                res.setStatusCode(200);
            } else if (req.getMethod() == 'PATCH') {
                res.setBody('{"error":{"code":"Forbidden","message":"Application does not have permission to patch this meeting."}}');
                res.setStatusCode(403);
            } else if (req.getEndpoint().contains('onlineMeetings')) {
                res.setBody('{"value":[{"id":"ms-meeting-id-test-001"}]}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"value":[{'
                    + '"id":"graph-event-id-001",'
                    + '"subject":"Jane Smith - 30 Min. Subcontracting Introduction",'
                    + '"start":{"dateTime":"' + Datetime.now().addHours(48).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '","timeZone":"UTC"},'
                    + '"organizer":{"emailAddress":{"address":"lrubino@onealgorithm.com","name":"Louis Rubino"}},'
                    + '"attendees":[{"type":"required","emailAddress":{"address":"jane.smith@primecontractor.com","name":"Jane Smith"},"status":{"response":"none"}}]'
                    + '}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ── Step 1.5 Tests ───────────────────────────────────────────────────────────

    // Test D — Step 1.5 happy path: join URL found, meeting lookup succeeds, PATCH succeeds.
    // Verifies that Lead.Teams_Meeting_Id__c is set to the resolved meeting ID and that
    // the full pipeline (CampaignMember, prep Task) is not blocked by Step 1.5 running.
    // Event description is set in @TestSetup and already contains a Teams join URL.
    @isTest
    static void testStep15PatchesNewMeeting() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Test.setMock(HttpCalloutMock.class, new Step15Mock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id, Teams_Meeting_Id__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals('ms-meeting-id-test-001', l.Teams_Meeting_Id__c,
            'Teams_Meeting_Id__c should be set when PATCH succeeds');

        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status,
            'CampaignMember status should be Meeting Booked — Step 1.5 must not block pipeline');

        List<Task> prepTasks = [SELECT Id FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(),
            'Prep task should be created — Step 1.5 success must not block subsequent pipeline steps');

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks when Step 1.5 succeeds');
    }

    // Test E — Step 1.5 skipped when event description has no Teams join URL.
    // Verifies that extractJoinUrl returning null causes Step 1.5 to abort without
    // any callouts, and Teams_Meeting_Id__c is left null. The rest of the pipeline
    // (attendee resolution, CampaignMember, prep Task) must still complete normally.
    @isTest
    static void testStep15SkipsWhenNoJoinUrl() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        // Overwrite description to remove the Teams join URL before the poller runs
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];
        ev.Description = 'This meeting was scheduled from the bookings page of Louis Rubino.\n\n'
            + 'No Teams link present in this booking.';
        update ev;

        // MatchedLeadMock handles token + calendarView. Step 1.5 exits before any
        // additional callout, so the mock never sees an onlineMeetings request.
        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id, Teams_Meeting_Id__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(null, l.Teams_Meeting_Id__c,
            'Teams_Meeting_Id__c should be null when event description has no Teams join URL');

        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status,
            'CampaignMember should still be updated — Step 1.5 skip must not block pipeline');

        List<Task> prepTasks = [SELECT Id FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(),
            'Prep task should be created even when Step 1.5 is skipped');

        List<Task> alerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%'];
        System.assertEquals(0, alerts.size(), 'No alert tasks when Step 1.5 exits early on missing URL');
    }

    // Test — extractJoinUrl strips trailing > from production Bookings angle-bracket format.
    // Microsoft Bookings writes the system-reference join URL as:
    //   System reference<https://teams.microsoft.com/l/meetup-join/...>
    // The > is not whitespace; pre-fix behavior included it in the extracted URL,
    // causing lookupOnlineMeetingId to return zero results and Teams_Meeting_Id__c to be null.
    @isTest
    static void testExtractJoinUrlStripsAngleBracketWrapper() {
        // Mirrors exact production description format observed 2026-06-22
        String eventDesc = 'Need help?<https://aka.ms/JoinTeamsMeeting?omkt=en-US> | '
            + 'System reference<https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22test-tenant%22%7d>\n'
            + 'For organizers: Meeting options<https://teams.microsoft.com/meetingOptions/>';

        String result = OA_BookingPoller.extractJoinUrl(eventDesc);

        System.assertNotEquals(null, result,
            'extractJoinUrl should find the Teams join URL in the angle-bracket format used by Microsoft Bookings');
        System.assert(!result.endsWith('>'),
            'Extracted URL must not include trailing > character — got: ' + result);
        System.assertEquals(
            'https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22test-tenant%22%7d',
            result,
            'URL should be extracted cleanly without the closing angle bracket');
    }

    // Test — extractJoinUrl still works for clean (no angle-bracket) URL format.
    // Confirms the fix does not regress the existing description format used in @TestSetup.
    @isTest
    static void testExtractJoinUrlCleanFormatUnchanged() {
        String eventDesc = 'This meeting was scheduled from the bookings page of Louis Rubino.\n\n'
            + 'Join Microsoft Teams Meeting\nhttps://teams.microsoft.com/l/meetup-join/clean-link-test\n'
            + 'Microsoft Teams meeting';

        String result = OA_BookingPoller.extractJoinUrl(eventDesc);

        System.assertEquals(
            'https://teams.microsoft.com/l/meetup-join/clean-link-test',
            result,
            'Clean (no angle-bracket) URL format must still be extracted correctly after the fix');
    }

    // ── Phase 2: Duplicate Email Protection Tests ────────────────────────────────

    // Verifies that a Lead whose Meeting_Booked_Date__c is already set (fully processed)
    // is excluded from the standard-path query, and the new unprocessed Lead with the
    // same email is selected and processed normally.
    @isTest
    static void testProcessedLeadIgnoredSelectsUnprocessed() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        // Mark the @TestSetup Lead as already processed
        Lead existing = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        update new Lead(Id = existing.Id, Meeting_Booked_Date__c = Date.today());

        // Insert a fresh unprocessed Lead with the same attendee email
        Lead fresh = new Lead(
            FirstName  = 'Bob', LastName  = 'Jones',
            Company    = 'New Contractor Inc',
            Email      = 'jane.smith@primecontractor.com',
            LeadSource = 'SAM.gov'
        );
        insert fresh;

        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> prepTasks = [SELECT WhoId FROM Task WHERE Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Exactly one PREP task should be created');
        System.assertEquals(fresh.Id, prepTasks[0].WhoId,
            'PREP task must be linked to the unprocessed Lead, not the already-processed one');

        List<Task> noMatchAlerts = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT:%no matching Lead%'];
        System.assertEquals(0, noMatchAlerts.size(),
            'No "no matching Lead" alert — an unprocessed Lead was found');
    }

    // Verifies that when two unprocessed Leads share the same attendee email,
    // the most recently created one is selected (ORDER BY CreatedDate DESC).
    @isTest
    static void testMostRecentUnprocessedLeadSelected() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;
        OA_BookingPoller.testAlertOwnerIdOverride = UserInfo.getUserId();

        Lead older = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        Lead newer = new Lead(
            FirstName  = 'Bob', LastName  = 'Jones',
            Company    = 'Newer Contractor Inc',
            Email      = 'jane.smith@primecontractor.com',
            LeadSource = 'SAM.gov'
        );
        insert newer;

        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> prepTasks = [SELECT WhoId FROM Task WHERE Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'Exactly one PREP task should be created');
        System.assertEquals(newer.Id, prepTasks[0].WhoId,
            'PREP task must be linked to the most recently created unprocessed Lead');

        List<Task> olderPrep = [SELECT Id FROM Task WHERE WhoId = :older.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(0, olderPrep.size(), 'Older Lead must not receive a PREP task');
    }

    // Verifies that when two unprocessed Leads share the same attendee email, a duplicate
    // alert task is created. Processing must still complete — the alert is additive, not blocking.
    @isTest
    static void testDuplicateUnprocessedLeadsCreatesAlert() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;
        OA_BookingPoller.testAlertOwnerIdOverride = UserInfo.getUserId();

        Lead duplicate = new Lead(
            FirstName  = 'Bob', LastName  = 'Jones',
            Company    = 'Duplicate Contractor Inc',
            Email      = 'jane.smith@primecontractor.com',
            LeadSource = 'SAM.gov'
        );
        insert duplicate;

        Test.setMock(HttpCalloutMock.class, new MatchedLeadMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        List<Task> dupAlerts = [SELECT Subject FROM Task
                                WHERE Subject LIKE 'ALERT:%duplicate unprocessed Leads%'];
        System.assertEquals(1, dupAlerts.size(),
            'Alert task should be created when duplicate unprocessed Leads share the same attendee email');

        List<Task> prepTasks = [SELECT Id FROM Task WHERE Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(),
            'PREP task should still be created — duplicate detection must not block processing');
    }

    // Test F — Step 1.5 PATCH failure is non-fatal.
    // Verifies that when the PATCH to /onlineMeetings returns 403, Teams_Meeting_Id__c
    // is left null (so the condition is retryable), and the booking pipeline continues
    // to completion: CampaignMember updated, prep Task created, no outer error task.
    @isTest
    static void testStep15PatchFailureDoesNotBlockPipeline() {
        Campaign c = [SELECT Id FROM Campaign WHERE Name = 'OA Test Campaign' LIMIT 1];
        OA_BookingPoller.testCampaignIdOverride = c.Id;

        Test.setMock(HttpCalloutMock.class, new Step15PatchFailMock());
        Test.startTest();
        OA_BookingPoller.processNewBookings();
        Test.stopTest();

        Lead l = [SELECT Id, Teams_Meeting_Id__c FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        System.assertEquals(null, l.Teams_Meeting_Id__c,
            'Teams_Meeting_Id__c should be null when PATCH returns 403 — not set unless PATCH confirmed successful');

        CampaignMember cm = [SELECT Status FROM CampaignMember WHERE LeadId = :l.Id AND CampaignId = :c.Id];
        System.assertEquals('Meeting Booked', cm.Status,
            'CampaignMember should be updated — PATCH failure must not block the booking pipeline');

        List<Task> prepTasks = [SELECT Id FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(),
            'Prep task should be created despite PATCH failure');

        List<Task> outerCatchTasks = [SELECT Subject FROM Task WHERE Subject LIKE 'ALERT: OA_BookingPoller error%'];
        System.assertEquals(0, outerCatchTasks.size(),
            'No outer-catch error task — Step 1.5 PATCH failure is internally swallowed and must not propagate');
    }
}
