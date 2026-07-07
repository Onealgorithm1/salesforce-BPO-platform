# Production Acceptance — Final Operational Validation

_2026-07-07 · Org 00Dbn00000plgUfEAI · evidence-based · **honest result — a rollback defect was found** · platform DORMANT_

## Headline verdict: ⚠️ **NOT YET a fully reliable production system — a rollback DEFECT was found and must be fixed.**
Preview, controlled write, audit, and dormant-reset all work. **Rollback does not** — it restores only 1 of 6 fields per record. Production was restored to a clean dormant baseline; nothing was left broken. This is engineering work, contradicting the earlier "engineering complete" claim.

## Track A — Operational cycle result (executed end-to-end)
| Step | Result | Evidence |
|---|---|---|
| Preview | ✅ success | 20 Leads, 12 matched, `dmlRows=0` |
| Activate 6 fill-empty policies | ✅ | 6 active, 0 Overwrite (~20 s) |
| Controlled write (5 Leads) | ✅ success | 5 updated, **30 fields**, 0 exceptions, `dmlRows=37` (~9 s) |
| Audit records created | ✅ | 30 change logs, each with a before-snapshot |
| **Rollback executed** | ❌ **PARTIAL FAILURE** | input 30 logs → "restored 5 records" but only **`Latest_Award_Date` blanked**; UEI/Federal_Contractor/Total_Award/Award_Count/Awarding_Agencies **remained populated** |
| Cleanup (restore Leads) | ✅ | 5 Leads manually reset to blank; 30 test change logs + run deleted |
| Dormant reset | ✅ | 0 active policies, 0 enabled connectors, 78 enriched (baseline) |

## The rollback DEFECT (root cause + fix)
`OA_ChangeLogService.rollback()` (line 77): `byRecord.put(log.Target_Record_Id__c, snap);`
Each change log's `Before_Snapshot__c` holds a **single field** (e.g. `{"UEI__c":null}`) because the writer snapshots one field per log. The rollback builds `Map<recordId, snapshot>` and **overwrites** the entry for every log of the same record, so only the **last** field's snapshot is applied. For a 6-field enrichment, **5 of 6 fields are never restored.**

**Exact fix (small, contained — for a follow-up sprint, not done here):** merge snapshots per record instead of overwriting:
```apex
Map<String,Object> existing = byRecord.get(log.Target_Record_Id__c);
if (existing == null) { existing = new Map<String,Object>(); byRecord.put(log.Target_Record_Id__c, existing); }
existing.putAll((Map<String,Object>) JSON.deserializeUntyped(log.Before_Snapshot__c));
```
Plus a regression test that writes ≥2 fields to one record, rolls back, and asserts **all** fields restored. (Prior "rollback proven" claims likely tested record-count, not per-field restoration.)

## Track B — Platform state (after cleanup)
Enabled connectors **0** · active policies **0** · scheduled enrichment jobs **0** · execution layer 3 classes Active (dormant) · Leads enriched **78** (baseline) · change logs **474** · open exceptions **1** · rollback logs **0**. **Dormant + clean.**

## Track C — Connector certification (evidence)
| Connector | Connectivity | Auth | Runtime | Status |
|---|---|---|---|---|
| **USASpending** | HTTP 200 (579 ms) | none (public) | in use | 🟢 READY / in production |
| **IRS** | n/a (bulk CSV) | none | n/a | ⚪ NOT APPLICABLE (no callout) |
| **Census** | HTTP 200 (734 ms) | none (public) | dormant | 🟢 READY |
| **SEC** | HTTP 200 (166 ms) | User-Agent (code) | dormant | 🟢 READY |
| **SAM** | HTTP 200 (prod `api.sam.gov`, Sprint 32) | data.gov key (valid) | dormant | 🟡 READY WITH CONDITIONS (JIT principal grant + enable) |
No connector is BLOCKED.

## Track D — KPI snapshot (live, post-cleanup)
```
Total Leads enriched:      78          Federal contractors:  78
Today's enrichments:       0 (test run rolled back/cleaned)
Connector runs:            18 (14 Succeeded)
Enrich change logs:        474         Rollback logs:        0
Open exceptions:           1           Conflicts:            0
Avg CPU:  ~25 ms/Lead      Avg latency: ~150 ms/callout
Platform state:            DORMANT (0 connectors, 0 policies, 0 jobs)
Top agencies (sample):     Dept of Defense, NASA, Dept of Commerce, DHS, SBA
```

## Track E — Can Louis operate daily without engineering help?
**Preview + write + review + dormant-reset: YES** (validated; commands in `DAILY_ENRICHMENT_OPERATING_PROCEDURE.md`, `LEAD_ENRICHMENT_GO_LIVE_DECISION.md`). **Rollback: NO** — the safety net is currently broken; if a bad write occurred, rollback would only partially restore. **So daily *forward* enrichment is usable, but the *reversibility guarantee is not trustworthy* until the defect is fixed.** Also note: the policy-deactivate deploy silently no-ops when the file paths contain spaces — **always verify `active policies = 0` after deactivation** (use explicit quoted `--source-dir` args).

## Track F — Remaining items (unambiguous)
- **Engineering (NEW — blocks reliability):** fix `OA_ChangeLogService.rollback()` multi-field merge + add a per-field regression test.
- **Operations:** verify-active-policies-after-deactivate habit (documented); optional convenience wrapper for activate/write/deactivate.
- **Licensing:** least-privilege runtime user (replace MAD `oauser`).
- **External vendors:** none blocking (SAM key valid); rotate SAM key if ever exposed.
- **UI:** dashboards/reports/alerts build (`DASHBOARD_UI_EXECUTION_CHECKLIST.md`).

## Direct answers
1. **Did the complete operational cycle succeed?** — **No** — the rollback step failed (partial restore).
2. **Was preview successful?** — **Yes.**
3. **Was controlled enrichment successful?** — **Yes** (5 Leads, 30 fields, audited, no overwrite).
4. **Was rollback successful?** — **No** — restored 1/6 fields per record (defect).
5. **Was dormant reset successful?** — **Yes** (after cleanup; verified 0 active policies).
6. **Can Louis manually operate daily?** — **Forward enrichment yes; rollback not safely** until fixed.
7. **Any remaining engineering work?** — **Yes** — the rollback fix (previously believed complete).
8. **What operational work remains?** — UI dashboards, least-priv user; verify-after-deactivate habit.
9. **Transition to maintenance mode now?** — **Not yet** — fix rollback first (one small sprint), then yes.
10. **Is the engineering program officially complete?** — **No** — the rollback defect reopens one engineering item.

## Recommendation
**One short engineering sprint** to fix `OA_ChangeLogService.rollback()` (multi-field merge) + a regression test + re-run this exact cycle to prove full restoration. After that, Lead Enrichment is a genuinely reliable production application and can transition to maintenance mode. **I did not declare success where the evidence didn't support it.**
