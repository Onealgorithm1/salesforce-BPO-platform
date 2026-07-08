# ADR-017 — Opportunity Data Model & Staging Grain

**Status:** Proposed (design-only; awaiting G0)
**Date:** 2026-07-08
**Decider:** Louis Rubino
**Relates:** ADR-006 (canonical data model), ADR-015 (OI charter), ADR-016 (registry/run reuse).

---

## Context

OI must land normalized opportunities somewhere for human review. The org already has three staging
objects — `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c`, `OA_Discovered_Organization__c` —
all of **entity/company grain** (UEI, CAGE, legal business name, registration status). An
opportunity posting (a solicitation with a NAICS, set-aside, deadline, and value) is a
**fundamentally different grain**.

## Decision

**Introduce one new object, `OA_Opportunity_Signal__c`, at opportunity-posting grain**, and **do not
reuse any entity staging object.** For the MVP, this single object serves as both the **staging
landing zone** and the **review queue** (differentiated by `Review_Status__c`).

Downstream objects `OA_Opportunity_Score__c` (P3), `OA_Go_NoGo_Assessment__c` (P4), and
`OA_Pursuit_Candidate__c` (P4) are **designed now but deferred** to their phases.

Dedupe identity is a **source-scoped external id** `Canonical_Key__c` (Unique ExtId), e.g.
`GRANTS:<oppNumber>`, `SAM:<noticeId>`. Provenance is a lookup to the reused `OA_Connector_Run__c`;
lineage is a no-PII `Raw_Payload_Ref__c`.

## Rationale

1. **Grain mismatch.** Forcing opportunity fields onto a company-shaped object would be a modeling
   error and would degrade both models.
2. **No-touch guardrail.** Entity staging is used by Lead Enrichment; writing opportunity rows into
   it would violate the hard rule against touching Lead-Enrichment data.
3. **Idempotency & reversibility.** A dedicated unique `Canonical_Key__c` gives clean upsert dedupe;
   the `Connector_Run__c` stamp gives delete-by-run reversibility for the insert-only MVP.
4. **Simplicity.** Staging == review queue on one object keeps the MVP minimal; splitting into a
   raw-staging + curated-queue pair is unnecessary at MVP volume and can be revisited later.

## Consequences

- **Positive:** clean grain; zero blast radius on entity/enrichment data; idempotent, reversible,
  auditable; smallest MVP footprint (one object).
- **Negative:** one more object to maintain — justified by the grain difference.
- **Reversible:** design-only; object ships empty/dormant.

## Alternatives considered
- **Reuse an entity staging object** — rejected (grain mismatch + no-touch violation).
- **Separate raw-staging and review-queue objects** — deferred; not warranted at MVP volume.
- **Reuse `OA_Enrichment_Exception__c`/`OA_Enrichment_Change_Log__c` for anomalies/audit** —
  **accepted** (those are generic, target-object-agnostic services); only the *primary* opportunity
  grain is new.
