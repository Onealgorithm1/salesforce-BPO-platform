# Dashboard UI Execution Checklist (follow-along)

_Sprint 32 · Org 00Dbn00000plgUfEAI · **literal step-by-step for Louis in Salesforce** · ~45 min · no code. Detail/rationale: `MONITORING_UI_BUILD_GUIDE.md`._

> CLI cannot build reports/dashboards (proven: "invalid report type"). This is the exact UI sequence. Tick each box.

## A. Folders (2 min)
- [ ] Reports tab → **New Folder** → Name `OA Enrichment Ops` → Save.
- [ ] Dashboards tab → **New Folder** → Name `OA Enrichment Ops` → Save.
- [ ] (If a report type for the custom objects isn't offered under "Other Reports": Setup → **Report Types** → New → Primary object `OA Connector Run` → Deployed → Save; repeat for `OA Enrichment Change Log`, `OA Enrichment Exception`.)

## B. Reports (build each: Reports → New Report → choose report type → add columns → filter → group → chart → Save to `OA Enrichment Ops`)
- [ ] **R1 Connector Health** — type *OA Connector Run*; group `Source_System__c`, `Status__c`; Count; filter Created last 7 days; chart Stacked Bar.
- [ ] **R2 Connector Success %** — *OA Connector Run*; group `Source_System__c`; summary formula `Succeeded/RowCount`; Gauge.
- [ ] **R3 Records Enriched** — *OA Connector Run*; group Day of `Started__c`; SUM `Records_Enriched__c`; last 30d; Column.
- [ ] **R4 Runtime** — *OA Connector Run*; group `Source_System__c`; column formula `Ended__c−Started__c`; Line.
- [ ] **R5 API Errors** — *OA Connector Run*; group `Source_System__c`, Day; SUM `HTTP_Errors__c`; Column.
- [ ] **R6 Records Updated** — *OA Enrichment Change Log*; filter `Change_Type__c=Enrich`; group Day; Count; Column.
- [ ] **R7 Rollback Events** — *OA Enrichment Change Log*; filter `Change_Type__c=Rollback`; group Day; Count (target 0).
- [ ] **R8 Open Exceptions** — *OA Enrichment Exception*; filter `Status__c=Open`; group `Exception_Type__c`; Count + table.
- [ ] **R9 Federal Contractors** — *Leads*; filter `Federal_Contractor__c=true`; group `State`/`Industry`; Count; Bar.
- [ ] **R10 Executive Summary** — *OA Connector Run*; last 30d; summarize runs, SUM `Records_Enriched__c`, success %; Metric row.

## C. Dashboards (Dashboards → New → into `OA Enrichment Ops` → add component → pick report → chart → set Running User)
- [ ] **Executive** — R10, R3, R2, R9, R6. Running User = any user with the runtime permset. Refresh: daily subscription.
- [ ] **Operations** — R1, R4, R5, R8, R7, R2. Refresh: hourly during runs.
- [ ] **Administrator** — R2 + a "Dormant check" component (report: active policies/enabled connectors = 0) + note-links for NC/permission (CLI snippets in `DASHBOARD_ADMIN.md`).
- [ ] **Connector Health** — R1, R2, R5, R4 + "last successful run per source" (R on OA Connector Run, group Source, MAX `Started__c`).

## D. Subscriptions / Alerts (open each report → **Subscribe** → set conditions → recipients `lronealgorithm@gmail.com`)
- [ ] Connector Failure — subscribe R1 filtered `Status='Failed'`, condition "Record Count > 0".
- [ ] API Failure — subscribe R5, condition "Sum HTTP_Errors > 0".
- [ ] High Exceptions — subscribe R8, condition "Record Count > (your threshold)".
- [ ] Rollback — subscribe R7, condition "Record Count > 0".
- [ ] No Successful Run — subscribe R2/R10, condition "Succeeded runs = 0" in the window.
- [ ] Policy Misconfig — new report on `OA_Field_Write_Policy__mdt` where `Active__c=true AND Write_Mode__c='Overwrite'` (must be 0); subscribe "Count > 0".

## E. Expected output (validation)
- [ ] Reports return rows (data exists: 18 runs, 474 enrich logs, 78 enriched Leads, 1 open exception).
- [ ] Dashboards render all components; refresh works.
- [ ] Subscriptions saved; send a test.
- [ ] Executive shows: enriched-Leads count, success %, records-enriched trend, federal contractors.

_Interim until built: the same numbers via CLI/SOQL (`DASHBOARD_ADMIN.md` snippets, `KPI_CATALOG.md`, or the daily KPI snapshot in `LEAD_ENRICHMENT_GO_LIVE_DECISION.md`)._
