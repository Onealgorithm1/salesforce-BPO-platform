# Lead Enrichment — Analytics Build Package (Dashboards & Reports)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Mode:** reuse audit (live) + build manifest
**Status:** build-ready spec — **metadata deploy is 🔴 RED (Louis)**; nothing deployed this sprint. Dashboards render only post-deploy.
**Reuses:** [DASHBOARD_EXECUTIVE.md](DASHBOARD_EXECUTIVE.md) / [DASHBOARD_OPERATIONS.md](DASHBOARD_OPERATIONS.md) / [DASHBOARD_ADMIN.md](DASHBOARD_ADMIN.md) designs · [LEAD_ENRICHMENT_KPI_FRAMEWORK.md](LEAD_ENRICHMENT_KPI_FRAMEWORK.md)

> Phases 1–4. Live reuse audit of existing analytics assets + the exact build manifest for the three dashboards, their
> underlying reports, and the custom report types that must be created (none exist for the enrichment objects).
> Every dashboard component maps to a named report; every report maps to a report type. **Two-phase build order**
> (report types → reports → dashboards) is mandatory (CLAUDE.md §7 lesson; the analytics epic proved it).

---

## 1. Reuse audit (live, 2026-07-08)
**Custom report types present:** `OA_Campaign_Funnel_Snapshots`, `OA_Email_Messages`, `OA_Engagement_Resolutions` (+ non-OA standard ones). **None cover the enrichment objects** (`OA_Connector_Run__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`, `OA_Discovered_Organization__c`) → these must be **created**.
**Report folders present (reuse):** `OA_Executive_Analytics` ✅, `OA_Engagement`, `OA_BPO_Pilot`, `BPO_Campaign_Operations`.
**Dashboard folders present (reuse):** `OA_Executive_Analytics` ✅, `BPO_Campaign_Dashboards`.
**Dashboards present:** 9 (campaign/analytics/company) — **0 Lead-Enrichment-specific** → build 3 new (Executive/Operations/BD) **in the existing `OA_Executive_Analytics` folder** (no new folder).

## 2. Custom report types to create (Phase 4 foundation — 4)
| Report Type (new) | Primary object | Purpose |
|---|---|---|
| `OA_Connector_Runs` | `OA_Connector_Run__c` | connector health / runtime / failures |
| `OA_Enrichment_Change_Logs` | `OA_Enrichment_Change_Log__c` | writes / rollbacks / audit |
| `OA_Enrichment_Exceptions` | `OA_Enrichment_Exception__c` | review queue / exceptions |
| `OA_Leads_Enrichment` | `Lead` (enrichment fields) | inventory / quality / coverage / source (Lead standard report type may suffice — reuse if so) |
Standard **Campaign/CampaignMember** and **Opportunity** report types already exist → **reuse** for BD dashboard.

## 3. Executive Dashboard — components → reports
Folder `OA_Executive_Analytics`. (Design: [DASHBOARD_EXECUTIVE.md](DASHBOARD_EXECUTIVE.md) E1–E17.)
| Component | Report (to build) | Report type |
|---|---|---|
| Lead Inventory | `LE_Lead_Inventory` (total, new-30d, enriched) | OA_Leads_Enrichment |
| Lead Quality Score | `LE_Quality_Score_Dist` (band buckets) | OA_Leads_Enrichment (formula) |
| Enrichment Coverage | `LE_Field_Coverage` (UEI/CAGE/NAICS/awards %) | OA_Leads_Enrichment |
| Review Queue | `LE_Open_Exceptions` | OA_Enrichment_Exceptions |
| Writeback Queue | `LE_Writebacks` (Enrich change logs) | OA_Enrichment_Change_Logs |
| Connector Health | `LE_Connector_Success` | OA_Connector_Runs |
| Processing Failures | `LE_Run_Failures` (Failed/PartialErrors) | OA_Connector_Runs |
| Campaign Performance | `LE_Campaign_Perf` | Campaign/CampaignMember (reuse) |
| Meetings Generated | `LE_Meetings` (CM 'Meeting Booked') | CampaignMember (reuse) |
| Lead Source Performance | `LE_Source_Perf` | OA_Leads_Enrichment |
| Opportunity Influence | `LE_Opp_Influence` (converted w/ Opp) | Opportunity (reuse) |
| Executive Summary | headline tiles (reuse above) | — |

## 4. Operations Dashboard — components → reports
Folder `OA_Executive_Analytics` (or `BPO_Campaign_Operations`). (Design: [DASHBOARD_OPERATIONS.md](DASHBOARD_OPERATIONS.md).)
| Component | Report | Report type |
|---|---|---|
| Connector Runtime / Processing Time | `OPS_Run_Duration` | OA_Connector_Runs |
| Queue Length | `OPS_Queue_Length` (open EX) | OA_Enrichment_Exceptions |
| Exceptions / Failures / Retry Counts | `OPS_Exceptions`, `OPS_Failures` | OA_Enrichment_Exceptions / OA_Connector_Runs |
| Inactive Connectors / Dormant Policies | `OPS_Config_State` (CMDT — via report on config export or a status tile) | CMDT (note: `__mdt` not directly reportable → surface via a status component / documented check) |
| Scheduler Status | `OPS_Scheduler` (CronTrigger) | standard "Scheduled Jobs" (reuse) |
| Named / External Credential Status | status tiles (metadata; not SOQL-reportable → documented check via audit script) | n/a — surface via `daily_enrichment_audit.sh` |

> Note: CMDT (`__mdt`) records and NC/EC status are **not natively reportable**. Surface them via the audit script
> (`scripts/shell/daily_enrichment_audit.sh`) or a small status component, not a fabricated report. Documented, not invented.

## 5. Business Development Dashboard — components → reports
Folder `OA_Executive_Analytics`. (Design: reuse [DASHBOARD_ADMIN.md](DASHBOARD_ADMIN.md) + KPI Framework §2.)
| Component | Report | Report type |
|---|---|---|
| Agency Trends | `BD_Top_Agencies` | OA_Leads_Enrichment |
| Prime Contractor Trends | `BD_Prime_Contractors` | OA_Leads_Enrichment |
| NAICS Distribution | `BD_NAICS` | OA_Leads_Enrichment |
| Certification Distribution | `BD_Certs` (SBA/socioeconomic) | OA_Leads_Enrichment |
| Lead Sources | `BD_Sources` | OA_Leads_Enrichment |
| Meeting / Campaign / Opportunity Conversion | `BD_Conversion` (×3) | CampaignMember / Opportunity (reuse) |
| Industry Distribution | `BD_Industry` | OA_Leads_Enrichment |
| Top Performing Campaigns / Sources | `BD_Top_Campaigns`, `BD_Top_Sources` | Campaign / OA_Leads_Enrichment |

## 6. Build & deploy order (🔴 gated)
1. **Phase A (report types):** create the 4 report types → **check-only validate** → deploy (🔴). Report types must exist before reports.
2. **Phase B (reports):** build reports in `OA_Executive_Analytics`; custom-report-type reports use `Object$Field` refs, no grouping-in-columns (CLAUDE.md §7) → validate → deploy (🔴).
3. **Phase C (dashboards):** assemble 3 dashboards from the reports; set daily subscription to Louis → deploy (🔴).
4. **Access:** grant via existing `OA_Executive_Analytics_Access` permset — assignment is a separate 🔴 gate.
5. **Render verification:** only possible **post-deploy** — open each dashboard, confirm components resolve. Cannot be verified read-only/check-only.

## 7. Reuse statement
Reuses existing `OA_Executive_Analytics` report + dashboard folders, existing Campaign/Opportunity report types, and the
existing dashboard designs. Net-new = 4 enrichment report types + the reports/dashboards. **No duplicate folder, no
duplicate dashboard, no duplicate object.** CMDT/NC/EC status is surfaced via the existing audit script (not a fabricated
report). This package is deploy-ready for a gated build; **no metadata was deployed this sprint.**
