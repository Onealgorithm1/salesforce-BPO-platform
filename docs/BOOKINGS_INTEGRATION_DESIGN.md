# Microsoft Bookings → Salesforce Integration Design

**Status:** Implemented and deployed to production.  
**Author:** One Algorithm LLC  
**Date:** 2026-06-20  
**Deployment:** Production job `0AfPn000001zC8XKAU` succeeded 2026-06-23. 67/67 tests passed.  
**Objective:** Automatically identify the Lead who booked a Microsoft "Book with me" meeting, link all Salesforce records, and stop the drip sequence — with zero manual intervention.

---

## Problem Statement

When a prospect books a meeting via the "Book with me" link in an outreach email:

1. Microsoft creates a calendar event in Louis's M365 calendar with the prospect as an attendee (`attendees[].emailAddress.address`)
2. Einstein Activity Capture (EAC) syncs that calendar event to Salesforce as an `Event` record
3. **The Event arrives with `WhoId = null`** — EAC does not map meeting attendees to Leads/Contacts for "Book with me" events
4. No CampaignMember status is updated
5. The drip sequence (Day 3/5/10) continues — the prospect receives follow-up emails after already booking a meeting

The attendee's email address is available upstream in Microsoft Exchange at the moment of booking, but is not captured anywhere in the Salesforce `Event` record after EAC sync. The `Event.Description` contains only the Teams join link and a Bookings management URL — not the attendee's email.

---

## Design Constraints

- Zero manual Salesforce work after a meeting is booked
- Scalable: works for 5 bookings/month and 500 bookings/month without rearchitecting
- Auditable: every matching decision and record update must be queryable
- Secure: no credentials hardcoded in Apex; no service account passwords
- Reusable: architecture accommodates future meeting types and campaign expansions

---

## Architecture: Apex Polling + Microsoft Graph API via Named Credential

### Why This Architecture

| Option | Infrastructure | Reliability | Auditability | Maintenance |
|--------|---------------|-------------|--------------|-------------|
| Power Automate + HTTP | M365 only | Medium (20-min delay, no retry) | Power Automate logs (30 days) | Low-code UI |
| Graph Webhook → Azure Function | Azure + SF | High (real-time) | App Insights + Platform Events | High (subscription renewal every ~3 days) |
| **Apex Polling + Named Credential** | **Salesforce only** | **High (15-min window)** | **Apex logs + Alert Tasks** | **Low (no external infra)** |

Apex polling via Named Credential is chosen because:
- All logic and audit trail stays in Salesforce — no split observability across tools
- Named Credential handles OAuth token lifecycle automatically (no subscription renewal problem)
- Alert Tasks in Salesforce surface unmatched bookings directly to Louis's task list
- No Azure infrastructure to provision, monitor, or pay for
- Salesforce Governor Limits are not a concern at current expected booking volume (<50/month)

---

## Components

### 1. Azure AD App Registration

| Property | Value |
|----------|-------|
| Display name | `OA-Salesforce-BookingSync` |
| Application type | Single-tenant |
| Tenant | `f4612edd-28c3-411a-a42e-ab15e7241712` (One Algorithm M365 tenant) |
| Permission type | **Application** (not Delegated — no user sign-in required) |
| Permission | `Calendars.Read` — Microsoft Graph |
| Grant | Admin consent required (one-time, by M365 Global Admin = Louis) |
| Credentials | Client secret (12-month rotation recommended); store in Salesforce Named Credential |
| Secret rotation | Update Named Credential before expiry; set a calendar reminder |

**Why Application permission (not Delegated):** Delegated permissions require an interactive user sign-in token. Application permissions allow a background process to call the API without a signed-in user. For a scheduled Apex job, application permissions are the only viable option.

**Why `Calendars.Read` only:** Principle of least privilege. The integration only needs to read calendar events to retrieve attendee details — it never writes to Exchange.

### 2. Salesforce Auth Provider

Setup path: **Setup → Auth. Providers → New → Open ID Connect**

| Property | Value |
|----------|-------|
| Name | `Microsoft Graph API` |
| URL suffix | `MicrosoftGraph` |
| Consumer key | Azure AD App client_id |
| Consumer secret | Azure AD App client_secret |
| Authorize endpoint | `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/authorize` |
| Token endpoint | `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token` |
| Default scopes | `https://graph.microsoft.com/.default` |
| Send client credentials | In header |

The Auth Provider wraps the Azure AD OAuth 2.0 Client Credentials flow. Salesforce stores and refreshes the token automatically — no Apex code manages auth state.

### 3. Salesforce Named Credential

Setup path: **Setup → Named Credentials → New**

| Property | Value |
|----------|-------|
| Label | `Microsoft Graph` |
| Name | `MicrosoftGraph` |
| URL | `https://graph.microsoft.com` |
| Identity type | Named principal |
| Authentication protocol | OAuth 2.0 |
| Authentication provider | Microsoft Graph API (from step 2) |
| Generate Authorization Header | Checked |
| Allow Merge Fields in HTTP Header | Unchecked |
| Allow Merge Fields in HTTP Body | Unchecked |

In Apex, callouts use `callout:MicrosoftGraph/v1.0/users/...` — the Named Credential prepends the base URL and injects the Bearer token automatically.

### 4. Salesforce Remote Site Setting

Setup path: **Setup → Remote Site Settings → New**

| Property | Value |
|----------|-------|
| Name | `MicrosoftGraph` |
| Remote Site URL | `https://graph.microsoft.com` |
| Disable Protocol Security | Unchecked |

Required for Apex HTTP callouts to the Graph API endpoint.

### 5. Custom Metadata: `OA_Graph_Config__mdt`

Purpose: Stores configuration values that can be changed without a code deployment. Prevents hardcoding org-specific values in Apex.

| Field | API Name | Type | Value |
|-------|----------|------|-------|
| Graph User OID | `Graph_User_OID__c` | Text | `1ffa0307-bcdf-4ac5-ac1e-eb3084437c39` |
| Campaign ID | `Campaign_Id__c` | Text | `701Pn00001ZOyj8IAD` |
| Booking Marker | `Booking_Marker__c` | Text | `bookings page` |
| Poller Enabled | `Is_Enabled__c` | Checkbox | true |
| Alert Owner ID | `Alert_Owner_Id__c` | Text | `005bn00000BP9zUAAT` (Louis's user ID) |

### 6. Apex Class: `OA_BookingPoller`

**Class signature:**
```apex
public class OA_BookingPoller implements Schedulable {
    public void execute(SchedulableContext sc) { ... }

    @future(callout=true)
    public static void processNewBookings() { ... }

    private static void processBookingEvent(Event ev, String token, String graphUserOid, String campaignId, String alertOwnerId) { ... }
    private static String patchTeamsMeetingAutoRecord(Event ev, String token, String graphUserOid, String existingMeetingId) { ... }
    private static String extractJoinUrl(String description) { ... }
    private static String lookupOnlineMeetingId(String joinUrl, String token, String graphUserOid) { ... }
    private static Boolean patchMeetingAutoRecord(String meetingId, String token, String graphUserOid) { ... }
    private static String getAttendeeEmail(Event ev, String token, String graphUserOid) { ... }
    private static String getAccessToken(OA_Graph_Credential__c cred) { ... }
    private static void createAlertTask(String subject, String description, String ownerId) { ... }
}
```

**Core logic (`processNewBookings`):**

```
1. Load OA_Graph_Config__mdt.getInstance('Default')
2. SOQL: Event WHERE Description LIKE '%{Booking_Marker__c}%'
              AND WhoId = null
              AND CreatedDate >= NOW() - 20 minutes
              AND OwnerId = {Louis's user ID}
3. For each Event:
   a. Call getAttendeeEmailFromGraph() → Graph API returns attendees[]
   b. Extract attendees[0].emailAddress.address
   c. SOQL: Lead WHERE Email = {email} AND IsConverted = false LIMIT 1
   d. If Lead found → linkAndActivate(eventId, leadId, startDateTime)
   e. If Lead not found → createAlertTask(subject, email)
4. No events found → return (no callout made)
```

**Graph API call (`getAttendeeEmailFromGraph`):**

```
GET callout:MicrosoftGraph/v1.0/users/{graphUserId}/events
    ?$filter=start/dateTime ge '{startDt - 2min}' and start/dateTime le '{startDt + 2min}'
    &$select=id,subject,attendees,start
    &$top=10
```

Filter by ±2-minute window around `Event.StartDateTime`. Match on `event.subject == Event.Subject` (EAC preserves exact subject). Extract `attendees[0].emailAddress.address`.

**Record updates (`linkAndActivate`):**

```apex
// 1. Link Event to Lead
update new Event(Id = eventId, WhoId = leadId);

// 2. Update CampaignMember Status → "Meeting Booked"
CampaignMember cm = [SELECT Id FROM CampaignMember
    WHERE LeadId = :leadId AND CampaignId = :cfg.Campaign_Id__c LIMIT 1];
if (cm != null) update new CampaignMember(Id = cm.Id, Status = 'Meeting Booked');
// OA_FollowUpScheduler will skip this lead on next run (STOP_STATUSES already includes 'Meeting Booked')

// 3. Stamp Lead fields
update new Lead(
    Id = leadId,
    Meeting_Booked_Date__c = startDt.date(),
    Relationship_Status__c = 'Meeting Booked'
);

// 4. Create prep Task due 24 hours before meeting
insert new Task(
    Subject      = 'PREP: Review prospect before intro call',
    WhoId        = leadId,
    Status       = 'Not Started',
    Priority     = 'High',
    ActivityDate = startDt.date().addDays(-1),
    Description  = 'Checklist: primary NAICS codes, active GovWin bids, '
                 + 'EDWOSB subcontracting history, prior contact notes, '
                 + 'Capability Statement link reviewed'
);
```

**Unmatched booking alert (`createAlertTask`):**

```apex
insert new Task(
    Subject      = 'ALERT: Booking received — no Lead match. Manual review required.',
    OwnerId      = cfg.Alert_Owner_Id__c,
    Status       = 'Not Started',
    Priority     = 'High',
    ActivityDate = Date.today(),
    Description  = 'Meeting subject: ' + subject
                 + '\nAttendee email (no match in Salesforce): ' + attendeeEmail
                 + '\nAction: Find or create Lead, manually link Event, '
                 + 'update CampaignMember Status to Meeting Booked.'
);
```

### 7. Apex Class: `OA_BookingPoller_Test`

Covers:
- `testNoNewEvents()` — empty query path, no callout
- `testMatchedLead()` — mock Graph response with known email, verifies all 4 updates (Event.WhoId, CampaignMember.Status, Lead fields, Task creation) via `HttpCalloutMock`
- `testUnmatchedEmail()` — mock Graph response with unknown email, verifies Alert Task creation
- `testGraphApiError()` — mock 500 response, verifies graceful failure (no DML exception)
- `testScheduler()` — verifies `System.schedule()` call without exception

### 8. Scheduled Jobs (4 cron expressions for 15-minute polling)

```apex
System.schedule('OA Booking Poller 00', '0 0  * * * ?', new OA_BookingPoller());
System.schedule('OA Booking Poller 15', '0 15 * * * ?', new OA_BookingPoller());
System.schedule('OA Booking Poller 30', '0 30 * * * ?', new OA_BookingPoller());
System.schedule('OA Booking Poller 45', '0 45 * * * ?', new OA_BookingPoller());
```

Maximum delay from booking to Salesforce update: 15 minutes.  
Org scheduler limit: 100 concurrent jobs; 4 new jobs is well within limit.

All 4 OA Booking Poller jobs are deployed and in WAITING state as of 2026-06-23. The org also runs 1 OA Artifact Poller job and 1 OA EDWOSB Follow-Up Daily job (defined in their respective modules).

---

## Data Flow Diagram

```
[Prospect]
    │ Clicks Bookings link in campaign email
    ▼
[Microsoft Bookings]
    │ Creates calendar event in Exchange
    │ event.attendees[0].emailAddress.address = prospect@prime.com
    │ event.subject = "Jane Smith - 30 min. Subcontracting Introduction"
    │ event.body = "This meeting was scheduled from the bookings page..."
    ├──► [M365 Calendar] ──EAC sync (5-15 min)──► [Salesforce Event]
    │                                                  WhoId = null  ← gap
    │                                                  Description contains "bookings page"
    │
    │         [OA_BookingPoller runs every 15 min]
    │                   │
    │         SOQL: Events WHERE Description LIKE '%bookings page%'
    │                          AND WhoId = null AND CreatedDate >= NOW-20min
    │                   │
    │         HTTP callout: GET /v1.0/users/{id}/events
    │           ?$filter=start/dateTime ~= {Event.StartDateTime}
    │           Named Credential injects Bearer token automatically
    │                   │
    │         Response: attendees[0].emailAddress.address = "prospect@prime.com"
    │                   │
    │         SOQL: Lead WHERE Email = 'prospect@prime.com'
    │                   │
    │    ┌─── Lead found ──────────────────────────────────────────────┐
    │    │                                                              │
    │    │   update Event.WhoId = Lead.Id                              │
    │    │   update CampaignMember.Status = "Meeting Booked"           │
    │    │     → OA_FollowUpScheduler skips on next run               │
    │    │   update Lead.Meeting_Booked_Date__c = today                │
    │    │   update Lead.Relationship_Status__c = "Meeting Booked"     │
    │    │   insert Task (prep, due day before meeting)                │
    │    │                                                              │
    │    └──────────────────────────────────────────────────────────────┘
    │    └─── No Lead match ──────────────────────────────────────────┐
    │                                                                  │
    │         insert Task: ALERT — unmatched booking                   │
    │         Louis receives task on his list                          │
    └──────────────────────────────────────────────────────────────────┘
```

---

## Security Model

| Layer | Control | Implementation |
|-------|---------|----------------|
| Azure AD credentials | Stored in Salesforce Named Credential — never in code | Named Credential with Auth Provider |
| Token lifetime | OAuth 2.0 Client Credentials — short-lived tokens, auto-refreshed by Salesforce | Auth Provider handles refresh |
| Graph API scope | `Calendars.Read` only — principle of least privilege | Azure AD App manifest |
| API access scope | Single user calendar (`/users/{userId}/events`) — not org-wide | Graph query path |
| Apex class access | `private static` for all non-scheduled methods | Class design |
| Config values | Custom Metadata (CMDT) — not hardcoded | `OA_Graph_Config__mdt` |
| Alert on failure | Alert Task created in Salesforce, visible to owner | `createAlertTask()` |
| Org-wide email | No outbound email in this class | Class scope |

**Secret rotation procedure (annually or on team change):**
1. Azure Portal → App Registration → Certificates & secrets → New client secret
2. Salesforce Setup → Named Credentials → Edit → update Consumer secret
3. Test: run `OA_BookingPoller.processNewBookings()` anonymously, confirm no auth errors
4. Delete old secret from Azure AD

---

## Auditability

Every booking processed by `OA_BookingPoller` leaves a queryable trail:

| Event | Evidence in Salesforce |
|-------|----------------------|
| Booking received and matched | `Event.WhoId` populated; `Lead.Meeting_Booked_Date__c` stamped |
| CampaignMember status change | `CampaignMember.Status = 'Meeting Booked'`; `LastModifiedDate` |
| Prep task created | `Task` record with `Subject LIKE 'PREP: Review%'` linked to Lead |
| Booking received, no match | `Task` with `Subject LIKE 'ALERT: Booking received%'` |
| Graph API response | Apex debug logs (Setup → Debug Logs → add trace flag for OA_BookingPoller) |
| Scheduler execution | `CronTrigger.LastFireTime` and `NextFireTime` per cron job |

Query to find all bookings processed:
```sql
SELECT Id, Subject, ActivityDate, Description, WhoId
FROM Task
WHERE Subject LIKE 'PREP: Review prospect before intro call'
ORDER BY CreatedDate DESC
```

Query to find unmatched bookings requiring attention:
```sql
SELECT Id, Subject, ActivityDate, Description, Status
FROM Task
WHERE Subject LIKE 'ALERT: Booking received%'
AND Status = 'Not Started'
ORDER BY CreatedDate DESC
```

---

## Scalability Notes

- **0–100 bookings/month:** Single-thread `@future(callout=true)` in schedulable is sufficient. Each run processes only new Events from the last 20 minutes — typically 0 or 1 event per run.
- **100–1,000 bookings/month:** Refactor to `Database.Batchable` + `Database.AllowsCallouts`. Each batch item is one Event; Graph callout per item. Batch size = 1 (callout limit in batch = 1 callout per execute method when using callout=true).
- **1,000+ bookings/month:** Move to Graph Change Notification subscriptions (webhooks) + Azure Function receiver — but this is unlikely given the EDWOSB subcontracting outreach use case.
- **Multiple campaigns:** Add `Campaign_Id__c` as a list field in CMDT, or create one CMDT record per campaign. `linkAndActivate()` queries CampaignMember by both `LeadId` and `CampaignId` — already parameterized.
- **Multiple meeting types:** No change needed. The filter `Description LIKE '%bookings page%'` matches all "Book with me" meeting types. `Meeting_Type_Filter__c` can add subject-based filtering if needed.

---

## Prerequisites Before Implementation

| # | Item | Owner | Notes |
|---|------|-------|-------|
| 1 | Azure AD App Registration | Louis (M365 Global Admin) | Requires admin consent for `Calendars.Read` application permission |
| 2 | Azure AD client_secret | Louis | 12-month expiry; set renewal calendar reminder |
| 3 | Salesforce Auth Provider | Developer | Requires client_id + client_secret from step 1–2 |
| 4 | Salesforce Named Credential | Developer | Requires Auth Provider from step 3 |
| 5 | Remote Site Setting | Developer | `https://graph.microsoft.com` |
| 6 | `OA_Graph_Config__mdt` object + record | Developer | One-time Setup + one CMDT record |
| 7 | `OA_BookingPoller` + `OA_BookingPoller_Test` | Developer | Apex deploy via `sf project deploy start` |
| 8 | Schedule 4 cron jobs | Developer | Via Apex Anonymous after class is deployed |
| 9 | Integration test | Developer + Louis | Book a test meeting with a known Lead email; verify all 4 record updates within 15 min |

**Estimated implementation time:** 4–6 hours (one developer session).

---

## Future Extensions

- **`Relationship_Status__c` automation:** After `linkAndActivate()`, the Lead's `Relationship_Status__c` is set to 'Meeting Booked'. A future Flow triggered on this field change can send a pre-meeting prep email to Louis or create additional calendar reminders.
- **Post-meeting nurture sequence:** After the intro call, Louis manually updates `Relationship_Status__c` to 'Call Complete'. A Flow on that transition initiates the post-meeting nurture templates (pending build).
- **Bidirectional status sync:** If Louis cancels or reschedules a meeting in Outlook, EAC updates the Event record. A future Flow on `Event.StartDateTime` change can notify or reset the prep Task due date.
- **Lead scoring integration:** `Meeting_Booked_Date__c` can feed into a scoring model — meetings within 7 days of Day 1 email indicate high intent, meetings on Day 10 or later indicate lower engagement.
