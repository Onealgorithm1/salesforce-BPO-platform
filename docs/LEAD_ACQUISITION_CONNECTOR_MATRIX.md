# Lead Acquisition — Connector Comparison & Unified Mapping (Phase 1–2)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** evidence-based audit (parser inspection + live USASpending pilot) · **No deploy, no writes.**

> Every connector implements the SAME contract — `OA_IEnrichmentConnector.fetch()` → `OA_ConnectorResult.organizations`
> (`List<OA_CanonicalOrg>`) → `OA_CandidateDiscoveryService` → dedup → Candidate. The service contains **zero
> connector-specific logic**; sources differ only in which `OA_CanonicalOrg` fields their parser populates (evidence below).

---

## 1. Connector comparison matrix (Phase 1)

| Connector | Auth | Deployed | Live-proven | Response quality | Confidence basis | Verdict |
|---|---|---|---|---|---|---|
| **USASpending** | public NoAuth | ✅ | ✅ (pilot: HTTP 200, 28 recipients, 3 candidates) | identity + award history; **no CAGE/NAICS/website/address** | HIGH (UEI present) | **Build Now — proven** |
| **SAM Entity** | SecuredEndpoint (EC `OA_SAM`, **key+JIT pending**, endpoint **alpha**) | ✅ | ✗ (blocked on cred) | **richest** — UEI+CAGE+address+website+phone | HIGH (UEI+CAGE) | **Build Now — gated on cred** |
| **SEC EDGAR** | public NoAuth | ✅ | ✗ (not yet run) | CIK+name+address+website; **no UEI/CAGE** | MEDIUM (CIK, no federal UEI) | **Build Now** |
| **IRS Tax-Exempt** | none (bulk CSV) | ✅ | ✗ | EIN+name+address; **no UEI/CAGE/website** | MEDIUM (EIN) | **Build Now (bulk)** |
| **Census** | public NoAuth | ✅ | ✗ | **no organization identity** (demographic/geographic only) | LOW | **WARN — not an org registry** |
| **Grants.gov** | (OI, Framework A) | ❌ repo-only | ✗ | opportunity-shaped, not entities | n/a | **Defer — OI boundary** |

## 2. Unified field-availability matrix (Phase 2 — evidence from parser inspection)
Which `OA_CanonicalOrg` field each connector's parser actually populates:

| Field | USASpending | SAM | SEC | IRS | Census |
|---|:--:|:--:|:--:|:--:|:--:|
| Organization Name | ✅ | ✅ | ✅ | ✅ | — |
| Normalized Name | ✅ | ✅ | ✅ | ✅ | — |
| UEI | ✅ | ✅ | — | — | — |
| CAGE | — | ✅ | — | — | — |
| EIN | — | — | — | ✅ | — |
| CIK | — | — | ✅ | — | — |
| NAICS | — (¹) | — (¹) | — | — | — |
| Address / City / State / Postal | state only | ✅ full | ✅ full | ✅ full | state only |
| Website | — | ✅ | ✅ | — | — |
| Phone | — | ✅ | — | — | — |
| Contract / Award activity | ✅ (attributes) | — | — | — | — |
| Source Confidence | ✅ | ✅ | ✅ | ✅ | ✅ |
| Source System | ✅ | ✅ | ✅ | ✅ | ✅ |
| Canonical Key | ✅ (computed) | ✅ | ✅ | ✅ | ✅ (weak) |
| Payload Hash | ✅ (computed) | ✅ | ✅ | ✅ | ✅ |
| Discovery Timestamp | ✅ (at persist) | ✅ | ✅ | ✅ | ✅ |

¹ NAICS is **not** mapped onto the canonical org by any current parser (carried in `attributes`/`Discovery_Metadata__c` at best). Gap noted §4.

## 3. Availability classification
- **Always available (every org-producing source):** Organization Name, Normalized Name, State, Source Confidence, Source System, Canonical Key, Payload Hash, Discovery Timestamp.
- **Sometimes available:** UEI (USASpending, SAM), CAGE (SAM only), full Address (SAM/SEC/IRS), Website (SAM/SEC), EIN (IRS), CIK (SEC), Phone (SAM), Award history (USASpending).
- **Never available (from any current connector, onto canonical):** NAICS (unmapped), Email domain, Business type, Revenue, Employees.

## 4. Missing enrichment fields (do NOT create new SF fields — reuse)
- **NAICS** — the object has `NAICS__c`; parsers don't populate it. Gap = mapping work in the parsers (not a new field). SAM/USASpending payloads carry NAICS; wire it through.
- **Email domain / business type / revenue / employees** — not provided by these gov sources; deferred to the **Lead Enrichment** platform after Lead creation (do not attempt at acquisition).
- No new Salesforce field is required — `OA_Discovered_Organization__c` already has targets for every field a connector can supply.

## 5. Unified-pipeline confirmation
`OA_CandidateDiscoveryService` already consumes any source's `OA_CanonicalOrg` list identically (dedup by
`Source_Payload_Hash__c`/`Canonical_Key__c`; Lead match by UEI/CAGE; status `Needs Review`/`Duplicate`). **No
connector-specific logic exists or is needed** — adding a source = a connector that emits `OA_CanonicalOrg`, nothing else.
