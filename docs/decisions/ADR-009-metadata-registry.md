# ADR-009 — Metadata Registry

**Status:** Accepted
**Date:** July 2, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** After each metadata retrieval or significant metadata addition

---

## Context

The repository has grown across multiple sessions (campaign automation, Graph/meeting pipeline,
communication preferences, an orphaned USASpending connector). Verification on 2026-07-02
surfaced drift that no single document tracked `[Verified from source]`:

- `OA_BookingPoller` exists **twice** (force-app and modules).
- `OA_USASpendingClient` has **no test** and **zero callers**.
- `OA_Anthropic` Named Credential references a **missing External Credential**.
- Three Remote Sites persist against the Named-Credential standard.

`METADATA_CLASSIFICATION.md` governs *which layer* metadata belongs to, but there was no single
*inventory* of what exists.

## Decision

**Maintain `docs/METADATA_REGISTRY.md` as the authoritative inventory of committed metadata**
(classes, triggers, flows, objects, platform events, custom settings/metadata, named/external
credentials, remote sites, permission sets), built from `git ls-files`, with a
"registry-derived findings" section that feeds `TECHNICAL_DEBT.md`.

The registry is **evidence-based** (every entry verified from source) and updated after each
retrieval or significant addition. It complements, not replaces, `METADATA_CLASSIFICATION.md`.

## Consequences

- **Positive:** drift (duplicates, missing tests, missing credentials) is visible and tracked; onboarding and audits have one map.
- **Negative:** must be kept current or it misleads; overlaps with classification doc (mitigated by clear scoping — inventory vs. layer assignment).

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Rely on `METADATA_CLASSIFICATION.md` alone | It assigns layers; it is not a complete current inventory. |
| Generate inventory ad hoc when needed | No durable record; findings (duplicates, gaps) get re-discovered each time. |
| Auto-generate only (no findings) | A raw list misses the *interpretation* (duplicate class, missing test) that makes it useful. |

## Related Decisions
- [[ADR-003-package-boundary-strategy]] — layer boundaries the registry checks against.
- [[ADR-006-canonical-data-model]] — objects the registry inventories.
- `docs/METADATA_REGISTRY.md`, `docs/METADATA_CLASSIFICATION.md`, `docs/TECHNICAL_DEBT.md`.
