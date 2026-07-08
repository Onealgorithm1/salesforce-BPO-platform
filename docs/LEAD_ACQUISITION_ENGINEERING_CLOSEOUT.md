# Lead Acquisition — Engineering Closeout & Scale Preparation (Phase 12)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-queueable-layer`
**Mode:** implementation (source-only) + deploy (dormant capability) · **No scheduling; no automation enabled; no data/Lead/Account change.**
**Builds on:** [LEAD_ACQUISITION_ENGINEERING_ASSESSMENT.md](LEAD_ACQUISITION_ENGINEERING_ASSESSMENT.md) (Phase 10) · [LEAD_ACQUISITION_OPERATIONAL_READINESS.md](LEAD_ACQUISITION_OPERATIONAL_READINESS.md) (Phase 11).

> Implements the last core engineering item (E1 — async/queueable discovery with callout spacing) and closes the
> engineering backlog to its irreducible set. Implementation prioritized over documentation.

---

## 1. E1 — Queueable discovery layer (IMPLEMENTED + DEPLOYED, dormant)
`OA_CandidateDiscoveryQueueable` (`Queueable, Database.AllowsCallouts`):
- Runs `OA_CandidateDiscovery.run()` for one or more inputs asynchronously; **chains itself** for the remainder.
- **Callout spacing:** with `batchSize=1`, one connector fetch per transaction → chained jobs run in separate
  transactions → **naturally spaces callouts** (mitigates SEC burst throttling) — **no scheduler**.
- **Connector-independent**; preserves preview (0 DML), commit, identity resolution, fusion, completeness, audit — all via the driver/service.
- **Bounded retry** (connector-agnostic) on a transient HTTP error (one re-attempt).
- **Dormant:** does nothing until a caller `System.enqueueJob()`s it — a future, gated operational action. Writes ONLY the Candidate object.
- **Validation `0AfPn0000023eJ7KAI`** (4 tests/0 fail, ~95% cov, mocked callout — no live call) → **deploy `0AfPn0000023eKjKAI` Succeeded**. Post-deploy: **0 async jobs running** for it; data unchanged (6 candidates / 13,301 leads / 1 account).

## 2. Connector resilience (Phase 2)
- **Reusable retry** added at the async-orchestration layer (queueable), **not per-connector** (no connector-specific paths).
- **Timeout:** connectors already set `setTimeout(30000)`.
- **Throttling:** addressed by one-input-per-transaction chaining (transaction-level spacing).
- **Error/telemetry:** connectors surface `httpErrors`/`parseErrors`/`messages` on `OA_ConnectorResult`; runs recorded in `OA_Connector_Run__c`.
- No connector class was modified (resilience is at the reusable driver/queueable layer).

## 3. Remaining engineering backlog (Phase 3) — reduced to its irreducible set
| Item | Status | Reason |
|---|---|---|
| **E1** queueable/spaced execution | ✅ **DONE** (deployed dormant) | this sprint |
| **E2** NAICS mapping | ⛔ **externally blocked** | no source yields NAICS mappably (SEC=SIC; SAM section excludes it; USASpending request omits it); SIC≠NAICS. Needs a **different SAM API section or a USASpending request-field change verified against live data** → requires the SAM credential / a live call to verify. **Cannot be completed without credentials/external verification.** |
| **E3** IRS bulk discovery framework | 🟡 **deferred (optional)** | requires ingesting the IRS bulk EO CSV (large file handling) + the IRS source; lower ICP value; not required for federal-contractor acquisition. Left as an optional future connector via the lifecycle standard. |
| **E4** candidate reports/dashboards | 🟡 **gated metadata deploy** | build/deploy is a 🔴 two-phase analytics deploy (extends RC1 analytics); operational/monitoring, not core-engine engineering. |
| parser/logging/perf improvements | ✅ none outstanding | 0 TODOs; per-record SOQL eliminated (Phase 9); batched DML; sub-second pilots |

## 4. Performance validation (Phase 5) — measurable evidence
| Limit | Evidence |
|---|---|
| SOQL | `OA_IdentityResolution.resolveAll` fixed queries/batch — test `bulk_resolveAll_is_soql_bounded` asserts **≤5 queries for 50 orgs** |
| DML | batched insert + update (no per-record DML) |
| Queueable | one connector fetch per transaction (batchSize=1) → separate callout limits per chained job; **spacing without a scheduler** |
| Bulk execution | pilots + unit tests pass; resolver bulk-safe |
| Heap / CPU | small in-memory maps; live pilots sub-second |
| Callout sequencing | chaining spaces SEC calls across transactions (addresses observed burst throttle) |

## 5. Production readiness — work classification (Phase 6)
- **Engineering (code) remaining:** **none required for the core acquisition engine.** Optional/blocked: E2 (external verify), E3 (optional IRS bulk), E4 (analytics deploy — operational).
- **Configuration:** SAM NC endpoint alpha→prod; org Matching/Duplicate Rules; registry `Enabled__c` toggles.
- **Administration:** SAM data.gov key; JIT EC principal grant; least-privilege runtime user (license); PR merges; Louis approvals.
- **Operations:** deploy candidate dashboards/alerts (E4); enqueue cadence; review staffing.
- **Activation (🔴):** connector enablement; committed writes; `System.enqueueJob`; scheduling; automation.
- **Future enhancements:** field-precedence fusion; UEI↔CIK crosswalk; additional sources.

## 6. Final objective — definitive answers (evidence-based)
1. **Is Lead Acquisition engineering now complete?** — **Yes for the core acquisition engine.** All core capabilities (discovery, generic driver, identity resolution, source fusion, completeness, **async/queueable layer**) are implemented, tested, and deployed dormant (deploys `0AfPn0000023dJpKAI`/`0AfPn0000023drhKAA`/`0AfPn0000023eKjKAI`). Remaining code items are **optional (E3, E4)** or **externally blocked (E2)** — none is core-engine engineering.
2. **What engineering work remains?** — E2 NAICS (blocked on live source verification / SAM credential), E3 IRS bulk discovery (optional), E4 candidate dashboards (operational/gated analytics deploy). No core-engine work.
3. **Configuration only?** — SAM endpoint alpha→prod; matching/duplicate rules; registry enable toggles.
4. **Administration only?** — SAM data.gov key; JIT EC principal grant; least-privilege user (license); PR merges; approvals.
5. **Activation only?** — connector enablement; committed candidate writes; `System.enqueueJob`; scheduling; automation.
6. **Ready to begin controlled connector expansion?** — **Yes.** Onboarding a source is configuration-first (implement `OA_IEnrichmentConnector` + registry row + run/enqueue); the shared pipeline is bulk-safe and async-capable. The immediate expansion (SAM pilot) is unblocked by engineering — it awaits **administrative** items (SAM key + JIT grant) and Louis approval.

## 7. Declaration
**Lead Acquisition core-engine ENGINEERING is COMPLETE.** The platform can onboard future connectors configuration-first
and execute them manually or asynchronously (dormant, gated). Remaining items are optional (E3/E4), externally blocked
(E2), or non-code (configuration/administration/activation).

**Recommended next major engineering program:** after the **SAM production pilot** (Stage 1, administrative/credential-gated)
proves the first committed cross-source fusion and additional sources onboard, begin the platform's documented next program
**Opportunity Intelligence** (ADR-015) as a separate, gated program.

## 8. PASS / WARN / FAIL — 🟢 PASS
Engineering backlog reduced to its irreducible set; queueable implemented + deployed dormant; connector resilience improved (reusable, no connector-specific paths); performance validated with evidence; no unnecessary metadata; no data/Lead/Account change; no scheduling; no automation enabled. **WARN:** E2 externally blocked, E3/E4 optional/gated; SAM configuration/administration remain for the pilot. 🔴 none.

## 9. Governance / evidence
Source added: `OA_CandidateDiscoveryQueueable` (+ test). No new object/field. Deploy `0AfPn0000023eKjKAI` (dormant; 0 async jobs running). Prod Apex from the epic now: `OA_CandidateDiscovery`, `OA_CandidateDiscoveryService`, `OA_IdentityResolution`, `OA_SourceFusion`, `OA_LeadCompleteness`, `OA_CandidateDiscoveryQueueable` — all deployed, all dormant. Data unchanged (6 candidates / 13,301 leads / 1 account). Stacked LA PRs #33–#44 open; this is #45.
