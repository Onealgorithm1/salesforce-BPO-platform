# Evergreen Data Dictionary

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Companion to [CANONICAL_DATA_MODEL.md](CANONICAL_DATA_MODEL.md).

**Confidence labels:** `[Verified from source]` = field metadata read from the repo on
2026-07-02; `[Proposed/Future]` = not yet built.

Field-level reference for Evergreen enrichment entities. Existing objects are documented from
metadata; future objects are marked `[Proposed/Future]`.

---

## 1. `OA_USASpending_Staging__c` `[Verified from source]`

Object: staging for USASpending.gov award data, AutoNumber name `USA-{0000}`, Private sharing,
"pending human review before write-back" (no PII — public federal data).

| Field | Type | Canonical role | Notes |
|-------|------|----------------|-------|
| `Recipient_UEI__c` | Text(12) | Entity.uei | SAM UEI; **preferred join key**. |
| `Recipient_Name__c` | Text(255) | Entity.legalName | Fuzzy match source. |
| `Performance_State__c` | Text(5) | Entity.state | Place-of-performance state code. |
| `Award_ID__c` | Text(50) | Award.awardId | Source award identifier. |
| `Award_Amount__c` | Number | Award.amount | |
| `Awarding_Agency__c` | Text(255) | Award.awardingAgency | |
| `Awarding_Sub_Agency__c` | Text(255) | Award.awardingSubAgency | |
| `Contract_Type__c` | Text(100) | Award.type | |
| `Award_Description__c` | LongTextArea(500) | Award.description | Truncated to 500. |
| `Lead__c` | Lookup → Lead | Lead anchor | Nullable for search-only rows. |
| `Enrichment_Run_ID__c` | Text(36) | EnrichmentRun.runId | UUID-shaped correlation id. |
| `Source_Endpoint__c` | Url | EnrichmentRun.sourceEndpoint | Audit of the exact endpoint. |
| `Query_Date__c` | Date | EnrichmentRun.queryDate | |
| `HTTP_Status__c` | Number | EnrichmentRun.httpStatus | Non-2xx rows retained for diagnosis. |
| `Search_Term__c` | Text(255) | EnrichmentRun.searchTerm | |
| `Match_Confidence__c` | Picklist | MatchAssessment.confidence | Values: **HIGH / MEDIUM / LOW**. |
| `Name_Match_Score__c` | Number | MatchAssessment.nameScore | Numeric fuzzy score. |
| `Review_Status__c` | Picklist | MatchAssessment.reviewStatus | Values: **Pending / Approved / Rejected / Written Back**. |
| `Notes__c` | LongTextArea(500) | diagnostic | Error/reviewer notes. |

**Gap `[Verified from source]`:** no Salesforce **External Id** field → idempotent upsert needs
a new External Id field or match-by-query (Sprint 1B decision).

---

## 2. Lead — Evergreen-relevant custom fields `[Verified from source]`

| Field | Type | Values / notes |
|-------|------|----------------|
| `Outreach_Segment__c` | Picklist | *Teaming Partner*, *EDWOSB Sub Prospect* |
| `Relationship_Status__c` | Picklist | *Cold, Warm, Meeting Booked, Call Complete, Capability Statement Sent, Teaming Active, Opportunity Identified* |
| `Outreach_Cohort__c` | Text(50) | **Free text, not a picklist.** Code filters only `'Wave 1'`; description names *Test / Validation, Pilot Batch 1, Pilot Batch 2, Production Ramp*. Actual org values `[Unverified]`. |
| `Is_Test_Lead__c` | Checkbox | Excludes test leads from enrollment. |
| `Meeting_Booked_Date__c` | Date | |

---

## 3. `OA_Campaign_Settings__c` (governor state) `[Verified from source]`

Hierarchy custom setting backing `OA_SendGovernor`.

| Field | Type | Notes |
|-------|------|-------|
| `Daily_Send_Cap__c` | Number | Daily cap (code default 200 if unset). |
| `Sends_Today__c` | Number | Running count; reset daily. |
| `Cap_Reset_Date__c` | Date | Last reset date. |

---

## 4. Future staging objects `[Proposed/Future]`

Each follows the canonical + framework-managed field contract.

- **`OA_Census_Staging__c`** (Sprint 2) — geography enrichment fields (geoid, tract, state,
  county) + framework-managed fields.
- **`OA_SAM_*_Staging__c`** — entity registration / exclusions / contract awards.
- **`OA_Grant_Staging__c`** — NSF/NIH/SBIR award(grant) data.

Field lists for these are defined when each connector is planned (Definition of Ready gate,
[`DEFINITION_OF_READY.md`](DEFINITION_OF_READY.md)).

---

## Related documents
- [Canonical Data Model](CANONICAL_DATA_MODEL.md)
- [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md)
- [Metadata Registry](METADATA_REGISTRY.md)
- [Connector Framework](CONNECTOR_FRAMEWORK.md)
