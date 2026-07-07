# Lead Enrichment — Operational Go-Live Decision

_Sprint 32 · 2026-07-07 · Org 00Dbn00000plgUfEAI · **decision: GO for controlled daily manual operation** · platform returned dormant_

## Decision: 🟢 GO — Louis can run Lead Enrichment manually, day to day, today.
Proven this sprint by an actual controlled production run (10 Leads enriched, 60 fields, 0 overwrites, fully audited, then returned to dormant).

## Track D — controlled daily run (executed, evidence)
| Step | Result |
|---|---|
| Preview (40 Leads, no writes) | 18 matched USASpending; `dmlRows=0` |
| Activate 6 fill-empty policies | 6 active, 0 Overwrite |
| Write 10 matched Leads (commit) | 10 updated, **60 fields**, 0 exceptions, 0 HTTP errors |
| Verify | UEI Old_Value=null (no overwrite); State preserved; 60 change logs w/ before-snapshots |
| Deactivate policies | 0 active → **dormant** |
Total enriched: **78 Leads** (68 prior + 10 today). Sample: Zivko Aeronautics (17 awards, $38.8M), Zoom INC. (100 awards, $23.5M).

## Track E — can Louis do the daily loop? (each step answered)
1. **Run preview** — ✅ yes (CLI; no writes, no activation needed).
2. **Review proposed updates** — ✅ yes (preview output shows matched + proposed values + confidence).
3. **Commit approved updates** — ✅ yes (activate policies → write → deactivate; proven).
4. **Review exceptions** — ✅ yes (`OA_Enrichment_Exception__c` query).
5. **Review audit** — ✅ yes (`OA_Enrichment_Change_Log__c` per run; before-snapshots present).
6. **Reset to dormant** — ✅ yes (deactivate policies; verified 0 active).
7. **Review KPI output** — ✅ yes via CLI now (sample below); via dashboards after the UI build.
**No missing step for manual daily operation.** (The only friction: activation/deactivation are CLI deploys; a future convenience would be a one-click flow, but it's not required.)

## Exact commands Louis runs (or asks Claude to run)
The literal daily procedure is in `DAILY_ENRICHMENT_OPERATING_PROCEDURE.md`. Core:
- Preview: anon-Apex `OA_USASpending_Connector().fetch(company,cfg)` → `OA_USASpending_Mapper` → `OA_EnrichmentWriter.preview(...)` (commit=false).
- Activate: `sf project deploy start --source-dir <6 policy files with Active=true>`.
- Write: same path with `OA_EnrichmentWriter.enrich(..., commit=true)`, **callout-before-DML**, ≤50/txn.
- Deactivate: `sf project deploy start --source-dir <6 policy files with Active=false>`.
- Rollback (if needed): `OA_ChangeLogService.rollback([logs WHERE Connector_Run__r.Run_ID__c LIKE '<run>%'])`.

## Answers (Track H)
- **Can Louis run this manually every day?** — **Yes.**
- **Can the platform produce useful output every day?** — **Yes** — real federal-contract enrichment + KPI snapshot.
- **Can it be safely reset after each run?** — **Yes** — deactivate policies → dormant (proven).
- **What prevents scheduled automation?** — least-privilege runtime user (needs a license) + monitoring/alerts wired; the connectors stay dormant/human-gated by design until then.
- **What prevents all-connector certification?** — SAM now READY-WITH-CONDITIONS (prod endpoint fixed, HTTP 200; needs JIT principal grant + enable); USASpending/IRS/Census/SEC ready. Nothing is BLOCKED anymore.
- **What must Louis do in Salesforce UI?** — build the dashboards/reports/alerts (`DASHBOARD_UI_EXECUTION_CHECKLIST.md`, ~45 min). Optional now — CLI KPI works today.
- **What must Louis do outside Salesforce?** — acquire a Salesforce license (for the least-privilege user). That's the only external item; the SAM key already works.

## Track G — alert readiness
| Alert | Class |
|---|---|
| Connector failure | NEEDS DASHBOARD/REPORT FIRST (then UI subscription) |
| API failure | NEEDS DASHBOARD/REPORT FIRST |
| No successful run | NEEDS DASHBOARD/REPORT FIRST |
| High exceptions | NEEDS DASHBOARD/REPORT FIRST |
| Credential failure | NEEDS DASHBOARD/REPORT FIRST |
| Rollback failure | NEEDS DASHBOARD/REPORT FIRST |
| Scheduler failure | BLOCKED (no scheduler until go-live for automation) |
All alerts are report-subscription based → require the reports (UI build) first. None are code-blocked. Steps: `DASHBOARD_UI_EXECUTION_CHECKLIST.md`.

## Bottom line
**Lead Enrichment is LIVE for controlled daily manual operation.** Dashboards (UI) and the least-privilege user (license) remain for *automation*, not manual use. SAM is fixed (prod endpoint). Next action for Louis: **run it daily** (or ask Claude to run each day), and when ready, do the ~45-min dashboard UI build.
