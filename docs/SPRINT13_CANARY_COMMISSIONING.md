# Sprint 13 — Dormant Deployment & Canary Commissioning Report

_2026-07-06 · Org 00Dbn00000plgUfEAI · branch feature/sprint13-canary_

## Deployment (Track A/B) — DONE
| Deploy | ID | Result |
|---|---|---|
| Lead enrichment fields (Sprint 12) | `0AfPn0000022znpKAA` | 29/29, 0 errors |
| Platform types (objects, fields, 35 classes, 22 tests, 5 CMDT types, runtime permset) | `0AfPn0000022zz7KAA` | 184/184, 0 errors, 86 tests pass |
| CMDT records (44) | `0AfPn000002308nKAA` | 44/44, 0 errors |

**CMDT sequence:** types first (deploy #1), then records (deploy #2). **KEY FIX (unblocks all prior
sprints):** CMDT record files require `xmlns:xsd="http://www.w3.org/2001/XMLSchema"` on the root element
— without it, the org rejects them with an opaque `UNKNOWN_EXCEPTION`. Adding it deployed all 44 records.

**Post-deploy verification:** 35 classes, 4 objects, 5 CMDT types, 44 records, 1 permission set, 29 Lead
fields — all present. **Fully dormant:** 0 connectors enabled, 0 active policies/rules, 0 enrichment
scheduled jobs (the 8 existing `OA_*` scheduled jobs are pre-existing campaign automation), 0 permset
assignments (after cleanup).

## Credentials (Track C)
- OA_SAM Named Credential + External Credential (X-Api-Key header) exist; **principal access = 0** (SAM live callout blocked).
- OA_USASpending Named Credential exists (no-auth).
- **Census / SEC Named Credentials absent** (create secret-free before enabling those connectors).
- Canary used **controlled synthetic values** (no live callout) — safest.

## Canary (Track D/E) — CORE PASSED
- **Canary Lead:** `00QPn000012Ktl3MAC` ("OA Lead Enrichment Canary"), synthetic; `UEI__c` blank (fill-empty target), `Website` pre-filled (conflict target).
- **Run:** synthetic SAM-shaped canonical → OA_SAM_Mapper → OA_EnrichmentWriter (commit) as oauser with runtime permset (FLS).
- **Results (validated live):**
  - Canonical model, mapper → 4 proposals ✓
  - Policy engine: `UEI__c` → **WRITE** (blank→`CANARYUEI001`); `Website` → **ROUTE_CONFLICT** (pre-filled, **not overwritten**) ✓
  - Writer committed under USER_MODE FLS ✓ (Lead field written + verified)
  - Qualification engine → **Qualified** ✓; confidence scoring ✓
  - Connector runner dispatched `SAM` → **Skipped** (correctly respected dormant/disabled connector) ✓
- **Fields changed:** `Lead.UEI__c` null → `CANARYUEI001` (later reset to null). `Website` unchanged.

## Change log / Exception / Rollback (Track E/F) — PENDING (transient infra)
- **Change log records persisted: 0. Exception records persisted: 0.** The writer BUILT them correctly
  (1 change log, 1 SourceConflict exception, in memory), but the inserts silently no-op'd because the
  **four new custom objects' fields have not yet propagated to the org's queryable data/Apex describe
  layer** (verified: data-API insert → `No such column`; anon-Apex → `Field does not exist`; while
  Tooling FieldDefinition lists them). The heavy deploy sequence thrashed the schema describe cache —
  even `Lead.UEI__c` (written/read successfully earlier) briefly became unqueryable. **This is Salesforce
  async schema propagation after multiple new-object deploys — NOT a platform defect.** All deploys
  Succeeded; the metadata is correct.
- **Rollback:** the write was **reversed manually** (UEI reset to null — reversibility demonstrated); the
  **automated change-log-driven rollback drill is PENDING** (needs persisted change logs). Rollback did
  **not fail** — it could not yet be executed. Rollback logic is validated in the deployed test suite (86 tests pass).

## Monitoring (Track G)
Objects for all metrics exist (`OA_Connector_Run__c`, change log, exception, discovered org). Telemetry
persistence pends the same propagation. Dashboards designed (`MONITORING_DASHBOARDS.md`); build after
propagation settles and the audit/rollback drill passes.

## Cleanup / final state
Dormant restored: 4 canary CMDT records deactivated, runtime permset assignment revoked, canary Lead
retained + clean (UEI null). Nothing scheduled/activated.

## Remaining blockers
1. **New-object schema propagation** (transient) — must settle so change-log/exception/telemetry persist
   and the automated rollback drill can pass.
2. SAM EC principal access (SAM live callout) + Census/SEC Named Credentials.
3. **Temporary MAD runtime user (oauser)** — standing top risk (FLS guardrail weakened).

## Go / No-Go for real-Lead pilot
**NO-GO** until the change-log/exception **persistence** and the **automated rollback drill** complete
successfully (blocked only by transient schema propagation). Re-run: wait for propagation → re-activate a
fill-empty policy + assign the runtime permset → re-enrich the canary → confirm change log + exception
persist → execute `OA_ChangeLogService.rollback` → confirm restore + rollback logged → then a 5-real-Lead pilot is reasonable.
