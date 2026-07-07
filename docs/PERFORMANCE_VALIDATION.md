# Performance Validation (Track F) — Sprint 17

_Measured 2026-07-06 · Org 00Dbn00000plgUfEAI · governor probe, no DML, no callouts_

## Method
An anonymous-Apex probe exercised the real, deployed write path per Lead — `OA_SAM_Mapper.toLeadProposals`
→ `OA_EnrichmentWriter.enrich(..., commit=false)` (map + per-field policy + preview) — over **200 synthetic
in-memory Leads**, sampling `Limits` before/after. No records were written; no callouts were made.

## Raw result
```
N=200  cpuMs=2215  perLeadCpuMs=11.08  queries=0  dml=0
heap≈negligible (per-iteration objects GC'd)  cpuLimit(sync)=10,000ms
written=0 conflicts=0   (dormant: write policies inactive, so no WRITE/CONFLICT — expected)
```
- **CPU:** ~11 ms/Lead for map + policy evaluation (includes one-time class/CMDT warm-up; steady-state is
  lower). **SOQL: 0 in-loop** — the policy engine caches CMDT via `getAll`, so it does **not** scale with
  volume. **Heap:** non-issue.

## The binding constraint: callouts
Each Lead makes **1 callout per source**. Apex allows **100 callouts per transaction**. With the
orchestrator's single transient retry (up to 1 extra callout/Lead), the safe ceiling is **~50 Leads per
batch `execute()` chunk** for callout-based sources. This — not CPU, SOQL, or heap — sets the batch size.

| Limit (async batch execute) | Cap | Cost/Lead | Practical Leads/chunk |
|---|---|---|---|
| Callouts | 100 | 1 (+1 retry) | **~50** (callout sources) |
| CPU | 60,000 ms | ~11 ms | ~5,000 (not binding) |
| DML rows | 10,000 | ~2–5 (update + logs + exceptions) | ~2,000 (not binding) |
| SOQL | 200 | ~0 (CMDT cached) | not binding |
| Heap | 12 MB | tiny | not binding |

## Throughput estimates (live, callout sources — SAM/USASpending/Census/SEC)
Callout latency (~0.3–1 s each, sequential within a chunk) dominates wall-clock, not Apex compute.

| Volume | Chunks @ 50 | Est. wall-clock | Notes |
|---|---|---|---|
| **100 Leads** | 2 | **< 1 min** | trivial; single job |
| **1,000 Leads** | 20 | **~5–15 min** | callout-latency bound |
| **10,000 Leads** | 200 | **~1–3 hrs** | one Batch job; well within platform job limits; run off-peak |

**IRS (bulk CSV, no callout):** not callout-bound — a single parse handles thousands of rows; batch size can
be **200** and volume is limited by CPU/DML only.

## Recommended production batch sizes
| Source | Batch size | Rationale |
|---|---|---|
| SAM, USASpending, Census, SEC | **50** | 100-callout limit with 1 retry headroom |
| IRS | **200** | no callout; CPU/DML bound |
| Default (`OA_EnrichmentOrchestrator.DEFAULT_BATCH_SIZE`) | **20** | conservative for first live runs |

Start live runs at **20**, watch telemetry (`OA_Connector_Run__c` duration/errors), then raise to 50 (callout)
/ 200 (IRS). Keep scheduled concurrency low so daily API allocation isn't exhausted by a single backfill.

## Caveats
- Numbers are the compute/limit profile; **real callouts were not executed** (credentials/endpoints pending —
  see `CREDENTIAL_STATUS.md`). Re-measure end-to-end latency during the first controlled live pilot.
- Warm-up inflates the per-Lead CPU average at small N; at production volume the amortized cost is lower.
