# Monitoring UI Build Guide — Reports, Dashboards & Alerts (click-by-click)

_Sprint 29 · Org 00Dbn00000plgUfEAI · **UI-only** (report/dashboard metadata does not deploy reliably — Sprint 28 "invalid report type"). Est. ~45 min, admin, no code._

> **Why UI, not metadata:** Salesforce Reports/Dashboards are point-and-click artifacts; hand-authored metadata fails (custom objects need Custom Report Types; dashboard XML is fragile). Sprint 28 proved this. Build in the UI below. All data already exists on `OA_Connector_Run__c` / `OA_Enrichment_Change_Log__c` / `OA_Enrichment_Exception__c` / `Lead`. KPI defs: `KPI_CATALOG.md`.

## 0. One-time setup
1. **Report folder:** Reports tab → New Folder → Name **"OA Enrichment Ops"** → Save → Share (Manager/roles as needed).
2. **Dashboard folder:** Dashboards tab → New Folder → **"OA Enrichment Ops"** → Save.
3. **(If needed) Custom Report Types:** Setup → Report Types → New → Primary object = `OA Connector Run` (repeat for `OA Enrichment Change Log`, `OA Enrichment Exception`). Deployed = checked. (Custom objects usually appear directly under "Other Reports" — CRTs only needed if not listed.)

## 1. Reports (build in folder "OA Enrichment Ops")
For each: Reports → New Report → pick the report type → add columns/filters/group → Save into the folder.

| Report | Report type (primary object) | Group by | Summarize | Filter | Chart |
|---|---|---|---|---|---|
| **R1 Connector Health** | OA Connector Run | Source_System__c, Status__c | Record Count | Created last 7d | Stacked bar |
| **R2 Connector Success %** | OA Connector Run | Source_System__c | Count Status='Succeeded' ÷ total (formula) | last 7d | Gauge |
| **R3 Records Enriched** | OA Connector Run | Day (Started__c) | SUM Records_Enriched__c | last 30d | Column |
| **R4 Runtime/Duration** | OA Connector Run | Source_System__c, Day | (Ended−Started) avg (formula) | last 7d | Line |
| **R5 API Errors** | OA Connector Run | Source_System__c, Day | SUM HTTP_Errors__c | last 7d | Column |
| **R6 Records Updated** | OA Enrichment Change Log | Day, Source_System__c | Record Count where Change_Type__c='Enrich' | last 30d | Column |
| **R7 Rollback Events** | OA Enrichment Change Log | Day | Count where Change_Type__c='Rollback' | last 30d | Column (≈0) |
| **R8 Open Exceptions** | OA Enrichment Exception | Exception_Type__c | Record Count + oldest CreatedDate | Status__c='Open' | Bar + table |
| **R9 Federal Contractors** | Leads | Industry / State | Count where Federal_Contractor__c=true | — | Bar |
| **R10 Executive Summary** | OA Connector Run | — | runs, SUM Records_Enriched__c, success % | last 30d | Metric row |

**Formula tips:** Success % = `RowCount` filtered; use a summary formula `Succeeded:SUM / RowCount`. Duration = add a column formula `Ended__c - Started__c` (days→minutes ×1440).

## 2. Dashboards (folder "OA Enrichment Ops") — Track B
Dashboards → New Dashboard → add components → pick report → chart type → set **Running User = a user with the runtime permset** (or "Run as logged-in user" for admins).

### Executive Dashboard (`DASHBOARD_EXECUTIVE.md`)
Components: R10 (metric row) · R3 (records-enriched trend) · R2 (success gauge) · R9 (federal contractors) · R6 (records updated) · a "Platform Health" metric (R-derived Failed=0). Refresh: daily subscription.

### Operations Dashboard (`DASHBOARD_OPERATIONS.md`)
Components: R1 (connector health) · R4 (runtime) · R5 (API errors) · R8 (exceptions) · R7 (rollback events) · R2 (success). Refresh: hourly during runs.

### Administrator Dashboard (`DASHBOARD_ADMIN.md`)
Mostly config panels — use **report components where possible** (R1/R2) + **"Dormant vs Active" metric** (a report on active policies/enabled connectors = should be 0). NC/permission/deploy-history panels are Setup/CLI reads (snippets in `DASHBOARD_ADMIN.md`); represent as a note/link component.

### Connector Health Dashboard (Track B 4th)
Components: R1 (health by source/status) · R2 (success % gauge per source) · R5 (API errors) · R4 (latency/runtime) · a "last successful run per source" table (R on OA Connector Run, group by Source, max Started__c). Refresh: hourly.

## 3. Alerts / Monitoring — Track C (click-by-click)
Native **Report Subscriptions** + optional **Flow** notifications. All conditions from `MONITORING_AND_ALERTS.md`.

| Alert | Build | Severity |
|---|---|---|
| **Connector Failure** | Subscribe to R1; condition "Record Count > 0" filtered Status='Failed" → email Louis | 🔴 |
| **API Failure** | Subscribe to R5; "SUM HTTP_Errors__c > 0" | 🔴 |
| **Rollback Failure/Event** | Subscribe to R7; "Record Count > 0" | 🔴/🔵 |
| **Exception Spike** | Subscribe to R8; "Record Count > threshold" | 🟠 |
| **Credential Failure** | Report on OA Connector Run where Messages__c contains 401/403 → subscribe | 🔴 |
| **Slow Runtime** | R4 with duration threshold column → subscribe | 🟠 |
| **Scheduler Failure** | (when scheduled) Report on CronTrigger / a Flow on job failure | 🟠 |
| **Policy Disabled/Misconfig** | Report on OA_Field_Write_Policy where Active=true AND Write_Mode='Overwrite' → should be 0; subscribe "Count>0" | 🔴 |

**Subscription steps:** open the report → **Subscribe** → set schedule + **conditions** ("when aggregate meets…") → recipients `lronealgorithm@gmail.com` → Save. For near-real-time criticals, build a **record-triggered Flow** on `OA_Enrichment_Exception__c` create → Email Alert.

## 4. Validation (after build)
- Each report opens and returns rows (data exists: 17 runs, 414 logs, 1 exception, 68 enriched Leads).
- Each dashboard renders all components; refresh works.
- Subscriptions saved with conditions; send a test.
- Security: folder shared to the right roles; running user has the runtime permset (field visibility).

_Interim (before this build): the same KPIs are queryable via CLI — see `DASHBOARD_ADMIN.md` snippets + `KPI_CATALOG.md`._
