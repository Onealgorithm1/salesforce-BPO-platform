# Teams Meeting Capture — Architecture & Implementation Plan

**Status:** Partially implemented. `OA_ArtifactPoller`, transcript retrieval, and AI handoff are deployed. `Meeting_Record__c` custom object is not yet deployed — this doc remains the forward design spec for that phase.  
**Author:** One Algorithm LLC  
**Date:** 2026-06-20  
**Objective:** Automatically capture Teams meeting recordings, transcripts, attendees, and AI summaries into Salesforce when a Microsoft Bookings meeting occurs. Zero manual intervention.

---

## A. Microsoft Licensing Assessment

### What the Evidence Shows

| Signal | Source | License Implication |
|--------|--------|---------------------|
| Einstein Activity Capture active | Salesforce org config | Requires M365 Business Basic+ |
| "Book with me" meetings in use | Event Subject/Description | Available on all M365 Business plans |
| OneDrive-backed EAC sync | EAC sync active | OneDrive for Business included |
| Teams meetings in org calendar | 4+ Teams events in Event records | Teams included in subscription |
| Tenant ID `f4612edd-28c3-411a-a42e-ab15e7241712` | EAC Event Description | Active M365 tenant |
| Organizer OID `1ffa0307-bcdf-4ac5-ac1e-eb3084437c39` | Teams join URL in Event | Specific user identity confirmed |

### License Feature Matrix

| Capability | Biz Basic ($6/u/mo) | Biz Standard ($12.50) | Biz Premium ($22) | + Teams Premium ($10 add-on) | + M365 Copilot ($30 add-on) |
|-----------|---------------------|-----------------------|-------------------|-----------------------------|------------------------------|
| Teams meetings | ✓ | ✓ | ✓ | ✓ | ✓ |
| Recording (host-initiated) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Recording (auto-start policy) | ✓* | ✓* | ✓* | ✓* | ✓* |
| Recording stored in OneDrive | ✓ | ✓ | ✓ | ✓ | ✓ |
| Meeting transcript (VTT) | ✗ | ✗ | ✗ | ✓ | ✓ |
| Auto-transcription | ✗ | ✗ | ✗ | ✓ | ✓ |
| Speaker attribution | ✗ | ✗ | ✗ | ✓ | ✓ |
| AI meeting notes (built-in) | ✗ | ✗ | ✗ | Intelligent Recap only | ✓ Full Copilot |
| Graph API `/recordings` | ✓ (file metadata) | ✓ | ✓ | ✓ | ✓ |
| Graph API `/transcripts` | ✗ | ✗ | ✗ | ✓ | ✓ |

*Auto-start recording requires Teams Admin policy: `autoStartMeetingRecording = true`. This is a meeting policy setting, not a license restriction.

### What One Algorithm Currently Has (Inferred)

Current license: **M365 Business Basic or Standard** (minimum required for EAC + Bookings + Teams).

**What this means:**
- ✓ Recording is available — Louis can record meetings OR meetings can auto-record via admin policy
- ✗ Transcription is NOT included — requires Teams Premium add-on ($10/user/month)
- ✗ AI notes (built-in) not available — must be custom-built via OpenAI (already configured)

### Recommendation

**Add Teams Premium ($10/month) before implementing this integration.** Without it:
- The Apex poller can retrieve the recording MP4 URL and store it in Salesforce
- AI summary requires custom Whisper API transcription of the audio (adds latency and cost)
- With Teams Premium: VTT transcript is auto-generated and immediately accessible via Graph API
- Total additional cost for 1 user: $10/month

**Path without Teams Premium (fallback):** OpenAI Whisper API (`/v1/audio/transcriptions`) can transcribe the recording MP4. Latency is 2-5 minutes per hour of meeting. Accuracy is equivalent to Teams native transcription. This is documented in Section D as the fallback branch.

### Required Policy Configuration (Teams Admin Center)

Regardless of license tier, these meeting policies must be set:

1. **Setup → Meetings → Meeting Policies → [Policy applied to lrubino@onealgorithm.com]**
   - `Allow cloud recording`: ON
   - `Recording expiration`: Set to Never (or 180 days) — default 60-day auto-delete will destroy recordings before they can be archived
   - `Allow transcription` (only if Teams Premium): ON

2. **Auto-start recording** (optional but recommended):
   - PowerShell: `Set-CsTeamsMeetingPolicy -AllowCloudRecording $true -AutoStartMeetingRecording $true`
   - OR: Teams Admin Center → Meeting Policies → Edit → Recording → Auto-record

---

## B. Storage Location

### Where Recordings Go

Teams meeting recordings for non-channel meetings (which all "Book with me" meetings are) are stored in the **meeting organizer's OneDrive for Business**:

```
OneDrive root
└── Recordings/
    └── {Meeting Title} {YYYY-MM-DD HH-mm-ss}.mp4
```

For Louis's account, this path is:
```
GET /users/1ffa0307-bcdf-4ac5-ac1e-eb3084437c39/drive/root:/Recordings:/children
```

The file name includes the meeting subject and start time. For a "Book with me" meeting named "Jane Smith - 30 min. Subcontracting Introduction", the file appears approximately as:
`Jane Smith - 30 min. Subcontracting Introduction 2026-07-01 10-00-00.mp4`

### Where Transcripts Go (Teams Premium only)

Transcripts are stored alongside the recording in OneDrive:
```
OneDrive root
└── Recordings/
    ├── {Meeting Title}.mp4
    └── {Meeting Title}.vtt   ← VTT subtitle/transcript file
```

Accessible via Graph API:
```
GET /users/{userId}/onlineMeetings/{meetingId}/transcripts
→ returns list of transcript objects with contentUrl
GET /users/{userId}/onlineMeetings/{meetingId}/transcripts/{transcriptId}/content
→ returns VTT or text/plain content
```

### Access After Meeting Ends

- **Recording is available**: 5–10 minutes after meeting ends (processing time)
- **Transcript is available**: 5–15 minutes after meeting ends (if Teams Premium)
- **Graph API availability**: As soon as the file appears in OneDrive, it's accessible via Drive API; via `onlineMeetings/recordings` API, availability may take up to 30 minutes

### Teams Meeting ID Extraction from Event Description

The EAC-synced Salesforce Event Description contains the full Teams join URL in two formats:

**Format 1 (short, not usable for Graph):**
```
Join: https://teams.microsoft.com/meet/288335565317932?p=Le00YIWIDw2Meo9YvF
```

**Format 2 (full join URL — required for Graph API lookup):**
```
System reference: https://teams.microsoft.com/l/meetup-join/
  19%3ameeting_ZDFjNjVjNmItMTg3YS00NGMwLTk5OGMtMDg2YzM0NjkyZmZh%40thread.v2
  /0?context=%7b%22Tid%22%3a%22f4612edd-28c3-411a-a42e-ab15e7241712%22
  %2c%22Oid%22%3a%221ffa0307-bcdf-4ac5-ac1e-eb3084437c39%22%7d
```

**The full join URL is always present in Event.Description.** The Apex regex to extract it:
```apex
Pattern p = Pattern.compile('https://teams\\.microsoft\\.com/l/meetup-join/[^\\s<>]+');
Matcher m = p.matcher(event.Description);
String joinUrl = m.find() ? m.group(0) : null;
```

This join URL is the filter value for:
```
GET /users/{userId}/onlineMeetings?$filter=JoinWebUrl eq '{joinUrl}'
→ returns onlineMeeting.id
```

### Salesforce Storage Limits (Confirmed)

- **Data storage (records):** 40,960 MB remaining / 40,960 MB total — effectively empty
- **File storage (attachments/ContentVersion):** 500,000,000 MB — effectively unlimited for current use
- **Current files in org:** 2 files (Capability Statement PDF 933KB + Channel Order PNG 460KB)
- **Transcript text storage:** 131,072 character Long Text Area field = ~100 pages of transcript per meeting. No storage concern at any realistic volume.

---

## C. Salesforce Data Model

### Object: `Meeting_Record__c`

One record per completed meeting. Parent object for all meeting artifacts.

**Fields:**

| API Name | Type | Length | Notes |
|----------|------|--------|-------|
| `Name` | Auto-number | — | `MTG-{YYYY}-{000001}` |
| `Lead__c` | Lookup(Lead) | — | Nullable (null if Lead converted) |
| `Contact__c` | Lookup(Contact) | — | Populated on Lead conversion |
| `Campaign_Member__c` | Lookup(CampaignMember) | — | Links to active campaign |
| `Salesforce_Event__c` | Lookup(Event) | — | EAC-synced Event record |
| `Teams_Meeting_Id__c` | Text | 255 | Graph `onlineMeeting.id` |
| `Teams_Thread_Id__c` | Text | 255 | Extracted from join URL (`19:meeting_...@thread.v2`) |
| `Teams_Join_URL__c` | URL | 1333 | Full join URL from Event.Description |
| `Teams_Conference_Id__c` | Text | 50 | Short meeting ID (e.g., `288335565317932`) |
| `Meeting_Date__c` | DateTime | — | `Event.StartDateTime` |
| `Duration_Minutes__c` | Number | 5,0 | Calculated from end - start |
| `Recording_URL__c` | URL | 1333 | OneDrive direct URL (authenticated) |
| `Recording_Drive_Item_Id__c` | Text | 255 | OneDrive DriveItem ID (permanent reference) |
| `Transcript_URL__c` | URL | 1333 | VTT file URL in OneDrive |
| `Transcript_Text__c` | Long Text Area | 131072 | VTT or plain text content — copied into SF for retention |
| `Attendee_List__c` | Long Text Area | 32768 | JSON array: `[{"name":"Jane Smith","email":"jane@co.com"}]` |
| `Meeting_Summary__c` | Long Text Area | 32768 | AI-generated 3–5 sentence summary |
| `Key_Topics__c` | Long Text Area | 16384 | AI-extracted bullet list of topics discussed |
| `Action_Items__c` | Long Text Area | 32768 | AI-extracted structured list: `- [Owner]: [Action] by [Date]` |
| `Next_Step__c` | Text Area | 4096 | Single primary next step (AI-distilled from Action_Items__c) |
| `Processing_Status__c` | Picklist | — | Pending / Recording Available / Transcript Available / AI Complete / Complete / Error / Skipped |
| `Processing_Attempts__c` | Number | 2,0 | Retry counter (max 3 before Error) |
| `Error_Details__c` | Text Area | 4096 | API error messages for debugging |
| `Processed_At__c` | DateTime | — | Timestamp of last successful processing step |
| `Requires_Manual_Review__c` | Checkbox | — | Set true when no recording found or unmatched |

**Object settings:**
- Enable Activities: Yes (to log follow-up tasks against the meeting record)
- Enable History Tracking: Yes (for `Processing_Status__c`, `Meeting_Summary__c`)
- Enable Reports: Yes
- Record Name: Auto-number `MTG-{0000000000}`

### Relationship to Existing Objects

```
Lead  ────────────────────────────────1:many──► Meeting_Record__c
  │                                                     │
  ├── Meeting_Booked_Date__c (stamp on first booking)   │
  └── Relationship_Status__c ('Call Complete' after)    │
                                                         │
CampaignMember ──────────────────────1:many──► Meeting_Record__c
                                                         │
Event (EAC-synced) ──────────────────1:1────► Meeting_Record__c
                                                         │
                                                         ├── Recording_URL__c → OneDrive MP4
                                                         ├── Transcript_Text__c → VTT content
                                                         ├── Meeting_Summary__c → AI text
                                                         └── Action_Items__c → AI structured list
```

### Why Not Store Files in Salesforce ContentVersion?

Recording MP4 files are 100MB–2GB. Salesforce ContentVersion storage would consume file storage quota rapidly and incur high API overhead for upload. The design stores only the **URL reference** to the recording in OneDrive (permanent, auth-protected) and the **text content** of the transcript directly in Salesforce (small, queryable, retained independently of OneDrive retention policy).

This separates concerns:
- OneDrive: holds the binary recording (subject to retention policy)
- Salesforce: holds the text artifacts (summary, transcript, action items — permanent CRM value)

---

## D. Automation Design

### Pipeline Overview

```
[Booking meeting occurs — OA_BookingPoller already ran]
  Lead.Meeting_Booked_Date__c stamped
  CampaignMember.Status = "Meeting Booked"
  Event.WhoId = Lead.Id

[Meeting time arrives + meeting ends]
  Teams auto-records (requires admin policy: autoStartMeetingRecording = true)
  Recording processes: ~5–10 min post-meeting

[OA_MeetingRecordPoller — runs every 30 minutes]
  ├── PHASE 1: Discovery
  │   Find Events WHERE StartDateTime < NOW()-90min
  │                  AND StartDateTime > NOW()-48hr   ← window: 1.5hr to 48hr post-meeting
  │                  AND WhoId != null
  │                  AND Description LIKE '%bookings page%'
  │                  AND Id NOT IN (
  │                    SELECT Salesforce_Event__c FROM Meeting_Record__c
  │                    WHERE Processing_Status__c != 'Error'
  │                  )
  │
  ├── PHASE 2: Online Meeting Lookup (Graph API)
  │   Extract join URL from Event.Description (regex: /l/meetup-join/...)
  │   GET /users/{orgOid}/onlineMeetings?$filter=JoinWebUrl eq '{joinUrl}'
  │   → onlineMeeting.id
  │   Create Meeting_Record__c (Status: Pending)
  │
  ├── PHASE 3: Recording Retrieval (Graph API)
  │   GET /users/{orgOid}/onlineMeetings/{meetingId}/recordings
  │   → If recordings[] not empty:
  │       recording.contentUrl = direct download URL for MP4
  │       recording.contentCorrelationId = permanent reference ID
  │       Update Meeting_Record__c.Recording_URL__c
  │       Update Processing_Status__c = "Recording Available"
  │   → If recordings[] empty AND attempts < 3:
  │       Increment Processing_Attempts__c (retry next cycle)
  │       EXIT (will retry in 30 min)
  │
  ├── PHASE 4A: Transcript Retrieval (Teams Premium path)
  │   GET /users/{orgOid}/onlineMeetings/{meetingId}/transcripts
  │   → If transcripts[] not empty:
  │       GET .../transcripts/{transcriptId}/content  (text/vtt)
  │       Parse VTT → extract plain text blocks
  │       Update Meeting_Record__c.Transcript_Text__c
  │       Update Transcript_URL__c
  │       Update Processing_Status__c = "Transcript Available"
  │       → PROCEED TO PHASE 5
  │
  ├── PHASE 4B: Whisper Transcription (fallback, no Teams Premium)
  │   If transcript not available AND recording URL is set:
  │       POST callout:OpenAI/v1/audio/transcriptions
  │         file: {streaming download of first 25MB of recording}
  │         model: whisper-1
  │         response_format: text
  │       NOTE: Apex callout 12MB limit — full audio requires chunked download
  │       Alternative: Store Recording_URL__c; trigger async Lambda/Azure Function for Whisper
  │       → If transcript generated: Update Transcript_Text__c
  │
  ├── PHASE 5: AI Summary (OpenAI Named Credential)
  │   POST callout:OpenAI/v1/chat/completions
  │   Body:
  │   {
  │     "model": "gpt-4o-mini",
  │     "messages": [
  │       {
  │         "role": "system",
  │         "content": "You are summarizing a B2B government contracting introductory call
  │                     for One Algorithm LLC (EDWOSB, Salesforce + federal IT contractor).
  │                     Be concise and professional. Return JSON with keys:
  │                     summary (3-4 sentences), key_topics (bullet list),
  │                     action_items (array of {owner, action, deadline}),
  │                     next_step (single most important immediate action)."
  │       },
  │       {
  │         "role": "user",
  │         "content": "Meeting transcript:\n\n{Transcript_Text__c}"
  │       }
  │     ],
  │     "response_format": {"type": "json_object"},
  │     "max_tokens": 1500
  │   }
  │
  │   Parse JSON response:
  │   → Meeting_Summary__c = response.summary
  │   → Key_Topics__c = response.key_topics
  │   → Action_Items__c = response.action_items (formatted)
  │   → Next_Step__c = response.next_step
  │   → Processing_Status__c = "AI Complete"
  │
  └── PHASE 6: Salesforce Record Updates
      Update Meeting_Record__c.Processing_Status__c = "Complete"
      Update Meeting_Record__c.Processed_At__c = Datetime.now()
      Update Lead.Relationship_Status__c = "Call Complete"
      Insert Task:
        Subject: "Follow-up: {Next_Step__c}"
        WhoId: Lead.Id
        WhatId: Meeting_Record__c.Id
        ActivityDate: Date.today() + 1
        Priority: High
        Description: "AI Summary: {Meeting_Summary__c}
                      Action Items: {Action_Items__c}"
```

### Apex Class: `OA_MeetingRecordPoller`

```apex
public class OA_MeetingRecordPoller implements Schedulable {
    private static final String GRAPH_USER_OID = '1ffa0307-bcdf-4ac5-ac1e-eb3084437c39';
    // Loaded from OA_Graph_Config__mdt in production

    public void execute(SchedulableContext sc) { processCompletedMeetings(); }

    @future(callout=true)
    public static void processCompletedMeetings() { ... }

    // Phase 2
    private static String getOnlineMeetingId(String joinUrl) {
        // GET /users/{oid}/onlineMeetings?$filter=JoinWebUrl eq '{joinUrl}'
        // Returns onlineMeeting.id
    }

    // Phase 3
    private static String getRecordingUrl(String meetingId) {
        // GET /users/{oid}/onlineMeetings/{meetingId}/recordings
        // Returns recordings[0].contentUrl
    }

    // Phase 4A
    private static String getTranscriptText(String meetingId) {
        // GET /users/{oid}/onlineMeetings/{meetingId}/transcripts
        // GET content as text/vtt → parse to plain text
    }

    // Phase 5
    private static Map<String, String> generateAISummary(String transcript) {
        // POST callout:OpenAI/v1/chat/completions
        // Returns {summary, key_topics, action_items, next_step}
    }

    // Phase 6
    private static void finalizeRecord(Meeting_Record__c rec, Id leadId,
                                       Map<String, String> summary) {
        // Update Meeting_Record__c, Lead, insert Task
    }
}
```

### Scheduled Jobs (every 30 minutes)

```apex
System.schedule('OA Meeting Record Poller 00', '0 0  * * * ?', new OA_MeetingRecordPoller());
System.schedule('OA Meeting Record Poller 30', '0 30 * * * ?', new OA_MeetingRecordPoller());
```

Two jobs (vs. four for OA_BookingPoller) because recording processing takes 10–30 minutes — checking every 15 minutes before the recording is ready generates wasted callouts.

### Handling the Whisper Transcription Problem

Apex callouts have a 12MB response body limit and 120-second timeout. A 30-minute meeting recording is ~200MB. Direct Whisper transcription from Apex is not viable for full recordings.

**Options:**
1. **Teams Premium (recommended):** Auto-transcript via Graph API — no audio processing, no size limit
2. **Azure Function bridge:** Apex calls an Azure Function URL with the recording download URL; Azure Function downloads the MP4, sends to Whisper, returns transcript. Apex receives text only (small response).
3. **Transcript at first 10 minutes only:** Whisper accepts 25MB audio files. Apex can stream the first 25MB chunk (approx. first 10–12 minutes of a meeting). Sufficient for capturing the key introduction and framing of the call.
4. **Manual transcript upload:** Louis pastes the Teams auto-generated transcript (available in Teams meeting chat) into a custom action that updates `Transcript_Text__c` and triggers AI summary. Bridge until Teams Premium is approved.

### Additional Graph API Permissions Required

Beyond `Calendars.Read` (already in Bookings poller design):

| Permission | Type | Purpose |
|-----------|------|---------|
| `OnlineMeetings.Read` | Application | Look up meeting by JoinWebUrl |
| `OnlineMeetingRecording.Read.All` | Application | Get recording metadata and content URL |
| `OnlineMeetingTranscript.Read.All` | Application | Get transcript content (Teams Premium only) |
| `Files.Read` | Application | Read recording/transcript files from OneDrive |

All permissions are **Application** type (no user sign-in) — same Azure AD app registration as OA_BookingPoller. Add these scopes to the existing app; submit for admin consent.

---

## E. Security Review

### Data Sensitivity Classification

| Data | Classification | Rationale |
|------|---------------|-----------|
| Meeting_Summary__c | Confidential | Captures discussions about federal contracting strategies and business relationships |
| Transcript_Text__c | Confidential | Full verbatim meeting content including prospect's disclosures |
| Action_Items__c | Confidential | Commitments and next steps; may reference contract values |
| Recording_URL__c | Restricted | Points to authenticated OneDrive resource; URL itself is not sufficient for access |
| Attendee_List__c | Internal | Names and email addresses of meeting participants |
| Teams_Join_URL__c | Internal | Join URL (meeting is past — no replay risk) |

### Access Control

**In Microsoft 365:**
- Recording file in OneDrive is private to Louis by default — only `lrubino@onealgorithm.com` can access
- Transcript file same privacy settings
- Graph API access requires application permission (admin-consented) — Azure AD audit log captures every API call
- No external party can access recording via Salesforce URL — it requires M365 authentication

**In Salesforce:**
- `Meeting_Record__c` object access: restrict to `oauser@pboedition.com` profile only (single-user org — not a risk)
- `Transcript_Text__c` and `Meeting_Summary__c`: exclude from Salesforce search index (no `isSearchable` on Long Text fields by default)
- Field History Tracking on `Processing_Status__c`: maintains audit log of processing state transitions
- `OA_MeetingRecordPoller` runs as system context — no user permission escalation
- OpenAI API calls: transcript content sent to OpenAI API. Ensure OpenAI API key is stored in External Credential (already uses `ExternalCredential: OpenAI`), never in Apex code

### Data Retention

| Artifact | M365 Retention | Salesforce Retention | Action |
|----------|---------------|---------------------|--------|
| Recording (MP4) | 60 days default (configurable to 180 days or Never) | Not stored — URL reference only | Set M365 recording expiration to 180 days; transcript text copied to Salesforce before expiry |
| Transcript (VTT) | Same as recording | Full text stored in `Transcript_Text__c` permanently | Copy transcript within 24 hours of meeting |
| Meeting_Summary__c | N/A | Permanent | No action needed |
| Action_Items__c | N/A | Permanent | No action needed |

**Critical:** Set M365 meeting recording expiration to **Never** (or minimum 180 days) before implementing. Default 60-day deletion will destroy recordings before Apex poller can process them if there is any backlog.

Configure in Teams Admin Center: Meetings → Meeting Policies → Recording → Meeting recording expiration (days) → set to -1 (Never).

### Audit Trail

| Event | Log Location |
|-------|-------------|
| Graph API call made | Azure AD audit log (30-day retention in Business plans; 90 days in Premium) |
| Recording accessed | Azure AD audit log + OneDrive audit log |
| Meeting_Record__c created | Salesforce audit trail + Field History on Status |
| Transcript sent to OpenAI | Apex debug log (enable trace flag on `OA_MeetingRecordPoller`) |
| AI summary generated | `Processed_At__c` timestamp on Meeting_Record__c |
| Follow-up Task created | Task created date + `WhatId` link to Meeting_Record__c |
| Processing error | `Error_Details__c` field + `Requires_Manual_Review__c` checkbox |

Query all meetings processed in a date range:
```sql
SELECT Id, Name, Lead__c, Meeting_Date__c, Processing_Status__c,
       Processing_Attempts__c, Processed_At__c, Next_Step__c
FROM Meeting_Record__c
WHERE Meeting_Date__c >= 2026-07-01T00:00:00Z
ORDER BY Meeting_Date__c DESC
```

Query meetings requiring manual review:
```sql
SELECT Id, Name, Lead__c, Meeting_Date__c, Error_Details__c
FROM Meeting_Record__c
WHERE Requires_Manual_Review__c = true
OR Processing_Status__c = 'Error'
```

### OpenAI Data Handling

Transcript content is sent to OpenAI API for summarization. Relevant OpenAI data handling policies:
- API data is not used to train OpenAI models (API data handling policy)
- API data may be retained up to 30 days for abuse detection (zero data retention available on higher-tier API plans)
- Recommendation: Use OpenAI's **zero data retention** option if available on the current API tier, or add a data processing addendum to the OpenAI account

If OpenAI data handling is a concern for prospect meeting content, alternative: deploy Claude via Anthropic API (similar capability, explicit no-training-on-API-data commitment).

---

## Implementation Plan

### Prerequisites Checklist

| # | Item | Who | Blocking |
|---|------|-----|---------|
| 1 | Enable Teams meeting recording policy (`allowCloudRecording = true`) | Louis (Teams Admin) | Yes |
| 2 | Set recording expiration to Never in Teams Admin | Louis (Teams Admin) | Yes |
| 3 | Enable auto-record meeting policy (`autoStartMeetingRecording = true`) | Louis (Teams Admin) | Yes |
| 4 | (If approving Teams Premium) Add license in M365 Admin Center | Louis (billing) | Conditional |
| 5 | Add Graph API permissions to existing Azure AD app (see Section D) | Louis (Azure AD admin) | Yes |
| 6 | Admin consent the new permissions | Louis (M365 admin) | Yes |
| 7 | Create `OA_Graph_Config__mdt` custom metadata object + record | Developer | Yes |
| 8 | Create `Meeting_Record__c` custom object + all fields | Developer (metadata deploy) | Yes |
| 9 | Create `OA_MeetingRecordPoller` Apex class + test class | Developer | Yes |
| 10 | Add `https://graph.microsoft.com` Remote Site Setting (if not already present) | Developer | Yes |
| 11 | Schedule 2 cron jobs | Developer (anonymous Apex) | Yes |
| 12 | Integration test: attend a test meeting → verify pipeline end-to-end | Developer + Louis | Yes |
| 13 | Configure Salesforce Field History Tracking on `Meeting_Record__c` | Developer | No |
| 14 | Set OpenAI zero-data-retention tier (if required) | Louis (OpenAI account) | No |

### Development Sequence

```
Sprint 1 (4 hours): Foundation
  ├── Create Meeting_Record__c object + all fields (metadata deploy)
  ├── Create OA_Graph_Config__mdt object + record
  ├── Add new permissions to Azure AD app + admin consent
  └── Validate: query /onlineMeetings with existing Bookings event join URL (anonymous Apex)

Sprint 2 (4 hours): Core Poller
  ├── Write OA_MeetingRecordPoller (Phase 1–3: Discovery + Meeting lookup + Recording)
  ├── Write OA_MeetingRecordPoller_Test with HttpCalloutMock
  └── Deploy + run first live test against past meeting

Sprint 3 (3 hours): AI Summary
  ├── Add Phase 4A (transcript retrieval — Teams Premium) or Phase 4B (Whisper fallback)
  ├── Add Phase 5 (OpenAI summary generation)
  ├── Add Phase 6 (Lead + Task updates)
  └── End-to-end test with real transcript

Sprint 4 (1 hour): Schedule + Validate
  ├── Schedule 2 cron jobs
  ├── Run full pipeline test with a Bookings meeting
  └── Verify Meeting_Record__c populated correctly
```

**Total estimated implementation time:** 12 hours across 4 sprints.

### Dependency on OA_BookingPoller

`OA_MeetingRecordPoller` depends on `OA_BookingPoller` having already run for the Event being processed — specifically that `Event.WhoId` is populated (linking the meeting to a Lead). Without `OA_BookingPoller`, the meeting record cannot be linked to any Lead.

Sequence guarantee: `OA_BookingPoller` runs within 15 minutes of booking creation. The meeting itself occurs at least hours to days later. By meeting time, `WhoId` is always set. No timing conflict.

### Future Extensions

- **Opportunity creation trigger:** After Meeting_Summary__c is populated and Next_Step__c includes "teaming agreement" language, an Apex trigger auto-creates an Opportunity linked to the Lead's Account
- **Slack/Teams notification:** Post Meeting_Summary__c to a private Teams channel or Slack DM immediately after completion
- **Multi-language support:** OpenAI model `gpt-4o` handles 90+ languages natively; transcript can be in any language and summary will be in English
- **Meeting series tracking:** For prospects with multiple meetings, `Lead__c` lookup enables querying all `Meeting_Record__c` for a Lead, showing progression through relationship stages
- **Capability Statement tracking:** If `Action_Items__c` contains "send capability statement," a separate automation can trigger the capability statement email template automatically
