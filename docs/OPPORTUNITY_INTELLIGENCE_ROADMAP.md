# Opportunity Intelligence Platform — Roadmap

_Design · 2026-07-07 · Program 2 · under ADR-011 (External Intelligence) / ADR-015 (this program)_

Governing principles (carry forward from Lead Enrichment v1.1): dormant-by-default · read-only sources · human-gated decisions · explainable/auditable · reversible · reuse the certified connector SDK · no framework redesign.

## Phase 1 — Opportunity Signal foundation
Objects + registry, dormant. `OA_Opportunity_Signal__c` (+ `Score__c`, `Go_NoGo_Assessment__c`, `Pursuit_Candidate__c`), `OA_Opportunity_Source__mdt`, reuse `OA_Connector_Run__c`. FLS permset. No connector live yet. **Exit:** objects deployed dormant, tests, 0 rows.

## Phase 2 — First connector (SAM.gov Contract Opportunities)
Thin Request/Parser/Mapper on the existing SDK → emits Signals. Credential (data.gov key) via Named/External Credential. Fetch → normalize → dedupe (by `noticeId`/`Canonical_Key__c`). **Exit:** controlled fetch produces Signals in a dormant/manual run; no scoring/assessment writes beyond signals; audited.

## Phase 3 — Go/No-Go scoring
`OA_FieldWritePolicy`-style CMDT-weighted scoring engine (explainable, versioned). Produces `OA_Opportunity_Score__c` + draft `OA_Go_NoGo_Assessment__c`. **Exit:** scored signals with per-factor reasons; human sees a ranked review queue; no Opportunity created.

## Phase 4 — Pursuit candidate workflow
`OA_Pursuit_Candidate__c` lifecycle (Draft→UnderReview→Approved/Rejected) + review UI (report/list views, later Lightning). Human approval gate to promote. **Exit:** humans work a pipeline; approval creates a candidate (still no CRM Opportunity).

## Phase 5 — Capture management
On human approval only: create Salesforce `Opportunity`, assign owner, proposal `Task`s. Read-only Account linkage (ADR-007). **Exit:** approved pursuits become real CRM Opportunities via a gated action.

## Phase 6 — Proposal support
Proposal checklists/tasks, teaming-partner flags, deadline tracking. Still no external submission. **Exit:** proposal workflow scaffolding.

## Phase 7 — Grant management integration (later)
Fold in Grants.gov/SBIR grant workspace (`OA_Grant_Workspace__c` per prior design). Grant *management*, not submission automation.

## Phase 8 — AI recommendations (later)
Human-in-the-loop AI layer (ADR-011 AI layer) to *suggest* fit/summaries — never to decide. Mandatory human approval retained.

## Standing constraints
- No auto-Opportunity, no outreach, no submission — ever without human approval.
- Least-privilege runtime user is the target (inherits the temporary MAD-`oauser` exception).
- Sources dormant until explicitly enabled; secrets only in External Credentials.

**Next:** Phase 1 + first connector slice → `SPRINT27_IMPLEMENTATION_PLAN.md`.
