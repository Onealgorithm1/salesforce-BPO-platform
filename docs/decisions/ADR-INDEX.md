# ADR Index & Numbering Reconciliation

**As of 2026-07-08 (Opportunity Intelligence Phase 0).**

## Accepted on `main`
| ADR | Title |
|---|---|
| ADR-001 | Namespace strategy |
| ADR-002 | Client isolation strategy |
| ADR-003 | Package boundary strategy |
| ADR-004 | Metadata retrieval strategy |
| ADR-005 | Connector framework |
| ADR-006 | Canonical data model |
| ADR-007 | Entity resolution framework |
| ADR-008 | Security & credential standard |
| ADR-009 | Metadata registry |
| ADR-010 | Definition of ready |

## Opportunity Intelligence (this branch, `feature/opportunity-intelligence`)
| ADR | Title | Status |
|---|---|---|
| ADR-015 | Opportunity Intelligence Platform (charter) | Proposed |
| ADR-016 | Opportunity registry & run object reuse | Proposed |
| ADR-017 | Opportunity data model & staging grain | Proposed |
| ADR-018 | Opportunity review queue & human gates | Proposed |
| ADR-019 | Opportunity Intelligence security model | Proposed |

## Numbering reconciliation (open governance item)

ADR numbers **011–015 are used inconsistently across parallel branches** and are not yet
reconciled onto `main`:

- **ADR-011 / ADR-012** — External Intelligence vision + related, on `design/lead-enrichment-platform`.
- **ADR-013 (LinkedIn OAuth) / ADR-014 (Enterprise Auth)** — on a parallel auth/LinkedIn workstream.
- **ADR-015 (Opportunity Intelligence)** — originally filed on `feature/opportunity-intelligence-design`
  (commit `1b558d0`, not merged). **This branch supersedes and expands that ADR-015** with the
  Phase-0 design (Grants.gov-first sequencing, registry-reuse decision, expanded object model).

**Decision for this branch:** keep OI at **ADR-015 + ADR-016–019** to preserve continuity with the
existing ADR-015 that the readiness audit referenced, and record the collision here. A separate
governance pass should reconcile 011–015 across branches when they merge to `main` (this is **not**
an OI engineering task). None of the OI ADRs depend on the disputed 011–014 numbers for meaning.
