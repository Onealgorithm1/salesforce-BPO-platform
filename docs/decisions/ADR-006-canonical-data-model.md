# ADR-006 — Canonical Data Model

**Status:** Accepted
**Date:** July 2, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before Sprint 1B (Connector SDK); re-review when the second connector (Census) lands

---

## Context

Each public data source (USASpending, Census, SAM, NSF/NIH/SBIR) returns a different shape.
Without a shared internal representation, every connector and every downstream consumer (entity
resolution, review, write-back) would need per-source logic. The existing
`OA_USASpending_Staging__c` already implies a canonical structure `[Verified from source]` — it
carries recipient (Entity), award (Award), match (MatchAssessment), and run-provenance fields —
but that structure is implicit and source-specific.

## Decision

**Adopt a source-neutral canonical data model** (`Entity`, `Award`, `Lead` anchor,
`EnrichmentRun`, `MatchAssessment`) that every connector maps into, as specified in
[`CANONICAL_DATA_MODEL.md`](../CANONICAL_DATA_MODEL.md). Each source keeps its own
`OA_<Source>_Staging__c` object that instantiates the canonical entities plus source-specific
columns and the framework-managed fields.

- **Preferred join key:** SAM UEI (`Recipient_UEI__c`, Text(12)).
- **Fallback:** fuzzy name + state (delegated to [ADR-007](ADR-007-entity-resolution-framework.md)).
- **Idempotency:** `Enrichment_Run_ID__c` + source external id. Note `[Verified from source]`:
  no Salesforce External Id field exists today; add one or match-by-query in Sprint 1B.

## Consequences

- **Positive:** connectors and consumers share one vocabulary; new sources are additive.
- **Negative:** requires disciplined mapping per connector; the model is abstracted from a single
  example (USASpending) and may need revision once Census exercises a second shape.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Per-source ad-hoc schemas | Reproduces bespoke logic everywhere; no shared entity resolution or review. |
| One giant universal staging object | Loses source fidelity; unmanageable field sprawl. |
| Model finalized before any connector | Premature; the model is validated by the second connector, not invented up front. |

## Related Decisions
- [[ADR-005-connector-framework]] — the framework that consumes this model.
- [[ADR-007-entity-resolution-framework]] — matching on canonical identifiers.
- [[ADR-009-metadata-registry]] — inventories the objects that instantiate the model.
- `docs/CANONICAL_DATA_MODEL.md`, `docs/EVERGREEN_DATA_DICTIONARY.md`.
