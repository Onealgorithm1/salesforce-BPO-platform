# Lead Acquisition — Connector Audit & Candidate Mapping (Phase 1–2)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-discovery`
**Mode:** read-only audit + design + source-only Apex (not deployed/run) · **Reuses:** connectors, `OA_ConnectorRunner`, `OA_CanonicalOrg`, `OA_Discovered_Organization__c`

> Phase 1 (connector audit) + Phase 2 (candidate mapping). Every connector returns `OA_ConnectorResult.organizations`
> (`List<OA_CanonicalOrg>`), which maps 1:1 to the Candidate object. The new `OA_CandidateDiscoveryService` persists
> those canonical orgs as Candidates with duplicate detection. **Nothing is enabled, executed, or written this sprint.**

---

## 1. Connector audit matrix

| # | Source | Connector class | Framework | Registry (prod) | Credential | Deployed | API readiness | Candidate suitability | Required changes | Risk | Verdict |
|---|--------|-----------------|-----------|-----------------|------------|----------|---------------|-----------------------|------------------|------|---------|
| 1 | **SAM Entity** | `OA_SAM_Connector` | B | present, disabled | NC `OA_SAM` (alpha) + EC (0 grants) | ✅ | needs key+JIT+prod endpoint | ⭐ High (authoritative federal entity registry) | data.gov key + JIT EC grant + alpha→prod + run via service | 🟠 Med | **BUILD NOW** (gated on cred) |
| 2 | **USASpending** | `OA_USASpending_Connector` | B | present, disabled | NC (public, NoAuth) | ✅ | ready | ⭐ High (award recipients w/ UEI) | run discovery via service | 🟢 Low | **BUILD NOW** |
| 3 | **Grants.gov** | `OA_GrantsGovConnector` | A (OI) | **not in enrichment registry** | NC `OA_GrantsGov` not in prod | ❌ (repo-only) | OI-scoped | ◐ Low (opportunity-shaped, not entities) | entity-extraction adapter (keep OI boundary) | 🟠 Med | **DEFER** (OI boundary; not entity discovery) |
| 4 | **SEC EDGAR** | `OA_SEC_Connector` | B | present, disabled | NC (public, NoAuth) | ✅ | ready | ◑ Med (public filers: CIK/name) | run discovery via service | 🟢 Low | **BUILD NOW** |
| 5 | **IRS Tax-Exempt** | `OA_IRS_Connector` | B | present, disabled | none (bulk CSV) | ✅ | ready | ◑ Med (EO orgs: EIN/name) | discovery = filter dataset → service | 🟢 Low | **BUILD NOW** |
| 6 | **Census** | `OA_Census_Connector` | B | present, disabled | NC (public, NoAuth) | ✅ | ready (demographic/geographic) | ✗ Low — **not an organization registry** | n/a — Census is market/geography enrichment, not org discovery | 🟢 Low | **WARN** (cannot produce org candidates) |
| 7 | **LinkedIn** | `OA_LinkedIn` (NC/EC/social) | — | not a registry connector | NC+EC+AuthProvider (live) | ✅ (social) | see §3 | audit-only | — | 🟠 Med | **AUDIT ONLY** |
| 8 | **Meta** | `OA_Meta` (NC/EC/social) | — | not a registry connector | NC+EC (live) | ✅ (social) | see §3 | audit-only | — | 🟠 Med | **AUDIT ONLY** |

## 2. Candidate mapping (Build-Now sources → `OA_Discovered_Organization__c`, via `OA_CanonicalOrg`)
All connectors already populate `OA_CanonicalOrg`; `OA_CandidateDiscoveryService.toRecord()` maps it to the object:

| Candidate field | Object field | Canonical source |
|---|---|---|
| Source System | `Source_System__c` | `sourceSystem` |
| Discovery Timestamp | `Last_Evaluated__c` (+ `CreatedDate`) | `System.now()` at persist |
| Organization Name | `Organization_Name__c` | `organizationName` |
| Normalized Name | `Normalized_Name__c` | `normalizedName` |
| Website | `Website__c` | `website` |
| UEI | `UEI__c` | `uei` |
| CAGE | `CAGE_Code__c` | `cageCode` |
| NAICS | `NAICS__c` | `naics` |
| Address | `Address__c`/`City__c`/`State__c`/`Postal_Code__c` | `address`/`city`/`state`/`postalCode` |
| Federal identifiers | `EIN__c`/`CIK__c`/`NPI__c` | `ein`/`cik`/`npi` |
| Source Confidence | `Source_Confidence__c` | `sourceConfidence` (HIGH/MED/LOW) |
| Source Payload Hash | `Source_Payload_Hash__c` | `payloadHash()` (SHA-256 of identity fields) |
| Canonical Key | `Canonical_Key__c` | `canonicalKey()` (UEI/EIN/NPI/CIK/CAGE, else NAME hash) |
| Review Status | `Qualification_Status__c` | set by dedup (Duplicate / Needs Review) |

**Existing-fields-only:** no new field was required — the object already has every mapping target.

## 3. LinkedIn / Meta — AUDIT ONLY (no candidates, no writes, no activation)
- **Readiness:** both have live Named + External Credentials (LinkedIn also an Auth Provider); prior smoke tests returned 200 (`GET /v2/userinfo`, `GET /me`). They are authenticated but **not registry connectors** and produce **no organization entities**.
- **Supported API paths:** LinkedIn Marketing/`userinfo`, Meta Graph `/me` and Marketing endpoints — **advertising/authenticated-account scope**, not a public company registry.
- **Compliance constraints:** LinkedIn & Meta platform terms **prohibit scraping** and restrict data storage/use to the authenticated account's own assets. Organization discovery from these platforms is **not a permitted use case**.
- **Allowed use cases (future, out of scope here):** first-party campaign/audience metrics for One Algorithm's own accounts — **not** candidate discovery.
- **This sprint:** no scrape, no candidates, no activation, no schedule, no records written. Documented and left dormant.

## 4. Governance
No connector enabled, no discovery executed, no candidates written, no Leads/Accounts touched. SAM credential remains
the same gated item as Lead Enrichment. Grants.gov stays within the Opportunity Intelligence boundary (not repointed).
