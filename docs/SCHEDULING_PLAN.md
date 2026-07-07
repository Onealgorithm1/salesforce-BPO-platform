# Enrichment Scheduling Plan (Track C) — Sprint 17

_Recommendations only · **no schedule is activated** · Org 00Dbn00000plgUfEAI_

The execution layer (`OA_EnrichmentOrchestrator` batch + `OA_EnrichmentQueueable`) is built but **nothing
schedules itself**. This plan defines *how* schedules would be configured when Louis authorizes go-live.
Confirmed live: **0 enrichment scheduled jobs** exist (the 8 existing `OA_*` cron jobs are campaign
automation, unrelated).

## Recommended cadences
| Cadence | Purpose | Scope (SOQL) | Batch size | Commit | Trigger |
|---|---|---|---|---|---|
| **Manual / on-demand** | canary, ad-hoc re-enrich of specific Leads | explicit Ids | n/a | opt-in | `OA_EnrichmentQueueable` via a button/Flow/anon-Apex |
| **Hourly (incremental)** | enrich newly-created/edited Leads | `WHERE UEI__c = null AND Company != null AND CreatedDate = LAST_N_HOURS:2` | 50 | true | scheduled `OA_EnrichmentOrchestrator` |
| **Nightly (sweep)** | catch anything missed; low-priority sources | missing-field scope, `LIMIT` bounded | 50 (200 IRS) | true | scheduled, off-peak (e.g. 02:00 ET) |
| **Backfill (one-off)** | initial enrichment of the existing book | broad missing-field scope | 50 → raise after watching | true | manual `Database.executeBatch`, run in waves |

## Metadata-driven design (recommended, not built)
To keep schedules configurable without code, add (in a future ops sprint) a lightweight CMDT
`OA_Enrichment_Schedule__mdt` read by a single `Schedulable` dispatcher:

| Field | Example | Meaning |
|---|---|---|
| `Source__c` | `SAM` | connector source key |
| `Cron__c` | `0 0 * * * ?` | schedule expression |
| `Scope_SOQL__c` | `SELECT ... FROM Lead WHERE ...` | target scope |
| `Batch_Size__c` | `50` | chunk size |
| `Commit__c` | `false` | dry-run vs write |
| `Ruleset__c` | `Federal EDWOSB` | ICP qualification |
| `Active__c` | `false` | **default off** — activation is a deliberate act |

A `Schedulable` class would read active rows and call `OA_EnrichmentOrchestrator.enqueueBatch(...)` per row.
This keeps cadence, scope, and safety flags in config, not code — consistent with the platform's
metadata-driven design. **Deferred**: only build once live callouts are enabled and a controlled pilot passes.

## Activation guardrails (when authorized)
1. Enable connectors and credentials first (`CREDENTIAL_STATUS.md`), then run a **manual** canary, then a
   25-Lead pilot, then a 100-Lead pilot — before any recurring schedule.
2. First schedule should run **`Commit__c = false` (preview)** for one cycle; review telemetry; then flip to
   commit.
3. Start hourly scope small (`LAST_N_HOURS:2`, bounded `LIMIT`); widen only after clean runs.
4. Keep an emergency stop ready (`OPERATIONS_GUIDE.md` → Emergency Stop): abort the job + deactivate policies.

**Nothing here is scheduled.** Activation requires Louis's explicit go-ahead and a passing pilot.
