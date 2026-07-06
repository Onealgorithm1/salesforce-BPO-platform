# ADR-011 — External Intelligence Platform

**Status:** Proposed (design-only; awaiting Louis's approval)
**Date:** July 6, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any implementation of the registry, canonical objects, or a fourth connector

---

## Context

Three connectors now exist dormant on the Connector SDK (USASpending, SAM.gov, Grants.gov). The goal
has expanded from "Lead Enrichment" to an **Enterprise External Intelligence Platform** able to ingest,
govern, review, and activate intelligence from **dozens** of government and (later) commercial sources
through one architecture.

The spine is already in place and correct — ADR-005 (Connector SDK), ADR-006 (canonical data model),
ADR-007 (entity resolution + human review), ADR-008 (security/credential standard), ADR-009 (metadata
registry). What is missing is the platform scaffolding that makes a fourth, tenth, and twentieth
connector cheap and safe: a **connector registry**, a physical **canonical intelligence layer**, a
**unified dedupe** model, **connector-level governance**, an **activation** object, a **grants
management** module, and a **human-approved AI** layer.

## Decision

**Adopt the External Intelligence Framework** as specified in
[`EXTERNAL_INTELLIGENCE_FRAMEWORK.md`](../EXTERNAL_INTELLIGENCE_FRAMEWORK.md) and its companion designs.
Key ratifications:

1. **Four-layer architecture** — SDK (L1) → per-source Staging (L2, preserves ADR-006) → source-neutral
   **Canonical Intelligence** (L3, new) → **Activation** (L4, new). Two data tiers: staging is the
   immutable provenance floor; canonical is the deduped, reviewed, AI-consumable view.
2. **Six intelligence categories** — Entity, Opportunity, Contract, Relationship, Compliance, Market —
   each with a canonical object.
3. **Metadata-driven connector registry** — `OA_Connector_Registry__mdt` (declarations) +
   `OA_Connector_Run__c` (runtime telemetry). SDK discovers connectors from metadata; safety defaults
   `Enabled=false`, `Review_Required=true`, `Status=Draft`.
4. **Unified dedupe** — three separated jobs (run idempotency via `Dedupe_Key__c`; canonical identity
   via `Canonical_Key__c`; change detection via SHA-256), with survivorship and review rules; distinct
   from ADR-007 CRM linkage.
5. **Connector governance standards** — a per-connector Definition of Ready (security, secrets,
   logging, retry, errors, rate limiting, versioning, ownership, deprecation, testing, docs).
6. **Grant Management module** (`OA_Grant_Workspace__c` + proposal/submission/checkpoint) — design only;
   **no authenticated Grants.gov S2S integration** until a separate gated decision.
7. **Human-approved AI layer** — AI reads Approved canonical data, writes recommendations to
   `OA_Intelligence_Action__c`; humans approve before any CRM automation. AI never writes to the CRM.

**Invariants preserved (unchanged):** Connector SDK, engine, interfaces, human review gate, Pending
workflow, Named Credential pattern, ADR-005, ADR-008, no automatic Lead write-back. **Everything remains
additive and dormant**; nothing is deployed, activated, scheduled, or built as Apex under this ADR.

## Consequences

**Positive**
- A new connector = 4 SDK classes + 1 staging object + 1 registry row + tests + runbook; the registry,
  canonical layer, dedupe, review, and governance are reused.
- The ~13k production Lead base stays protected — two mandatory human gates and no auto write-back.
- Intelligence is source-neutral and auditable end to end (CRM → Action → Canonical → Staging → Run →
  Source), and ready for AI without loosening any gate.

**Negative / costs**
- New objects and a promotion service add surface area and mapping discipline.
- Two sources (IRS bulk files, SEC EDGAR) need an ingestion pattern the SDK doesn't yet cover.
- Commercial sources carry licensing/ToS/PII constraints that must be encoded per-source before use.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Keep adding bespoke connectors, no registry | Doesn't scale to dozens; central hardcoded registration becomes a bottleneck |
| One universal staging object for all sources | Loses source fidelity; unmanageable field sprawl (already rejected in ADR-006) |
| Skip the canonical layer; AI reads staging directly | AI would consume unreviewed, un-deduped, source-shaped data — unsafe and inconsistent |
| Let AI write to the CRM when confidence is high | Violates the human-review invariant and ADR-008 #5 |
| Build authenticated Grants.gov S2S now | Requires credentials/authority + security review; out of scope, separately gated |

## Related Decisions
- [[ADR-005-connector-framework]] — the SDK this platform is built on (unchanged).
- [[ADR-006-canonical-data-model]] — extended into physical canonical objects (per-source staging preserved).
- [[ADR-007-entity-resolution-framework]] — CRM linkage remains human-reviewed; distinct from dedupe.
- [[ADR-008-security-and-credential-standard]] — Named/External Credential + no auto write-back (unchanged).
- [[ADR-009-metadata-registry]] — `METADATA_REGISTRY.md` inventory vs. the runnable-connector registry.
- Designs: `EXTERNAL_INTELLIGENCE_FRAMEWORK.md`, `EXTERNAL_INTELLIGENCE_ROADMAP.md`,
  `CONNECTOR_REGISTRY_ARCHITECTURE.md`, `EXTERNAL_INTELLIGENCE_OBJECT_MODEL.md`,
  `UNIFIED_DEDUPE_STRATEGY.md`, `CONNECTOR_GOVERNANCE_STANDARDS.md`, `GRANT_MANAGEMENT_ROADMAP.md`,
  `EXTERNAL_INTELLIGENCE_AI_LAYER.md`.
