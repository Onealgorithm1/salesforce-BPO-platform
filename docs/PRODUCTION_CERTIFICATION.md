# Lead Enrichment Platform — Production Certification

_Issued 2026-07-07 (Sprint 25) · Org **00Dbn00000plgUfEAI** · Assessed at Release **v1.1** · connector: USASpending_

> **Version note (normalized 2026-07-08):** the current certified production baseline is **`lead-enrichment-v1.2`**
> (commit `f4894e9` — see [RELEASE_1.2.md](RELEASE_1.2.md) and [MAINTENANCE.md](MAINTENANCE.md)). The certification
> below was issued at v1.1 (Sprint 25); v1.2 is an additive hardening release (DML bulkification + monitoring layer)
> that does not alter this certification's scope. This document is retained as the Sprint-25 certification record.

## Certification statement
The Lead Enrichment Platform is **CERTIFIED for controlled/manual production enrichment**. It has been validated end-to-end on production data, both acceptance-test defects have been eliminated, the full test suite passes, the audit trail exactly matches committed data, and rollback is verified. The platform is safe, auditable, and reversible.

## Evidence of certification
| Criterion | Status | Evidence |
|---|---|---|
| Live production enrichment works | ✅ | 68 Leads enriched (Sprints 23–25) |
| FillEmptyOnly — no overwrites | ✅ | 0 populated fields overwritten; State preserved |
| Audit matches data | ✅ | 408 Enrich logs = 68 Leads × 6 fields; 68 distinct; 0 orphans |
| Rollback operational | ✅ | Every write has a before-snapshot; `OA_ChangeLogService.rollback` proven |
| Defect #1 (field length) fixed | ✅ | `Awarding_Agencies__c` → Long Text Area(32768); 6 Leads repaired |
| Defect #2 (writer integrity) fixed | ✅ | Writer inspects SaveResults; failure → exception, no misleading audit |
| Regression | ✅ | Deploy `0AfPn0000023BnNKAU`, RunLocalTests **261 tests, 0 failures** |
| Platform dormant by default | ✅ | 0 active policies, 0 enabled connectors, 0 schedules |

## Certified operating modes
| Mode | Certified? |
|---|---|
| Manual enrichment | ✅ **CERTIFIED** |
| 25-Lead controlled runs | ✅ **CERTIFIED** |
| 100-Lead controlled runs | ✅ **CERTIFIED** |
| Daily manual use | ✅ **CERTIFIED** |
| Scheduled enrichment | ⛔ **NOT certified** — requires least-privilege runtime user + visual monitoring/alerts (orchestrator now deployed, Sprint 28) |
| Batch enrichment | 🟡 **Conditionally ready** — orchestrator deployed (Sprint 28, dormant); needs least-privilege runtime user for volume |
| 24×7 automation | ⛔ **NOT certified** — requires least-priv user + monitoring/alerts + scheduler |

## Standard operating procedure (certified path)
1. Verify Org ID = `00Dbn00000plgUfEAI` and no concurrent deployment.
2. Activate the 6 USASpending FillEmptyOnly policies (deploy `Active=true`).
3. Enrich in per-transaction batches of ≤50 Leads, **callout-before-DML** (all fetches first, then `enrich(commit=true)`).
4. Verify change logs / connector run / exceptions; confirm no overwrite.
5. Deactivate policies → return to dormant. Enriched data + audit persist.
Rollback (if needed): `OA_ChangeLogService.rollback([logs WHERE Connector_Run__r.Run_ID__c LIKE '<run>%'])`.

## Conditions & limits
- Runtime user is the temporary MAD `oauser` (documented exception) — replace with a least-privilege user before any automation.
- **Sprint 30:** program CLOSED at ops baseline `lead-enrichment-ops-v1.1`. USASpending in use; **Census + SEC NCs deployed + live-tested (HTTP 200) → credential-READY** (connectors dormant); IRS ready (no callout); **SAM BLOCKED** (data.gov key / EC principal access).
- Baseline KPIs: `KPI_BASELINE.md`. Closure: `LEAD_ENRICHMENT_FINAL_CLOSURE.md`. Daily ops: `DAILY_ENRICHMENT_OPERATING_PROCEDURE.md`.

**Certifying evidence author:** Claude (CLI-verified). **Owner/approver:** Louis (`lronealgorithm@gmail.com`).
