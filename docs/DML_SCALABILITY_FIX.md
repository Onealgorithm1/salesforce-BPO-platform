# DML Scalability Fix — Bulk Enrichment Write Path

_Org `00Dbn00000plgUfEAI` · 2026-07-08 · found by Operational Acceptance Test_

## Defect
The OAT triggered Salesforce DML-warning emails ("84 of 150 DML statements"). Root cause:
`OA_EnrichmentOrchestrator.processScope` Phase 2 called `OA_EnrichmentWriter.enrich()` **once per
connector match, per Lead**, and each `enrich()` performed its own DML (`Database.update` +
`commitLogs` + `commitExceptions`). Common company names match ~15 federal award recipients each, so a
5-Lead run executed ~84 DML statements. **DML consumption grew O(Leads × matches)** and would exceed
the 150 governor limit at production batch scale — a blocker for unattended/scheduled write automation
(not for the small manual runs the platform is certified for).

## Design (smallest change, no redesign)
Batch the DML inside the writer; leave all enrichment logic untouched.
- **`OA_EnrichmentWriter.enrichAll(List<WorkItem>, runId, commit)`** (new): evaluates every
  (target, proposals) work item in memory using the *identical* per-field policy engine, FillEmptyOnly,
  before-snapshot, audit, conflict/type-error routing — then commits the whole scope with **one**
  `Database.update`, **one** `commitLogs`, **one** `commitExceptions`. The Sprint-25 SaveResult-discard
  guarantee is preserved per-target within the bulk result.
- **`OA_EnrichmentWriter.enrich(...)`** (unchanged signature): now a thin wrapper delegating a
  single-item list to `enrichAll` — every existing caller and test is unaffected.
- **`OA_EnrichmentOrchestrator.processScope`**: Phase 2 builds one work-list and makes a single
  `enrichAll` call; per-Lead telemetry is re-derived from the change logs.

Preserved unchanged: FillEmptyOnly, Policy Engine, Audit Logging, Exception Logging, Rollback,
telemetry schema, and all existing tests.

## Measurements (live, 5-Lead workload, ~15 matches/Lead)
| Metric | Before | After |
|---|---:|---:|
| DML statements | ~84 | **4** |
| SOQL queries | (n/a — same path) | 1 |
| CPU time | not captured | ~1,400 ms |
| Runtime (preview+commit+rollback cycle) | not captured | 7–10 s |
| Governor headroom (DML) | 66 / 150 (44% used) | **146 / 150 (97% free)** |

DML is now **constant (4)** regardless of match volume. Regression tests
`OA_EnrichmentWriter_Test.testBatchCommitUsesBoundedDml` (3 Leads × 10 matches → `used ≤ 3`) and
`testBatchPartialFailureDiscardsOnlyFailedTarget` prove the bound and the per-target failure isolation.

## Validation & deploy
- Check-only validation `0AfPn0000023KsHKAU` — **RunLocalTests, 279 tests, 0 failures**.
- Production deploy (quick-deploy) `0AfPn0000023Kx7KAE` — **Succeeded**, `checkOnly=false`.
- Classes deployed **dormant** (0 connectors enabled, 0 active policies, nothing scheduled).

## OAT re-run (5 cycles, post-fix)
Every cycle: 5 processed, 5 enriched, 5 fields written, **DML=4**, SOQL=1, 0 HTTP errors, 73 conflicts
routed, rollback restored 5/5, dormant verified. Platform returned to baseline (78 real enriched Leads,
474 change logs, 1 exception, 18 runs) with all synthetic test data deleted.
