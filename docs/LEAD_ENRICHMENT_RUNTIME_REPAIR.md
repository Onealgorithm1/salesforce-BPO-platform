# Lead Enrichment Runtime Repair — Program 025F

Org `00Dbn00000plgUfEAI` · main baseline `bffa36b` · repair branch `feature/lead-enrichment-runtime-repair`.

## Root cause (independently verified — the 025E diagnosis was wrong)
Program 025E concluded "Lead enrichment produces zero proposals; needs connector rewiring." **That was incorrect.** Live tracing proved:

1. **The connector works.** `new OA_USASpending_Connector().fetch('Zolon Tech', cfg)` and `fetch('XVE2FA8DRTL7', cfg)` both return **HTTP 200 with a canonical org**, and `OA_ProposalAdapter.toLeadProposals('USASpending', org)` returns **7 HIGH-confidence proposals** (UEI, Federal_Contractor, Total_Award_Amount, Award_Count, Awarding_Agencies, Latest_Award_Date, State).
2. **The "0 proposals" was a measurement error.** `OA_EnrichmentOrchestrator.Metrics.recordsEnriched` counts **writes**, not proposals — and in preview mode writes are 0 by design. The 025E pilots measured `recordsEnriched` and concluded (wrongly) that no proposals existed.
3. **The connector was disabled** (`OA_Connector_Registry__mdt.USASpending.Enabled__c=false`, dormant-by-design) in the early pilots, so the runner skipped it entirely.

**Conclusion:** no connector rewiring, no adapter, no third USASpending generation. The existing pipeline (`OA_EnrichmentOrchestrator → OA_ConnectorRunner → OA_USASpending_Connector → OA_USASpending_ResponseParser → OA_ProposalAdapter → OA_USASpending_Mapper → OA_EnrichmentWriter`) already produces useful, source-backed, reviewer-gated proposals.

## Architecture (unchanged, reused)
```
Lead → deriveInput (UEI/name) → ConnectorRunner (registry) → OA_USASpending_Connector.fetch
     → USASpending spending_by_award POST → ResponseParser → OA_CanonicalOrg
     → OA_ProposalAdapter.toLeadProposals → OA_USASpending_Mapper → FieldProposal[]
     → OA_EnrichmentWriter (preview = no DML; commit = FLS + audit, Approved-only) → OA_Enrichment_Change_Log__c
```

## The one real defect fixed — field mapping
`deriveInput` read only `Lead.UEI__c` (**79** leads populated — because `UEI__c` is *populated by enrichment*), while the bulk imported UEI lives in `UEI_Unique_entity_Identifier__c` (**13,278** leads). Company-name fallback still matched, but UEI is more precise.

**Minimal fix (this repair):** `deriveInput` now falls back through populated identifier fields, and the default scope query selects them:
```
UEI__c → UEI_Unique_entity_Identifier__c → USASpending_UEI__c → Company name
```
No new fields, no new objects, no bulk data mutation. `safeGet` tolerates a field not being queried. Test-visible `deriveInput` + `UEI_FIELDS`.

## Registry (unchanged approved state)
All connectors remain `Enabled__c=false` (dormant). The USASpending connector was temporarily enabled for the pilot (`0AfPn0000023yxlKAA`) and **reverted to dormant** (`0AfPn0000023z5pKAA`). Manual enrichment operations enable it per-session (kill-switch: set `false`).

## Tests
`OA_EnrichmentOrchestrator_Test.derive_input_uei_fallback_order` — asserts the full fallback order (primary → imported → USASpending → company → null). Existing tests (preview zero-DML, commit path, adapter resolves every source, blank-input-skipped, telemetry) preserved. **Check-only `0AfPn0000023yuXKAQ`** (2/2, 9 tests, `OA_EnrichmentOrchestrator` 97%). Deploy `0AfPn0000023yw9KAA`. Full suite `707Pn00003GSgFrIAL`: **0 failures**.

## Pilot (preview, reviewer-gated, zero writes)
- **Smoke (2 leads):** both HTTP 200; Zolon Tech → 7 proposals; We-Design → 0 (USASpending authoritatively no-match).
- **Value pilot (10 leads):** **10/10 HTTP 200, 6 matched, 4 legitimate no-match, 42 total proposals** (7 fields each, all HIGH confidence). Example (Zolon Tech): Federal_Contractor=true, Total_Award_Amount=$328.4M, Award_Count=68, 15 awarding agencies, latest award 2025-12-29, State=VA.
- **Zero unapproved writes:** `processScope(...,commitWrites=false)` → written=0; all 10 Lead SystemModstamps identical pre/post.

## Governance (intact)
Lifecycle preserved: Lead → connector result → proposal → review queue → **human approval** → controlled write-back (Approved-only, FLS-enforced, allowlisted) → audit log. No connector writes to Lead. No proposal auto-approved. Preview makes no DML.

## Risks / debt
- Manual enrichment requires temporarily enabling the connector (documented; reversible) — acceptable until a runtime user + scheduling exist.
- Duplicate connector *generations* remain (legacy vs enrichment framework) — a future cleanup, not needed for operation.
- No "proposals generated" metric on `Metrics` (only writes) — an observability nicety, deferred.

## Rollback
Revert this branch's commit + redeploy `OA_EnrichmentOrchestrator` (main version); connector already dormant; no Lead data changed.
