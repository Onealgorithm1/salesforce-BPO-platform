# Automated Write Path Fix — Orchestrator Callout-Before-DML

_2026-07-07 · Org 00Dbn00000plgUfEAI · scope: ONLY `OA_EnrichmentOrchestrator.processScope` · platform DORMANT after · **defect FIXED + verified**_

## Defect
`OA_EnrichmentOrchestrator.processScope` interleaved, per Lead: `runner.fetch (callout) → OA_EnrichmentWriter.enrich (commit → DML)`. After the first Lead's write, the next Lead's callout threw *"You have uncommitted work pending"*; the connector caught it as an HTTP error, so in **commit mode only the FIRST Lead per invocation was written** while the rest silently failed (AsyncApexJob still "Completed"). Preview mode (no DML) was unaffected.

## Fix (two-phase: all callouts, then all writes)
Restructured `processScope` into:
- **Phase 1 — all callouts:** fetch every Lead's connector result and store `(Lead, RunOutcome)` in memory. No Lead DML. (`m.leadsProcessed`, `httpErrors`, `qualified`, `aborted` accumulate here; stop-fetch on a `Failed` status.)
- **Phase 2 — all writes:** after every callout is done, loop the stored results → `OA_ProposalAdapter` → `OA_EnrichmentWriter.enrich(commit)`; accumulate `recordsEnriched`, `conflicts`, `exceptions`; add per-Lead telemetry.

Mirrors the proven manual pattern (all fetches first, then `enrich(commit=true)`). **No connector, writer, adapter, policy, or preview-mode changes.**

## Tests added (`OA_EnrichmentOrchestrator_Test`)
- `multi_lead_commit_no_callout_after_dml` — REAL runner + mocked USASpending callout + active fill-empty policy, **commit over 3 Leads → all 3 written, httpErrors=0** (fails on the old interleaved code, passes on the fix).
- `multi_lead_preview_writes_nothing` — same setup, preview → 0 writes.

## Validation & deploy
- Check-only: **Succeeded** (8 `OA_EnrichmentOrchestrator_Test` methods, 0 errors).
- Production deploy (RunLocalTests): **Succeeded — 270 tests, 0 errors, 2 components.**

## Controlled automation re-test (the exact Sprint-34 failing case)
Enabled USASpending + activated 6 fill-empty policies, ran `OA_EnrichmentQueueable(5 Leads, 'USASPENDING', null, true)`:
| Metric | Sprint 34 (before) | Sprint 35 (after) |
|---|---|---|
| Leads enriched | **1 / 5** | **5 / 5** |
| Records_Enriched | 6 | **30** (5 × 6) |
| HTTP_Errors | 4 | **0** |
- State values preserved; no overwrites.
- **Rollback:** 30 logs → 5 records restored → 0 fields remain (fixed rollback works with the fixed orchestrator).
- Note: run Status = `PartialErrors` is **correct** — one company ("Zentech") matched multiple federal recipients, so the fill-empty policy routed the 2nd recipient's differing UEI to a **SourceConflict exception (no overwrite)**. Ambiguous multi-recipient matches are surfaced for review, not silently overwritten.
- Cleaned all test data (leads rolled back, change logs/telemetry/test exceptions deleted) → dormant baseline (78 enriched, 474 logs, 1 exception, 0 active policies/connectors/jobs).

## Result
- **Orchestrator write defect fixed?** — **Yes** (deployed, tested).
- **Multi-Lead automated write?** — **Yes** — 5/5 (was 1/5).
- **Rollback of automated writes?** — **Yes** — all restored.
- **Scheduled WRITE automation technically ready?** — **Yes** (orchestrator now safe). Still gated operationally by: **least-privilege runtime user (license)** + **monitoring dashboards/alerts (UI)** before *unattended* scheduling.
- **Engineering work still open?** — **None** for Lead Enrichment.

## Remaining (non-engineering) before unattended scheduled writes
1. Least-privilege runtime user (replace MAD `oauser`) — Salesforce license.
2. Monitoring dashboards + alerts — Salesforce UI (`DASHBOARD_UI_EXECUTION_CHECKLIST.md`).
3. First scheduled cycles should run **preview then commit**, small scope, with the CLI monitoring after each run.
