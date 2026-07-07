# Live Pilot Plan — First Controlled Production Enrichment (25 Leads)

_Sprint 18 · Org **00Dbn00000plgUfEAI** · **DESIGN ONLY — do not execute** · every RED step needs Louis's explicit approval_

This plan designs the first controlled production enrichment against **real Leads**. Nothing here is executed.
It builds on the proven Sprint-16 canary + 5-Lead pilot (all rolled back clean) and scales that to 25 Leads,
one connector, preview-first, with a rehearsed rollback and an emergency stop.

## 0. Pre-conditions (all must be true before scheduling the pilot)
- [x] Execution layer built + validated (`OA_EnrichmentOrchestrator` / `OA_EnrichmentQueueable`, validate `0AfPn0000023185KAA`, 6/6 tests).
- [x] Runtime FLS permset `OA_Lead_Enrichment_Runtime` assigned to runtime user (live-verified: 1 assignment).
- [x] Rollback proven (`OA_ChangeLogService.rollback`, Sprint-16, 5/5 restored) with retained audit.
- [ ] **Chosen connector is READY** — pilot uses **USASpending** (public API, no secret, endpoint set). No SAM in the first pilot.
- [ ] A **fill-empty** write policy for the chosen source is staged (activation is a RED go-live step).
- [ ] Owner (Louis) available during the run to approve the commit step and monitor.

> **Runtime-user caveat:** the pilot runs as `oauser` (admin/MAD) — the temporary runtime-user exception and the
> single highest standing risk. MAD weakens FLS enforcement, so the pilot stays conservative: fill-empty only,
> full snapshots, small scope, one connector. (See `RUNTIME_USER_EXCEPTION.md` and the risk register.)

## 1. Lead selection criteria (exactly 25)
Deterministic, low-risk, representative scope — no high-value or actively-worked Leads:
- `UEI__c = null` (nothing to overwrite on the strongest identifier) **AND** `Company != null` (connector needs an input).
- **Exclude** converted Leads, Leads in an active campaign send window, and any Lead edited in the last 24h.
- Prefer Leads already in an enrichment-eligible segment (e.g. `Outreach_Segment__c` in the EDWOSB/Teaming cohort).
- Cap: `ORDER BY CreatedDate DESC LIMIT 25`. Capture the 25 Ids to a pinned list **before** the run (reproducible scope + rollback set).
- **Selection SOQL (illustrative):**
  `SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead WHERE UEI__c = null AND Company != null AND IsConverted = false ORDER BY CreatedDate DESC LIMIT 25`

## 2. Expected writes
- **Preview pass (commitWrites=false):** **0 Lead writes.** Only telemetry (`OA_Connector_Run__c`) is inserted.
  Review the previewed field proposals + conflicts before committing.
- **Commit pass (commitWrites=true):** only **fill-empty** fields the policy allows, per matched org. Typical
  USASpending fields: award/recipient-derived attributes onto empty Lead fields. Every write produces:
  - an `OA_Enrichment_Change_Log__c` row with a **`Before_Snapshot__c`** (rollback source of truth), and
  - a summary `OA_Connector_Run__c` row (`Records_Enriched__c`, `Exceptions_Raised__c`, `HTTP_Errors__c`).
- **Expected magnitude:** ≤ 25 Leads touched, only empty fields filled, **0 overwrites**, **0 rollback events**.

## 3. Execution shape (when authorized — RED)
1. Enable **only** the USASpending registry row (`Enabled__c=true`); all other connectors stay dormant.
2. Activate the fill-empty write policy for USASpending.
3. **Preview:** `OA_EnrichmentQueueable(the25Ids, 'USASPENDING', ruleset, false)` → review telemetry + proposals.
4. **Canary within the pilot:** commit **1** Lead first (`commitWrites=true`), verify change log + snapshot + a rollback dry-run.
5. **Commit the 25:** `OA_EnrichmentQueueable(the25Ids, 'USASPENDING', ruleset, true)`. Batch size ≤ 20 (default), well under the 50-callout ceiling.
6. Return to dormant immediately after (disable connector, deactivate policy) unless proceeding to the 100-Lead pilot.

## 4. Monitoring plan (during + immediately after)
Watch live via the ops reports (`MONITORING_DASHBOARDS.md`) or direct SOQL on the four objects:
- **Run health:** `OA_Connector_Run__c.Status__c` (expect `Succeeded`; any `Failed` = orchestrator already stopped the run).
- **HTTP/auth errors:** `HTTP_Errors__c` = 0; no 401/403 pattern in `Messages__c`.
- **Writes vs snapshots:** every `OA_Enrichment_Change_Log__c` write row has a non-blank `Before_Snapshot__c` (must-be-zero tile: writes-without-snapshot).
- **Exceptions:** `OA_Enrichment_Exception__c` open count and type; exception rate < 20% of requested.
- **Rollback tile:** `Change_Type__c='Rollback'` = 0 (unless the drill in §3.4).

## 5. Success criteria (all must hold)
- Run `Status__c = Succeeded`; `HTTP_Errors__c = 0`.
- Only **empty** fields written; **0 overwrites**; every write has a before-snapshot.
- Exception rate < 20%; no `PolicyException`.
- The in-pilot canary rollback restored the 1 Lead exactly (field-for-field), audit retained.
- Previewed proposals matched committed writes (no surprise fields).

## 6. Failure criteria (any one → stop, do not scale)
- Any `Status__c = Failed`, or `HTTP_Errors__c > 0` / 401 / 403.
- Any overwrite of a non-empty field, or any write missing a `Before_Snapshot__c`.
- Exception rate ≥ 20%, or any `PolicyException` / floor violation.
- Previewed proposals diverge from committed writes.
- Any write to a Lead outside the pinned 25-Id set.

## 7. Emergency stop procedure (fastest → safest)
1. **Abort jobs:** `Setup → Apex Jobs` → Abort, or `System.abortJob(jobId)`.
2. **Kill writes:** deactivate all `OA_Field_Write_Policy__mdt` (no active policy ⇒ no WRITE outcomes even if a connector runs).
3. **Cut callouts:** set the USASpending registry row `Enabled__c=false`.
4. **Roll back if needed:** `OA_ChangeLogService.rollback(<logs for the pilot Run_ID>)` → restores prior values, logs the reversal.
5. **Confirm dormant:** `SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%nrich%'` = 0 and all registry rows disabled.

## 8. Rollback plan
- Rollback set = the pinned 25 Ids + their `OA_Enrichment_Change_Log__c` rows for the pilot `Run_ID`.
- `OA_ChangeLogService.rollback(...)` restores each field to `Before_Snapshot__c` and writes a `Rollback` log row (audit retained).
- Proven deterministic in Sprint-16 (5/5). Rehearse once on the in-pilot canary Lead before committing all 25.

## 9. Pilot timeline (indicative, single session, ~2–3 hrs incl. review)
| Phase | Action | Gate |
|---|---|---|
| T-0 | Close USASpending pre-conditions; pin the 25 Ids | Louis approves scope |
| T+0 | Enable USASpending row + activate fill-empty policy | **RED — approval** |
| T+10m | Preview pass (commit=false); review proposals/telemetry | Preview clean? |
| T+30m | Commit 1-Lead canary + rollback dry-run | Canary + rollback pass? **RED** |
| T+45m | Commit the 25 (commit=true) | Success criteria met? |
| T+75m | Review dashboards/telemetry; decide scale-vs-hold | Go/No-Go to 100-Lead |
| T+90m | Return to dormant (disable connector, deactivate policy) unless proceeding | — |

## 10. What this pilot does NOT do
- No SAM (unconfirmed key, EC principal access) — deferred to a later pilot after key validation.
- No scheduled/recurring enrichment — schedules stay off until 25→100 pilots pass and the least-priv runtime user exists.
- No overwrite policies — fill-empty only.
- No change beyond the pinned 25 Leads.
