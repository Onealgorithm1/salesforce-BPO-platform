# Lead Acquisition — Source Adapter Assessment (Phase 4)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** assessment (no build, no enablement, no scheduling)
**Reuses:** existing connectors + `OA_ConnectorRunner` + `OA_Connector_Registry__mdt` · writes candidates to `OA_Discovered_Organization__c`

> Phase 4. What each prioritized source needs to perform **Candidate discovery** (write to the candidate object), reusing
> the existing connector SDK. Discovery = fetch organizations → normalize → write Candidate (NOT enrich a Lead, NOT create a Lead).

---

## 1. Priority sources

### 1) SAM Entity — `OA_SAM_Connector` (Framework B, deployed dormant)
- **State:** class deployed; NC `OA_SAM` present (endpoint **alpha** `api-alpha.sam.gov`); EC `OA_SAM` present but **0 principal grants**; registry row disabled.
- **Fit:** best acquisition source — authoritative federal entity registry (UEI/CAGE/NAICS/address) → maps directly to the Candidate model.
- **Remaining work (gated):** (a) data.gov key + JIT EC principal grant; (b) move endpoint alpha→prod; (c) a **discovery mode** that writes `OA_Discovered_Organization__c` candidates (search/list) rather than single-entity enrichment. No new connector — extend the existing one's output path.

### 2) Grants.gov — `OA_GrantsGovConnector` (Framework A / Opportunity Intelligence)
- **State:** exists but on the **legacy Framework A** and scoped to **Opportunity Intelligence** (opportunities, not entities); NC `OA_GrantsGov` in repo, **not deployed to prod**; not in the enrichment registry runner.
- **Fit:** secondary — yields applicant/awardee organizations, but is opportunity-shaped. **Do not repoint the OI connector** (stay separate from OI).
- **Remaining work (gated):** a thin **entity-extraction adapter** that derives candidate organizations from grant records into `OA_Discovered_Organization__c`. Design-only; deferred (lower priority; keep OI boundary clean).

### 3) USASpending — `OA_USASpending_Connector` (Framework B, live-proven for enrichment)
- **State:** class deployed; NC `OA_USASpending` (public, NoAuth) live; registry row disabled. Already the certified enrichment source (78 Leads).
- **Fit:** strong — recipient/awardee organizations with UEI + award context. Public, no key.
- **Remaining work (gated):** a **discovery mode** that emits award **recipients** as candidates (dedup by UEI) rather than enriching a known Lead. Reuse the connector + mapper; add a candidate-write path. No new connector.

## 2. Common remaining work (all sources)
1. A **discovery output path**: connector result → `OA_Discovered_Organization__c` candidate (Source_System, confidence, canonical key, payload hash) instead of a Lead write. Reuse `OA_ConnectorRunner` + `OA_CanonicalOrg`.
2. **Duplicate detection** invoked post-write ([LEAD_ACQUISITION_DUPLICATE_DETECTION.md](LEAD_ACQUISITION_DUPLICATE_DETECTION.md)).
3. **Qualification** via existing `OA_Qualification_Rule__mdt` → set `Qualification_Status__c`.
4. **Human approval → Lead creation** (gated) → then existing Lead Enrichment.

## 3. What is NOT done (rules)
No connector enabled, no discovery executed, no jobs scheduled, no candidates written, no Leads created. SAM key/endpoint
and EC principal grant remain the same gated items as Lead Enrichment. Grants.gov stays within its OI boundary (not repointed).

## 4. Recommended sequence (future, gated)
USASpending discovery mode (public, lowest risk) → supervised candidate pilot + dedup validation → SAM Entity (after key/JIT/prod
endpoint) → Grants.gov entity-extraction (last, keep OI separate). Each step is a separate 🔴 gate.
