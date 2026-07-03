# Connector Framework Roadmap

**Version:** 0.1 (Proposed)
**Date:** July 1, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed sequencing. Governed by [ADR-005](decisions/ADR-005-connector-framework.md).

---

## Relationship to the platform roadmap

This is a **parallel workstream**, not a replacement for `docs/ROADMAP.md`. The 6-phase
platform roadmap (Phase 0 Foundation → Phase 6 AI Layer) remains authoritative for platform
engineering. The Connector Framework is an **enrichment/integration track** that runs
alongside it, feeding external open-data into the Lead base through a reviewed staging gate.

> Sprint numbering here (`1A/1B/1C/1D`, `2`) is the connector track's own sequence. It is
> distinct from the platform roadmap's Phase numbers and from the historical
> `Sprint 1 Production Launch Ready` commit (which was the email-campaign launch).

---

## Track sequence

```
Sprint 1A  Repository alignment ......... docs + ADR + roadmap → Commit   ◀ current
Sprint 1B  Connector SDK ............... interfaces, engine, mock harness
Sprint 1C  USASpending refactor ........ migrate onto SDK + Named Credential + staging
Sprint 1D  Testing .................... coverage, mocks, sandbox validation → Sprint Review
Sprint 2   Census Connector ........... second implementation via the SDK
```

---

## Sprint 1A — Repository alignment (current)

**Goal:** Make the Connector Framework a first-class, documented part of the repository
before any code exists — closing the gap found in verification (the framework had no
presence in the repo).

**Deliverables**
- [x] `docs/decisions/ADR-005-connector-framework.md` (Status: Proposed)
- [x] `docs/CONNECTOR_FRAMEWORK.md` — SDK design
- [x] `docs/CONNECTOR_FRAMEWORK_ROADMAP.md` — this document
- [ ] Cross-reference from `docs/ROADMAP.md` to this track *(proposed edit — held for commit approval)*
- [ ] `OA_USASpending` integration entry added to `docs/INTEGRATION_REGISTRY.md` *(proposed edit — held for commit approval)*
- [ ] Commit *(gated — see "Commit & branch" below)*

**Exit criteria**
- ADR-005 reviewed and moved from **Proposed** to **Accepted** by the decider.
- Roadmap model confirmed (parallel workstream vs. insert-as-Phase-1 vs. replace).
- Alignment docs committed to the agreed branch.

**Constraints:** No Apex, no metadata changes. Documentation only.

---

## Sprint 1B — Connector SDK

**Goal:** Build the framework types in `force-app/` (Layer 1, `OA-Core-Platform`, API v67)
per `docs/CONNECTOR_FRAMEWORK.md`.

**Deliverables**
- Contract interfaces (`OA_IConnector`, `OA_IConnectorRequest`, `OA_IConnectorParser`, `OA_IConnectorMapper`).
- Engine + support (`OA_ConnectorEngine`, `OA_ConnectorContext`, `OA_ConnectorRow`, `OA_ConnectorRunResult`, `OA_ConnectorHttp`).
- Async/invocation wrappers (`OA_ConnectorQueueable`, `OA_ConnectorInvocable`).
- Test scaffolding (`OA_ConnectorMock`, `OA_ConnectorTestBase`) with its own coverage.

**Exit criteria**
- SDK compiles; framework classes ≥75% covered by their own tests (no connector yet).
- No changes to the live USASpending client in this sprint (isolation).

---

## Sprint 1C — USASpending refactor

**Goal:** Re-home `OA_USASpendingClient` onto the SDK as `OA_USASpendingConnector`, behavior-
preserving, per §5 of `docs/CONNECTOR_FRAMEWORK.md`.

**Deliverables**
- `OA_USASpendingConnector` implementing the four interfaces (reusing existing build/parse logic).
- Named Credential `OA_USASpending` (public, no External Credential); retire Remote Site use.
- Persistence into `OA_USASpending_Staging__c` (fields already exist), idempotent by run id + `Award_ID__c`.
- Invocation wired (Flow-invocable + bulk Queueable) — no more orphaned client.
- API version raised to v67 for this surface (`TD-006` partial retirement).

**Exit criteria**
- End-to-end enrichment produces reviewed staging rows in a scratch org / sandbox.
- Old `OA_USASpendingClient` either deleted or reduced to a thin deprecated shim (decided in 1C).

---

## Sprint 1D — Testing → Sprint Review

**Goal:** Prove the framework and the first connector.

**Deliverables**
- `OA_USASpendingConnector_Test` via `OA_ConnectorMock` (success, non-2xx, empty-result, parse-error cases).
- Aggregate connector-surface coverage ≥75% (CI-deployable).
- Sandbox validation run (note prerequisite `TD-001`: Full Sandbox not yet provisioned).
- Integration registry + technical-debt updates finalized.

**Sprint Review gate (before Sprint 2)**
- Does the interface hold up against a real second source? Capture any changes Census will need.
- Confirm auth path readiness for an API-keyed source.

---

## Sprint 2 — Census Connector

**Goal:** Second implementation validates the abstraction, per §6 of `docs/CONNECTOR_FRAMEWORK.md`.

**Deliverables**
- Named Credential `OA_Census` (+ External Credential if an API key is used — exercises the authenticated path).
- New `OA_Census_Staging__c` object (seven framework-managed fields + Census-specific fields).
- `OA_CensusConnector` + `OA_CensusConnector_Test`.
- Registry entry for Census.

**Exit criteria**
- Census enrichment produces reviewed staging rows with no changes to the framework engine
  (or, if changes were required, they are captured as ADR-005 amendments).

---

## Commit & branch (Sprint 1A)

Sprint 1A alignment docs are committed to the dedicated branch `feature/connector-framework`
(off canonical `HEAD`), isolated from other workstreams. Two divergent copies of the repo exist
under OneDrive; work only in the canonical copy.

**Cross-session coordination**

- **Unsubscribe workstream status: COMPLETE — Production Done, Cleanup Pending.** The remaining
  cleanup is **non-blocking** for Evergreen work.
- **Do not touch unsubscribe records or files from the Evergreen workstream.** Unsubscribe
  cleanup is owned by that workstream, not this one.
- **Evergreen Sprint 1A remains documentation-only** — no Apex, no metadata, no deployment.
- **Sprint 1B must not start** until PR #1 is merged or explicitly accepted as the working
  baseline.

---

## Related documents

- [ADR-005 — Connector Framework](decisions/ADR-005-connector-framework.md)
- [Connector Framework — Architecture & SDK Design](CONNECTOR_FRAMEWORK.md)
- [Technical Implementation Roadmap (platform)](ROADMAP.md)
- [Integration Registry](INTEGRATION_REGISTRY.md)
- [Technical Debt Register](TECHNICAL_DEBT.md)
