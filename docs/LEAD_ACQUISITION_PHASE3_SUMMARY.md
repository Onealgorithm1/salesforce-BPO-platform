# Lead Acquisition — Phase 3 Unified Framework Summary

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-acquisition-unified-framework` · **Mode:** design/documentation only — no deploy, no automation, no writes.

> Detailed docs: [LEAD_ACQUISITION_CONNECTOR_MATRIX.md](LEAD_ACQUISITION_CONNECTOR_MATRIX.md) · [LEAD_ACQUISITION_LEAD_COMPLETENESS_MODEL.md](LEAD_ACQUISITION_LEAD_COMPLETENESS_MODEL.md) · [LEAD_ACQUISITION_CONNECTOR_RANKING.md](LEAD_ACQUISITION_CONNECTOR_RANKING.md)

---

## 1. Unified framework — already achieved
The target pipeline (Connector → `OA_CanonicalOrg` → `OA_CandidateDiscoveryService` → Duplicate Detection → Candidate →
Review Queue → Lead Approval → Enrichment) **already operates uniformly**. Evidence:
- Every connector implements one contract (`OA_IEnrichmentConnector.fetch` → `OA_ConnectorResult.organizations`).
- `OA_CandidateDiscoveryService` (deployed, pilot-proven) contains **zero connector-specific logic** — it consumes any source's `OA_CanonicalOrg` list identically (dedup, match, status).
- The USASpending pilot proved the full path end-to-end in production (3 candidates).
- **Adding a source = a connector that emits `OA_CanonicalOrg`** — no pipeline change, no per-source branching. Mission satisfied.

## 2. Deliverables
1. Connector comparison matrix — CONNECTOR_MATRIX §1.
2. Unified mapping matrix (evidence-based field availability) — CONNECTOR_MATRIX §2–3.
3. Lead Completeness framework (0–100, banded) — LEAD_COMPLETENESS_MODEL.
4. Connector quality ranking — CONNECTOR_RANKING §1.
5. Recommended activation roadmap — CONNECTOR_RANKING §4.
6. Remaining architectural gaps — §3 below.
7. PASS/WARN/FAIL — §4.

## 3. Remaining architectural gaps
| # | Gap | Impact | Fix (gated, future) |
|---|---|---|---|
| G1 | **No generic discovery driver** | each pilot runs via bespoke anonymous Apex (connector→persist) | thin `OA_CandidateDiscovery.run(sourceKey, input, commit)` reusing `OA_ConnectorRunner` + `OA_CandidateDiscoveryService` — one entry point, still manual/gated |
| G2 | **NAICS not mapped onto canonical** | `NAICS__c` target exists but no parser populates it | wire NAICS in SAM/USASpending parsers (mapping, no new field) |
| G3 | **SAM credential** | richest source blocked | data.gov key + JIT EC principal grant + alpha→prod endpoint |
| G4 | **Completeness score not implemented** | design only | report/formula (shared with enrichment quality score) |
| G5 | **Candidate analytics not deployed** | report type built (Phase 1), reports/dashboard pending | two-phase deploy, extends RC1 analytics |
| G6 | **Runtime user is MAD `oauser`** | least-privilege gap | dedicated integration user (license) before volume |
| G7 | **Org Matching/Duplicate Rules empty** | Apex dedup only | configure Lead matching rules to reinforce |

None blocks the unified framework; all are enhancements/activation items.

## 4. PASS / WARN / FAIL
- 🟢 **PASS** — pipeline is unified and connector-agnostic (proven); comparison + mapping matrices produced from evidence; completeness model designed; connectors ranked; activation roadmap + evidence-based next-connector recommendation delivered; no connector-specific logic; no deploy/automation/writes.
- 🟡 **WARN** — Census not org-suitable; Grants.gov deferred (OI boundary); SAM gated on credentials; several enhancements (G1–G7) remain.
- 🔴 none.

## 5. Recommended next engineering sprint
**"Lead Acquisition Phase 4 — SAM Entity discovery + generic discovery driver."** Scope: (a) resolve SAM credential (data.gov key + JIT EC grant + prod endpoint), (b) build the thin generic `OA_CandidateDiscovery.run()` driver (G1) + NAICS mapping (G2), (c) supervised SAM candidate pilot (≤N, manual, gated), (d) then SEC EDGAR as the no-gate parallel source. Defer completeness-score implementation + candidate analytics deploy to a following sprint.

## 6. Governance
No production metadata deployed this sprint (documentation only). No automation, no schedules, no Leads created, no Accounts modified, no merges. The 3 USASpending pilot candidates from Phase 2.5 remain in `OA_Discovered_Organization__c` (Needs Review), untouched.
