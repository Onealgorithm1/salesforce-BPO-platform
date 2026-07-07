# Daily Enrichment Operating Procedure (DEOP)

_Sprint 30 · Org 00Dbn00000plgUfEAI · v1.1 · controlled/manual enrichment · runtime user = temporary MAD `oauser`_

The step-by-step for a day of controlled Lead Enrichment. Platform is **dormant by default**; each run is deliberate and reversible. Reference: `OPERATIONS_GUIDE.md` (incident authority), `PRODUCTION_CERTIFICATION.md`, `PERFORMANCE_VALIDATION.md` (limits).

## 1. Morning checklist (5 min, read-only)
- [ ] Verify Org ID = `00Dbn00000plgUfEAI` (`sf org display`).
- [ ] Confirm dormant: 0 enabled connectors, 0 active policies, 0 enrichment jobs, 0 concurrent deploys.
      `sf data query -q "SELECT COUNT() FROM OA_Field_Write_Policy__mdt WHERE Active__c=true"` → 0.
- [ ] USASpending healthy: run the isolated probe → HTTP 200.
- [ ] Review overnight: any new `OA_Enrichment_Exception__c` (Status='Open'); any `Change_Type__c='Rollback'` (should be 0).

## 2. Select scope + PREVIEW run (no writes)
- [ ] Pick ≤ 50 Leads (blank `UEI__c`, has Company, not converted, not a campaign member, exclude internal/test/Pisano/MediaNow).
- [ ] Save a before-snapshot of the target fields (CSV) — the rollback baseline.
- [ ] **Preview** (commitWrites=false), **callout-before-DML**, chunk ≤ 50: run the connector→mapper→`OA_EnrichmentWriter.preview` path (or `OA_EnrichmentQueueable(ids,'USASPENDING',ruleset,false)`).
- [ ] Capture: matched count, proposed fields, conflicts (should be 0 for blank targets), confidence, HTTP errors (0).

## 3. Review proposed updates (Louis)
- [ ] Eyeball the previewed values (UEI, award totals, agencies, dates) for sanity.
- [ ] Confirm only intended (blank) fields would fill; no overwrite; State untouched.
- [ ] Approve → proceed to commit. Reject → stop (nothing written).

## 4. COMMIT write (controlled)
- [ ] Activate the 6 USASpending FillEmptyOnly policies (deploy `Active=true`). Verify: exactly 6 active, 0 active Overwrite.
- [ ] Run the write (commitWrites=true), **callout-before-DML**, on the matched Leads only.
- [ ] Verify: Leads updated, fields written, change logs = leads×fields, connector run recorded, exceptions understood, no overwrite.
- [ ] **Deactivate** the 6 policies (deploy `Active=false`) → back to dormant.

## 5. Exception review
- [ ] Query `OA_Enrichment_Exception__c` (Status='Open') created by the run; triage by type (SourceConflict / PolicyException / write-failure). Resolve or note.

## 6. Rollback (only if needed)
- [ ] `OA_ChangeLogService.rollback([SELECT Id,Target_Object__c,Target_Record_Id__c,Before_Snapshot__c,Reversible__c FROM OA_Enrichment_Change_Log__c WHERE Connector_Run__r.Run_ID__c LIKE '<runId>%'])` → restores prior values, logs a Rollback entry. Verify restoration.

## 7. Dashboard / monitoring review
- [ ] (Once built via `MONITORING_UI_BUILD_GUIDE.md`) open Executive + Operations dashboards; confirm today's run, success %, 0 failures, 0 rollbacks.
- [ ] Interim (until dashboards exist): CLI/SOQL over `OA_Connector_Run__c` / `OA_Enrichment_Change_Log__c` / `OA_Enrichment_Exception__c` (`DASHBOARD_ADMIN.md` snippets, `KPI_CATALOG.md`).

## 8. Shutdown / dormant verification (end of day)
- [ ] 0 active policies · 0 enabled connectors · 0 enrichment scheduled jobs.
- [ ] Enriched data + audit preserved. Platform dormant. Done.

## Guardrails (always)
FillEmptyOnly only · no overwrite · **callout-before-DML** (all fetches first, then writes) · ≤ 50 callout-Leads/txn · connectors dormant between runs · runtime FLS permset stays assigned · never expose secrets. Emergency stop + recovery: `OPERATIONS_GUIDE.md`.

## Automation note (Sprint 34)
For **writes, use the manual callout-before-DML path** (this procedure) — proven and rollback-safe. The `OA_EnrichmentQueueable`/`OA_EnrichmentOrchestrator` are safe for **PREVIEW automation only**; their commit path currently writes just 1 Lead/invocation (defect, `AUTOMATION_ENABLEMENT_REPORT.md`). Rollback is fixed (`ROLLBACK_DEFECT_FIX.md`): every write is fully reversible via `OA_ChangeLogService.rollback([logs])`. Always **verify `active policies = 0` after deactivating** (use explicit quoted `--source-dir` paths).
