# Sprint 27 — Implementation Plan: Opportunity Signal Foundation + SAM.gov Slice (thin)

_Design · 2026-07-07 · **do not implement now** · scope = ADR-015 Phase 1 + start of Phase 2, dormant_

## Goal
Build the **Opportunity Signal foundation** (objects, registry, permset) and a **thin SAM.gov Contract Opportunities connector** that, in a controlled manual run, fetches a small set of opportunities and normalizes them into `OA_Opportunity_Signal__c` — **dormant, no scoring writes, no CRM Opportunity, no outreach.**

## Exact metadata to build (all dormant/additive; no changes to Lead Enrichment)
**Custom objects + fields** (design per ADR-015 §Object model):
- `OA_Opportunity_Signal__c` (+ fields: `Canonical_Key__c` ExtId/Unique, `Title__c`, `Solicitation_Number__c`, `Source__c`, `Agency__c`, `NAICS__c`, `PSC__c`, `Set_Aside__c`, `Place_of_Performance__c`, `Posted_Date__c`, `Response_Deadline__c`, `Estimated_Value__c`, `Type__c`, `URL__c`, `Status__c`, `Confidence__c`, `Review_Status__c`, `Opportunity_Run__c` lookup).
- `OA_Opportunity_Run__c` *(or decision: reuse `OA_Connector_Run__c`)* — minimal telemetry.
- **Defer** `OA_Opportunity_Score__c` / `OA_Go_NoGo_Assessment__c` / `OA_Pursuit_Candidate__c` to Sprint 28 (Phase 3).
- **CMDT** `OA_Opportunity_Source__mdt` record `SAM_Opportunities` (`Enabled__c=false`).
- **Named/External Credential** `OA_SAM_Opportunities` (data.gov key; **secret provisioned in Setup by Louis**, not in git).
- **Permission set** `OA_Opportunity_Intelligence_Runtime` (CRUD/FLS on the new objects; unassigned by default).

**Apex classes** (thin, reuse the SDK — no framework edits):
- `OA_SAMOpportunities_Request` — builds the get-opportunities REST call from registry config.
- `OA_SAMOpportunities_Parser` — response → in-memory signal rows.
- `OA_SAMOpportunities_Mapper` — signal rows → `OA_Opportunity_Signal__c` (dedupe key = noticeId).
- `OA_OpportunitySignalService` — orchestrates fetch→parse→map→(optional persist), **callout-before-DML**, commit flag default false.
- (reuse `OA_ConnectorHttp`, `OA_ConnectorRunner` patterns; **do not modify them**).

**Tests:** `OA_SAMOpportunities_*_Test` + `OA_OpportunitySignalService_Test` with mocked HTTP (no live callout in tests), covering parse, dedupe, preview (no DML), and commit paths. Target ≥ platform norm (~90%+).

**Docs:** `SAM_OPPORTUNITIES_CONNECTOR_RUNBOOK.md`; update this plan's status.

## Validation strategy
1. Check-only `sf project deploy validate` with `RunSpecifiedTests` (new tests) → 0 errors.
2. Deploy **dormant** (source `Enabled__c=false`, permset unassigned, NC secret-less in git).
3. Controlled connectivity smoke (1 read-only call) **only after** Louis provisions the data.gov key — capture status + top-level schema keys, no bulk.
4. Preview run (commit=false) on a tiny date window → inspect proposed Signals; **no persist** until reviewed.

## Deployment constraints
- No production data changes; objects ship empty/dormant.
- No connector enabled; no scheduling; no CRM Opportunity/outreach/submission.
- Callout-before-DML (Lead-Enrichment learning); ≤50 records/txn.
- Secrets only in External Credentials; least-privilege intent (temporary MAD `oauser` carryover documented).
- Branch: `feature/opportunity-intelligence-sam-slice`; gated deploy; no push/merge without approval.

## Out of scope for Sprint 27 (later sprints)
Scoring engine, Go/No-Go assessment, pursuit workflow, CRM Opportunity creation, additional sources, AI.

## Definition of Ready (ADR-010) checklist for Sprint 27
- [ ] Louis approves ADR-015 + this plan.
- [ ] data.gov Opportunities API key available for the `OA_SAM_Opportunities` External Credential (Setup).
- [ ] Object model field list frozen (this doc + ADR-015).
- [ ] Confirm `OA_Opportunity_Run__c` vs reuse `OA_Connector_Run__c` decision.
