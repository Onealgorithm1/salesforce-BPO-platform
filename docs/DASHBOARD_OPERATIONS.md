# Operations Dashboard — Lead Enrichment

_Design (build-ready, not deployed) · Sprint 27 · audience: operators · over existing objects_

Folder: **"OA Enrichment — Operations"**. Refresh: hourly during active runs. KPI defs: `KPI_CATALOG.md`.

| # | Component | Type | Metric | Source | Filter |
|---|---|---|---|---|---|
| O1 | **Connector Runs** | Table | recent `Run_ID__c`, Source, Status, Requested, Enriched, HTTP_Errors | CR | last 7d |
| O2 | **Success Rate** | Gauge | Connector Success % (KPI 6) | CR | last 7d |
| O3 | **Runtime** | Line | Avg/p95 run duration (KPI 8) by source | CR | last 7d |
| O4 | **API Errors** | Column | `SUM(HTTP_Errors__c)` by source/day | CR | last 7d |
| O5 | **Exceptions** | Bar + table | Open exceptions by type (KPI 13) + oldest | EX | Status=Open |
| O6 | **Retries** | Metric | retries used (from `Messages__c`) | CR | last 7d |
| O7 | **Processing Queue** | Metric | pending `AsyncApexJob` enrichment (0 today) | AsyncApexJob | current |
| O8 | **Rollback Events** | Column | `Change_Type__c='Rollback'` (KPI 11) — should be ~0 | CL | last 30d |
| O9 | **Policy Decisions** | Bar | WRITE / SKIP_* / CONFLICT mix (from run metrics) | CR/CL | last 7d |
| O10 | **System Health** | Tiles | Failed runs, writes-without-snapshot (0), audit-consistency (100%) | CR/CL | last 24h |

**Alert-linked tiles** (see `MONITORING_AND_ALERTS.md`): Connector failure, Repeated API errors, High exception rate, Rollback event.
**Operator actions surfaced:** links to `OPERATIONS_GUIDE.md` (emergency stop, recovery, rollback command).
