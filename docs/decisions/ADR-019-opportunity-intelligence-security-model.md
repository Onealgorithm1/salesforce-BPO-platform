# ADR-019 — Opportunity Intelligence Security Model

**Status:** Proposed (design-only; awaiting G0)
**Date:** 2026-07-08
**Decider:** Louis Rubino
**Relates:** ADR-008 (security & credential standard), ADR-015 (OI charter), ADR-018 (human gates).

---

## Context

OI makes external callouts to government APIs and (eventually) can create CRM records. ADR-008
already sets the platform standard (Named/External Credentials, no secrets in objects/metadata/
Apex, minimal guest access). OI must apply that standard and add opportunity-specific guardrails.
A known standing constraint carries over from Program 1: the runtime user is the over-privileged
MAD `oauser` (0 spare licenses), which is the top standing operational risk.

## Decision

**OI adopts ADR-008 unchanged and adds five OI-specific rules:**

1. **Read-only sources, no external writes.** Every OI source is GET-only; OI submits/posts nothing
   to any external system in any phase.
2. **Dedicated credentials, no reuse of entity credentials.** Grants.gov = public Named Credential
   `OA_GrantsGov` (no secret). SAM Opportunities = **new** Named + External Credential
   `OA_SAM_Opportunities` (data.gov `api_key` in the EC, provisioned in Setup by Louis). **Do not**
   reuse or repoint the existing `OA_SAM` (Entity) or `OA_USASpending` credentials.
3. **Least-privilege permset, unassigned by default.** `OA_Opportunity_Intelligence_Runtime` grants
   CRUD/FLS on OI objects only; assigned only when a run is authorized. Reviewers get a narrower
   review grant (read + review-field edit; cannot enable connectors or create CRM records).
4. **New-object-only DML in MVP; CRM writes are separately gated.** The MVP's only DML is
   `insert OA_Opportunity_Signal__c` (+ reused run/exception rows). Creating a CRM `Opportunity`
   is Phase 5, human-approved (G5), one-at-a-time, audited and reversible via `OA_ChangeLogService`.
5. **Runtime-user exception is documented and gates automation.** OI inherits the temporary MAD
   `oauser` carryover; the MVP is manual (bounded exposure); **unattended/24×7 OI automation is
   gated (G5) on replacing the runtime user with a least-privilege user.**

## Consequences

- **Positive:** consistent with the certified security baseline; no new secret-handling surface for
  the MVP (Grants.gov is keyless); bounded blast radius (new-object-only writes); auditable/reversible.
- **Negative:** the MAD `oauser` weakens FLS enforcement — an accepted, documented, temporary risk
  that blocks only unattended automation, not the manual MVP.
- **Reversible:** design-only; connectors dormant, permset unassigned, object empty.

## Threat summary
Secret leakage (EC-only), over-privileged runtime user (documented, MVP manual), accidental write
outside OI (no code path; engines left alone), unauthorized connector enablement (`Enabled__c=false`
default + kill switch), rate-limit lockout (callout-before-DML, paging/backoff), queue noise
(dedupe + filters), parallel-session collision (isolated worktree/branch, quiet-org check). Full
matrix in `../OI_SECURITY_MODEL.md`.
