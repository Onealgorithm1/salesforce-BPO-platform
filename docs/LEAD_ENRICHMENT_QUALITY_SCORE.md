# Lead Enrichment — Quality Score (Configurable Model)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Status:** design/build-ready (not deployed; no schema change without a 🔴 gate)
**Reuses:** existing deployed Lead fields (verified live) · **Distinct from:** `Compatibility_Score__c` (AI fit, unpopulated — TD-005) and KPI-17 "Data Quality Score" (run-health composite). This score = **per-Lead enrichment completeness/quality, 0–100.**

> A configurable, explainable score measuring how complete and trustworthy a Lead's enrichment is. It maps **only to
> fields already deployed in production** (verified by live describe) — no invented fields. Two implementation options
> are given; the default (Option A, report/formula) adds **no new object and no persisted field**, honoring
> reuse-before-build and "no new infrastructure." Weights are configurable.

---

## 1. Category model (weights sum to 100)

| # | Category | Signal (existing Lead field, live-verified) | Weight | Scoring rule |
|---|---|---|---|---|
| 1 | Company Identity | `Name`, `Website__c`/`Website`, `Entity_Type__c` | 10 | proportion of the 3 populated |
| 2 | Contact Data | `Email`, `Phone`, `Title`/contact name | 10 | proportion populated |
| 3 | Website | `Website__c` or standard `Website` present + valid host | 5 | full if present |
| 4 | NAICS | `Primary_NAICS_code__c` | 8 | full if present |
| 5 | UEI | `UEI__c` + `UEI_Verification_Status__c` = verified | 12 | 6 if present, +6 if verified |
| 6 | CAGE | `CAGE_Code__c` | 6 | full if present |
| 7 | Government / SAM data | `SAM_Registration_Status__c` (Active) + not-expired (`SAM_Registration_Expiration__c`) | 10 | 5 if registered, +5 if active/unexpired |
| 8 | Socioeconomic Certifications | `Socioeconomic_Certifications__c` / `Active_SBA_Certifications__c` | 8 | full if any present |
| 9 | Revenue | `AnnualRevenue` (standard) | 5 | full if > 0 |
| 10 | Employees | `NumberOfEmployees` (standard) | 5 | full if > 0 |
| 11 | Federal Awards | `Federal_Contractor__c` + `Total_Award_Amount__c` + `Award_Count__c` + `Latest_Award_Date__c` | 15 | proportion of the 4 populated (weighted to award value) |
| 12 | Active Opportunities | linked `OA_Opportunity_Signal__c` (future / OI) | 6 | full if ≥1 (0 until OI live) |
| | **Total** | | **100** | |

**Bands:** 0–29 Poor · 30–44 Weak · 45–59 Fair · 60–79 Good · 80–100 Excellent. (Aligns with the KPI-Framework Avg-Quality thresholds: target ≥ 60, warning < 45, critical < 30.)

## 2. Configurability
Weights and the "present/verified" rules must be tunable without code change:
- **Config store (design):** a Custom Metadata Type `OA_Quality_Weight__mdt` (Category, Weight, Field_API_Name, Rule) — **one small CMDT, reusing the platform's existing CMDT-config pattern** (like `OA_Field_Write_Policy__mdt`), not a new framework. Records are data, tunable in Setup.
- Until deployed, the weights table above is the source of truth (a report can hard-map them).

## 3. Implementation options (choose at the gated build)
- **Option A — Report/formula only (DEFAULT, no new schema):** compute the score in a report formula (or a Lead **formula field**) from the existing fields. **No new object, no data write, no batch.** Cannot be filtered server-side if formula-in-report, but sufficient for the dashboard gauge (E13) and Lead Source performance (E14). Zero infrastructure.
- **Option B — Persisted field + Apex (gated, only if server-side filtering/rollups are required):** add `Enrichment_Quality_Score__c` (Number 0–100) + `OA_Quality_Weight__mdt` + a scoring method invoked in the **existing** `OA_EnrichmentWriter`/orchestrator path (reuse — no new pipeline). Requires: new field + FLS permset bundle (CLAUDE.md §7), CMDT, Apex, tests, and a 🔴 deploy. Recommended only after the dashboard proves the score is needed persisted.

**Recommendation:** ship **Option A** (formula) with the dashboard; defer Option B until there's a concrete need to filter/rollup on the score. This keeps the epic closeout free of new infrastructure.

## 4. Explainability & governance
- The score is **transparent** (each category maps to named fields + a simple rule) — no opaque AI in v1.
- It is **read-only/derived** — it measures enrichment, never triggers a write or a campaign action.
- Categories 5/7/8/11 depend on connectors that are currently dormant; scores rise as connectors are enabled and Leads are enriched (expected).
- Distinct from `Compatibility_Score__c` (buyer-fit, AI, separate program) — do not overload that field.

## 5. Reuse statement
Maps to 100% existing, deployed Lead fields (live-verified). Default implementation adds **no object and no field**.
Optional persisted variant reuses the existing CMDT-config pattern and the existing writer path — no new connector
framework, no new pipeline.
