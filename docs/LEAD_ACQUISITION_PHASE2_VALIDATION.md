# Lead Acquisition — Phase 2 Validation Report (Discovery)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-discovery`
**Mode:** source-only Apex + check-only validation + read-only audit · **No deploy, no execution, no writes.**

> Phases 6–7. Validates the candidate-discovery capability and confirms nothing in production was changed. Producing the
> live Candidate samples requires crossing 🔴 RED gates (connector execution + production writes + SAM credential) and is
> therefore **not performed** — reported as WARN with the exact gated procedure.

---

## 1. What was built (deployment-ready, dormant)
| Component | Type | State |
|---|---|---|
| `OA_CandidateDiscoveryService` | Apex (persist + duplicate detection, preview-safe) | source-only, **check-only validated**, not deployed/run |
| `OA_CandidateDiscoveryService_Test` | Apex test (5 methods) | validated |
| `OA_Discovered_Organizations` | report type (Phase 1, Candidate reporting) | validated (`0AfPn0000023bY9KAI`) |

**Reuse:** `OA_CanonicalOrg` (canonicalKey/payloadHash), connectors, `OA_ConnectorResult`, `OA_Discovered_Organization__c`, `OA_Enrichment_Exception__c`. **No new object/field.**

## 2. Validation evidence (check-only)
| Scope | Validation ID | Result |
|---|---|---|
| Candidate discovery service + test (RunSpecifiedTests) | **`0AfPn0000023bgDKAQ`** | 🟢 **SUCCESS** — 0 component errors, **5 tests / 0 failures**, coverage 91/94 (~97%) |
| Candidate report type | `0AfPn0000023bY9KAI` | 🟢 SUCCESS — 0 errors, 1 component |

**Tests prove:** preview writes nothing; a unique org → `Needs Review` + insert; a UEI/CAGE match to an existing Lead →
`Duplicate` + `Matched_Lead__c` set + **no Lead created**; idempotent re-run (same payload hash) → skipped (no duplicate
Candidate); empty input safe.

## 3. Production-safety verification (Phase 6) — all confirmed
| Check | Result | Evidence |
|---|---|---|
| No Lead created | ✅ | service inserts only `OA_Discovered_Organization__c`; nothing run in prod |
| No Lead modified | ✅ | Lead queried read-only (`WITH USER_MODE`), never updated |
| No Account modified | ✅ | Accounts not written |
| No connector schedules created | ✅ | 0 acquisition cron; no `System.schedule` |
| No write-back activated | ✅ | enrichment write path untouched; `commitWrites` unchanged |
| No campaign automation changed | ✅ | not touched |
| No LinkedIn/Meta records written | ✅ | audit-only |
| No website work | ✅ | out of scope |
| Candidate object state | ✅ | still **0 records** (nothing written) |

## 4. Sample Candidate evidence (Phase 4) — WARN (gated)
**Sample Candidate record IDs: none produced this sprint.** Producing them requires executing connectors (live callouts)
and inserting production Candidate records — both 🔴 RED — plus, for SAM, a data.gov key + JIT EC principal grant. Per
the sprint's own rule ("if a source cannot produce Candidates, document why and mark WARN"), each Build-Now source is
**WARN — ready, gated**; the exact manual run is in [LEAD_ACQUISITION_DISCOVERY_PROCEDURE.md](LEAD_ACQUISITION_DISCOVERY_PROCEDURE.md).

| Source | Sample | Reason |
|--------|--------|--------|
| SAM Entity | ⚠ 0 | gated: cred (key+JIT+prod endpoint) + execution + write |
| USASpending | ⚠ 0 | gated: deploy service + enable connector + live callout + write |
| SEC EDGAR | ⚠ 0 | gated: deploy service + enable connector + callout + write |
| IRS Tax-Exempt | ⚠ 0 | gated: deploy service + dataset fetch + write |
| Census | ⚠ n/a | not an organization registry (cannot produce org candidates) |
| Grants.gov | ⏸ defer | OI boundary; needs entity-extraction adapter |

## 5. PASS / WARN / FAIL
- 🟢 **PASS** — candidate-discovery + duplicate-detection **implemented, unit-tested, and check-only validated** (deployment-ready, dormant); mapping reuses existing fields; review routing reuses the single queue; production untouched; LinkedIn/Meta audited-only.
- 🟡 **WARN** — live Candidate samples not produced (require RED execution/write/cred gates); Census not org-suitable; Grants.gov deferred (OI boundary).
- 🔴 none.

## 6. Remaining activation gates (all 🔴 Louis)
1. Deploy `OA_CandidateDiscoveryService` (+ test) — validated, ready.
2. Enable a Build-Now connector (start USASpending — public) for a manual discovery run.
3. Run the manual procedure (preview → commit) to produce the 3-per-source sample; verify + reversible.
4. SAM: data.gov key + JIT EC principal grant + alpha→prod endpoint.
5. Deploy the Candidate report type → candidate reports/dashboard (two-phase; extends RC1 analytics).
6. Least-privilege runtime user before volume discovery.
No connector enablement, execution, scheduling, permission assignment, or Lead creation was performed.

## 7. Success-criteria status
Candidate records **will** be created from approved API sources only, via a validated, reversible, dedup-first,
human-reviewable path — pending the gated execution above. No Leads created; no automation enabled; no schedules; no
production Lead data changed; LinkedIn/Meta audited only. **Capability delivered; live sample is the gated next step.**
