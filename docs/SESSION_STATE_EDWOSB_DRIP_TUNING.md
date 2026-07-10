# Session State — EDWOSB Drip Tuning (targeting + throughput + timing)

**Date:** 2026-07-10 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/edwosb-drip-tuning` (off `main` `3de5acc`).
**Campaign:** EDWOSB drip `701Pn00001ZOyj8IAD`. **Production changed: YES** (source deploy + custom-setting value + scheduled-job reschedule). All three Louis-approved in-session.

## What changed
### A. ICP filter on enrollment query (source deploy)
`OA_DripScheduler` enrollment SOQL now includes `AND Industry IN :ICP_INDUSTRIES` where
`ICP_INDUSTRIES = {Technology, Consulting, Engineering, Telecommunications}`. `Industry='Other'`
(unclassified — awaits NAICS work) and all non-ICP industries are excluded. `MAX_SYNC_BATCH` stays 50.
- **Tests:** helper leads stamped `Industry='Technology'`; added 4 filter tests (non-ICP excluded, Other excluded, null excluded, mixed→only 4 ICP enroll). **14 tests / 0 failures.**
- **Validate** `0AfPn0000024BbdKAE` (Succeeded) → **Quick-deploy** `0AfPn0000024BdFKAU` (Succeeded, 3 components).

### B. Throughput — Daily_Send_Cap__c 100 → 200
Live `OA_Campaign_Settings__c` org-default cap was **100** (not 200 — the `DEFAULT_CAP=200` constant is only the null-fallback). Raised **100 → 200** via anonymous Apex; `Sends_Today__c` left at 100 (not reset). Governor NOT removed — 200 is the deliverability ceiling. **350 deferred to next week** pending bounce/spam-rate review.

### C. Timing — 3x/day Tue–Thu, 1x/day Mon/Fri, 10am-Central primary window
Scheduling user `oauser` TZ = `America/New_York`, so cron hours are Eastern; **11 ET = 10 CT = 8 PT** (primary window). Aborted old `OA_DripScheduler_Wave1` (`0 0 8,14 ? * MON-FRI`, 2x/day). Created:
- `OA_DripScheduler_Wave1_TWT` — `0 0 9,11,14 ? * TUE,WED,THU` (3x/day, Tue–Thu weighted). Next: Tue 07-14 09:00 ET.
- `OA_DripScheduler_Wave1_MF` — `0 0 11 ? * MON,FRI` (1x/day at primary window). Next: Mon 07-13 11:00 ET / 10:00 CT.

## Preflight snapshot (2026-07-10, read-only)
- **Members (401):** Day 1 Sent 120 · Day 3 Sent 131 · Day 5 Sent 19 (= **270 active**) · Removed-Out-of-ICP 126 · Unsubscribed **4** · Meeting Booked 1 (Marty Pisano). No members altered this session.
- **Eligible-but-unenrolled Wave 1 (5,394):** Other 1,692 (excluded) · **Technology 1,619 · Consulting 998 · Engineering 765 · Telecommunications 45 = 3,427 ICP backlog** · Construction 220 · Healthcare 21 · Transportation 13 · Education 12 · Energy 5 · Finance 4.

## Projected days to clear the 3,427 ICP backlog
Assumes ~3 emails/lead (Day1/3/5) all drawing the shared daily send cap; enrollment batch = `min(50, remainingToday)`.
- **Enrollment-batch ceiling:** 11 runs/wk (3×Tue-Thu + 1×Mon + 1×Fri) × 50 = 550/wk → ~31 business days.
- **Send-cap-limited @ 200/day (steady state, pipeline full):** ~200÷3 ≈ **66 new/day** → **~52 business days (~10 wks)** — this is the binding constraint.
- **If cap → 350 next week:** ~350÷3 ≈ 116 new/day → **~30 business days (~6 wks)**.
Realistic: **~8–10 weeks at cap 200**, dropping to **~6 weeks** once cap moves to 350.

## Governance / closeout
- **Bulk member changes:** none this session (ICP filter is forward-only). Responded-status exclusion (Meeting Booked, Replied, Interested, Not Interested, Unsubscribed, Call Completed) not needed — no existing-member DML.
- **Connectors:** unchanged (enrichment connectors out of scope; none enabled this session).
- **Next approval gate (RED):** raise cap 200 → 350 next week after deliverability review.
- **Follow-up:** classify `Industry='Other'` (1,692 leads) via NAICS to unlock them for ICP enrollment.
