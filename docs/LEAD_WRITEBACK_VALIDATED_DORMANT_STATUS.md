# Lead Write-Back — Validated & Dormant Status

_Last updated: 2026-07-04_

This document records the validation state of the USASpending → Lead write-back
engine. The engine is **built, deployed, functionally validated, and DORMANT**.
**No real-data write-back is authorized.** See Standing Guardrails below.

---

## A. Final Classification

| Item | Status |
|---|---|
| Functional canary (write-back) | **COMPLETE** |
| Rollback drill | **COMPLETE** |
| Least-privilege canary | **DEFERRED** (no spare full Salesforce license for a non-admin run user) |
| Real-data write-back | **NOT AUTHORIZED** |
| Connector | **DORMANT** |

---

## B. Verification Evidence

- **Rollback-enabled engine deployment Id:** `0AfPn0000022Z29KAE`
  - Result: **166/166 Apex tests passed**, **80.5% coverage** on `OA_LeadWritebackService`.
- **Synthetic test Lead:** `00QPn000012F3SAMA0` (`PREVIEW_TEST_DO_NOT_CONTACT`)
- **Synthetic staging row:** `a0kPn00001MqNQ8IAN` (`Review_Status__c = Approved`)
- **Functional write-back run Id:** `WB-005bn00000BP9zUAAT-1783185213233`
  - `attempted=1, succeeded=1, failed=0`; all KPI tripwires `= 0`
  - Lead mapped exactly (award amount 250000.00, award id `TEST-AWARD-0001`,
    agency `Test Agency of Preview`, UEI `TESTUEI00001`, `UEI_Verification_Status__c = Verified`, …).
  - `Before_Snapshot__c` captured (valid JSON of prior values) before the Lead write.
- **Rollback run Id:** `RB-005bn00000BP9zUAAT-1783185291326`
  - `attempted=1, succeeded=1, failed=0, rollbackFailures=0`
  - Lead restored to pre-canary values (`UEI_Verification_Status__c = Unverified`, other 15 fields `null`).
  - Staging reset to `Approved`; `Written_Back_Date__c` / `Written_Back_By__c` cleared;
    `Before_Snapshot__c` **retained for audit**; `Gate_Results__c` holds both write-back and rollback notes.
- **Temporary `OA_Connector_Staging` assignment was assigned and then REVOKED** (assign → run → revoke).
- **`OA_Lead_Writeback_Automation` assignment remained 0** throughout (never assigned).
- **No connector invocation / no callouts** occurred.
- **No CampaignMember records** were touched.
- **No real production Leads** were touched (synthetic record only; reverted to pre-drill state).

Post-drill baseline: `OA_Lead_Writeback_Reviewer = 1`, `OA_Lead_Writeback_Automation = 0`,
`OA_Connector_Staging = 0`; synthetic Lead + staging row back to pre-canary state.

---

## C. Important Security Finding (positive guardrail)

The first admin-executed commit attempt was run **without** `OA_Connector_Staging`:

- The engine's `SELECT … Lead__c … WITH USER_MODE` staging read **enforced field-level
  security even for `oauser`** (a System Administrator with Modify All Data).
- Result: `unauthorizedRunAttempts = 1`, the row `FAILED` at the `FLS` gate, and
  **zero writes** occurred.

This is a **positive guardrail finding**: the engine refuses to run when the executing
identity lacks proper field access on the staging source fields — even a Modify All Data
admin cannot bypass the `WITH USER_MODE` read enforcement.

---

## D. Caveat

- The functional canary was **admin-executed using `oauser`**.
- `oauser` has **System Administrator / Modify All Data**, which bypasses the write-side
  FLS check (`Security.stripInaccessible`).
- Therefore the **write-side test does NOT prove least-privilege runtime / FLS enforcement**.
  It validates the engine's write/rollback **logic and data mapping** against a real record only.
- The **least-privilege canary remains DEFERRED** because there is **no spare full Salesforce
  license** available to create a non-admin run user that can (a) log in interactively and
  (b) access Lead + the staging object. (`Salesforce` licenses: 2/2 used; other license types
  cannot access Lead or cannot log in interactively.)

---

## E. Standing Guardrails

- **Do NOT run write-back against real Leads.**
- **Do NOT assign `OA_Lead_Writeback_Automation`.**
- **Do NOT assign `OA_Connector_Staging`** except **JIT** for an explicitly approved test (assign → run → revoke).
- **Do NOT invoke the USASpending connector.**
- **Do NOT schedule write-back** (no trigger / flow / scheduler / batch).
- **Do NOT run batch/pilot writes.**
- **Do NOT merge PR #11 without review/approval.**

---

## F. Future Gates (allowed, each requiring explicit approval)

1. Review / merge **PR #11** (24 fields + 2 permission sets + engine + rollback).
2. Optional cleanup of the synthetic test Lead (`00QPn000012F3SAMA0`) and staging row (`a0kPn00001MqNQ8IAN`).
3. **Least-privilege canary** when a spare Salesforce license / auth path exists for a non-admin run user.
4. **Design-only** first real-data pilot (eligible real Approved rows, batch size, least-privilege user plan, gates).
5. **No real write-back until explicit approval.**
