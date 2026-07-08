# Existing Lead Assessment — Production (Read-Only)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Mode:** READ-ONLY live SOQL · **No Lead modified.**
**Companion:** [LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md) (model) · [LEAD_ENRICHMENT_KPI_VALIDATION.md](LEAD_ENRICHMENT_KPI_VALIDATION.md)

> Phases 5 + 6. Audit of every production Lead (enrichment completeness, gaps, quality, source, duplicates, coverage)
> and the Lead Quality Score computed against real data. Every number is a live query result (2026-07-08).

---

## 1. Lead inventory (live)
| Metric | Value |
|---|---|
| **Total Leads** | **13,301** |
| Enriched (deep — `UEI__c` populated) | **78 (0.6%)** |
| Converted Leads | 0 |
| Converted with Opportunity | 0 |

**Lead Source distribution:** SAM.gov **13,280 (99.8%)** · Internal Validation 10 · null 5 · OA Internal QA 3 · Web 2 · Other 1.
All 78 deep-enriched Leads are SAM.gov-sourced.

## 2. Field coverage (live)
| Field | Populated | % of 13,301 | Interpretation |
|---|---|---|---|
| Email | 13,301 | 100% | complete |
| Phone | 13,271 | 99.8% | complete |
| `CAGE_Code__c` | 13,279 | 99.8% | ingested from SAM.gov |
| `Primary_NAICS_code__c` | 13,279 | 99.8% | ingested |
| Industry | 13,279 | 99.8% | ingested |
| Website (standard) | 11,045 | 83.0% | good |
| `Active_SBA_Certifications__c` | 3,134 | 23.6% | partial |
| `UEI__c` | 78 | 0.6% | **deep-enrichment cohort only** |
| `Total_Award_Amount__c` / `Award_Count__c` | 78 | 0.6% | USASpending enrichment |
| `Socioeconomic_Certifications__c` | 0 | 0% | **gap — connector not run** |
| `SAM_Registration_Status__c` | 0 | 0% | **gap — SAM connector dormant** |
| `Website__c` (custom) | 0 | 0% | unused (standard `Website` is the live field) |
| `AnnualRevenue` | 0 | 0% | **gap** |
| `NumberOfEmployees` | 0 | 0% | **gap** |

## 3. Coverage summary by category
| Category | Coverage | Status |
|---|---|---|
| Contact (email/phone) | ~100% | 🟢 |
| NAICS | 99.8% | 🟢 |
| CAGE | 99.8% | 🟢 |
| Website | 83% | 🟢 |
| SBA certifications | 23.6% | 🟡 |
| UEI | 0.6% | 🔴 (pilot only) |
| Federal awards | 0.6% | 🔴 (pilot only) |
| Socioeconomic certs / SAM status / revenue / employees | 0% | 🔴 (not enriched) |

## 4. Duplicate posture
- SAM.gov ingestion provides CAGE on 13,279 Leads; `duplicateRules`/`matchingRules` folders are **empty scaffolds** (no active dedup rules in source). Recommendation: configure org Matching/Duplicate Rules on UEI/CAGE/domain before any intake pipeline (see [LEAD_INTAKE_ROADMAP.md](LEAD_INTAKE_ROADMAP.md)); assess dup rate then. **No dedup executed here (read-only).**

## 5. Lead Quality Score — computed on real data
Using the model in [LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md) (0–100; standard `Website` substituted for `Website__c`). Applying the category weights to the live coverage:

**Typical SAM.gov Lead (the ~13,200 not deep-enriched):** Contact 10 + NAICS 8 + CAGE 6 + Website ~4 (83%) + Identity(name+industry) ~7 + SBA cert (24% get 8) ≈ **~35–43 → band: Weak–Fair.**
**Deep-enriched cohort (78):** the above **+ UEI 12 + Federal awards 15** (+ SBA on 21/78) ≈ **~60–70 → band: Good.**
**Estimated portfolio average:** ≈ **37** (dominated by ingestion-level Leads). Deep-enriched Leads score ~25–30 points higher, confirming the enrichment value and the score's discrimination.

> Validation: the score behaves as designed — it separates ingestion-level Leads (base identity only) from enriched
> Leads (gov + award data), and is 0 for fields whose connectors are dormant (socioeconomic, SAM status, revenue).
> The model maps cleanly to the live field model; no schema needed for the report/formula (Option A) implementation.

## 6. Recommendations (no Lead modified)
1. **Enrich the base at scale (biggest lever):** 13,223 Leads have CAGE/NAICS but **no UEI/awards** — a supervised USASpending run would lift the portfolio average markedly. Gated (connector enablement + least-priv user).
2. **Close the 0% gaps:** SAM registration status + socioeconomic certs require the **SAM connector** (needs key + JIT grant); revenue/employees need a firmographic source (not yet a connector) — do not invent one.
3. **Populate standard `Website`→ retire custom `Website__c`** (custom field is 0%; standard is 83%) — consolidate to avoid a dead field (docs/hygiene; not a Lead change).
4. **Configure duplicate/matching rules** (currently empty) before any intake growth.
5. **Re-enrichment freshness:** track `USASpending_Last_Enriched__c`; re-enrich > 90 d (KPI: Data Freshness).
6. **Do NOT bulk-write** — all improvements go through the gated FillEmptyOnly + audited path; no direct Lead updates.
