# Lead Acquisition — Enterprise Connector Readiness (Phase 9)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-acquisition-connector-readiness`
**Mode:** readiness review + one bulk-scalability refactor (deployed, behavior-preserving) · **No new connector; no automation; no scheduling; no data change.**

> Prepares the platform to onboard future intelligence sources through one repeatable, governed, scalable process.
> Companion: [LEAD_ACQUISITION_CONNECTOR_MATRIX.md](LEAD_ACQUISITION_CONNECTOR_MATRIX.md), [LEAD_ACQUISITION_FUSION_ENGINE.md](LEAD_ACQUISITION_FUSION_ENGINE.md), [LEAD_ACQUISITION_IDENTITY_RESOLUTION.md](LEAD_ACQUISITION_IDENTITY_RESOLUTION.md).

---

## 1. Connector readiness audit (Phase 1)
| Connector | Auth | Connector class | Parser maturity | Canonical mapping | Deployment readiness |
|---|---|---|---|---|---|
| **USASpending** | public NoAuth | `OA_USASpending_Connector` | mature (live-proven) | UEI+name+state+awards | ✅ deployed, pilot-proven |
| **SEC EDGAR** | public NoAuth (User-Agent) | `OA_SEC_Connector` | mature (live-proven) | CIK+name+address+website+SIC | ✅ deployed, pilot-proven |
| **SAM Entity** | SecuredEndpoint (EC `OA_SAM`) | `OA_SAM_Connector` | mature (parser present) | UEI+CAGE+address+website+phone | 🟡 **cred-gated** (key+JIT+prod endpoint) |
| **IRS Tax-Exempt** | none (bulk CSV) | `OA_IRS_Connector` | present | EIN+name+address | 🟡 bulk-run design |
| **Census** | public NoAuth | `OA_Census_Connector` | present | none (no org identity) | ⚪ WARN — not an org registry |
| **State Registries** | varies | `OA_StateRegistry_Template` | template only | scaffold | ⚪ template |
| Website | n/a | — | — | — | out of scope (this program) |
| LinkedIn / Meta | OAuth (live) | `OA_LinkedIn`/`OA_Meta` NC/EC | n/a (social) | none | ⚪ audit-only, compliance-constrained |
| Additional Federal | varies | (future) | — | — | onboard via lifecycle §3 |

## 2. Enterprise connector capability matrix (Phase 2)
Legend: ✅ yes · ◑ partial · — none.
| Capability | USASpending | SEC | SAM | IRS | Census |
|---|:--:|:--:|:--:|:--:|:--:|
| Identity (name) | ✅ | ✅ | ✅ | ✅ | — |
| Government IDs | UEI | CIK | UEI+CAGE | EIN | — |
| Address | state only | ✅ | ✅ | ✅ | state |
| Website | — | ✅ | ✅ | — | — |
| Phone | — | — | ✅ | — | — |
| Industry | — | SIC | ◑ | — | — |
| NAICS | — (¹) | — | — (¹) | — | — |
| Contract history | ✅ | — | — | — | — |
| Certifications | — | — | ◑ | — | — |
| Contacts | — | — | — | — | — |
| Source confidence | HIGH (UEI) | HIGH | HIGH | MED | LOW |
| Refresh frequency | daily-ish | daily | near-real-time | periodic file | static |
| Rate limits | none observed | **bursty throttle** | key quota | file size | none |
| Auth requirement | none | User-Agent | data.gov key + JIT EC | none | none |
| Operational cost | low | low | low (key mgmt) | low | low |

¹ **NAICS gap (G2):** no current parser maps NAICS (SEC exposes SIC only; SAM's read sections exclude NAICS; USASpending request omits it). SIC ≠ NAICS — do not conflate. Contacts are never available from gov sources → Lead Enrichment fills them post-creation.

## 3. Connector lifecycle standard (Phase 3) — every future connector follows this
```
Connector Request -> Credential Verification -> Parser Validation -> Preview (0 DML)
  -> Identity Resolution -> Fusion -> Completeness Assessment -> Candidate Review
  -> Production Approval (RED) -> Automation Readiness (RED)
```
Onboarding a new source = **3 reusable steps, no framework change**:
1. Implement `OA_IEnrichmentConnector` (emit `OA_CanonicalOrg`).
2. Add an `OA_Connector_Registry__mdt` row (`Enabled__c=false`).
3. Run `OA_CandidateDiscovery.run('<Name>', input, false, N)` — preview → (gated) commit.
Everything downstream (identity resolution, fusion, completeness, dedup, review, audit) is shared and connector-agnostic. Each gate (credential, production approval, automation) is a 🔴 Louis decision.

## 4. Bulk readiness review (Phase 4) — refactor performed
| Component | Per-record SOQL? | Per-record DML? | Status |
|---|---|---|---|
| `OA_CandidateDiscovery` (driver) | no | no | ✅ |
| `OA_CandidateDiscoveryService` | **fixed** — was per-org resolve + per-fusion query | no (batched insert + update) | ✅ refactored |
| `OA_IdentityResolution` | **fixed** — `resolveAll()` bulk (was per-org) | n/a (read-only) | ✅ refactored |
| `OA_SourceFusion` | no (pure) | no | ✅ |

**Refactor (deployed, behavior-preserving):** `OA_IdentityResolution.resolveAll(List)` now issues a **fixed number of
queries** for the whole batch (candidates, leads, accounts) and carries the matched candidate record so **fusion needs
no extra query**; `resolve(single)` delegates to it; the service runs **one** resolution pass. Proven by
`bulk_resolveAll_is_soql_bounded` (≤5 queries for 50 orgs) and 26 tests/0 fail. Deploy `0AfPn0000023drhKAA`.

## 5. SAM readiness checklist (Phase 5) — ready to pilot once credentials land
- [ ] **data.gov API key** entered in the `OA_SAM` External Credential (Setup only; never in git) — **external blocker**.
- [ ] **NC endpoint** moved from `api-alpha.sam.gov` → prod `api.sam.gov` (`OA_SAM` NamedCredential).
- [ ] **JIT EC principal access** granted to the runtime user via the `OA_SAM_Connector` permset (SetupEntityAccess; MAD does not substitute) — currently **0 grants**.
- [x] Connector class `OA_SAM_Connector` deployed; implements the contract; emits `OA_CanonicalOrg`.
- [x] Parser `OA_SAM_ResponseParser` present (UEI+CAGE+address+website+phone; NAICS excluded by API section).
- [x] Registry row `SAM` present, `Enabled__c=false`.
- [x] Generic driver `OA_CandidateDiscovery` deployed (runs SAM with no source-specific code).
- [x] Identity resolution + fusion deployed (SAM UEI/CAGE will **fuse** into existing UEI candidates — the first real cross-source fusion).
- [ ] **Louis approval** for the SAM pilot (credential creation + connector run + ≤N candidate writes).
Expected contribution: SAM adds **CAGE + full address + website + phone** to UEI candidates → largest single completeness lift; the first source that will produce a **committed** cross-source fusion.

## 6. Production readiness (Phase 6) — verified, not enabled
| Capability | Ready? | Evidence |
|---|---|---|
| Additional connectors | 🟢 | lifecycle §3; 5 classes deployed; driver connector-agnostic |
| Large Candidate volumes | 🟢 (resolution/fusion) / 🟡 (end-to-end) | bulk resolver deployed; **connector fetch volume still needs spacing/queueable for SEC throttle** |
| Future scheduling | 🟡 | supported by design; **not enabled**; needs least-priv user + monitoring first |
| Monitoring | 🟡 | telemetry (`OA_Connector_Run__c`) + audit exist; candidate dashboards designed, not deployed |
| Audit | 🟢 | `Discovery_Metadata__c` provenance + `Source_Payload_Hash__c` + change logs |
| Rollback | 🟢 | candidates are staging rows (delete/reverse); idempotent re-runs; no Lead/Account writes |
| Governance | 🟢 | every write/enable/schedule is a documented 🔴 gate; FillEmptyOnly fusion; human review |

## 7. Remaining scalability risks
- **SEC burst throttling** — space calls / queueable before volume (per Phase-6 finding).
- **Connector-fetch volume** — a discovery over thousands needs batch/queueable orchestration (no scheduling yet).
- **NAICS gap (G2)** — requires a different SAM section or USASpending request-field change (live-verify, gated).
- **Least-privilege runtime user** — MAD `oauser` today; required before unattended volume (R1).
- **Candidate analytics not deployed** — monitoring surface for volume.

## 8. PASS / WARN / FAIL — 🟢 PASS
Enterprise matrix ✅ · lifecycle standard ✅ · bulk readiness reviewed + **per-record SOQL eliminated (deployed)** ✅ · SAM checklist ✅ · scalability risks documented ✅ · no data/Lead/Account change, no connector activation, no scheduling, no OI work. **WARN:** SEC throttling + connector-fetch volume orchestration + NAICS + least-priv user remain for the pre-automation sprint.

## 9. Recommended next sprint
**SAM production pilot** (credential unlock → first real committed cross-source fusion), then additional federal/commercial sources via the lifecycle standard; separately, a queueable/spaced fetch layer + least-priv user before any volume or scheduling.
