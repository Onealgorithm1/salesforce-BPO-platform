# Lead Acquisition — Enterprise Operational Readiness (Phase 11)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-operational-readiness`
**Mode:** assessment (documentation only) · **No code change; no new metadata; no data/Lead/Account change; no automation; no scheduling.**
**Builds on (does not duplicate):** [LEAD_ACQUISITION_CONNECTOR_READINESS.md](LEAD_ACQUISITION_CONNECTOR_READINESS.md) (Phase 9) · [LEAD_ACQUISITION_ENGINEERING_ASSESSMENT.md](LEAD_ACQUISITION_ENGINEERING_ASSESSMENT.md) (Phase 10).

> Definitive operational-readiness assessment. New substance: a **data-driven Candidate Quality Framework** (measured
> against the 6 live pilot candidates) and an **executive Business Readiness** Q&A. Connector certification, volume,
> and closeout reference the Phase 9/10 artifacts with deltas only.

---

## 1. Enterprise connector certification (Phase 1) — confirmed vs Phase 9/10 (no change)
| Connector | Classification | Evidence |
|---|---|---|
| USASpending | 🟢 **CERTIFIED** | deployed, live pilot (3 candidates), public NoAuth, mature parser |
| SEC EDGAR | 🟢 **CERTIFIED** (space calls at volume) | deployed, live pilot (3 candidates); burst throttle documented |
| SAM Entity | 🟡 **READY AFTER CONFIGURATION** | class+parser+registry ready; needs data.gov key + JIT EC grant + alpha→prod |
| IRS Tax-Exempt | 🟠 **REQUIRES ENGINEERING** | connector present; bulk-CSV discovery path not built |
| Census | ⚪ **DEFERRED** | not an organization registry |
| State Registry | ⚪ **DEFERRED** | template only |
| Website | ⚪ **DEFERRED / OUT OF SCOPE** | not this program |
| LinkedIn / Meta | ⚪ **AUDIT-ONLY (never a discovery source)** | OAuth-live but ToS prohibits scraping; own-account data only |
| Future federal/commercial | **onboard via lifecycle** | 3-step standard (implement interface → registry row → run) |

## 2. Candidate Quality Framework (Phase 2) — measured on the 6 live candidates
**Live measurement (2026-07-08):**
| Metric | Value |
|---|---|
| Candidates | 6 (3 USASpending, 3 SEC) |
| Confidence | **100% HIGH** (6/6) |
| Duplicate rate | **0%** (0 Duplicate; 0 Matched_Lead) |
| Strong-identifier coverage | **100%** carry exactly one (UEI ×3, CIK ×3); CAGE 0, EIN 0 |
| **Cross-source coverage** | **0%** (no org has ≥2 source identifiers — fusion not yet exercised in prod) |
| Firmographic depth | Website 0, NAICS 0; Address 3 (SEC only); awards on USASpending (attributes) |
| Review readiness | 100% `Needs Review` (correct — none auto-created as Leads) |

**Interpretation:** candidates are **identity-complete but firmographically thin** — each has a name + one deterministic
ID + partial location, so all correctly land as `Needs Review` and would score <70 (Needs Enrichment) on
`OA_LeadCompleteness`. This is by design: acquisition establishes identity; SAM fusion + Lead Enrichment fill the rest.

**Recommended Candidate Quality KPIs (documented, not implemented):**
| KPI | Formula | Target |
|---|---|---|
| Candidate Completeness % | avg `OA_LeadCompleteness` score | ≥ 60 after fusion |
| Confidence Distribution | HIGH/MED/LOW split | ≥ 80% HIGH |
| Duplicate Rate | Duplicate ÷ discovered | 10–30% (healthy overlap) |
| Strong-Identifier Coverage | % with UEI/CAGE/CIK/EIN | ≥ 95% |
| **Cross-Source Coverage** | % orgs with ≥2 source identifiers (fused) | grows as sources added |
| Fusion Lift | avg completeness gain per fusion | > 0 (pilot: +18) |
| Review Queue Age | avg age of `Needs Review` | < 3 d |
| Source Yield / Quality | discovered-per-run / approved-per-discovered by source | per-source baseline |

## 3. Connector performance certification (Phase 3)
| Concern | Status | Evidence |
|---|---|---|
| Retry / backoff | ❌ not built | connectors return non-2xx on `OA_ConnectorResult` (no throw); no auto-retry → belongs in the gated fetch layer |
| Throttling | SEC bursts throttle | documented (Phase 6); space calls / queueable |
| Timeout | ✅ | `setTimeout(30000)` in requests |
| Error recovery | ✅ (surfaced) | httpErrors/parseErrors counts on result; orchestrator stops on Failed |
| Logging / telemetry | ✅ | `OA_Connector_Run__c` + messages |
| Batch / queueable suitability | 🟡 | pipeline bulk-safe; **fetch orchestration not built** |
**Low-risk reusable improvement made this sprint:** none. A retry/spacing helper is only safe as part of the **reusable
gated fetch layer** (E1) — implementing it now would either touch deployed connectors (not low-risk) or be connector-
specific (prohibited). Documented as E1; no code change.

## 4. Production volume readiness (Phase 4)
| Volume | Ready? | Blocker |
|---|---|---|
| Tens (pilot) | 🟢 | proven |
| Hundreds | 🟢 pipeline / 🟡 fetch | `resolveAll` bulk (≤5 SOQL/50 orgs); connector-fetch spacing for SEC |
| Thousands | 🟡 | needs queueable/batch **fetch** orchestration (E1) + off-peak spacing |
| Scheduled discovery | 🔴 | no scheduler (deliberate) + least-priv user + monitoring |
Governor posture: SOQL bulk-safe (per-record eliminated, Phase 9); DML batched; heap/CPU small (sub-second pilots);
**callout/fetch volume is the one remaining scalability item** — no safe refactor outstanding (SOQL/DML already optimized).

## 5. Operational governance (Phase 5) — 🟢 PASS
| Control | Status |
|---|---|
| Audit coverage | ✅ `OA_Connector_Run__c` + change logs + candidate records |
| Rollback | ✅ staging rows deletable/reversible; idempotent (`Source_Payload_Hash__c`); no Lead/Account writes |
| Review workflow | ✅ `Qualification_Status__c` + `OA_Enrichment_Exception__c` (single queue) |
| Source provenance | ✅ `Discovery_Metadata__c` JSON `sources[]` |
| Confidence preservation | ✅ fusion keeps strongest; never downgrades |
| Completeness preservation | ✅ fill-empty never overwrites populated data |
| Identity traceability | ✅ `Canonical_Key__c` + matched identifiers + rationale |
| Fusion traceability | ✅ provenance per fusion |
**Gaps:** none in governance. (Firmographic depth is a data-source limitation, not a governance gap.)

## 6. Business readiness (Phase 6) — executive Q&A (evidence-based)
| Question | Answer | Evidence |
|---|---|---|
| **Activate first?** | **SAM Entity** (highest value) once credentials; **SEC EDGAR** as the immediate no-gate parallel; USASpending already certified/proven | field matrix + pilots |
| **Greatest business value?** | **SAM** — authoritative federal registry (UEI+CAGE+registration+socioeconomic) = the federal-contracting ICP | `CONNECTOR_MATRIX` |
| **Greatest enrichment value?** | **SAM** — fills the most identity fields; the best fusion partner (adds CAGE/address/website/phone to UEI candidates) | pilot completeness 23→41 |
| **Best acquisition value?** | **USASpending** — award recipients are active federal spenders = strongest pursue-intent signal | pilot (award recipients) |
| **Never automate?** | **LinkedIn, Meta** (ToS/compliance — no scraping; audit-only) and **Census** (not an org registry) | compliance notes |
| **Permanent human review?** | **All Candidate→Lead creation**; every `REVIEW` (ambiguous) match; any low-identifier-quality (name-only) source | identity thresholds |

## 7. Release roadmap (Phase 7) — explicit approval gates
| Stage | Scope | 🔴 Gate |
|---|---|---|
| **1 — Manual connector expansion** | SAM pilot (first committed fusion) → additional sources via lifecycle; preview→commit | Louis approval per connector + SAM credential |
| **2 — Controlled automation** | queueable/spaced fetch (E1) + least-priv user → scheduled discovery | Louis approval + user provisioned + E1 built |
| **3 — Production monitoring** | deploy candidate reports/dashboards + alerts | Louis approval + metadata deploy |
| **4 — Executive KPI deployment** | surface Candidate Quality KPIs (§2) to leadership | Louis approval |
| **5 — Business Development Operating System** | candidate→Lead→campaign→meeting→opportunity lifecycle instrumentation | Louis approval (program-level) |

## 8. Engineering closeout (Phase 8) — backlog separated (non-code removed from engineering)
- **Engineering (code):** E1 spaced/queueable fetch layer + SEC throttle; E2 NAICS mapping (needs live API verify); E3 IRS bulk-CSV discovery; E4 candidate reports/dashboards.
- **Configuration:** SAM NC endpoint alpha→prod; org Matching/Duplicate Rules; connector registry `Enabled__c` toggles (gated).
- **Administration:** SAM data.gov key; JIT EC principal grant; least-privilege user (license); PR merges; Louis approvals.
- **Operations:** monitoring wiring; review-queue staffing; run cadence.
- **Activation (🔴):** connector enablement; committed writes; scheduling; automation.
- **Future enhancements:** field-precedence fusion config; UEI↔CIK external crosswalk; more sources.
**Removed from engineering backlog** (not code): SAM key, JIT grant, least-priv user, merges, approvals, endpoint config.

## 9. Final objective — definitive answers (evidence-based)
1. **Is Lead Acquisition engineering complete?** — **Foundation COMPLETE** (5 classes deployed dormant, bulk-safe, 0 debt; deploys `0AfPn0000023dJpKAI`/`0AfPn0000023drhKAA`). **Not the full roadmap:** E1–E4 remain, none blocking controlled manual expansion.
2. **Ready for enterprise-scale connector onboarding?** — **Yes, configuration-first for the pipeline** (a new source = interface + registry row + run, all downstream shared/bulk-safe). **Not yet for high-volume fetch/automation** (E1 fetch orchestration + least-priv user).
3. **What engineering work remains?** — only E1 (fetch orchestration/throttle), E2 (NAICS, live-verify), E3 (IRS bulk), E4 (candidate dashboards). That is the entire code backlog.
4. **What is configuration/administration only?** — SAM key, JIT EC grant, endpoint alpha→prod, least-priv user, matching-rule config, PR merges, approvals. None is code.
5. **Next major program after operational readiness?** — complete acquisition (Stage 1 SAM + sources), then the platform's documented next program **Opportunity Intelligence** (ADR-015), separate and gated; longer-term, Stage 5 Business Development Operating System ties acquisition→enrichment→campaign.

## 10. PASS / WARN / FAIL — 🟢 PASS
All connectors classified; Candidate Quality KPIs defined (data-driven); performance certified; volume readiness assessed; governance verified (PASS); business readiness documented; engineering backlog separated from operational/administrative. No unnecessary metadata; no data/Lead/Account change; no connector activation; no scheduling. **WARN:** E1–E4 engineering + SAM configuration/administration remain for expansion/automation (all documented, gated). 🔴 none.

## 11. Evidence / governance
No source change this sprint (documentation only). Production Apex unchanged since `0AfPn0000023drhKAA` (Phase 9). Live data: 6 candidates (100% HIGH, 0% duplicate, 100% single-strong-ID, 0% cross-source), 13,301 Leads, 1 Account — unchanged. Stacked Lead-Acquisition PRs #33–#43 open; this is #44.
