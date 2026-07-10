# Operational Runbook — Salesforce BPO Platform

**Procedures for running the platform.** State of record lives in `docs/OPERATIONAL_BASELINE.md`. Org `00Dbn00000plgUfEAI` (verify by ID). Human review is mandatory; nothing auto-creates Opportunities or writes Leads unapproved.

## Daily review procedure
1. **Grants.gov queue:** open the Procurement Intake report/queue → `OA_Opportunity_Signal__c WHERE Review_Status__c='Pending'`. For each: read Compliance_Decision__c, Qualification_Decision__c, Investment_Level__c, Evidence_Summary__c.
   - **Approve** a candidate → set Review_Status__c='Reviewed'/'Approved' and (human) create the CRM Opportunity manually. **Never auto-create.**
   - **Reject** → set Review_Status__c='Rejected' with a rationale.
2. **Lead Enrichment:** review enrichment proposals (preview output / `OA_Enrichment_Change_Log__c`). Approve only via the reviewer-gated writeback (`OA_LeadWritebackService`, requires Review_Status__c='Approved'). **No unreviewed writeback.**
3. **Health:** check Connector & Runtime Health — `OA_Connector_Run__c` failures, `AsyncApexJob` failures, `OA_AI_Request_Log__c` HTTP errors + cost, `OA_Knowledge_Document__c` Manual Review backlog, `OA_Enrichment_Exception__c` new rows.

## Approval procedure (Grants candidate → Opportunity)
Human decides. Confirm compliance GO (not NO-GO/REVIEW), qualification fit, evidence-backing → create Opportunity in the UI, link the signal, set Review_Status__c='Approved'. Platform never does this automatically.

## Rejection procedure
Set Review_Status__c='Rejected'; record reason in Compliance/Qualification rationale; leave the signal for audit (do not delete unless within pilot rollback scope).

## Rollback
- **Grants pilot signals:** `DELETE [SELECT Id FROM OA_Opportunity_Signal__c WHERE Source__c='Grants.gov' AND Review_Status__c='Pending' AND CreatedDate=TODAY]`.
- **Enrichment:** preview makes no writes (nothing to roll back); committed writes use the `OA_LeadWritebackService` rollback path.
- **Metadata:** revert the relevant PR; PSG unassign + destructive-deploy.

## Failure response
- **Connector failure** (`OA_Connector_Run__c` Status='Failed'): read error; if API/network, re-run manually later; if auth, check the Named Credential (do not expose secrets); log persists for audit.
- **AI failure** (`OA_AI_Request_Log__c` Status_Code≥400): check OpenRouter status; the gateway falls back (Anthropic) automatically; if cost spikes, pause AI-dependent runs.
- **Apex job failure** (`AsyncApexJob` Failed): inspect ExtendedStatus; re-enqueue manually; never auto-retry destructively.
- **Document extraction failure** (`OA_Knowledge_Document__c` Extraction_Status IN ('Failed','Manual Review')): binary docs need the (unbuilt) OCR sidecar — route to manual review.

## Escalation
Governance-sensitive anomaly (an Opportunity auto-created, an unreviewed Lead write, FLS bypass, a scheduled job firing unexpectedly) → **stop automation, notify Louis, capture evidence** (record IDs, job IDs, logs). Do not "fix forward" without review.

## Credential rotation
Named/External Credentials are protected. Rotation is a Louis-gated action in Setup; never place secrets in source/logs/docs. After rotation, run a read-only smoke callout to confirm 2xx.

## User deactivation / break-glass
- **Runtime user** (once provisioned): deactivate in Setup; scheduled jobs owned by it must be reassigned or suspended first.
- **Break-glass:** if the least-privilege runtime is insufficient for an incident, a temporary admin action is Louis-approved, time-boxed, and logged — then reverted.

## Emergency schedule suspension
No schedules are enabled today. If/when scheduled: Setup → Scheduled Jobs → delete the OA job; or `System.abortJob(jobId)` (Louis-gated). Confirm via `CronTrigger`.

## Audit evidence
Every run writes telemetry: `OA_Connector_Run__c`, `OA_AI_Request_Log__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`. Compliance/qualification/investment decisions + rationale persist on `OA_Opportunity_Signal__c`. Retain for audit.

## Weekly review
Pipeline (pursued vs passed), AI cost trend, connector success rate, exception backlog, review-queue age, governance check (0 auto-Opps, 0 unreviewed writes).

## Monthly review
KPIs (below); SAM.gov/Graph fast-follow decision; partner-capability data progress; least-privilege user status.

## KPI review
Opportunities discovered/week · % evidence-backed · qualification GO-rate · leads enriched (once committed) · review-queue latency · job success ≥95% · AI cost within budget · **governance violations = 0**.
