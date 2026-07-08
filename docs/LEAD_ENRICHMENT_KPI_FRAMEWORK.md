# Lead Enrichment — KPI Framework (Operations)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Status:** operational framework (measurement layer; no schema change)
**Reuses:** [KPI_CATALOG.md](KPI_CATALOG.md) (definitions) · [KPI_BASELINE.md](KPI_BASELINE.md) (measured values) · [MONITORING_AND_ALERTS.md](MONITORING_AND_ALERTS.md) (alerts)
**Surfaced by:** [DASHBOARD_EXECUTIVE.md](DASHBOARD_EXECUTIVE.md) · [LEAD_ENRICHMENT_OPERATIONS_GUIDE.md](LEAD_ENRICHMENT_OPERATIONS_GUIDE.md)

> This is the **operations framework layer** on top of the existing KPI catalog. The catalog defines *what* each KPI
> is and *how* it's computed; this doc adds the missing operational contract for each: **Formula · Source Object ·
> Refresh Method · Target · Warning Threshold · Critical Threshold.** All KPIs derive from existing objects
> (`OA_Connector_Run__c` = CR, `OA_Enrichment_Change_Log__c` = CL, `OA_Enrichment_Exception__c` = EX, `Lead`,
> `CampaignMember` = CM, `Opportunity`) — **no new schema.** Thresholds are starting values for the dormant→pilot phase;
> tune from `KPI_BASELINE.md` after the first pilots.

---

## 1. Operational (platform-health) KPIs

| KPI | Formula | Source | Refresh | Target | Warning | Critical |
|---|---|---|---|---|---|---|
| Lead Completeness % | avg(populated target fields ÷ target fields) per enriched Lead | Lead | daily | ≥ 80% | < 70% | < 50% |
| Average Fields Added | `COUNT(CL Enrich) ÷ distinct enriched Leads` | CL | daily | ≥ 5 | < 3 | < 1 |
| Average Processing Time | `AVG(CR.Ended−Started) ÷ CR.Requested` | CR | weekly | < 300 ms/Lead | > 1 s | > 5 s |
| Connector Success Rate | `CR Succeeded ÷ CR total` | CR | daily | ≥ 98% | < 95% | < 90% |
| Connector Failure Rate | `CR (Failed+PartialErrors) ÷ CR total` | CR | daily | ≤ 2% | > 5% | > 10% |
| Review Queue Age | `AVG(NOW − EX.CreatedDate)` for open EX | EX | daily | < 3 d | > 7 d | > 14 d |
| Average Approval Time | `AVG(EX.Resolved − EX.Created)` | EX | weekly | < 2 d | > 5 d | > 10 d |
| Duplicate Detection Rate | `dupes flagged ÷ candidates` (intake — future) | Discovered Org | per-run | monitor | — | — |
| Data Freshness | `AVG(NOW − USASpending_Last_Enriched__c)` | Lead | weekly | < 90 d | > 180 d | > 365 d |
| Dashboard Refresh Health | last successful dashboard refresh age | Dashboard | daily | < 24 h | > 48 h | > 72 h |
| Rollback Success % | `restored ÷ attempted` | CL | on-event | 100% | < 100% | any fail |
| Audit Consistency | `distinct enrich-log Leads = enriched Leads` AND `logs = Leads×fields` | CL/Lead | daily | = 100% | < 100% | any orphan |

## 2. Business-value KPIs

| KPI | Formula | Source | Refresh | Target | Warning | Critical |
|---|---|---|---|---|---|---|
| Meeting Conversion % | `Meetings (CM 'Meeting Booked') ÷ enriched Leads in campaign` | CM/Lead | weekly | ≥ 5% | < 2% | < 1% |
| Campaign Conversion % | `responded members ÷ members` | CM | weekly | ≥ 10% | < 5% | < 2% |
| Opportunity Conversion % | `Opportunities from enriched Leads ÷ enriched Leads` | Opportunity/Lead | monthly | ≥ 2% | < 1% | ~0% |
| Federal Contractor Coverage | `COUNT(Lead Federal_Contractor__c=true) ÷ enriched Leads` | Lead | weekly | monitor | — | — |
| Avg Enrichment Quality Score | `AVG(Enrichment_Quality_Score 0–100)` | Lead | daily | ≥ 60 | < 45 | < 30 |

## 3. Governance
- **Refresh methods:** "daily" = report subscription / audit script; "weekly"/"monthly" = scheduled report; "on-event" = triggered by a rollback run. No new scheduled Apex is introduced by this framework (reporting only).
- **Must-be-zero (hard safety, from MONITORING_AND_ALERTS):** active Overwrite policies · writes-without-snapshot · audit-consistency < 100% · unauthorized enabled connectors → any breach = Critical.
- **Ownership:** Ops works platform KPIs daily; Owner (Louis) reviews business KPIs weekly/monthly (see Operations Guide).
- **Baseline anchor (dormant, 2026-07-08):** 78 enriched Leads · 18 runs · 474 change logs · 1 exception · 0 rollbacks — thresholds above are pre-pilot starting points; recalibrate against `KPI_BASELINE.md` after the 25/100-Lead pilots.

## 4. Reuse statement
No new objects, fields, or KPIs duplicated. This framework references the 24 catalog KPIs and adds only the
operational threshold contract + 5 business-value KPIs computed from existing campaign/opportunity objects. The
quality-score KPI is defined in [LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md).
