# ADR-010 — Definition of Ready

**Status:** Accepted
**Date:** July 2, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** After the first two sprints run under this gate

---

## Context

Work on this platform touches a live production campaign, a compliance-sensitive lead base, and
multiple parallel sessions (campaign, unsubscribe, Evergreen). Prior sessions produced planning
under a strict, user-enforced discipline: evidence-first, repository overrides memory, no
production action without approval. That discipline was implicit; it needs to be a written gate
so every unit of work meets it **before** implementation.

## Decision

**Adopt a written Definition of Ready** (`docs/DEFINITION_OF_READY.md`) with a universal gate
plus stricter gates for Apex/metadata changes and for new connectors:

- Universal: objective mapped to a repo artifact; evidence gathered with confidence labels;
  production/runtime claims labeled `[Unverified]` unless command-verified; scope + reversibility
  + approval recorded.
- Apex/metadata: sandbox/target confirmed, check-only validation planned, ≥75% coverage planned,
  no unapproved campaign/Lead/Contact/CampaignMember/Flow/scheduler/template changes.
- New connector: API behavior verified, data classification declared, Named Credential + staging
  + entity-resolution + review-gate + mock-test strategy defined.

## Consequences

- **Positive:** codifies the working style; prevents unverified production claims and surprise
  changes; makes "ready" objective and reviewable.
- **Negative:** adds up-front ceremony; low-risk doc tasks must still pass the (lightweight)
  universal gate.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Keep the discipline implicit | It has already been violated by drift (untested/orphaned code, missing credentials); implicit rules don't hold across sessions. |
| One-size gate for all work | Doc tasks and production Apex have very different risk; a single heavy gate is ignored, a single light gate is unsafe. |

## Related Decisions
- [[ADR-005-connector-framework]] · [[ADR-008-security-and-credential-standard]] — gated by this DoR.
- `docs/DEFINITION_OF_READY.md`, `docs/CONNECTOR_FRAMEWORK_ROADMAP.md`.
