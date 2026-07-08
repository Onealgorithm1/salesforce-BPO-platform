# Lead Enrichment Platform — Release 1.2 (Production)

_Final production-certified release. Closes the Lead Enrichment engineering epic._

## Release facts
| Field | Value |
|---|---|
| Release | **lead-enrichment-v1.2** |
| Release date | 2026-07-08 |
| Production Org ID | `00Dbn00000plgUfEAI` |
| Repository | `salesforce-BPO-platform` |
| Commit hash | `f8eef52` (Apex identical to deployed `1725041`; monitoring adds docs/script only) |
| Production deployment ID | `0AfPn0000023Kx7KAE` (checkOnly=false, Succeeded) |
| Validated build ID | `0AfPn0000023KsHKAU` (RunLocalTests, 279 tests, 0 failures) |
| Prior release | `lead-enrichment-v1.1` (`a0c8bd0`) · ops `lead-enrichment-ops-v1.1` (`deecba4`) |

## What changed since v1.1 / ops-v1.1
- **DML scalability fix** (`DML_SCALABILITY_FIX.md`): the enrichment write path is now bulkified.
  `OA_EnrichmentWriter.enrichAll(...)` evaluates the whole scope in memory then commits once
  (one update + one log insert + one exception insert). DML dropped from ~84 to **4** for a 5-Lead
  run and is now **constant regardless of connector-match volume** — removing the last blocker to
  scheduled/unattended batch writes. `enrich()` retained as a thin wrapper; no logic changed.
- **Operational monitoring layer** (`LEAD_ENRICHMENT_MONITORING.md`,
  `scripts/shell/daily_enrichment_audit.sh`): telemetry audit, gap analysis (0 new metadata required),
  dashboard build steps, and a read-only daily audit script emitting PASS/WARN/FAIL.
- **Maintenance handoff** (`MAINTENANCE.md`).

## Acceptance evidence
Five-cycle Operational Acceptance Test (post-fix), each cycle: 5 processed, 5 enriched, 5 fields
written, **DML=4**, SOQL=1, 0 HTTP errors, 73 conflicts routed to Review, rollback restored 5/5,
platform returned dormant. Baseline restored (78 real enriched Leads, 474 change logs, 1 exception,
18 runs); all synthetic test data deleted.

## Defects fixed across the v1.x line
1. Writer SaveResult handling + `Awarding_Agencies__c` length (Sprint 25).
2. Rollback multi-field restore (Rollback Fix Sprint).
3. Orchestrator callout-after-DML (Sprint 35).
4. **DML scalability / bulkification (this release).**

## State at release
Platform **dormant**: 0 connectors enabled, 0 active write policies, nothing scheduled. All code
deployed and inert; enabling requires explicit authorization per `OPERATIONS_GUIDE.md`.
