# Lead Acquisition — Generic Candidate Discovery Driver (Phase 5)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-acquisition-discovery-driver`
**Mode:** source-only Apex + check-only validation · **No deploy, no live callouts, no production writes, no Lead/Account change, no merge.**

> One reusable driver — `OA_CandidateDiscovery.run()` — executes **any** approved connector through a single common
> path, eliminating connector-specific execution logic (closes gap G1). It reuses the existing interface, registry,
> duplicate detection, Candidate staging, and telemetry. Preview = 0 DML; commit inserts Candidates only.

---

## 1. Architecture review (Phase 1)
Prior execution ran via bespoke anonymous Apex per pilot (registry lookup → `Type.forName` → `fetch` → cap →
`OA_CandidateDiscoveryService`). Every piece already existed; only a single entry point was missing.

| Concern | Reused component |
|---|---|
| Connector interface | `OA_IEnrichmentConnector.fetch(input, cfg)` → `OA_ConnectorResult` |
| Registry lookup | `OA_Connector_Registry__mdt` (by `DeveloperName`) |
| Candidate persistence + dedup | `OA_CandidateDiscoveryService` (preview/commit) |
| Duplicate detection | canonical-key + payload-hash + UEI/CAGE Lead match (in the service) |
| Staging | `OA_Discovered_Organization__c` |
| Telemetry | `OA_ConnectorResult` (requested/parsed/httpErrors/status) |

**Minimum implementation:** one class wiring these together with no source-specific branches. Built as `OA_CandidateDiscovery`.

## 2. Generic Discovery Driver (Phase 2) — `OA_CandidateDiscovery`
Signature: `run(String connectorName, String input, Boolean commitWrites, Integer maxResults) : Result`.
- **connector name** → registry lookup → `Type.forName(cfg.Connector_Class__c)` → cast to `OA_IEnrichmentConnector`.
- **preview mode** (`commitWrites=false`) → `OA_CandidateDiscoveryService.persist(scoped, false)` → 0 DML.
- **commit mode** (`commitWrites=true`) → inserts new, non-duplicate Candidates only.
- **maxResults** → caps organizations processed (null = all).
- **duplicate detection / Candidate creation / audit** → delegated to the existing service (no reimplementation).
- **Zero connector-specific branching** — behavior is identical for every source; a `@TestVisible` connector-injection seam enables unit testing without a live callout.

## 3. Validation evidence (Phase 3)
- **Check-only Validation ID `0AfPn0000023cXRKAY`** — 0 component errors, **6 tests / 0 failures**, coverage ≥75%. Source-only; **not deployed**.
- Tests (no live callout): maxResults cap + preview 0 DML; commit inserts exactly the capped N; null cap = all; unknown connector name throws; blank name throws; **real name-resolution path** (`run('USASpending', …)`) via `Type.forName` + a **mocked** HTTP callout (proves the generic resolve→fetch→persist path end-to-end without a live call).
- No live production callouts; no production Candidate records; no Lead/Account modification.

## 4. Documentation (Phase 4)
**Execution sequence:** `run(name,input,commit,max)` → lookup registry row → instantiate connector → `fetch(input,cfg)` (live callout at runtime) → cap to `maxResults` → `OA_CandidateDiscoveryService.persist(scoped, commit)` → `Result` (connector telemetry + candidate outcome).

**Extension process for a future connector (no driver change):**
1. Implement `OA_IEnrichmentConnector` (`sourceKey()`, `fetch(input,cfg)` returning `OA_ConnectorResult` with `organizations`).
2. Add an `OA_Connector_Registry__mdt` row (`DeveloperName`, `Connector_Class__c`, `Named_Credential__c`, `Endpoint_Path__c`, `Enabled__c=false`).
3. Call `OA_CandidateDiscovery.run('<DeveloperName>', input, false, N)` — done. No driver edit.

**Required connector interface:** `OA_IEnrichmentConnector` — `String sourceKey()`, `OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg)`.
**Expected connector outputs:** `OA_ConnectorResult` with `organizations` (`List<OA_CanonicalOrg>`) + telemetry (`requested/parsed/httpErrors/lastStatus/messages`). Absent fields stay null (never fabricated).
**Error handling:** `DiscoveryException` for missing/blank name, missing registry row, class-not-found, or a class not implementing the interface; a null connector result throws. Connector HTTP/parse errors surface as `OA_ConnectorResult` counts (connectors never throw for expected failures).
**Duplicate handling:** delegated to `OA_CandidateDiscoveryService` — idempotency (`Source_Payload_Hash__c`), candidate dedup (`Canonical_Key__c`), Lead match (UEI/CAGE → `Duplicate` + `Matched_Lead__c`).
**Preview vs commit:** preview = classification only, **0 DML**; commit = insert new/unique Candidates only (never Lead/Account).

## 5. Connector compatibility matrix (Phase 5)
| Connector | Implements `OA_IEnrichmentConnector` | Registry row | Runs via driver with NO source-specific code | Notes |
|---|---|---|---|---|
| USASpending | ✅ | ✅ | ✅ (validated via mock) | live-proven in the pilot |
| SAM Entity | ✅ | ✅ | ✅ | gated on data.gov key + JIT EC grant + prod endpoint |
| SEC EDGAR | ✅ | ✅ | ✅ | public, no gate |
| IRS | ✅ | ✅ | ✅ | bulk CSV input |
| Census | ✅ | ✅ | ✅ (executes, but yields no org identity) | WARN — not an org registry |
| StateRegistry (template) | ✅ | ✅ | ✅ | template only |
| **Future connectors** | required | required | ✅ by contract | add via the 3-step extension process |

**Every current registry connector executes through the driver with no connector-specific code.** Grants.gov remains out
of scope (Opportunity Intelligence / Framework A — not in the enrichment registry).

## 6. Remaining framework gaps
- **G2** NAICS not mapped by parsers (mapping work, no new field).
- **G3** SAM credential (key + JIT + prod endpoint).
- **G8** cross-source fusion merge (designed Phase 4; DML-update, gated).
- G4 completeness-score surfacing · G5 candidate analytics deploy · G6 least-privilege runtime user · G7 org Matching/Duplicate Rules.
- Driver itself: none — it is connector-agnostic and complete. (Optional future: batch/queueable wrapper for volume — deliberately excluded, no scheduling this sprint.)

## 7. PASS / WARN / FAIL — 🟢 PASS
- 🟢 PASS — one reusable driver; no duplicated connector logic; existing pipeline/audit/dedup/staging reused; validated (6 tests); no production change; no connector activation/scheduling; no Lead/Account modification.
- 🟡 WARN — driver not deployed (source-only, gated); live execution still requires connector enablement + (for SAM) credentials.
- 🔴 none.

## 8. Remaining activation gates (🔴 Louis)
Deploy `OA_CandidateDiscovery` (with `OA_CandidateDiscoveryService`) → enable a connector → run the driver (preview→commit) for the next source (SEC EDGAR no-gate; SAM after credentials) → least-privilege runtime user before volume. No scheduling.
