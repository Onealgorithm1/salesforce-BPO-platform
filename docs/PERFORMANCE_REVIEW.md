# Lead Enrichment Platform — Performance Review

_Status: **review + measurable recommendations** · 2026-07-06. Based on the current dormant code
(6 connectors + platform). Recommendations are made only where there is a measurable governor risk._

## Findings by dimension

| Dimension | Current behavior | Assessment | Recommendation (only where measurable) |
|---|---|---|---|
| **Callouts** | One `Http().send()` per connector `fetch(input)`; SEC/USASpending/Census/SAM are 1 callout/input; IRS makes none (bulk parse) | Safe per-transaction (limit 100 callouts/txn) | For multi-input enrichment, cap inputs/transaction < 100; move bulk enrichment to **Queueable chunks** (≤ N callouts each) — deferred (no async built this sprint) |
| **SOQL** | Engines query CMDT (cached, no SOQL limit) via `@TestVisible` overrides in tests; runtime CMDT reads don't count against SOQL; `OA_DiscoveryQualificationEngine` does 1–2 Lead/Account SOQL per org | Low | **Bulkify discovery match** if run over many orgs: batch the Lead/Account lookups (one SOQL with `IN`), not per-org, before enabling high-volume discovery |
| **DML** | Writer updates the target Lead in USER_MODE; change-log/exception inserts are system-mode; all `allOrNone=false` | Safe, partial-success | For batches, collect writes and DML **once per chunk** (the writer already accepts one record — a batch wrapper should group) |
| **Heap** | Connectors hold one response body + parsed rows in memory; USASpending aggregates in maps; raw payload OFF by default | Low for single-input | Keep `debugStoreRawPayload=false` in production (raw bodies inflate heap); for large USASpending result sets, cap `limit` (already 100) |
| **CPU** | JSON parse + string ops per record; `OA_NameNormalizer` regex per name | Low | No action; regex is bounded. If normalizing thousands/txn, precompute normalized names in a batch pass |
| **Governor headroom** | Single-input runs use a tiny fraction of limits | Ample | — |
| **Bulk readiness** | Framework is single-input today; the runner processes one input per call | **Gap for scale, by design** | Add a **Queueable/Batch orchestrator** that chunks inputs and calls the runner per chunk (respecting callout/DML limits). This is the ONE performance item required before high-volume operation — additive, not a platform change |

## Bulk-readiness plan (design; not built — no async this sprint)
1. A `Queueable` that takes a list of inputs, chunks to ≤ 90 callouts/txn, calls `OA_ConnectorRunner`
   per input, and re-enqueues the remainder.
2. Persist `OA_Connector_Run__c` per chunk; aggregate telemetry.
3. Client-side rate governor (reuse the `OA_SendGovernor` pattern) per connector
   (`Rate_Limit_Per_Min__c`).
4. Idempotent throughout (upsert on canonical key) — safe to retry a chunk.

## Verdict
No governor problems in the current per-input design. The **only** measurable optimization needed for
production **scale** is an async bulk orchestrator (Queueable/Batch) — an additive component that uses
the frozen platform unchanged. Everything else is within limits.
