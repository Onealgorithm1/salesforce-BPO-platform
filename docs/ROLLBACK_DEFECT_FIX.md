# Rollback Multi-Field Defect — Fix

_2026-07-07 · Org 00Dbn00000plgUfEAI · scope: ONLY `OA_ChangeLogService.rollback()` · platform DORMANT after_

## Defect
`OA_ChangeLogService.rollback()` restored only **one field per record**. The enrichment writer records **one field per change log** (each `Before_Snapshot__c` = a single-field JSON, e.g. `{"UEI__c":null}`). The rollback grouped snapshots with `byRecord.put(recordId, snap)`, which **overwrote** the map on every log — so only the last field's snapshot survived. A 6-field enrichment rolled back only 1 field; 5 remained written. (Prior "rollback proven" tests checked record count, not per-field restoration, so it went unnoticed.)

## Fix (merge, don't overwrite)
`force-app/main/default/classes/OA_ChangeLogService.cls` — in the log-grouping loop:
```apex
Map<String, Object> merged = byRecord.get(log.Target_Record_Id__c);
if (merged == null) { merged = new Map<String, Object>(); byRecord.put(log.Target_Record_Id__c, merged); }
merged.putAll(snap);   // accumulate ALL of a record's field snapshots
```
No other logic changed. No enrichment/connector/architecture changes.

## Regression test (added)
`OA_ChangeLogService_Test.testMultiFieldRollbackRestoresAllFields` — writes 3 fields (Rating, Title, Website) to one Lead via 3 single-field logs, rolls back, asserts **all three** restored. Fails on the old code, passes on the fix.

## Validation
- Check-only validate: **Succeeded** (3 `OA_ChangeLogService_Test` methods, 0 errors).
- Production deploy (RunLocalTests): **Succeeded — 268 tests, 0 errors, 2 components.**

## Re-run of the exact operational cycle (evidence)
| Step | Result |
|---|---|
| Preview | 5 Leads matched |
| Activate 6 fill-empty policies | 6 active, 0 Overwrite |
| Write 5 Leads | 5 updated, **30 fields**, 0 exceptions |
| **Rollback (fixed)** | input 30 logs → 5 records restored |
| **Verify** | **all 30 fields blank on all 5 Leads** (0 fields populated); State preserved; org back to 78 |
| Cleanup + deactivate | test audit deleted; **0 active policies, 0 connectors, 0 jobs, 78 enriched, 474 logs** |

## Result
- **Rollback fixed?** — **Yes** (deployed, tested).
- **Full multi-field rollback pass?** — **Yes** — all 30 fields restored (was 5/30 before).
- **Production clean?** — **Yes** — dormant, baseline restored, no residual test data.
- **Safe for daily manual use?** — **Yes** — forward enrichment + a now-trustworthy rollback safety net.
- **Engineering work still open?** — **None for rollback.** Remaining items are non-engineering: UI dashboards, least-privilege runtime user (license), SAM activation (JIT grant). Operational note: deactivate policies with explicit quoted `--source-dir` paths (spaces in the OneDrive path silently no-op the loop form) and verify `active policies = 0`.
