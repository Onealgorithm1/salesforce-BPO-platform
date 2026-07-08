# Lead Acquisition — Candidate KPI Framework (Phase 6)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** design + one additive report type (validated); dashboards/reports = extend existing analytics
**Reuses:** existing `OA_Executive_Analytics` folders + the Lead-Enrichment analytics package (RC1) · candidate data from `OA_Discovered_Organization__c`

> Phase 6. Candidate metrics computed from the existing candidate object + telemetry. **No duplicate dashboards.** The
> Candidate report type is the only new metadata; candidate reports/dashboards extend the existing analytics package
> (built in RC1 / PR #31) once it merges — same folder, same pattern, two-phase deploy.

---

## 1. New metadata (this sprint): Candidate report type
`OA_Discovered_Organizations` (base `OA_Discovered_Organization__c`) — **check-only validated GREEN** (`0AfPn0000023bY9KAI`,
0 errors, 1 component). Non-duplicative (no report type existed for this object). Enables all candidate reports below.

## 2. Candidate KPIs (from existing objects; no new schema)

| KPI | Formula | Source | Target | Warning | Critical | Business purpose |
|---|---|---|---|---|---|---|
| **Candidates Discovered** | `COUNT(OA_Discovered_Organization__c)` in window | candidate obj | grow | — | 0 (source dry) | acquisition volume |
| **Candidates Approved** | `COUNT(Qualification_Status__c='Approved')` | candidate obj | ≥ 40% of discovered | < 25% | < 10% | qualified yield |
| **Duplicate Rate** | `COUNT(Status='Duplicate') ÷ discovered` | candidate obj | 10–30% (healthy) | > 50% | > 70% | source overlap/quality |
| **Lead Creation Rate** | `Leads created from candidates ÷ Approved` | candidate/Lead | ≥ 90% of approved | < 75% | < 50% | approval→Lead throughput |
| **Average Review Time** | `AVG(reviewed − CreatedDate)` for reviewed candidates | candidate obj | < 3 d | > 7 d | > 14 d | review responsiveness |
| **Source Quality** | `Approved ÷ discovered` by `Source_System__c` | candidate obj | per-source baseline | — | — | which sources yield keepers |
| **Source Yield** | `Candidates discovered ÷ run` by source | candidate obj + `OA_Connector_Run__c` | per-source baseline | — | — | discovery efficiency |
| Confidence Distribution | `Source_Confidence__c` HIGH/MED/LOW split | candidate obj | monitor | — | — | trust in discovery |
| Needs-Review Backlog | `COUNT(Status='Needs Review')` | candidate obj | < 20 open | > 50 | > 100 | review queue health |

## 3. Candidate reports (design — build in `OA_Executive_Analytics`, on the new report type)
`CAND_Discovered_By_Source`, `CAND_Status_Funnel` (Discovered→Approved→Duplicate→Rejected), `CAND_Duplicate_Rate`,
`CAND_Review_Age`, `CAND_Source_Yield`, `CAND_Confidence_Distribution`. Each groups the candidate object by the relevant
field with record count (same proven pattern as the RC1 LE_ reports).

## 4. Candidate dashboard (design — extend, do not duplicate)
Add a **"Lead Acquisition" section/components to the existing analytics** (reuse `OA_Executive_Analytics` dashboard folder;
optionally a `Lead_Acquisition.dashboard` alongside the RC1 dashboards). Components (Metric/Table, proven schema): Candidates
Discovered, Approved, Duplicate Rate, Needs-Review backlog, Source Yield, Confidence distribution. **No new folder.**

## 5. Deploy note (two-phase, gated)
Report type (validated, ready) → candidate reports → candidate dashboard. Same two-phase order and gates as the RC1
analytics package. Nothing deployed this sprint beyond the (un-deployed, validated) report type on the feature branch.
