# Lead Acquisition Engine — Phase 1 Summary (Executive)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-candidate-foundation`
**Epic:** Lead Acquisition (NEW) · **Mode:** design + reuse audit + 1 additive report type (validated) · **No production change; everything dormant.**

> Detailed docs: [LEAD_ACQUISITION_ARCHITECTURE.md](LEAD_ACQUISITION_ARCHITECTURE.md) · [LEAD_ACQUISITION_DUPLICATE_DETECTION.md](LEAD_ACQUISITION_DUPLICATE_DETECTION.md) · [LEAD_ACQUISITION_SOURCE_ADAPTERS.md](LEAD_ACQUISITION_SOURCE_ADAPTERS.md) · [LEAD_ACQUISITION_KPI_FRAMEWORK.md](LEAD_ACQUISITION_KPI_FRAMEWORK.md)

---

## 1. Executive summary
The Lead Acquisition pipeline (API → Candidate → dedup → existing-Lead match → review → human approval → Lead → enrichment)
is **almost entirely already built** in the deployed platform. The **Candidate model already exists** as
`OA_Discovered_Organization__c` (all required fields present, 0 records, dormant); the **review queue, dedup fields, policy
engine, telemetry, and audit are all reusable as-is**. This sprint delivers the architecture, duplicate-detection design,
source-adapter assessment, and Candidate KPI framework — creating **only one** new metadata component (a Candidate report
type) — and specifies the thin, gated operational wiring that remains. **Nothing automatically creates Leads; nothing
changes production.**

## 2. Reuse summary (reuse-before-build)
| Component | Reused? | New? |
|---|---|---|
| Candidate staging (`OA_Discovered_Organization__c`) | ✅ reused (is the Candidate model) | — |
| Review Queue (`OA_Enrichment_Exception__c`) | ✅ reused (single queue) | — |
| Connector SDK / Runner / Registry | ✅ reused | — |
| Duplicate fields (Canonical_Key, Normalized_Name, Payload_Hash, Matched_Lead/Account) | ✅ reused | — |
| Policy engine / write-back / telemetry / audit | ✅ reused | — |
| Connectors (SAM Entity, USASpending / Grants.gov) | ✅ reused (assessment) | — |
| Candidate report type (`OA_Discovered_Organizations`) | — | 🟡 1 additive report type (validated) |
| Objects / fields / dashboards / second review process | — | **none created** |

**Net new metadata: 1 report type.** No new object, field, connector, or review process. No duplicate architecture.

## 3. Operational readiness (Phase 7 — everything dormant, verified)
| Check | State |
|---|---|
| Production activation | none |
| Connector enablement | none (registry rows disabled; live-verified) |
| Scheduled jobs | none (no acquisition cron) |
| Automatic Lead creation | none (human-gated by design) |
| Write-back changes | none (`commitWrites` default false) |
| Candidate records | 0 (object empty/dormant) |
| Production data | unchanged |

## 4. Validation
| Scope | Validation ID | Result |
|---|---|---|
| Candidate report type (`OA_Discovered_Organizations`) | **`0AfPn0000023bY9KAI`** | 🟢 SUCCESS — 0 errors, 1 component |
No Apex added → no tests executed (RunRelevantTests). The Candidate model reuses the existing (already-validated) object,
so no object/field deploy is needed.

## 5. PASS / WARN / FAIL
- 🟢 **PASS** — pipeline architecture complete via reuse; Candidate model exists; dedup + review + KPI designs done; 1 report type validated green; no duplicate metadata; no production change; everything dormant.
- 🟡 **WARN** — candidate reports/dashboards are design-only (extend RC1 analytics, two-phase deploy); operational wiring (discovery mode, approval→Lead step) is specified but not built.
- 🔴 none.

## 6. Remaining activation gates (all 🔴 Louis; future phases)
1. Build the **discovery output path** (connector result → Candidate) — reuse `OA_ConnectorRunner`; Apex, gated deploy.
2. Build the **duplicate-detection service** + configure org Matching/Duplicate Rules.
3. Build the **human approval → Lead creation** step (gated; reuses write-back/policy/audit).
4. Deploy the Candidate report type → candidate reports → candidate dashboard (two-phase; extends RC1 analytics).
5. Source credentials/enablement (SAM key + JIT + prod endpoint) — same gated items as Lead Enrichment.
6. Least-privilege runtime user before any volume discovery/creation.
None of these is done or scheduled in this sprint.

## 7. Boundaries respected
Separate from Opportunity Intelligence (Grants.gov OI connector not repointed). Website integration out of scope.
LinkedIn/Meta dormant and untouched. Lead Enrichment RC1 not modified (this epic branches off `main`, independent).
