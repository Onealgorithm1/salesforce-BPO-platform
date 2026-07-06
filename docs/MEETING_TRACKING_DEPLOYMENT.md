# Meeting Tracking — Deployment Summary

**Branch:** `feature/meeting-tracking-link`
**Status:** PR-ready. NOT deployed, NOT merged, flow NOT activated.
**Target org:** `00Dbn00000plgUfEAI` (production)
**Last check-only validation:** `0AfPn0000022w8PKAQ` — Succeeded, 2/2 components, 174 tests, 0 errors.

## Purpose
Lightweight tracking of campaign-generated meetings, **without** introducing full Opportunity management. When a Teams meeting is scheduled from a Lead, the Lead's EDWOSB campaign membership is advanced to **"Meeting Booked"** so the campaign funnel reflects the conversion.

## Components ADDED (2 deployable + 1 doc)
| Component | Type | Notes |
|---|---|---|
| `Lead.Meeting_Join_URL__c` | CustomField (URL) | Storage field for the Teams join link |
| `OA_Meeting_Scheduled_Link` | Flow (Autolaunched, record-triggered on Event **Create**) | **DRAFT / inactive.** Sets CampaignMember.Status = "Meeting Booked" |
| `docs/MEETING_TRACKING_DEPLOYMENT.md` | Doc | This file |

## Components CHANGED
**None.** No existing metadata, flow, class, object, field, or automation is modified. This is purely additive. `OA_EDWOSB_Outreach_Sequence`, `OA_Reply_Detection`, `OA_PostMeeting_Nurture`, and `OA_EmailSender` are untouched.

## Design rationale

**Why no Opportunity is created.** The requirement is lightweight relationship/meeting tracking, explicitly *without* Opportunity management. Creating Opportunities would impose pipeline/stage/forecast overhead the team did not ask for. The flow contains no `recordCreates` and never touches Opportunity.

**Why `CampaignMember.Status` is the source of truth.** The live campaign funnel already lives on `CampaignMember.Status` (Day 1/3/5/10 Sent → Replied → Meeting Booked → Call Completed), maintained by the existing flows. It is inherently per-campaign, which is the correct grain for "campaign-generated" meetings. The Lead-level `Relationship_Status__c` field is ~99.9% empty and only read as a trigger by `OA_PostMeeting_Nurture`; tracking here would fragment the funnel and require a custom report type. Reusing the existing `CampaignMember.Status` value **"Meeting Booked"** (a confirmed member status on the campaign) means no new picklist values and zero change to existing automation.

**Why `Event.StartDateTime` is reused.** The Teams meeting Event already stores the exact start date/time in the standard `Event.StartDateTime` field. Adding a duplicate Lead field would create a second, drift-prone copy. The meeting datetime is therefore read from the Event, not restamped.

**Why `Meeting_Join_URL__c` is storage-only.** Salesforce Flow cannot reliably parse a variable-length Teams URL out of the `Event.Description` free-text body (no regex/substring extraction). Rather than overclaim, the flow does **not** populate this field. It exists as a storage target to be filled **manually** or by a **future Microsoft Graph integration** that has the URL as structured data. Both the field and flow descriptions state this explicitly.

## Deployment (when approved — RED, do not run yet)
```
sf project deploy start \
  --target-org 00Dbn00000plgUfEAI \
  --source-dir force-app/main/default/objects/Lead/fields/Meeting_Join_URL__c.field-meta.xml \
  --source-dir force-app/main/default/flows/OA_Meeting_Scheduled_Link.flow-meta.xml \
  --test-level RunLocalTests
```
Flow deploys as **Draft**. It does nothing until explicitly **activated** (a separate, approved step). Grant the `Meeting_Join_URL__c` FLS to the campaign users' permission set as a follow-up.

## Rollback procedure
- **Before activation (metadata only):** the flow is inactive, so no runtime effect. To remove: delete the flow (Setup → Flows → delete all versions) and delete the field (Setup → Object Manager → Lead → Fields → `Meeting Join URL` → Delete), or deploy a `destructiveChanges.xml` for both. No data was written, so nothing to unwind.
- **After activation:** deactivate the flow (Setup → Flows → `OA Meeting Scheduled Link` → Deactivate) to stop further writes immediately. Any `CampaignMember.Status` values it set to "Meeting Booked" are ordinary data and can be corrected manually; the flow keeps no separate state.
- **Git:** revert the PR / `git revert` the merge commit; branch is isolated and additive, so revert is clean.

## Post-deployment verification checklist
- [ ] Both components present: `Lead.Meeting_Join_URL__c` field and `OA_Meeting_Scheduled_Link` flow.
- [ ] Flow status is **Draft/Inactive** (not Active) immediately after deploy.
- [ ] No existing flow/class was modified (diff the org or check LastModified).
- [ ] `Meeting_Join_URL__c` FLS granted only to the intended permission set.
- [ ] (On activation) Create a test Teams-meeting Event on a test Lead that is a member of campaign `701Pn00001ZOyj8IAD`; confirm the member advances to "Meeting Booked" and no Lead/Event/Opportunity write occurs.
- [ ] Confirm no regression: editing an existing meeting Event does NOT change member status (create-only trigger).
