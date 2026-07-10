# Session State — Program 025G-A (Lead Enrichment Write-Back Certification)

**Date:** 2026-07-10 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-enrichment-certification` (off main `a4efe0c`).
**Outcome:** certification **NOT completed tonight** — a defect was found first. No proposals approved, no Lead writes. Resume from this note.

## What happened
- **PR #93 merged** → **main = `a4efe0c`**. `OA_EnrichmentOrchestrator` + `_Test` now match production (parity restored; the 025F UEI-fallback repair is in main).
- **Decision (Louis): certify Path A only.** Path B's ungated direct-commit is **not** to be used for committed writes → **tech debt** (candidate for disable/removal).
- **Permsets assigned to `oauser` (carry over — intentional):** `OA_Connector_Staging`, `OA_Lead_Writeback_Automation` (plus pre-existing `OA_Lead_Writeback_Reviewer`). → **Add both to the `OA_Runtime_Operations` PSG evaluation** for the future Integration user.
- **Duplicate rule probe (3a): NO BLOCK.** Savepoint-rollback update of a `USASpending_*` field on Zolon's Lead succeeded (no duplicate/validation error), then rolled back (Lead modstamp unchanged). `OA_Partner_Duplicate_Rule` matches on partner/name fields, not the write-back fields; **no `DuplicateRuleHeader` needed.**
- **Path A `enrich(persist=true)` on the 4-lead cohort:** created **5 Pending `OA_USASpending_Staging__c` rows for Zolon Tech** (award-level: $97.4M/$73.2M/$33.1M/$20.4M/$17.0M); **0 rows for @Orchard, 1 Source, 1 Sync.** Zero Lead writes.

## The two architectures (key finding)
| | Path A — `OA_USASpendingEnrichmentService` → `OA_USASpendingMapper` → staging → `OA_LeadWritebackService` | Path B — `OA_USASpending_Connector` → orchestrator → `OA_EnrichmentWriter` (025F) |
|---|---|---|
| Persists proposals | **Yes** (`OA_USASpending_Staging__c`, `Review_Status='Pending'`) | No (in-memory; commit writes Lead directly) |
| Review gate | **Yes** (`Approved`-only, deterministic `Lead__c`, required fields, before-snapshot, idempotent, FLS) | **No** (ungated) → tech debt |
| Fields | 16 `USASpending_*` / `UEI_Verification_*` | 7 (`UEI__c`, `Federal_Contractor__c`, `Total_Award_Amount__c`, …) |
| Cohort match tonight | **1 / 4** (Zolon only) | **4 / 4** |

## Two defects to fix FIRST (why cert was stopped)
`OA_USASpendingMapper.toStaging` produces staging rows that FAIL `OA_LeadWritebackService` eligibility:
1. **`Recipient_UEI__c` left blank** → writeback `DATA` gate fails (required non-blank: `Recipient_UEI__c`, `Award_ID__c`, `Award_Amount__c`, `Awarding_Agency__c`, `Enrichment_Run_ID__c`).
2. **`Lead__c` not linked** when enriching by name → writeback `MATCH` gate fails ("Missing deterministic `Lead__c`").

Hand-stamping these on the staging row would certify a *manually-repaired* record, not the production lifecycle — so we fix the mapper, then certify.

## Also to investigate
- **Path A search matched only 1/4 vs Path B 4/4.** `OA_USASpendingEnrichmentService`/its request builder uses a narrower USASpending search than Path B's `spending_by_award` (`recipient_search_text`). Reconcile the search method so Path A matches what Path B finds.

## Left in place (do not disturb)
- **5 Pending Zolon staging rows** (`CreatedDate = 2026-07-10`, `Review_Status='Pending'`, `Lead__c=null`, `Recipient_UEI__c` blank) — awaiting a **post-fix rerun**. Rollback if needed: `DELETE [SELECT Id FROM OA_USASpending_Staging__c WHERE CreatedDate=TODAY]` (they are session pilot artifacts).
- Cohort Lead Ids: Zolon `00QPn000011DshSMAS` (UEI `XVE2FA8DRTL7`), @Orchard `00QPn000011Dv2xMAC`, 1 Source `00QPn000011Dxb0MAC`, 1 Sync `00QPn000011DzGxMAK` — all have Email (satisfy VR `Require_Email_Or_Contact_Person_Email`).

## Final session state (verified)
0 connectors enabled · 0 scheduled enrichment/procurement jobs · Opportunities = 1 · **0 Lead writes** (all 4 cohort SystemModstamps unchanged at their 2026-07-07 values) · 0 staging rows Approved/linked/written · permsets in place · working tree clean.

## Tomorrow (do NOT start tonight)
Fix `OA_USASpendingMapper` to populate `Recipient_UEI__c` and link `Lead__c` when the caller supplies a Lead context → add tests → check-only validate → deploy → rerun Path A on the cohort → fresh checkpoint table of *legitimately eligible* rows for Louis's approval. Investigate the Path A search-method gap.
