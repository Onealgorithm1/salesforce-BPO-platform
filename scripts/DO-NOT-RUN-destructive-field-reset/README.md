# ⛔ DO NOT RUN — destructive field reset

This directory holds a Salesforce **destructive** deployment manifest
(`destructiveChanges.xml` + `package.xml`). Running it deletes production metadata.

## What it deletes
- `Lead.Meeting_Booked_Date__c`
- `Lead.Relationship_Status__c`

## Why running it is dangerous
Both fields are load-bearing in production automation:
- **`OA_BookingPoller`** stamps `Meeting_Booked_Date__c` (its idempotency guard) and
  `Relationship_Status__c` on every booking. Deleting them breaks the booking pipeline.
- **`OA_PostMeeting_Nurture`** (record-triggered flow) fires on
  `Relationship_Status__c = 'Call Complete'`. Deleting the field disables the flow.
- `Relationship_Status__c` is **Lead-only pursuit-tracking data with no Contact equivalent** —
  deleting the field permanently destroys that history.

## Status
Kept for reference only. **Not tracked in git** except this README (the manifest files are
gitignored under `scripts/`), so a repo/project deploy will not pick it up — the only way to
run it is manually from this directory. Do not do that. If a field reset is ever genuinely
needed, get explicit approval and take a full export first.
