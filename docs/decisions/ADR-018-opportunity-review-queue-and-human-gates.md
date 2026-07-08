# ADR-018 — Opportunity Review Queue & Human Gates

**Status:** Proposed (design-only; awaiting G0)
**Date:** 2026-07-08
**Decider:** Louis Rubino
**Relates:** ADR-015 (OI charter), ADR-017 (data model/grain).

---

## Context

OI's value and its safety both hinge on the same thing: **a human decides.** The platform can
autonomously fetch, normalize, dedupe, and (later) score opportunities, but it must never
autonomously commit the business — no CRM `Opportunity`, no pursuit assignment, no outreach, no
submission — without a person acting. The mechanism for that is the review queue.

## Decision

**Every ingested opportunity lands in a review queue as `Review_Status__c = 'Pending'`, and the
system only ever writes `Pending`.** All other transitions (Reviewed, Dismissed, Promoted) are
recorded human actions. **Promotion never auto-creates a CRM record**; creating a CRM `Opportunity`
is a separate, later, explicitly-gated human action (G5).

State machine on `OA_Opportunity_Signal__c`:
`Pending → {Reviewed | Dismissed | Promoted}` (human-only after ingest).

Human gates:
| Action | Automated? | Gate |
|---|---|---|
| Ingest signal as Pending | yes | — |
| Reviewed / Dismissed | no | human |
| Promote → Pursuit Candidate | no | human (P4) |
| Final Go/No-Go `Decision__c` | no | human (P4); system only drafts `Recommendation__c` |
| Create CRM `Opportunity` | no | human + **G5** (P5) |
| Assign owner / proposal tasks | no | human (P5/6) |
| External submission | **never** | not automated, any phase |

MVP surface = **standard Salesforce reporting** (Custom Report Type + "Opportunity Review Queue"
report + list views), not a custom Lightning app. Ranked queue, Go/No-Go review, and a pursuit
Kanban are later-phase UI builds.

## Rationale

- Puts the human decision at the center by construction, not by policy alone — the system has **no
  code path** to advance a signal past Pending.
- Standard reporting delivers the MVP queue with zero custom-UI build (consistent with the prior
  lesson that reports/dashboards are UI-first and report types must precede reports).
- Every transition is attributable (`Reviewed_By__c`/`Reviewed_At__c`/`Review_Notes__c`) for audit.

## Consequences

- **Positive:** strong, structural human-in-the-loop guarantee; auditable; cheap MVP surface.
- **Negative:** manual review is a throughput bottleneck at scale — addressed later by scoring
  (P3) ranking the queue and by metrics/SLAs (P4), never by removing the human gate.
- **Reversible:** design-only; queue object ships empty/dormant.

## Alternatives considered
- **Auto-promote high-confidence opportunities to CRM** — rejected (violates the core human-gate
  guarantee; not acceptable for a government-adjacent pursuit decision).
- **Custom Lightning review app for the MVP** — deferred (UI-first, not needed to prove the pipeline).
