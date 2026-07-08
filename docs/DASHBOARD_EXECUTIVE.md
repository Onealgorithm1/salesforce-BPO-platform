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

---

## Business-value components (added Sprint — Operations Platform epic closeout)

Extends the operational tiles above with leadership business components. **Reuse-before-build:** all components sit
in the **existing** `OA Executive Analytics` dashboard folder (already deployed for campaign analytics) — add an
"Enrichment" section rather than a new folder — and use existing objects/fields (no new schema). Full KPI definitions,
targets, and thresholds: [LEAD_ENRICHMENT_KPI_FRAMEWORK.md](LEAD_ENRICHMENT_KPI_FRAMEWORK.md). Quality-score components
use [LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md).

| # | Component | Type | Metric (KPI-Framework ref) | Source | Filter |
|---|---|---|---|---|---|
| E11 | **Lead Inventory** | Metric row | Total Leads · New Leads (created 30d) · Enriched Leads (B1) | Lead | to-date / 30d |
| E12 | **Review Pipeline** | Funnel | Pending Review (open EX) · Writebacks Approved (CL Enrich) · Rejected Proposals (EX Rejected) | EX/CL | to-date |
| E13 | **Average Enrichment Quality Score** | Gauge | Avg `Enrichment_Quality_Score` 0–100 (Quality-Score doc) | Lead (formula/rollup) | current |
| E14 | **Lead Source Performance** | Bar | Enriched Leads + avg quality by `LeadSource` | Lead | last 90d |
| E15 | **Campaign Performance** | Metric row | Members · Meetings Generated (CM "Meeting Booked") · Response rate | CampaignMember | active campaign |
| E16 | **Opportunities Influenced** | Metric | Opportunities linked to enriched Leads (converted) | Opportunity/Lead | last 180d |
| E17 | **Meeting Conversion** | Line | Meetings ÷ enriched Leads by month | CM/Lead | last 12 mo |

**Notes / reuse:**
- E15–E17 read the **live campaign** objects (CampaignMember, Opportunity) — read-only reporting; no automation change.
- "Meetings Generated" reuses the CampaignMember "Meeting Booked" status set by the existing meeting-tracking flow.
- Opportunities-influenced requires the enriched Lead → converted-Opportunity linkage (ConvertedOpportunityId); if not populated, mark N/A rather than fabricate.
- E13 depends on the enrichment quality score (formula-field option = no new object; see Quality-Score doc for the configurable model).

## Build-ready implementation checklist (🔴 deploy gated)
This design is **not deployed** (0 enrichment dashboards live — confirmed in production). To implement (gated):
1. Confirm/reuse **custom report types** for `OA_Connector_Run__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`, and `Lead` (create only those not already present; the analytics epic established the report-type-before-report two-phase rule).
2. Build the underlying **reports** (one per component) in the `OA Executive Analytics` folder — custom-report-type reports must reference the type as `Name__c` and fields as `Object$Field` (CLAUDE.md §7 lesson).
3. Assemble the **dashboard** from those reports; set the daily **subscription** to Louis.
4. Grant view access via the existing analytics permission set (`OA_Executive_Analytics_Access`) — assignment is a separate 🔴 gate.
5. Deploy is 🔴 (production metadata) — validate check-only first; two-phase (report types → reports/dashboard).
