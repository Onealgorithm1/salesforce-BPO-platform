# Automation Enablement Report (Sprint 34)

_2026-07-07 · Org 00Dbn00000plgUfEAI · evidence-based · **honest result — preview automation works; orchestrator WRITE automation has a defect** · platform DORMANT_

> **⚠️ SUPERSEDED (Sprint 35): the write defect below is FIXED.** `OA_EnrichmentOrchestrator.processScope` is now two-phase (all callouts first, then all writes); commit-mode automation writes ALL Leads (verified 5/5, was 1/5). See `AUTOMATED_WRITE_PATH_FIX.md`. Scheduled WRITE automation is now **technically ready**; remaining gates are non-engineering (least-priv user + monitoring UI).

## Headline (as of Sprint 34; write defect since fixed — see banner)
- ✅ Rollback fix merged to `main` (`decd12a`), pushed.
- ✅ **Preview automation works** via the deployed `OA_EnrichmentQueueable` (async, telemetry, 0 writes).
- ❌→✅ **Write automation** was DEFECTIVE (1 Lead/invocation, callout-after-DML) — **FIXED in Sprint 35**.
- GO/NO-GO for scheduled WRITE enrichment: was 🔴 NO-GO (defect); now 🟡 technically-ready, gated on least-priv user + monitoring.

## Track B — Rollback fix merged
`main` now contains `OA_ChangeLogService` merge fix + `testMultiFieldRollbackRestoresAllFields` + `ROLLBACK_DEFECT_FIX.md` (FF `deecba4..decd12a`, pushed; already deployed to prod, 268 tests). Confirmed present on main.

## Track C — Automation asset review
- `OA_EnrichmentOrchestrator` (Batchable + Stateful + AllowsCallouts), `OA_EnrichmentQueueable`, `OA_ProposalAdapter` — all deployed, Active, dormant.
- Modes: **preview (commitWrites=false)** and **commit (commitWrites=true)**; **batch** (`enqueueBatch`) and **manual queueable** (`System.enqueueJob`).
- Kill switch: connector `Enabled__c` (registry) + write-policy `Active__c`. With either off, no writes occur. Verified.
- **No job runs unless scheduled or explicitly invoked** — 0 scheduled enrichment jobs; the classes self-schedule nothing (verified).

## Track D — Preview automation (PASS)
Enabled USASpending (temporary), ran `OA_EnrichmentQueueable(5 Ids, 'USASPENDING', null, false)`:
- AsyncApexJob **Completed**; telemetry `ORCHQ-USASPENDING` created (Requested=5, HTTP_Errors=0, Succeeded); per-connector run records created.
- **0 writes** (5 test Leads stayed blank); dormant policies → 0 enriched; no policy-activation issues; no rollback needed; no Campaign/unrelated Lead changes.
- ✅ Scheduled/queued execution + telemetry + zero writes all validated.

## Track E — Controlled automated WRITE (DEFECT found)
Activated 6 fill-empty policies, ran `OA_EnrichmentQueueable(5 Ids, 'USASPENDING', null, true)`:
- Result: **only 1 of 5 Leads enriched** (Records_Enriched=6 = 1 Lead × 6 fields); **HTTP_Errors=4**; AsyncApexJob "Completed" (defect is masked).
- **Root cause:** `OA_EnrichmentOrchestrator.processScope` interleaves per-Lead `runner.fetch (callout) → OA_EnrichmentWriter.enrich (commit → Database.update)`. After the first Lead's DML, the next Lead's callout throws *"You have uncommitted work pending"*; the connector catches it as an HTTP error, so subsequent Leads silently fail to enrich. This is the same callout-before-DML rule the **manual path already respects** (all fetches first, then DML) — the orchestrator does not.
- **Action taken:** rolled back the 1 written Lead (fixed rollback restored all 6 fields), deleted test telemetry, deactivated policies, disabled connector → **dormant baseline (78 enriched, 474 logs, 0 active policies/connectors)**.
- **Recommended fix (NOT done — needs authorization; do not confuse with redesign):** restructure `processScope` to **collect all connector results first (all callouts), then apply all writes** (mirror the proven manual pattern), OR chunk to 1 callout-Lead per transaction. Add a multi-Lead commit regression test. This is a contained execution-core fix.

## Track F — Scheduler design (recommendation; nothing scheduled)
Given the write defect, recommend a **preview-first** rollout:
| Aspect | Recommendation |
|---|---|
| Phase 1 (now) | **Scheduled PREVIEW only** — nightly `OA_EnrichmentQueueable`/`Batch` in commit=false over a bounded scope; review telemetry. No writes. |
| Phase 2 (after orchestrator write fix + least-priv user + dashboards) | Scheduled **commit** enrichment. |
| Frequency | Nightly off-peak (e.g., 02:00 ET) |
| Scope (SOQL) | `UEI__c=null AND Company!=null`, bounded `LIMIT`, incremental (`CreatedDate=LAST_N_DAYS`) |
| Batch size | 50 callout-Leads/txn (once the callout-before-DML fix lands) |
| Mode | commit=false first cycle, then commit |
| Kill switch | disable connector (`Enabled__c=false`) and/or deactivate policies (`Active__c=false`) |
| Alerts | connector failure, high HTTP errors, 0-successful-run, zero-enrichment (needs reports/dashboards) |
| Manual approval | required before flipping any schedule to commit=true |

## Track G — Safety controls (verified)
- **Kill switch:** connector `Enabled__c=false` (no fetch) + policy `Active__c=false` (no write) — either stops enrichment; both verified returning to dormant.
- **Active policy / enabled connector counts:** monitored (0/0 when dormant).
- **Rollback:** fixed + verified (all fields restored).
- **Exception routing / SaveResult handling:** the writer now checks SaveResults (Sprint 25) and routes failures.
- **Uncommitted-work ordering:** the **manual path is safe** (callout-before-DML); the **orchestrator is NOT** (Track E defect).
- **Connector credential failure:** returns non-2xx on `OA_ConnectorResult` (never throws) → run marked PartialErrors/Failed, no writes.
- **Emergency stop:** (1) `Setup → Apex Jobs → Abort` any running job; (2) deploy connector `Enabled__c=false`; (3) deploy all policies `Active__c=false`; (4) verify `active policies=0 AND enabled connectors=0`; (5) rollback if needed via `OA_ChangeLogService.rollback([logs])`.

## Track H — Monitoring status
Dashboards remain **UI-only** (not built). **Automation may run only in controlled mode with manual CLI review until dashboards exist.** CLI monitoring after every automated job:
```
sf data query -q "SELECT Run_ID__c,Status__c,Requested__c,Records_Enriched__c,HTTP_Errors__c,Exceptions_Raised__c FROM OA_Connector_Run__c ORDER BY CreatedDate DESC LIMIT 5"
sf data query -q "SELECT COUNT() FROM OA_Enrichment_Exception__c WHERE Status__c='Open'"
sf data query -q "SELECT COUNT() FROM OA_Field_Write_Policy__mdt WHERE Active__c=true"   # must be 0 when idle
sf data query -q "SELECT COUNT() FROM OA_Connector_Registry__mdt WHERE Enabled__c=true"  # must be 0 when idle
```

## Direct answers
1. **Is Lead Enrichment automated now?** — **Partially** — preview automation works; write automation is defective.
2. **Can it run preview automatically?** — **Yes** (validated).
3. **Can it run write automation safely?** — **No** — orchestrator commit writes only 1 Lead/invocation (defect).
4. **Is scheduled enrichment ready?** — **Preview: yes. Write: no.**
5. **What prevents full unattended automation?** — (a) orchestrator commit defect (engineering fix), (b) least-privilege runtime user (license), (c) monitoring dashboards/alerts (UI).
6. **What can Louis use today?** — manual controlled enrichment (proven, callout-before-DML) + optional manual/scheduled preview automation.
7. **Next operational action?** — authorize the orchestrator callout-before-DML fix; meanwhile use the manual path for real enrichment.

## GO / NO-GO
🟢 Manual controlled enrichment · 🟢 Scheduled/queued **preview** automation · 🔴 **Scheduled WRITE automation (NO-GO until orchestrator fix + least-priv user + monitoring).**
