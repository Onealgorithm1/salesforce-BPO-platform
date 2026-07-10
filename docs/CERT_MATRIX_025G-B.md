# Certification Matrix — Program 025G-B (Path A Lead Write-Back)

**Date:** 2026-07-10 · **Org:** `00Dbn00000plgUfEAI` · **Path:** A (`OA_USASpendingEnrichmentService` → `OA_USASpending_Staging__c` → `OA_LeadWritebackService`).
**Pilot unit:** ONE Lead write-back bundle (writer is atomic per Lead). **Pilot record:** Zolon Tech (`00QPn000011DshSMAS`), staging `a0kPn00001NbqBZIAZ`, award `SAQMMA12C0014` ($97,441,995.15, Dept of State). **Approved by:** Louis (025G-B certification pilot).

**Cohort certified (Louis-approved, all checks 1–5/11 re-verified per Lead — one row each, same lifecycle):**
| Lead | Staging (Award ID) | UEI | Amount / Agency | Result | Modstamp |
|---|---|---|---|---|---|
| Zolon Tech | `SAQMMA12C0014` | XVE2FA8DRTL7 | $97.44M / Dept of State | **WRITTEN** (+ rollback→reapply proof) | 13:19:59Z |
| 1 Source Consulting | `TPDTTB13K0013` | EXEYN7TNGWH7 | $78.50M / Treasury | **WRITTEN** | 13:38:22Z |
| 1 Sync Technologies | `FA330022C0055` | SHKSNU48JHZ7 | $3.90M / Air Force (DoD) | **WRITTEN** | 13:39:24Z |
| @Orchard LLC | — | — | — | **excluded (no verifiable match)** | unchanged 07-07 |

All 3: succeeded=1, snapshot captured, tripwires 0, staging Written Back, only that Lead's modstamp moved, Opp=1, CampaignMember/Task unchanged. Staging landscape: **3 Written Back · 12 Pending** (4 remaining rows per certified Lead, all untouched).

## Result summary: **12 PASS · 3 WARN/NOTE · 0 FAIL** · full suite 365/365 pass (after a test-only fix — see #15)

| # | Certification check | Expectation | Result | Evidence |
|---|---|---|---|---|
| 1 | Path A staging eligibility (post-fix) | UEI populated + Lead linked | **PASS** | Staging row `Recipient_UEI__c=XVE2FA8DRTL7`, `Lead__c=00QPn000011DshSMAS` |
| 2 | Happy-path write-back | 15 of 16 Lead fields written (Evidence stays null) | **PASS** | RowOutcome WRITTEN; 15 fields verified on Lead; `UEI_Verification_Evidence__c` null (Gate_Results null) |
| 3 | Snapshot-first | `Before_Snapshot__c` captured pre-write (all-null) | **PASS** | Snapshot JSON present w/ leadId + writeBackRunId; `snapshotCaptured=1` |
| 4 | Isolation | Only Zolon SystemModstamp changes | **PASS** | Zolon → 2026-07-10T13:19:59Z; @Orchard/1 Source/1 Sync unchanged at 2026-07-07 |
| 5 | No side effects | Opp / CampaignMember / Task counts stable | **PASS** | Opportunities=1; Zolon CampaignMember=1; Zolon Task=3 — all unchanged |
| 6 | Rollback restores | Lead → snapshot (all-null); staging → Approved | **PASS** | RollbackOutcome RESTORED; Lead all-null; staging Approved, write markers cleared |
| 7 | Reapply after rollback | Approved values restored (final state keeps data) | **PASS** | Re-write WRITTEN; Lead re-verified; staging Written Back |
| 8 | Negative: Pending can't write | Blocked at ELIGIBILITY, no Lead write | **PASS** | `FAILED / ELIGIBILITY "Review_Status__c != Approved"`, succeeded=0; modstamp stable |
| 9 | Negative: Rejected can't write | Blocked at ELIGIBILITY, no Lead write | **PASS** | `FAILED / ELIGIBILITY`, succeeded=0 (flip done in a Savepoint, then reverted) |
| 10 | Idempotency re-run | Already-written row skipped, no re-write | **PASS** | `SKIPPED / IDEMPOTENCY "Already written back"`, `duplicateWritePrevention=1`; modstamp stable |
| 11 | Tripwires | All defensive counters = 0 | **PASS** | noSnapshot=0, noApproval=0, noRunId=0, fuzzy=0, unauthorized=0 (both write + reapply) |
| 12 | Multi-row-per-Lead safety | Safe failure if >1 Approved row per Lead | **⚠️ WARN** | **Certification defect** — uncaught `System.ListException: Duplicate id in list` aborts+rolls back the whole batch (verified pre-DML even with allOrNone=false). See below. |
| 13 | Native change-log | `LeadHistory` entries on write | **⚠️ NOTE** | **0 entries** — the 16 write-back fields are not field-history-tracked. Config decision for Louis (below). Audit trail lives on staging snapshot + Lead run-id/verified-by. |
| 14 | Cross-operation audit fidelity | Every op leaves a durable trace | **⚠️ NOTE** | `Gate_Results__c` is last-write-wins for write-back (append-only for rollback), so a reapply overwrites the intermediate rollback line. **`Before_Snapshot__c` + approval `Notes__c` are preserved.** |
| 15 | Full local test suite | All local tests pass | **PASS (after fix)** | `RunLocalTests` = **365 ran, 365 pass** after correcting one test I introduced (`testLeadLinkedAndUeiPopulatedForWriteback` hit `MIXED_DML_OPERATION` — Lead insert moved inside `System.runAs`). Deploy-context masked it (async setup DML); interactive run caught it. See "Production test-state" below. |

## Production test-state — RESOLVED
Corrected `OA_USASpendingEnrichmentService_Test` **deployed** (Louis-approved, deploy `0AfPn00000243qzKAA`). Interactive `RunLocalTests` on the class now **11/11 Pass** (the MIXED_DML method passes). Org suite green.

## WARN / NOTE detail

### #12 — Duplicate-Id abort (certification DEFECT — required fix before any multi-lead / scheduled write-back)
`OA_LeadWritebackService.writeBack` builds one `buildLeadUpdate` per staging row; when ≥2 Approved rows target the same Lead, `leadsToWrite` holds duplicate-Id `Lead` sObjects and `Database.update(leadsToWrite, false)` (line ~313) throws an **uncaught** `System.ListException: Duplicate id in list`, which rolls back the entire batch (snapshots included). An uncaught exception on a legitimate reviewer action (approving two rows for one Lead) is **not a safe failure mode**.
- **NOT fixed this session** (per Louis).
- **Required fix before multi-lead or scheduled write-back:** dedupe `leadUpdates` to one row per Lead (choose highest award / most recent) before DML, or process per-Lead; add a regression test for the multi-row-per-Lead case.
- **Interim rule:** approve at most ONE staging row per Lead per `writeBack` batch (distinct Leads in one batch are fine).

### #13 — Field-history tracking (config decision for Louis — NOT changed)
A committed write produced **0 `LeadHistory`** rows because none of the 16 target fields are enabled for field-history tracking. **Decision needed:** enable field-history tracking on these fields for native change-log coverage, or accept the staging-snapshot + Lead run-id audit trail as sufficient. No tracking config was changed this session.

## Final state (verified)
Zolon Lead holds the approved write-back data (`UEI_Verification_Status__c=Verified`, UEI `XVE2FA8DRTL7`, award `SAQMMA12C0014` $97.44M) · staging `a0kPn00001NbqBZIAZ` = Written Back (snapshot retained, approval note in `Notes__c`) · Zolon's other 4 rows + all 1 Source / 1 Sync rows = Pending (untouched) · other 3 cohort Leads unchanged · Opportunities=1 · 0 connectors enabled · 0 scheduled jobs · no campaign/email side effects.
