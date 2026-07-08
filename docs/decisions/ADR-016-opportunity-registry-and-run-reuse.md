# ADR-016 — Opportunity Registry & Run Object Reuse

**Status:** Proposed (design-only; awaiting G0)
**Date:** 2026-07-08
**Decider:** Louis Rubino
**Relates:** ADR-005 (connector framework), ADR-009 (metadata registry), ADR-015 (OI charter).

---

## Context

OI needs per-source configuration (which connector/parser/mapper class, which credential, endpoint,
dedupe key, whether review is required) and per-run telemetry. The prior design (ADR-015 design
branch) left two options open: **reuse** the existing `OA_Connector_Registry__mdt` /
`OA_Connector_Run__c`, or **mint new** `OA_Opportunity_Source__mdt` / `OA_Opportunity_Run__c`.

Verification of the existing CMDT and run object (2026-07-08) found they already carry every field
OI needs:
- `OA_Connector_Registry__mdt`: `Connector_Class__c`, `Parser_Class__c`, `Mapper_Class__c`,
  `Named_Credential__c`, `Endpoint_Path__c`, `Enabled__c`, `Category__c`, `Source_System__c`,
  `Dedupe_External_Id_Field__c`, `Staging_Object__c`, `Review_Required__c`, `Owner_Steward__c`,
  `Version__c`, `Status__c`.
- `OA_Connector_Run__c`: `Run_ID__c` (ExtId), `Category__c`, `Source_System__c`, `Status__c`,
  `Requested/Parsed/Mapped/Persisted__c`, `Records_Enriched__c`, `HTTP_Errors__c`,
  `Parse_Errors__c`, `Exceptions_Raised__c`, `Endpoint__c`, `Started/Ended__c`, `Initiated_By__c`,
  `Messages__c`.

## Decision

**Reuse `OA_Connector_Registry__mdt` and `OA_Connector_Run__c`.** OI sources are added as **new
registry rows** with `Category__c = 'Opportunity'`, `Staging_Object__c = 'OA_Opportunity_Signal__c'`,
`Enabled__c = false`, and `Dedupe_External_Id_Field__c = 'Canonical_Key__c'`. OI runs are stamped
`Category__c = 'Opportunity'`. **No new source CMDT or run object is created.**

Rationale:
- The registry is already source-agnostic and drives `OA_ConnectorRunner` dynamically; adding rows
  needs **zero framework or dispatcher changes**.
- A `Category__c` field already separates concerns, so opportunity rows/runs coexist cleanly with
  enrichment rows/runs without collision.
- Minting parallel CMDT/objects would duplicate a certified, tested surface for no functional gain
  and would fragment telemetry reporting.

## Consequences

- **Positive:** smallest footprint; reuses certified/tested config + telemetry; unified run
  reporting across programs via `Category__c`.
- **Negative:** enrichment and opportunity rows share one CMDT — mitigated by `Category__c` filters
  and clear `Source_System__c` naming (e.g. `GRANTS_GOV`, `SAM_OPPORTUNITIES`).
- **Reversible:** config-only; rows ship `Enabled__c=false`.

## Alternatives considered
- **New `OA_Opportunity_Source__mdt` + `OA_Opportunity_Run__c`** — rejected: duplicates a working
  surface, fragments telemetry, adds build/test cost with no benefit. Revisit only if opportunity
  config later diverges structurally from connector config (no evidence it will).
