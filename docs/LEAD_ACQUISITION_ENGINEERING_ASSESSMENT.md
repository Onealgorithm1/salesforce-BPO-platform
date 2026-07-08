# Lead Acquisition — Engineering Assessment & Expansion Readiness (Phase 10)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-expansion-readiness`
**Mode:** audit + assessment (documentation only) · **No code change; no new metadata; no data/Lead/Account change; no automation; no scheduling.**

> Definitive, evidence-based engineering assessment of the Lead Acquisition platform. Every conclusion cites repository,
> validation, deployment, or live-org evidence.

---

## 1. Repository audit (Phase 1)
| Component | Class | Lines | Deployed | Findings |
|---|---|---|---|---|
| Discovery driver | `OA_CandidateDiscovery` | 89 | ✅ | clean |
| Candidate service | `OA_CandidateDiscoveryService` | 145 | ✅ | identity + fusion integrated |
| Identity resolution | `OA_IdentityResolution` | 224 | ✅ | bulk-safe (`resolveAll`) |
| Fusion engine | `OA_SourceFusion` | 89 | ✅ | fill-empty + provenance |
| Lead completeness | `OA_LeadCompleteness` | 88 | ✅ | pure scorer |
| Canonical / registry / connectors / review / audit | reused (`OA_CanonicalOrg`, `OA_Connector_Registry__mdt`, `OA_IEnrichmentConnector`, `OA_Enrichment_Exception__c`, `OA_Connector_Run__c`) | — | ✅ | reused, not duplicated |

- **TODO/FIXME/XXX/HACK:** **none** in Lead-Acquisition classes.
- **Dead code / obsolete classes:** none (635 total lines; all reachable; each class single-purpose).
- **Duplicated logic:** none — one identity path, one fusion engine, one completeness scorer, one driver.
- **Incomplete implementations:** none in the foundation (all validated + tested).
- **Fixes made:** none required (no low-risk issue found that warrants re-touching a deployed class).

## 2. Remaining gap closure (Phase 2)
| Gap | Safe to close now? | Decision (evidence) |
|---|---|---|
| **G2 NAICS mapping** | ❌ | No source yields NAICS mappably: SEC exposes **SIC** (`OA_SEC_ResponseParser` l.35), SAM's read sections **exclude NAICS** (`OA_SAM_ResponseParser` l.19/75), USASpending request omits it. SIC≠NAICS. Requires a different SAM section or a USASpending request-field change → **live-verify, gated. Deferred.** |
| Parser improvements | partial | Parsers are mature for the certified sources; NAICS aside, no defect found. Deferred to per-source needs. |
| Fusion edge cases | ✅ addressed | fill-empty never overwrites; conflicts retained in provenance; corroboration confidence; multi-source accumulation into one record (batch-map). Unit-tested. |
| Identity scoring refinements | ✅ addressed | cross-identifier + domain + name+state (REVIEW) + thresholds; bulk-safe. |
| Connector error handling | ✅ (existing) | connectors return non-2xx on `OA_ConnectorResult` (never throw); driver surfaces telemetry. |
| Retry / spacing | ❌ (deferred) | **SEC bursts throttle** — needs a spaced/queueable fetch layer (pre-automation, gated). |
| Provenance | ✅ addressed | `Discovery_Metadata__c` JSON `sources[]` + `Source_Payload_Hash__c`. |
| Candidate quality | ✅ measurable | Lead Completeness (0–100) live. |

**Net:** every gap that is safely closable without production activation or unverified API changes is closed; the rest
(NAICS live-verify, spaced-fetch orchestration) is gated/pre-automation and documented with evidence.

## 3. Enterprise connector certification (Phase 3)
| Connector | Engineering | Auth | Parser | Canonical map | Completeness contrib | Fusion contrib | Dup risk | Op readiness | **Classification** |
|---|---|---|---|---|---|---|---|---|---|
| **USASpending** | complete | public NoAuth ✅ | mature, live-proven | UEI+name+state+awards | contract intel | UEI anchor | low | proven (3 candidates) | **🟢 CERTIFIED** |
| **SEC EDGAR** | complete | public + User-Agent ✅ | mature, live-proven | CIK+name+address+website+SIC | location+profile | CIK anchor | low (diff namespace) | proven (3 candidates); **burst throttle** | **🟢 CERTIFIED (space calls at volume)** |
| **SAM Entity** | complete | SecuredEndpoint (key+JIT pending) 🟡 | mature | UEI+CAGE+address+website+phone | highest identity lift | **UEI/CAGE — best fusion partner** | low | needs credential | **🟡 READY AFTER CONFIGURATION** |
| **IRS Tax-Exempt** | connector present; **bulk-CSV discovery path not built** | none | present | EIN+name+address | modest (nonprofit) | EIN anchor | low | not run | **🟠 REQUIRES ENGINEERING** (bulk ingestion) |
| **Census** | present | public | present | none | none | none | n/a | n/a | **⚪ DEFERRED** (not an org registry) |
| **State Registry** | template only | varies | template | scaffold | — | — | — | — | **⚪ DEFERRED** (template) |
| **Future template** | lifecycle §3 | — | — | — | — | — | — | onboard via 3-step | **standard** |

Evidence: pilots (`LEAD_ACQUISITION_PRODUCTION_PILOT.md`, `LEAD_ACQUISITION_MULTI_SOURCE_VALIDATION.md`), parser inspection (`LEAD_ACQUISITION_CONNECTOR_MATRIX.md`), SAM checklist (`LEAD_ACQUISITION_CONNECTOR_READINESS.md`).

## 4. Operational readiness (Phase 4 — verified, not enabled)
| Capability | Ready | Evidence |
|---|---|---|
| High-volume discovery (pipeline) | 🟢 | bulk `resolveAll` (≤5 SOQL/50 orgs), batched DML |
| High-volume **fetch** | 🟡 | needs spaced/queueable layer (SEC throttle) — gated |
| Batch / queueable execution | 🟡 | supported by design; **not built/enabled** |
| Rollback | 🟢 | staging rows; idempotent; no Lead/Account writes |
| Auditing | 🟢 | telemetry + provenance + change logs |
| Monitoring | 🟡 | telemetry queryable; candidate dashboards designed, not deployed |
| Review workflow | 🟢 | `Qualification_Status__c` + `OA_Enrichment_Exception__c` |
| Connector isolation | 🟢 | interface + registry; no source-specific pipeline logic |
| Production safety | 🟢 | preview-first, commit-gated, candidate-only writes; 6 candidates, Leads/Accounts untouched |

## 5. Governance review (Phase 5) — 🟢 PASS
- **No new custom object; no new field** created by the entire Lead Acquisition epic (verified: `git diff main` on objects = empty). Reused `OA_Discovered_Organization__c` end-to-end.
- **One** LA-specific report type (`OA_Discovered_Organizations`); no duplicate metadata.
- **No connector-specific framework logic** — driver/service/resolution/fusion are all connector-agnostic.
- **Reusable services only.**
- **Program separation intact:** no Lead-Acquisition class references Lead-Enrichment write-back, Opportunity Intelligence, or Campaign automation (the only grep hit is the `"Campaign Ready"` completeness *band label* in `OA_LeadCompleteness` — a string, not a dependency). Lead Enrichment / OI / Website / Marketing untouched.
- **Violations:** none.

## 6. Performance review (Phase 6)
| Limit | Pattern | Status |
|---|---|---|
| SOQL | `resolveAll` = fixed queries/batch; **per-record SOQL eliminated** (Phase 9) | 🟢 |
| DML | batched insert + update (no per-record DML) | 🟢 |
| CPU / Heap | small in-memory maps; measured pilots sub-second | 🟢 |
| Queueable / Batch | not used yet (manual/pilot) | 🟡 (needed for volume) |
| Callouts | one per connector fetch; **SEC bursts throttle** → space/queueable | 🟡 |
Remaining risk: connector-**fetch** volume (callout spacing/queueable) — the pipeline itself is bulk-safe. No safe performance change outstanding this sprint (SOQL/DML already optimized + deployed).

## 7. Documentation consolidation (Phase 7)
Lead-Acquisition docs (12) are complementary, non-duplicative, and current:
`ARCHITECTURE`, `DUPLICATE_DETECTION`, `SOURCE_ADAPTERS`, `KPI_FRAMEWORK`, `PHASE1_SUMMARY`, `CONNECTOR_AUDIT`, `DISCOVERY_PROCEDURE`, `PHASE2_VALIDATION`, `PRODUCTION_PILOT`, `MULTI_SOURCE_VALIDATION`, `CONNECTOR_MATRIX`, `LEAD_COMPLETENESS_MODEL`, `COMPANY_INTELLIGENCE`, `DISCOVERY_DRIVER`, `IDENTITY_RESOLUTION`, `FUSION_ENGINE`, `CONNECTOR_READINESS`, + this assessment. No duplicates to remove; each is a distinct phase artifact. This document is the **consolidated engineering assessment** and current-state index.

## 8. Production readiness assessment (Phase 8)
**Lead Acquisition FOUNDATION engineering is COMPLETE.** Work classification:
- **Engineering — remaining (pre-automation, not blocking manual expansion):** (E1) spaced/queueable connector-fetch layer for volume + SEC throttle; (E2) NAICS mapping (needs live API verification); (E3) IRS bulk-CSV discovery path; (E4) candidate reports/dashboards build.
- **Operational:** deploy candidate dashboards/alerts; monitoring wiring.
- **Administrative:** SAM data.gov key; JIT EC principal grant; least-privilege runtime user (license); PR merges; Louis approvals.
- **Activation (🔴):** connector enablement; committed candidate writes; scheduling; automation.
- **Future enhancements:** field-precedence fusion config; UEI↔CIK external crosswalk; additional federal/commercial sources.

## 9. Release recommendation (Phase 9)
- **Phase A — Manual connector expansion:** SAM pilot (credential unlock → first committed cross-source fusion) → additional sources via the 3-step lifecycle. Gated, manual, preview→commit.
- **Phase B — Controlled automation:** build the queueable/spaced-fetch layer (E1) + least-privilege user; then scheduled discovery per a scheduling plan. Gated.
- **Phase C — BI dashboards:** deploy candidate reports/dashboards (extends RC1 analytics).
- **Phase D — Executive KPIs:** candidate KPI framework surfaced (discovery/approval/duplicate/conversion).
- **Phase E — Production optimization:** field-precedence fusion, entity crosswalk, NAICS, volume tuning.

## 10. Final objective — definitive answers (evidence-based)
1. **Is Lead Acquisition engineering complete?** — **The foundation is COMPLETE** (5 classes deployed dormant, 0 TODOs, 0 dead code, 0 new schema, bulk-safe, tested — validations `0AfPn0000023doTKAQ`/deploys `0AfPn0000023dJpKAI`,`0AfPn0000023drhKAA`). **Not 100% of the roadmap:** 4 pre-automation engineering items remain (E1 fetch-orchestration, E2 NAICS, E3 IRS bulk, E4 dashboards) — none blocks **controlled manual expansion**.
2. **What prevents production-scale connector expansion?** — the connector-**fetch** volume layer (spaced/queueable + SEC throttle handling) and a least-privilege runtime user. The candidate pipeline (resolution/fusion/dedup/persist) is already bulk-safe.
3. **What prevents controlled automation?** — no queueable/scheduled orchestration is built (deliberately), the runtime user is MAD `oauser`, and monitoring dashboards aren't deployed; all are 🔴-gated.
4. **What is administrative rather than engineering?** — SAM data.gov key, JIT EC principal grant, least-privilege user (licensing), PR merges, Louis approvals, and the dashboard deploy (UI/gated). None is code.
5. **Next major program after Lead Acquisition reaches engineering completion?** — finish acquisition via the **SAM production pilot** + additional sources (Phase A), then the platform's documented next program **Opportunity Intelligence** (ADR-015) as a separate, gated program — keeping Acquisition/Enrichment/OI cleanly separated.

## 11. PASS / WARN / FAIL — 🟢 PASS
Repository audited (clean); safe gaps closed (none outstanding-and-safe); connector certification complete; governance verified (no new metadata, program separation intact); performance reviewed (per-record SOQL eliminated); documentation consolidated; production readiness assessed. No unnecessary metadata; no Lead/Account change; no automation/scheduling. **WARN:** E1–E4 engineering items + administrative/credential items remain for controlled expansion/automation (all documented, gated). 🔴 none.

## 12. Governance / evidence
No source changes this sprint (documentation only). Production Apex unchanged since Phase 9 deploy `0AfPn0000023drhKAA`. Data: 6 candidates (3 USASpending + 3 SEC), 13,301 Leads, 1 Account — unchanged. 10 stacked Lead-Acquisition PRs open (#33–#42); this assessment is #43.
