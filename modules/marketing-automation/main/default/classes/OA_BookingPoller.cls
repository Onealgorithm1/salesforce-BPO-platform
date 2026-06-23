public class OA_BookingPoller implements Schedulable {

    // Allows tests to override the campaign ID without org data dependency
    @TestVisible private static String testCampaignIdOverride;
    // Allows tests to override the alert owner ID without Custom Metadata dependency
    @TestVisible private static Id testAlertOwnerIdOverride;

    // ── Schedulable entry point ──────────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        processNewBookings();
    }

    // ── Main processing method — @future required for HTTP callouts from scheduler ─
    @future(callout=true)
    public static void processNewBookings() {
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        if (cfg == null || !cfg.Is_Enabled__c) {
            System.debug('[OA_BookingPoller] Not configured or disabled. Exiting.');
            return;
        }

        OA_Graph_Credential__c cred = OA_Graph_Credential__c.getOrgDefaults();
        if (cred == null || String.isBlank(cred.Client_Id__c) || String.isBlank(cred.Tenant_Id__c)) {
            System.debug('[OA_BookingPoller] Graph credentials not configured in OA_Graph_Credential__c. Exiting.');
            return;
        }

        // Look back 20 minutes to catch events created since the previous poll.
        // WhoId = null is intentionally omitted: EAC may auto-link the event to a Lead
        // (populating WhoId) before the poller runs. Idempotency is enforced inside
        // processBookingEvent() using Lead.Meeting_Booked_Date__c as the processed flag.
        Datetime lookback = Datetime.now().addMinutes(-20);
        String marker = '%' + cfg.Booking_Marker__c + '%';

        List<Event> bookingEvents = [
            SELECT Id, Subject, StartDateTime, EndDateTime, Description, OwnerId, WhoId
            FROM Event
            WHERE CreatedDate >= :lookback
            AND OwnerId = :UserInfo.getUserId()
        ];

        // Filter for booking marker in Apex — Event.Description is not filterable in SOQL
        List<Event> filteredEvents = new List<Event>();
        for (Event ev : bookingEvents) {
            if (ev.Description != null && ev.Description.containsIgnoreCase(cfg.Booking_Marker__c)) {
                filteredEvents.add(ev);
            }
        }

        if (filteredEvents.isEmpty()) {
            System.debug('[OA_BookingPoller] No booking events found in window.');
            return;
        }

        System.debug('[OA_BookingPoller] Found ' + filteredEvents.size() + ' booking event(s) to process.');

        String campaignId    = testCampaignIdOverride    != null ? testCampaignIdOverride    : cfg.Campaign_Id__c;
        Id     alertOwnerId  = testAlertOwnerIdOverride  != null ? testAlertOwnerIdOverride  : cfg.Alert_Owner_Id__c;

        String accessToken = getAccessToken(cred);
        if (accessToken == null) {
            System.debug('[OA_BookingPoller] Failed to obtain Graph access token.');
            createAlertTask(
                'SYSTEM ALERT: OA_BookingPoller — Graph token request failed',
                'The poller could not obtain a Microsoft Graph access token.\n\n' +
                'Action Required:\n' +
                '1. Verify OA_Graph_Credential__c has correct Client_Id__c, Client_Secret__c, Tenant_Id__c\n' +
                '2. Verify the Azure AD app has Calendars.Read application permission with admin consent\n' +
                '3. Check that the client secret has not expired in Azure Portal',
                alertOwnerId
            );
            return;
        }

        for (Event ev : filteredEvents) {
            try {
                processBookingEvent(ev, accessToken, cfg.Graph_User_OID__c, campaignId, alertOwnerId);
            } catch (Exception e) {
                System.debug('[OA_BookingPoller] Error processing Event ' + ev.Id + ': ' + e.getMessage());
                createAlertTask(
                    'ALERT: OA_BookingPoller error — manual review required',
                    'Event: ' + ev.Subject + ' (' + (ev.StartDateTime != null ? ev.StartDateTime.format() : 'unknown time') + ')' +
                    '\n\nError: ' + e.getMessage() +
                    '\nStack: ' + e.getStackTraceString(),
                    alertOwnerId
                );
            }
        }
    }

    // ── Process a single booking event ──────────────────────────────────────────
    private static void processBookingEvent(Event ev, String token, String graphUserOid,
                                             String campaignId, String alertOwnerId) {
        System.debug('[OA_BookingPoller] Processing Event: ' + ev.Subject + ' (' + ev.Id + ')');

        Lead lead;
        String dupAlertSubject = null;
        String dupAlertBody    = null;

        // Fast-path for EAC pre-linked events: EAC may have already matched the attendee
        // email to a Lead and populated WhoId before this poller ran. When WhoId is set,
        // bypass the Graph calendarView call and use the existing Lead directly.
        // Meeting_Booked_Date__c is the idempotency guard — when set, the full pipeline
        // has already completed and the event must not be reprocessed.
        if (ev.WhoId != null) {
            List<Lead> preLinked = [
                SELECT Id, FirstName, LastName, Email, Meeting_Booked_Date__c, Teams_Meeting_Id__c
                FROM Lead WHERE Id = :ev.WhoId AND IsConverted = false LIMIT 1
            ];
            if (!preLinked.isEmpty()) {
                if (preLinked[0].Meeting_Booked_Date__c != null) {
                    System.debug('[OA_BookingPoller] Event ' + ev.Id + ' already fully processed — Meeting_Booked_Date__c is set. Skipping.');
                    return;
                }
                lead = preLinked[0];
                System.debug('[OA_BookingPoller] EAC pre-linked Lead: ' + lead.Id);
            }
            // If preLinked is empty, WhoId references a Contact or User — fall through to Graph path.
        }

        // Standard path: resolve customer email from the Graph attendees array.
        if (lead == null) {
            String attendeeEmail = getAttendeeEmail(ev, token, graphUserOid);

            if (attendeeEmail == null) {
                createAlertTask(
                    'ALERT: Booking received — attendee email not found in Graph',
                    'Meeting: ' + ev.Subject +
                    '\nStart: ' + (ev.StartDateTime != null ? ev.StartDateTime.format() : 'unknown') +
                    '\n\nNo attendee email returned from Microsoft Graph for this event time window.\n' +
                    'Possible causes:\n' +
                    '- Event was cancelled or rescheduled before polling ran\n' +
                    '- Subject mismatch between EAC sync and Graph\n' +
                    '- Graph API permission not fully propagated\n\n' +
                    'Manual Action: Find the attendee from the calendar event and update the Lead manually.',
                    alertOwnerId
                );
                return;
            }

            System.debug('[OA_BookingPoller] Attendee email: ' + attendeeEmail);

            // Prefer the most recently created unprocessed Lead. Meeting_Booked_Date__c = null
            // is the unprocessed predicate — it is the idempotency guard for the full pipeline.
            // LIMIT 2 allows duplicate detection without fetching an unbounded result set.
            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email, Teams_Meeting_Id__c
                FROM Lead
                WHERE Email = :attendeeEmail
                AND IsConverted = false
                AND Meeting_Booked_Date__c = null
                ORDER BY CreatedDate DESC
                LIMIT 2
            ];

            if (leads.isEmpty()) {
                createAlertTask(
                    'ALERT: Booking received — no matching Lead found. Manual action required.',
                    'Meeting: ' + ev.Subject +
                    '\nStart: ' + (ev.StartDateTime != null ? ev.StartDateTime.format() : 'unknown') +
                    '\nAttendee email (unmatched): ' + attendeeEmail +
                    '\n\nNo active Lead found with this email address.\n' +
                    'Manual Action:\n' +
                    '1. Find or create a Lead with email: ' + attendeeEmail + '\n' +
                    '2. Set Relationship_Status__c = Meeting Booked\n' +
                    '3. Set Meeting_Booked_Date__c = ' + (ev.StartDateTime != null ? String.valueOf(ev.StartDateTime.date()) : 'see calendar') + '\n' +
                    '4. Update CampaignMember Status to Meeting Booked\n' +
                    '5. Link this Event to the Lead (WhoId)',
                    alertOwnerId
                );
                return;
            }

            // Capture duplicate alert for deferred creation — must not DML before callouts.
            if (leads.size() > 1) {
                dupAlertSubject = 'ALERT: OA_BookingPoller — duplicate unprocessed Leads for attendee email. Review required.';
                dupAlertBody    = 'Meeting: ' + ev.Subject +
                    '\nAttendee email: ' + attendeeEmail +
                    '\nDuplicate Lead candidates (most recent selected for processing):\n' +
                    '  Lead 1 (selected): ' + leads[0].Id + ' — ' + leads[0].FirstName + ' ' + leads[0].LastName + '\n' +
                    '  Lead 2 (ignored):  ' + leads[1].Id + ' — ' + leads[1].FirstName + ' ' + leads[1].LastName + '\n\n' +
                    'Action Required: Review both Leads. Merge or delete the older duplicate. ' +
                    'The most recently created Lead was selected automatically.';
            }

            lead = leads[0];
        }

        System.debug('[OA_BookingPoller] Matched Lead: ' + lead.FirstName + ' ' + lead.LastName + ' (' + lead.Id + ')');

        // Step 1.5: PATCH the Teams meeting for automatic recording and transcription.
        // Non-fatal — any failure logs a warning and allows the pipeline to continue.
        // Teams_Meeting_Id__c is stored in Step 3 DML alongside the other Lead fields,
        // avoiding an extra DML statement here.
        String pendingMeetingId = patchTeamsMeetingAutoRecord(ev, token, graphUserOid, lead.Teams_Meeting_Id__c);

        // Deferred duplicate-lead alert — created after all callouts to avoid DML-before-callout.
        if (dupAlertSubject != null) {
            createAlertTask(dupAlertSubject, dupAlertBody, alertOwnerId);
        }

        // Step 1: Link Event to Lead — skip if EAC already populated WhoId
        if (ev.WhoId == null) {
            ev.WhoId = lead.Id;
            update ev;
            System.debug('[OA_BookingPoller] Event ' + ev.Id + ' linked to Lead ' + lead.Id);
        }

        // Step 2: Update CampaignMember Status
        List<CampaignMember> cms = [
            SELECT Id, Status
            FROM CampaignMember
            WHERE LeadId = :lead.Id
            AND CampaignId = :campaignId
            LIMIT 1
        ];
        if (!cms.isEmpty() && cms[0].Status != 'Meeting Booked') {
            cms[0].Status = 'Meeting Booked';
            update cms[0];
            System.debug('[OA_BookingPoller] CampaignMember ' + cms[0].Id + ' status → Meeting Booked');
        }

        // Step 3: Stamp Lead fields — Teams_Meeting_Id__c batched here to avoid extra DML
        try {
            update new Lead(
                Id = lead.Id,
                Meeting_Booked_Date__c = ev.StartDateTime.date(),
                Relationship_Status__c = 'Meeting Booked',
                Teams_Meeting_Id__c    = pendingMeetingId  // null if Step 1.5 did not resolve
            );
            System.debug('[OA_BookingPoller] Lead ' + lead.Id + ' — fields stamped'
                + (pendingMeetingId != null ? ' (Teams_Meeting_Id__c set)' : ' (Teams_Meeting_Id__c not set)'));
        } catch (Exception e) {
            System.debug('[OA_BookingPoller] Lead field stamp failed: ' + e.getMessage());
            createAlertTask(
                'ALERT: Booking matched — Lead fields require manual update',
                'Lead: ' + lead.Id + ' — ' + lead.FirstName + ' ' + lead.LastName +
                '\nError: ' + e.getMessage() +
                '\n\nManual action: set Meeting_Booked_Date__c and Relationship_Status__c = Meeting Booked',
                alertOwnerId
            );
        }

        // Step 4: Create prep task — guard prevents duplicates when the same event appears
        // in consecutive poll windows (e.g., EAC links in the same window as a prior partial run).
        Integer existingPrep = [SELECT COUNT() FROM Task WHERE WhoId = :lead.Id AND Subject LIKE 'PREP:%'];
        if (existingPrep == 0) {
            Date meetingDate  = ev.StartDateTime.date();
            Date taskDueDate  = meetingDate.addDays(-1);
            if (taskDueDate <= Date.today()) taskDueDate = Date.today();

            insert new Task(
                Subject      = 'PREP: Review prospect before intro call — ' + lead.FirstName + ' ' + lead.LastName,
                WhoId        = lead.Id,
                OwnerId      = alertOwnerId,
                Status       = 'Not Started',
                Priority     = 'High',
                ActivityDate = taskDueDate,
                Description  = 'Meeting: ' + ev.Subject +
                               '\nDate: ' + ev.StartDateTime.format() +
                               '\n\nPre-call checklist:' +
                               '\n• Company overview: primary NAICS codes, size standard, certifications' +
                               '\n• Active GovWin bids and incumbent contract vehicles' +
                               '\n• EDWOSB subcontracting and teaming history on SAM.gov' +
                               '\n• Review prior email exchange and any notes on the Lead record' +
                               '\n• Confirm Capability Statement is current (updated for this quarter)' +
                               '\n• Identify 1–2 relevant contract vehicles to reference in the call'
            );
            System.debug('[OA_BookingPoller] Prep Task created for Lead ' + lead.Id + ', due ' + taskDueDate);
        } else {
            System.debug('[OA_BookingPoller] Prep Task already exists for Lead ' + lead.Id + ' — skipping duplicate.');
        }
    }

    // ── Step 1.5: Patch Teams meeting for auto-recording ────────────────────────
    // Extracts the Teams join URL from the event description, resolves the onlineMeeting
    // ID via Graph filter, and PATCHes recordAutomatically=true + allowTranscription=true.
    // Returns the onlineMeeting ID if successfully patched, null in all failure cases.
    // NEVER throws — all failures are logged as warnings and the pipeline continues.
    private static String patchTeamsMeetingAutoRecord(Event ev, String token,
                                                       String graphUserOid, String existingMeetingId) {
        if (existingMeetingId != null) {
            System.debug('[OA_BookingPoller][Step1.5] Teams_Meeting_Id__c already set. Skipping PATCH.');
            return existingMeetingId;
        }

        String joinUrl = extractJoinUrl(ev.Description);
        if (joinUrl == null) {
            System.debug('[OA_BookingPoller][Step1.5] No Teams join URL found in event description. Skipping PATCH.');
            return null;
        }
        System.debug('[OA_BookingPoller][Step1.5] Extracted joinUrl: ' + joinUrl.left(80) + '...');

        String meetingId = lookupOnlineMeetingId(joinUrl, token, graphUserOid);
        if (meetingId == null) {
            System.debug('[OA_BookingPoller][Step1.5] No onlineMeeting found for joinUrl. Skipping PATCH.');
            return null;
        }
        System.debug('[OA_BookingPoller][Step1.5] Resolved meetingId: ' + meetingId.left(40) + '...');

        Boolean patched = patchMeetingAutoRecord(meetingId, token, graphUserOid);
        if (patched) {
            System.debug('[OA_BookingPoller][Step1.5] Meeting configured for auto-recording. Teams_Meeting_Id__c will be set in Step 3.');
            return meetingId;
        }
        // PATCH failed — return null so Teams_Meeting_Id__c is not set.
        // The poller will retry on the next cycle if Meeting_Booked_Date__c is not yet set,
        // but in practice the event will already be fully processed by then.
        return null;
    }

    // ── Extract Teams join URL from Bookings event description ──────────────────
    // Bookings writes the join URL in the Description in the format:
    //   "Join Microsoft Teams Meeting\nhttps://teams.microsoft.com/l/meetup-join/..."
    // The URL ends at the first whitespace character (newline or space).
    @TestVisible
    private static String extractJoinUrl(String description) {
        if (description == null) return null;
        String prefix = 'https://teams.microsoft.com/l/meetup-join/';
        Integer start = description.indexOf(prefix);
        if (start == -1) return null;
        String fromUrl = description.substring(start);
        Integer urlEnd = fromUrl.length();
        for (Integer i = 0; i < fromUrl.length(); i++) {
            String ch = fromUrl.substring(i, i + 1);
            if (ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t' || ch == '>' || ch == '<') {
                urlEnd = i;
                break;
            }
        }
        return fromUrl.substring(0, urlEnd).trim();
    }

    // ── Look up onlineMeeting ID via joinWebUrl filter ───────────────────────────
    @TestVisible
    private static String lookupOnlineMeetingId(String joinUrl, String token, String graphUserOid) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/onlineMeetings?%24filter=joinWebUrl%20eq%20%27'
            + EncodingUtil.urlEncode(joinUrl, 'UTF-8') + '%27');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('[OA_BookingPoller][Step1.5] Meeting lookup HTTP ' + res.getStatusCode()
                + ' — ' + res.getBody().abbreviate(200));
            return null;
        }

        Map<String,Object> body = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> meetings = (List<Object>) body.get('value');
        if (meetings == null || meetings.isEmpty()) return null;
        return (String)((Map<String,Object>) meetings[0]).get('id');
    }

    // ── PATCH onlineMeeting to enable automatic recording and transcription ──────
    @TestVisible
    private static Boolean patchMeetingAutoRecord(String meetingId, String token, String graphUserOid) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/onlineMeetings/' + EncodingUtil.urlEncode(meetingId, 'UTF-8'));
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"recordAutomatically":true,"allowTranscription":true}');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        Integer status = res.getStatusCode();
        if (status == 200) {
            return true;
        }
        System.debug('[OA_BookingPoller][Step1.5] PATCH HTTP ' + status
            + ' — ' + res.getBody().abbreviate(200));
        return false;
    }

    // ── Graph API: get attendee email for an event matching subject and time ─────
    private static String getAttendeeEmail(Event ev, String token, String graphUserOid) {
        // Search a ±3-minute window around the event start time to account for EAC sync drift
        Datetime windowStart = ev.StartDateTime.addMinutes(-3);
        Datetime windowEnd   = ev.StartDateTime.addMinutes(3);

        String isoStart = windowStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String isoEnd   = windowEnd.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        // calendarView is the correct Graph endpoint for time-bounded event queries.
        // The alternative /events?$filter with quoted datetime strings causes 400 errors
        // due to unencoded single quotes being rejected at the network level.
        String endpoint = 'https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/calendarView'
            + '?startDateTime=' + isoStart
            + '&endDateTime='   + isoEnd
            + '&$select=id,subject,attendees,start,organizer'
            + '&$top=10';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('[OA_BookingPoller] Graph events API: HTTP ' + res.getStatusCode()
                + ' — ' + res.getBody().abbreviate(500));
            return null;
        }

        Map<String, Object> body   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> graphEvents   = (List<Object>) body.get('value');

        if (graphEvents == null || graphEvents.isEmpty()) {
            System.debug('[OA_BookingPoller] No Graph events found in time window for ' + ev.Subject);
            return null;
        }

        for (Object gevObj : graphEvents) {
            Map<String, Object> gev         = (Map<String, Object>) gevObj;
            String graphSubject              = (String) gev.get('subject');
            List<Object> attendees           = (List<Object>) gev.get('attendees');

            // Match on subject — EAC preserves the Exchange subject exactly
            if (ev.Subject == null || graphSubject == null) continue;
            if (ev.Subject.trim() != graphSubject.trim()) continue;

            if (attendees == null || attendees.isEmpty()) continue;

            // In Bookings events the host appears as type=required in the attendees array,
            // not type=organizer. Read the organizer node — the only reliable host identifier.
            Map<String, Object> orgNode  = (Map<String, Object>) gev.get('organizer');
            Map<String, Object> orgEmail = orgNode != null
                                            ? (Map<String, Object>) orgNode.get('emailAddress') : null;
            String organizerEmail        = (orgEmail != null && orgEmail.get('address') != null)
                                            ? ((String) orgEmail.get('address')).toLowerCase().trim()
                                            : '';

            for (Object attObj : attendees) {
                Map<String, Object> att       = (Map<String, Object>) attObj;
                Map<String, Object> emailAddr = (Map<String, Object>) att.get('emailAddress');
                if (emailAddr == null) continue;

                String email = (String) emailAddr.get('address');
                if (String.isBlank(email)) continue;
                email = email.toLowerCase().trim();

                // Skip the meeting organizer — must exclude by address because Bookings
                // events carry the host as type=required, not type=organizer.
                if (String.isNotBlank(organizerEmail) && email.equals(organizerEmail)) continue;

                // Skip internal OA staff added via Bookings service staff configuration.
                if (email.endsWith('@onealgorithm.com')) continue;

                return email;
            }
        }

        System.debug('[OA_BookingPoller] No subject-matching event found in Graph results for: ' + ev.Subject);
        return null;
    }

    // ── Microsoft OAuth 2.0 Client Credentials — get access token ───────────────
    private static String getAccessToken(OA_Graph_Credential__c cred) {
        String tokenEndpoint = 'https://login.microsoftonline.com/'
            + cred.Tenant_Id__c.trim()
            + '/oauth2/v2.0/token';

        String reqBody = 'client_id='     + EncodingUtil.urlEncode(cred.Client_Id__c.trim(), 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(cred.Client_Secret__c.trim(), 'UTF-8')
            + '&scope='         + EncodingUtil.urlEncode('https://graph.microsoft.com/.default', 'UTF-8')
            + '&grant_type=client_credentials';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(reqBody);
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('[OA_BookingPoller] Token endpoint: HTTP ' + res.getStatusCode()
                + ' — ' + res.getBody().abbreviate(500));
            return null;
        }

        Map<String, Object> tokenResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) tokenResp.get('access_token');
    }

    // ── Create an alert or system Task ──────────────────────────────────────────
    private static void createAlertTask(String subject, String description, String ownerId) {
        insert new Task(
            Subject      = subject.left(255),
            OwnerId      = ownerId,
            Status       = 'Not Started',
            Priority     = 'High',
            ActivityDate = Date.today(),
            Description  = description
        );
    }
}
