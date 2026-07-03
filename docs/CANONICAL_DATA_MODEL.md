# Canonical Data Model — Evergreen Intelligence Platform

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Governed by [ADR-006](decisions/ADR-006-canonical-data-model.md).

**Confidence labels:** `[Verified from source]` = confirmed by reading repo metadata;
`[Unverified]` = org/runtime not checked from this repo; `[Proposed/Future]` = not yet built.

This document defines the **source-neutral canonical entities** that every Evergreen connector
maps into, so that USASpending, Census, SAM, NSF/NIH/SBIR, and future sources produce one
consistent internal representation before staging and human review.

---

## 1. Why a canonical model

Each public API returns its own shape. Without a canonical layer, every connector would invent
its own fields and every downstream consumer (entity resolution, review UI, write-back) would
need per-source logic. The canonical model fixes a small set of entities and identifiers that
all connectors populate.

The current `OA_USASpending_Staging__c` object is the **first, source-specific instance** of
this pattern. `[Verified from source]` Its fields already anticipate the canonical entities
below (recipient, award, match confidence, run correlation, review status).

---

## 2. Canonical entities

### 2.1 `Entity` (organization / recipient)
The external organization being researched (a contractor, awardee, business).

| Canonical attribute | Meaning | Strong/weak key | Source example `[Verified from source]` |
|---------------------|---------|-----------------|------------------------------------------|
| `uei` | SAM Unique Entity Identifier (12 chars) | **Strong** | `OA_USASpending_Staging__c.Recipient_UEI__c` — Text(12) |
| `legalName` | Recipient legal name | Weak (fuzzy) | `Recipient_Name__c` — Text(255) |
| `state` | Place-of-performance / location state | Weak | `Performance_State__c` — Text(5) |

### 2.2 `Award` (funding / obligation event)
A contract, grant, or obligation associated with an `Entity`.

| Canonical attribute | Meaning | Source example `[Verified from source]` |
|---------------------|---------|------------------------------------------|
| `awardId` | Source award identifier | `Award_ID__c` — Text(50) |
| `amount` | Award/obligation amount | `Award_Amount__c` — Number |
| `awardingAgency` | Funding agency | `Awarding_Agency__c` — Text(255) |
| `awardingSubAgency` | Funding sub-agency | `Awarding_Sub_Agency__c` — Text(255) |
| `type` | Contract/award type | `Contract_Type__c` — Text(100) |
| `description` | Award description | `Award_Description__c` — LongTextArea(500) |

### 2.3 `Lead` (CRM anchor) `[Verified from source]`
The existing Salesforce Lead the enrichment attaches to. Canonical link:
`OA_USASpending_Staging__c.Lead__c` (Lookup → Lead). Relevant Lead fields:
`Outreach_Segment__c` (picklist: *Teaming Partner*, *EDWOSB Sub Prospect*),
`Relationship_Status__c` (*Cold*→*Opportunity Identified*), `Outreach_Cohort__c` (Text 50).

### 2.4 `EnrichmentRun` (provenance) `[Verified from source]`
Correlates all rows produced by one connector execution.

| Canonical attribute | Source example |
|---------------------|----------------|
| `runId` | `Enrichment_Run_ID__c` — Text(36) (UUID-shaped) |
| `sourceEndpoint` | `Source_Endpoint__c` — Url |
| `queryDate` | `Query_Date__c` — Date |
| `httpStatus` | `HTTP_Status__c` — Number |
| `searchTerm` | `Search_Term__c` — Text(255) |

### 2.5 `MatchAssessment` (entity resolution result) `[Verified from source]`
See [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md).

| Canonical attribute | Source example |
|---------------------|----------------|
| `confidence` | `Match_Confidence__c` — Picklist **HIGH / MEDIUM / LOW** |
| `nameScore` | `Name_Match_Score__c` — Number |
| `reviewStatus` | `Review_Status__c` — Picklist **Pending / Approved / Rejected / Written Back** |

---

## 3. Source → canonical mapping (staging objects)

Each connector owns an `OA_<Source>_Staging__c` object that instantiates the canonical entities
plus source-specific columns. Every staging object **must** carry the framework-managed fields
(run id, source endpoint, http status, query date, review status, Lead lookup, notes) defined in
[`CONNECTOR_FRAMEWORK.md`](CONNECTOR_FRAMEWORK.md).

| Source | Staging object | Primary canonical entities | State |
|--------|----------------|----------------------------|-------|
| USASpending | `OA_USASpending_Staging__c` | Entity + Award + MatchAssessment | Exists `[Verified from source]`; not production-wired |
| Census Geocoder | `OA_Census_Staging__c` | Entity (geography enrichment) | `[Proposed/Future]` (Sprint 2) |
| SAM (Entity/Exclusions/Awards) | `OA_SAM_*_Staging__c` | Entity + Exclusion + Award | `[Proposed/Future]` |
| NSF / NIH / SBIR | `OA_Grant_Staging__c` (or per-source) | Entity + Award(grant) | `[Proposed/Future]` |

---

## 4. Identifier strategy

- **Preferred join key:** `uei` (SAM UEI) — deterministic where present.
- **Fallback:** fuzzy name + state (`legalName` + `state`) via the
  [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md), producing `nameScore` +
  `confidence`.
- **Run idempotency:** `runId` + source external id (e.g. `awardId`). Note `[Verified from
  source]`: no Salesforce External Id field exists on the staging object today, so idempotency
  must be enforced by match-by-query or by adding an External Id field in Sprint 1B.

---

## 5. Write-back rule (hard constraint)

No canonical entity is written back to `Lead`/`Contact`/`Campaign` automatically. Write-back
occurs **only** after `reviewStatus = Approved`, and even then is a separate, governed step.
`[Proposed]` Connectors never mutate production campaign data (see
[`SECURITY_BASELINE.md`](SECURITY_BASELINE.md) and root `README.md` governance rules).

---

## Related documents
- [ADR-006 — Canonical Data Model](decisions/ADR-006-canonical-data-model.md)
- [Evergreen Data Dictionary](EVERGREEN_DATA_DICTIONARY.md)
- [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md)
- [Connector Framework](CONNECTOR_FRAMEWORK.md)
- [Metadata Registry](METADATA_REGISTRY.md)
