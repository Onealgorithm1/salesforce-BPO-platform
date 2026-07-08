# Lead Acquisition — Lead Completeness Model (Phase 3, design only)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** scoring-framework design (no implementation, no auto-enrichment)
**Reuses:** existing candidate/Lead fields + relates to [LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md) (do not duplicate that engine).

> A reusable, connector-agnostic **0–100 Lead Completeness Score** measuring whether a Candidate/Lead is ready for
> campaign outreach. Design only — computed via report/formula over existing fields; **no automatic enrichment**.

---

## 1. Weighted model (sums to 100)

| # | Dimension | Signals (existing fields) | Weight | Scoring |
|---|-----------|---------------------------|--------|---------|
| 1 | Identity | Organization/Normalized Name | 10 | present = full |
| 2 | Government identifiers | UEI / CAGE / EIN / CIK | 20 | UEI 10 + CAGE 5 + (EIN|CIK) 5 |
| 3 | Location | Address + City + State + Postal | 12 | proportion populated |
| 4 | Website | Website | 10 | present + valid host |
| 5 | Industry | NAICS | 10 | present |
| 6 | Contract intelligence | Federal_Contractor / Total_Award / Award_Count / Awarding_Agencies | 15 | proportion (weighted to award value) |
| 7 | Business profile | AnnualRevenue / NumberOfEmployees / Entity Type / socioeconomic certs | 13 | proportion populated |
| 8 | Contact readiness | Email + Phone | 10 | Email 6 + Phone 4 |
| | **Total** | | **100** | |

## 2. Bands (as specified)
| Score | Band | Meaning |
|---|---|---|
| **90–100** | **Campaign Ready** | complete identity + contact + firmographics → eligible for outreach |
| **70–89** | **Review** | strong but missing some dimensions → human review |
| **< 70** | **Needs Enrichment** | route to Lead Enrichment before outreach |

## 3. How connectors score at acquisition (from the field matrix)
| Source | Typical acquisition-time completeness | Band |
|---|---|---|
| SAM Entity | Identity+GovID(UEI+CAGE)+Location+Website (~55–65, no contract/contact/industry yet) | Needs Enrichment → Review |
| USASpending | Identity+UEI+State+Contract (~40–50; no address/website/contact) | Needs Enrichment |
| SEC | Identity+CIK+Location+Website (~40; no UEI/contract) | Needs Enrichment |
| IRS | Identity+EIN+Location (~30; no website/contract) | Needs Enrichment |

**Implication:** acquisition candidates almost always land as **Needs Enrichment** — which is correct: acquisition
establishes identity; **Lead Enrichment then fills contract/firmographic/contact fields** to lift the score toward
Campaign Ready. The two programs compose cleanly.

## 4. Relationship to the existing Enrichment Quality Score (no duplication)
`LEAD_ENRICHMENT_QUALITY_SCORE.md` measures **enrichment completeness on Leads**; this **Lead Completeness Score**
measures **campaign-readiness across the full acquisition→enrichment lifecycle**. They share fields and bands; recommend
implementing **one** shared scoring utility (report formula / optional CMDT weights) parameterized by context, rather
than two engines. Default implementation = report/formula (no new schema), consistent with prior decisions.

## 5. Constraints honored
Design only. No score field created, no Apex, no automatic enrichment, no Lead creation. Implementation (report/formula
or a gated persisted field) is a future sprint.
