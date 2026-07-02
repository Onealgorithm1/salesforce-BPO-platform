# ADR-005 — Connector Framework

**Status:** Accepted
**Date:** July 1, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before Sprint 1B (Connector SDK) implementation begins; re-review before adding any second connector (Census, Sprint 2)

---

## Context

The platform enriches Lead records from external open-data sources. The first such
integration — `OA_USASpendingClient` — was retrieved into the repository as production
metadata (`chore: reconcile usaspending production metadata`, commit `e40ff83`). A
verification pass on July 1, 2026 established the following facts about its current state:

- **Orphaned:** `OA_USASpendingClient` has zero callers anywhere in `force-app/`. Nothing
  invokes it.
- **No persistence:** it returns in-memory DTOs (`AwardResult`) and never writes to
  `OA_USASpending_Staging__c`, even though that staging object exists (20 fields, AutoNumber
  `USA-{0000}`, Private sharing, "pending human review before write-back" design).
- **No test:** there is no `OA_USASpendingClient_Test`. It cannot be deployed through a CI
  gate that enforces the Salesforce 75% coverage rule.
- **Non-standard auth:** it calls `new Http().send()` against a hardcoded endpoint via a
  **Remote Site Setting** (`OA_USASpending`), not a Named Credential. The repository's
  established pattern for callouts is Named Credential (`OA_Anthropic`; planned
  `OA_OpenAI_Prod` per INT-P01).
- **Version debt:** it is at API v61 (`TD-006`); the project source API version is v67.

The Sprint 2 objective is a **Census connector**, and further open-data connectors
(USASpending, Census, and beyond) are anticipated. Building each as a bespoke, one-off
client class — as USASpending currently is — would reproduce the same four defects per
connector: no persistence contract, no test scaffold, ad-hoc auth, and no shared
governor/error discipline.

A shared **Connector Framework** is therefore required so that every external-data
connector follows one contract for auth, callout execution, result normalization, staging
persistence (with human review), error capture, and testing.

---

## Decision

**Establish a Connector Framework as a Layer 1 (Core Platform) capability, and refactor
`OA_USASpendingClient` to be its first reference implementation.**

The framework defines a single lifecycle that every connector follows:

```
build request → execute callout (Named Credential) → parse to normalized DTO
              → map to staging SObject → persist (idempotent, pending review)
              → capture run outcome (status, errors, correlation id)
```

The framework lives in the **`force-app/` core package (`OA-Core-Platform`)**, because
`sfdx-project.json` already scopes that package as the home for "shared foundation,
utilities, integrations" and because connectors are reusable across every client org
(consistent with ADR-003's Layer 1 definition).

### Framework standards (binding for all connectors)

| Concern | Standard |
|---------|----------|
| **Naming** | `OA_` prefix, no namespace (ADR-001). Framework types: `OA_Connector*`. Concrete connectors: `OA_<Source>Connector`. |
| **API version** | New and refactored framework/connector Apex targets **v67** (closes `TD-006` for this surface; does not require touching unrelated v61 classes). |
| **Package layer** | Framework + connectors in `force-app/` (Layer 1, `OA-Core-Platform`). Not in `modules/` or `clients/`. |
| **Auth** | **Named Credential** for every connector, including public no-auth endpoints (declared as a Named Credential with no External Credential). Remote Site Settings are deprecated for connector use. |
| **Persistence** | Every connector writes to a dedicated staging object (`OA_<Source>_Staging__c`) with a human `Review_Status__c` gate before any write-back to production fields. No connector writes directly to `Lead` fields. |
| **Idempotency** | Staging writes are keyed by a run correlation id (`Enrichment_Run_ID__c`) plus the source's external id, so re-runs do not duplicate rows. |
| **Governor discipline** | Callouts respect Salesforce per-transaction callout limits; bulk enrichment runs asynchronously (Queueable/Batchable), coordinated with the existing `OA_SendGovernor` daily-limit pattern where relevant. |
| **Error capture** | Non-2xx responses and parse failures are recorded on the staging row (`HTTP_Status__c`, `Notes__c`) and surfaced to the run summary, never silently swallowed. |
| **Testing** | Every connector ships an `OA_<Source>Connector_Test` using the framework's shared `HttpCalloutMock` harness. Connector surface must reach ≥75% coverage before deploy. |

### Scope of this ADR

This ADR ratifies the framework's existence, placement, and standards. The concrete class
design (interfaces, base classes, mock harness) is specified in
`docs/CONNECTOR_FRAMEWORK.md` and built in Sprint 1B. The USASpending migration is
Sprint 1C.

---

## Consequences

**Positive**
- One contract to learn; the Census connector (Sprint 2) and all future connectors reuse
  auth, persistence, error handling, and test scaffolding rather than reinventing them.
- The human-review staging gate is enforced structurally, protecting the ~13k production
  Lead base from unreviewed external write-back.
- CI-deployable: the ≥75% coverage rule is satisfiable because every connector has a mock
  harness from day one.
- Auth is consistent and rotatable (Named Credential), matching the rest of the platform.

**Negative / costs**
- Sprint 1C must migrate `OA_USASpendingClient` off its Remote Site to a Named Credential —
  a behavior-preserving refactor that still requires sandbox validation (blocked by
  `TD-001`: no Full Sandbox yet).
- Introduces abstraction from a single example; the interface may need revision once the
  Census connector reveals a second shape (this is the explicit purpose of the Sprint 1
  review gate before Sprint 2).

---

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Keep bespoke per-source clients (status quo) | Reproduces USASpending's four defects (no persistence, no test, ad-hoc auth, no governor discipline) once per connector. Does not scale to Census + future sources. |
| Framework in a new feature module (`modules/connectors/`) | Connectors are reusable Layer 1 utilities per ADR-003, not an optional feature. `sfdx-project.json` already designates `force-app/` for integrations. A separate module adds a package dependency for no isolation benefit. |
| Named Credential only for authenticated APIs; Remote Site for public ones | Two callout patterns to maintain and test. Public endpoints as no-auth Named Credentials cost nothing extra and keep one code path. |
| Write enriched data straight to `Lead` fields (skip staging) | Removes the human-review safeguard on external data flowing into a compliance-sensitive (EDWOSB) lead base. The staging-with-review object already exists and is the intended design. |

---

## Related Decisions

- [[ADR-001-namespace-strategy]] — No namespace; `OA_` prefix governs framework/connector naming.
- [[ADR-002-client-isolation-strategy]] — Connectors are Layer 1, shared across client orgs.
- [[ADR-003-package-boundary-strategy]] — Places the framework in the Core Platform package (Layer 1).
- [[ADR-004-metadata-retrieval-strategy]] — USASpending metadata entered the repo via the retrieval/reconcile discipline defined here.
- `docs/CONNECTOR_FRAMEWORK.md` — Concrete SDK design (Sprint 1B).
- `docs/CONNECTOR_FRAMEWORK_ROADMAP.md` — Sprint 1A–1D → Sprint 2 sequencing.
- `docs/INTEGRATION_REGISTRY.md` — USASpending must be added as an active integration (currently undocumented there).
- `docs/TECHNICAL_DEBT.md` — `TD-006` (v61→v67) is partially retired for the connector surface by this ADR.
