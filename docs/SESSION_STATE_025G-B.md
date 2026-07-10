# Session State — Program 025G-B (Path A mapper repair + rerun)

**Date:** 2026-07-10 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-enrichment-certification` (off main `a4efe0c`).
**Outcome:** the two 025G-A defects are **fixed and deployed to production**; Path A rerun produced **15 legitimately-eligible Pending staging rows** across **3 of 4** cohort leads. **Still no proposals Approved, no Lead writes.** Certification (write-back) awaits Louis's explicit approved numbers.

## What was fixed (deployed — production changed: YES, source only)
`OA_USASpendingMapper` produced rows that failed `OA_LeadWritebackService` eligibility. Root causes + fixes:
1. **Blank `Recipient_UEI__c` (DATA gate).** `OA_USASpendingRequest` requested the UEI column as snake_case `recipient_uei` and `OA_USASpendingParser` read the same key. The live `spending_by_award` API echoes requested **display-field** names verbatim — the UEI column is **`Recipient UEI`** (title case). The snake_case name returned no column → blank UEI. Path B already used `Recipient UEI` (that's why it matched). **Fix:** request field + parser key → `Recipient UEI`. The connector test's mock had encoded the same wrong key (green test hid the live bug) — mock corrected + regression guards added.
2. **`Lead__c` not linked (MATCH gate).** `OA_USASpendingEnrichmentService.enrich` took no Lead context. **Fix:** added a 4-arg `enrich(name, limit, persist, leadId)` overload (3-arg preserved) that threads `leadId` via `ctx.config`; mapper stamps `s.Lead__c`. Staging-only — no Lead DML.

**Commit:** `9a8a687` (6 files). **Check-only + deploy:** both `Succeeded`, 19 tests / 0 failures. Deploy id `0AfPn00000243MLKAY`.

## Search-gap investigation (025G-A open item) — RESOLVED
- **Both paths use identical USASpending search filters** (`spending_by_award` + `recipient_search_text` + `award_type_codes` A–D). `OA_ConnectorRunner` passes the caller's input straight through (no normalization at request time). **There is no code-level "narrower search" in Path A** — the 025G-A note's hypothesis is not supported by the code.
- The 1/4-vs-4/4 gap was **search-term/pre-fix specific**, not structural. After the fix, previews returned 5 awards for all 4 companies (raw *and* normalized name).
- **BUT the true cohort match is 3/4, not 4/4.** Inspecting the actual returned recipients: `@Orchard LLC`'s fuzzy `Orchard` search returns only **unrelated** recipients (ALTAFRESH LLC, MISSION SYSTEMS ORCHARD PARK, KINGSBURG ORCHARDS…) — **no verifiable `@Orchard` federal contractor.** Path B's "4/4" was almost certainly a fuzzy false positive. `@Orchard` was **excluded** (not persisted) — the review gate working as intended.

## Operational note (not a defect)
`enrich(persist=true)` does callout→DML, so **only one recipient can be persisted per Apex transaction** ("uncommitted work pending" on a 2nd callout). The rerun persisted one company per anonymous-Apex execution. If a future batch UI is built, queue one callout+persist per transaction (or split callout/DML phases).

## Legitimately-eligible rows now staged (Pending — awaiting Louis) — the approval table
All `Review_Status__c='Pending'`, `Lead__c` linked, `Recipient_UEI__c` populated; 5 award rows each (top-5 by amount).

| Lead (Company) | Lead Id | UEI | Run Id | Awards | Top award |
|---|---|---|---|---|---|
| Zolon Tech INC. | `00QPn000011DshSMAS` | XVE2FA8DRTL7 | `USASP-Zolon Tech` | 5 | $97.44M (Dept of State, SAQMMA12C0014) |
| 1 Source Consulting, INC. | `00QPn000011Dxb0MAC` | EXEYN7TNGWH7 | `USASP-1 Source Consulting` | 5 | $78.50M (Treasury, TPDTTB13K0013) |
| 1 Sync Technologies, LLC | `00QPn000011DzGxMAK` | SHKSNU48JHZ7 | `USASP-1 Sync Technologies` | 5 | $3.90M (DoD, FA330022C0055) |
| @Orchard LLC | `00QPn000011Dv2xMAC` | — | — | 0 | **No verifiable match — excluded** |

Zolon's 5 rows were **refreshed in place** (same dedupe key) — now carry UEI + Lead link (previously blank/null). 1 Source + 1 Sync are new. Total **15 Pending rows.**

## Verified final state
0 connectors enabled (all 6 `Enabled__c=false`) · 0 enrichment/procurement scheduled jobs · **0 Lead writes** (all 4 cohort SystemModstamps unchanged at 2026-06-26/2026-07-07) · only Approved staging row is the pre-existing `2026-07-04 PREVIEW_TEST` · working tree clean after commit.

## Tech debt / follow-ups (not started)
- **`OA_LeadWritebackService` aborts on >1 Approved row for the same Lead (NEW — found 025G-B).** Commit builds one `buildLeadUpdate` per staging row; `leadsToWrite` (line 306-313) ends up with N Lead sObjects sharing one Id, and `Database.update(leadsToWrite, false)` throws an **uncaught** `System.ListException: Duplicate id in list` (verified: thrown pre-DML even with allOrNone=false), rolling back the whole run — no fields change, not last-write-wins, not aggregation. **Operational guardrail until fixed: approve at most ONE staging row per Lead per writeBack batch.** Upgrade path: dedupe `leadUpdates` to one row per Lead (pick highest award / most recent) before DML, or process per-Lead.
- **Legacy `OA_USASpendingClient`** — same snake_case `recipient_uei` latent bug, but **dead code** (referenced only by its own test, superseded by the SDK parser/request). Per Louis (025G-B): **leave untouched**; tracked here beside Path B's ungated commit.
- **Path B ungated commit** (`OA_EnrichmentWriter commitWrites=true`) — still tech debt (025G-A decision: Path A only).

## Cohort certification — DONE (Louis-approved, 2026-07-10)
**3 of 4 Leads certified & written** (one best row each, same lifecycle). See **`CERT_MATRIX_025G-B.md`** (12 PASS · 3 WARN/NOTE · 0 FAIL; full suite 365/365).
| Lead | Award | UEI | $ / Agency | Modstamp |
|---|---|---|---|---|
| Zolon Tech `00QPn000011DshSMAS` | `SAQMMA12C0014` | XVE2FA8DRTL7 | $97.44M / State (+ rollback→reapply proof) | 13:19:59Z |
| 1 Source `00QPn000011Dxb0MAC` | `TPDTTB13K0013` | EXEYN7TNGWH7 | $78.50M / Treasury | 13:38:22Z |
| 1 Sync `00QPn000011DzGxMAK` | `FA330022C0055` | SHKSNU48JHZ7 | $3.90M / Air Force | 13:39:24Z |
| @Orchard `00QPn000011Dv2xMAC` | — | — | excluded (no verifiable match) | unchanged 07-07 |
- Per Lead: 15 fields written, snapshot-first, isolation (only that Lead's modstamp moved), zero side effects, tripwires 0. Negative controls (Pending/Rejected blocked, idempotent skip) + rollback→reapply proven once on Zolon.
- **Staging landscape:** 3 Written Back · 12 Pending (4 untouched sibling rows per certified Lead). @Orchard has 0 rows.
- **Corrected test class deployed** (MIXED_DML fix; deploy `0AfPn00000243qzKAA`; interactive suite 11/11). Org suite green.

## Config decision (Louis: accept snapshot audit trail — NO change)
Field-history tracking on the 16 write-back fields stays **off** → 0 `LeadHistory` rows. Audit relies on staging `Before_Snapshot__c` + Lead `USASpending_Source_Run_ID__c`/`UEI_Verified_By/Date`. No tracking config changed.

## Next session (RED — deferred by Louis)
1. **Duplicate-Id abort fix (WARN #12)** — dedupe `leadUpdates` per Lead (or process per-Lead) + regression test, **before any multi-lead or scheduled write-back**. Approved as next session's task. *(In progress on branch `feature/writeback-dedupe-leadupdates`: winner = highest `Award_Amount__c` per Lead, tie-broken caller-first; extras → `SKIPPED/DEDUPE`, left Approved.)*
   - **Note:** deferred same-Lead rows are left `Approved` but are **not guaranteed to write later** — because a Lead's rows usually share one `Enrichment_Run_ID__c`, once the winner writes, the others hit the existing **idempotency skip** (source run already applied to the Lead) on any later run. To actually write a different award for that Lead, it must carry a different `Enrichment_Run_ID__c`.
