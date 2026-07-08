# Lead Acquisition — Multi-Source Intelligence Validation (SEC EDGAR Pilot)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (Enterprise, production — verified by ID) · **Branch:** `feature/lead-acquisition-sec-pilot`
**Scope executed (authorized):** deploy the generic driver + create **3 SEC Candidate records** in `OA_Discovered_Organization__c`. **No Leads/Accounts/Contacts touched; no schedules; no automation.** Verdict: **🟢 PASS.**

> Second acquisition source proven through the **Generic Candidate Discovery Driver** (`OA_CandidateDiscovery.run`) with
> no connector-specific code, plus a multi-source comparison against the USASpending candidates.

---

## 1. Org verification (Phase 1)
Org `00Dbn00000plgUfEAI` (prod). Before: Candidates 3 (all USASpending), Leads 13,301, Accounts 1. The 3 USASpending
candidates (`a0qPn00000jySqk/l/m`) remained unchanged throughout.

## 2. SEC connector readiness audit (Phase 2)
| Item | Finding |
|---|---|
| Class / contract | `OA_SEC_Connector` implements `OA_IEnrichmentConnector`; emits `OA_CanonicalOrg` ✅ |
| Registry | `SEC EDGAR` row, class `OA_SEC_Connector`, NC `OA_SEC`, path `/submissions`, Enabled=false |
| Auth / endpoint | public, keyless; SEC requires a descriptive **User-Agent** (set by `OA_SEC_Request`); `data.sec.gov` |
| **Input** | a **CIK** (10-digit, zero-padded) — `/submissions/CIK{cik}.json`. **Lookup-by-CIK, not a search** → 1 org per call |
| Parser output | organization name, **CIK**, business address (street/city/state/zip), website (often blank), **SIC + industry (sicDescription)**, ticker/exchange, state of incorporation, entity type; **no UEI/CAGE/EIN/NAICS** |
| Candidate suitability | Good identity for **public** companies; canonical key = `CIK:…`; confidence HIGH (observed) |
| Completeness contribution | identity + CIK(gov) + full address + entity-type/SIC (profile) ≈ **~40 → Needs Enrichment** |
| Known limitations | requires a **known CIK** (no discovery/search); **SEC rate-limits** rapid sequential callouts (see §6); public filers only (off-ICP for pure federal contractors) |

## 3. Metadata deployed (Phase 3)
Driver `OA_CandidateDiscovery` was **not** deployed → deploy required to run SEC via the driver.
| Item | Value |
|---|---|
| Validation ID | `0AfPn0000023ckLKAQ` |
| **Deployment ID** | **`0AfPn0000023clxKAA`** (Succeeded, checkOnly=false) |
| Files | `OA_CandidateDiscovery.cls` (+meta), `OA_CandidateDiscovery_Test.cls` (+meta) |
| Tests | 6 run / **0 failures** |
| Production changed | Yes — 1 additive Apex class (dormant driver) |

## 4. SEC preview evidence (Phase 4 — 0 DML)
Via `OA_CandidateDiscovery.run('SEC', <CIK>, false, 3)` for 4 defense primes — all HTTP 200, parsed 1, 0 duplicates, **DML=0**:
| CIK | Organization | State | Confidence | Canonical Key | Status |
|---|---|---|---|---|---|
| 0000936468 | LOCKHEED MARTIN CORP | MD | HIGH | CIK:0000936468 | (would) Needs Review |
| 0000012927 | BOEING CO | VA | HIGH | CIK:0000012927 | (would) Needs Review |
| 0001133421 | NORTHROP GRUMMAN CORP /DE/ | VA | HIGH | CIK:0001133421 | (would) Needs Review |
| 0000040533 | GENERAL DYNAMICS CORP | VA | HIGH | CIK:0000040533 | (would) Needs Review |

## 5. SEC Candidate records created (Phase 5)
| Candidate ID | Organization | CIK | State | Confidence | Status | Matched Lead |
|---|---|---|---|---|---|---|
| `a0qPn00000jyyfJIAQ` | LOCKHEED MARTIN CORP | 0000936468 | MD | HIGH | Needs Review | — |
| `a0qPn00000jyblyIAA` | BOEING CO | 0000012927 | VA | HIGH | Needs Review | — |
| `a0qPn00000jyfKwIAI` | NORTHROP GRUMMAN CORP /DE/ | 0001133421 | VA | HIGH | Needs Review | — |

All carry `Source_System__c=SEC`, `Canonical_Key__c` (CIK-based), `Source_Payload_Hash__c`, `Last_Evaluated__c`. Review-queue compatible (`Needs Review`).

**Before/after:** Candidates **3 → 6** (SEC 3 / USASpending 3; == 3-record SEC cap) · **Leads 13,301 unchanged** · **Accounts 1 unchanged** · 0 schedules · no automation enabled.

## 6. Multi-source comparison (Phase 6): SEC vs USASpending
| Question | Answer |
|---|---|
| Overlapping organizations? | **No** in these samples (USASpending = "aerospace" recipients; SEC = defense primes). Even for the same real company, keys differ (`UEI:` vs `CIK:`) → no automatic collision. |
| Fields SEC adds that USASpending lacks | **CIK, full business address, SIC + industry, entity type, ticker/exchange, state of incorporation** |
| Fields USASpending has that SEC lacks | **UEI, award/contract history** (contract intelligence) |
| Did SEC improve completeness? | Adds **location + business-profile** dimensions; complementary — neither alone reaches Campaign Ready |
| Duplicate risk? | **Low within-source** (canonical-key dedup works). **Cross-source risk EXISTS at the real-entity level**: a company with both a UEI and a CIK produces two candidates under different canonical keys — **not caught by `canonicalKey()`** → needs a name/domain crosswalk (fusion gap **G8**) |
| Candidate quality | Comparable — both HIGH confidence; SEC skews to large **public** companies (off pure-federal-contractor ICP); USASpending skews to award recipients (on-ICP) |
| SEC authoritative for | CIK, SIC/industry, business address, entity type, ticker, state of incorporation |
| USASpending authoritative for | UEI, award/contract activity |

**Key architectural finding:** cross-source fusion cannot rely on `canonicalKey()` alone when sources use different
identifier systems (UEI vs CIK). The Phase-4 fusion design (G8) must add an **entity crosswalk** (normalized name +
state, or an external UEI↔CIK map) to merge the same real company across sources. Fusion **not implemented** here (bounded, gated).

## 7. NAICS / industry mapping findings (Phase 7)
| Source | NAICS available? | Evidence |
|---|---|---|
| SEC | **No — provides SIC** (`sic` + `sicDescription`), captured in candidate attributes as `SIC`/`Industry` | `OA_SEC_ResponseParser` lines 35–36 |
| SAM | **No** in the parser's read sections | `OA_SAM_ResponseParser`: "NAICS … are NOT returned by the entityRegistration/coreData sections → left null" |
| USASpending | **No** in the current `spending_by_award` request fields | request builds a fixed field list without NAICS |

**Decision: NO parser change implemented.** No connector currently yields NAICS in a mappable form; **SIC ≠ NAICS**
(different taxonomies — mapping SIC→`NAICS__c` would be semantically incorrect). Populating `NAICS__c` safely would
require either a different SAM API section or a USASpending request-field addition (`naics_codes`) + per-recipient
handling — both need **live verification** and are gated. `NAICS__c` remains intentionally unpopulated; SIC/industry is
already captured on SEC candidates. Gap **G2** stays open with this evidence.

## 8. Production safety verification (Phase 11)
No Lead created/modified; no Account/Contact modified; no campaign automation; no enrichment write-back; no scheduled
jobs; no connector automation enabled (registry rows still Enabled=false — ran via direct driver instantiation); no
Meta/LinkedIn/website changes. SEC candidate inserts = **3 (== cap)**.

## 9. Risks
- **SEC rate-limiting:** rapid sequential callouts (a burst of 3–4) throttle — only the first reliably returns data; retries succeeded. For volume, **space SEC calls** (≤ a few/sec) or use a queueable with delays (gated). Documented, not a data-safety issue.
- SEC requires a known CIK (no search) — for discovery, seed CIKs from a list or resolve name→CIK first.
- Cross-source duplicate risk at the entity level (UEI vs CIK) until fusion crosswalk (G8) is built.
- Runtime user still MAD `oauser` (acceptable for a supervised 3-record pilot).

## 10. Rollback
Reversible: `delete [SELECT Id FROM OA_Discovered_Organization__c WHERE Source_System__c='SEC']` (the 3 SEC rows). No Lead/Account impact; idempotent re-runs via `Source_Payload_Hash__c`.

## 11. PASS / WARN / FAIL — 🟢 PASS
SEC audited + executed through the **generic driver**; preview 0 DML; 3 SEC candidates created (== cap); no Leads/Accounts modified; no schedules/automation; review-queue verified; multi-source comparison documented; NAICS gap analyzed (evidence-based, no unsafe change); evidence source-controlled.

## 12. Recommended next connector
**SAM Entity** — highest incremental value and the natural **fusion** partner (adds UEI+CAGE+registration to complement SEC's CIK/address and USASpending's UEI/awards). Gated on data.gov key + JIT EC principal grant + alpha→prod endpoint. Then build the fusion crosswalk (G8) so the same real company merges across UEI/CIK.

## 13. Next approval gate (🔴 Louis)
SAM credential setup; implement + gated-deploy the fusion crosswalk (G8); a queueable/spaced SEC discovery mode for volume (no scheduling); least-privilege runtime user; any merge to `main`.
