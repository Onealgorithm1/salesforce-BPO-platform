# Lead Enrichment — KPI Catalog

_Definitions · 2026-07-07 (Sprint 27) · Org 00Dbn00000plgUfEAI · companion to `KPI_BASELINE.md` (measured values)_

All KPIs derive from **existing** objects — no new schema. Sources: `OA_Connector_Run__c` (CR, telemetry), `OA_Enrichment_Change_Log__c` (CL, writes/rollbacks), `OA_Enrichment_Exception__c` (EX, review queue), `Lead` (enriched fields).

| # | KPI | Purpose | Formula | Source | Refresh | Owner |
|---|---|---|---|---|---|---|
| 1 | **Leads Processed** | volume attempted | `SUM(CR.Requested__c)` over window | CR | per-run / daily | Ops |
| 2 | **Leads Enriched** | Leads with ≥1 field written | distinct `CL.Target_Record_Id__c` where `Change_Type__c='Enrich'` | CL | daily | Ops |
| 3 | **Enrichment Success %** | quality of runs | `Leads Enriched / Leads Matched` | CL/CR | daily | Ops |
| 4 | **Fields Updated** | write volume | `COUNT(CL where Change_Type__c='Enrich')` | CL | daily | Ops |
| 5 | **Average Fields per Lead** | enrichment depth | `Fields Updated / Leads Enriched` | CL | daily | Ops |
| 6 | **Connector Success %** | connector reliability | `COUNT(CR Status='Succeeded') / COUNT(CR)` | CR | daily | Ops |
| 7 | **Connector Failure %** | connector reliability | `COUNT(CR Status IN ('Failed','PartialErrors')) / COUNT(CR)` | CR | daily | Ops |
| 8 | **Average Runtime** | run duration | `AVG(CR.Ended__c − CR.Started__c)` | CR | daily | Ops |
| 9 | **Average API Latency** | source responsiveness | latency parsed from `CR.Messages__c` / measured per callout | CR | weekly | Ops |
| 10 | **Average Processing Time** | per-Lead cost | `Runtime / Leads Processed` | CR | weekly | Ops |
| 11 | **Rollback Count** | reversals | `COUNT(CL Change_Type__c='Rollback')` | CL | daily | Ops |
| 12 | **Rollback Success %** | recoverability | `restored / attempted` (from rollback run) | CL | on-event | Ops |
| 13 | **Exception Count** | review backlog | `COUNT(EX Status__c='Open')` | EX | daily | Ops |
| 14 | **Conflict Rate** | fill-empty conflicts | `COUNT(EX Type='SourceConflict') / Fields Proposed` | EX | daily | Ops |
| 15 | **Fill-Empty %** | write-mode mix | `fill-empty writes / total writes` | CL | weekly | Ops |
| 16 | **Skipped Fields** | policy gating | proposed − written (from run metrics) | CR/CL | weekly | Ops |
| 17 | **Data Quality Score** | composite health | weighted: success% + (1−conflict%) + audit-consistency + confidence | derived | weekly | Owner |
| 18 | **Confidence Distribution** | match trust | % HIGH / MED / LOW of matched | CL/CR | weekly | Ops |
| 19 | **Top Connectors** | usage mix | `COUNT(CR) GROUP BY Source_System__c` | CR | weekly | Owner |
| 20 | **Top Agencies** | business insight | `GROUP BY Awarding_Agencies` (enriched Leads) | Lead | monthly | Owner |
| 21 | **Top Industries** | business insight | `GROUP BY Industry` (enriched Leads) | Lead | monthly | Owner |
| 22 | **Top NAICS** | business insight | `GROUP BY NAICS` (enriched Leads) | Lead | monthly | Owner |
| 23 | **Federal Contractor Count** | pipeline value | `COUNT(Lead where Federal_Contractor__c=true)` | Lead | weekly | Owner |
| 24 | **Certification Coverage** | audit integrity | `enriched Leads with complete change-log set / enriched Leads` (should = 100%) | CL/Lead | weekly | Owner |

## Notes
- **Audit-consistency invariant** (KPI 24): `distinct enrich-log Leads == enriched Leads` and `enrich logs == enriched Leads × fields`. Verified 100% at v1.1 (68 Leads, 408 logs, 68 distinct).
- KPIs 20–22 depend on standard Lead fields (`Industry`, `NAICS`) being populated; enrichment currently populates award/agency fields (`Awarding_Agencies__c` is Long Text Area → not groupable in SOQL; group in a report formula or a helper text field if needed).
- Baseline values: `KPI_BASELINE.md`. Dashboards that surface these: `DASHBOARD_EXECUTIVE.md` / `DASHBOARD_OPERATIONS.md` / `DASHBOARD_ADMIN.md`.
