# Executive Dashboard — Lead Enrichment

_Design (build-ready, not deployed) · Sprint 27 · audience: Louis / leadership · all components over existing objects, no new schema_

Folder: **"OA Enrichment — Executive"**. Refresh: daily (subscription). KPI defs: `KPI_CATALOG.md`.

| # | Component | Type | Metric (KPI) | Source | Filter |
|---|---|---|---|---|---|
| E1 | **Platform Health** | Status tile | Failed runs 24h (KPI 7); green if 0 | CR | last 24h |
| E2 | **Production Readiness** | Gauge | readiness score (from `LEAD_ENRICHMENT_OPERATIONAL_READINESS.md`) | manual/derived | current |
| E3 | **Business Value** | Metric row | Leads Enriched (KPI 2), Federal Contractors (KPI 23), Fields Updated (KPI 4) | CL/Lead | to-date |
| E4 | **Enrichment Activity** | Column (trend) | Fields Updated per day (KPI 4) | CL | last 30d |
| E5 | **Data Quality** | Gauge | Data Quality Score (KPI 17) + Conflict Rate (KPI 14) | derived | current |
| E6 | **Connector Health** | Donut | Connector Success % (KPI 6) by source | CR | last 7d |
| E7 | **Confidence** | Donut | HIGH/MED/LOW distribution (KPI 18) | CR/CL | last 30d |
| E8 | **Weekly Trend** | Line | Leads Enriched + Success % (KPI 2/3) by week | CL/CR | last 12 wk |
| E9 | **Monthly Trend** | Line | Leads Enriched + Federal Contractors by month | CL/Lead | last 12 mo |
| E10 | **Top Agencies / Industries** | Bar | KPI 20/21 | Lead | last 90d |

**Headline (top strip):** enriched-Leads-to-date, this-week delta, connector success %, open exceptions, "platform dormant/active" state.
**Must-be-green tiles:** Failed runs (0), Rollback failures (0), Audit consistency = 100% (KPI 24).
