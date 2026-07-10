# Operational Kill Switches & Emergency Rollback — Program 025E

Emergency controls for the Salesforce BPO Platform. Org `00Dbn00000plgUfEAI` (verify by ID). Every control is reversible; audit evidence is preserved.

## Immediate stops (fastest first)
1. **Abort a scheduled job:** Setup → Scheduled Jobs → delete the OA job; or `System.abortJob('<CronTriggerId>')`. Verify via `SELECT Id,CronJobDetail.Name,State FROM CronTrigger`.
2. **Remove runtime authority:** Setup → Permission Set Groups → `OA Runtime Operations` → Manage Assignments → remove **OA Runtime**. Instantly strips the automation user of all platform permissions.
3. **Deactivate the runtime user:** Setup → Users → OA Runtime → Deactivate (reassign/suspend owned jobs first).
4. **Revoke Named Credential principal access:** Setup → Named Credentials → Principals → remove OA Runtime → halts all external callouts (AI, USASpending).
5. **Disable a connector:** deploy `OA_Connector_Registry.<source>.Enabled__c = false` (CMDT) → the runner skips that source. (All connectors are `false` by default today.)

## Halt specific behaviors
- **Lead proposal generation:** ensure connectors disabled (above) and run enrichment only in preview (`commitWrites=false`).
- **Prevent write-back:** `OA_LeadWritebackService` writes only `Review_Status__c='Approved'` staging rows — leave rows un-approved; no committed pilot without Louis approval.
- **Prevent Opportunity creation:** platform never auto-creates; promotion is manual. No control needed beyond not doing it.

## Data rollback
- **Grants pilot signals:** `DELETE [SELECT Id FROM OA_Opportunity_Signal__c WHERE Source__c='Grants.gov' AND Review_Status__c='Pending' AND CreatedDate=TODAY]`.
- **Enrichment writes:** preview makes none; committed writes use the `OA_LeadWritebackService` rollback (restores prior values from `OA_Enrichment_Change_Log__c`).
- **Never** delete production business records outside a documented pilot rollback scope.

## Metadata rollback
- **Revert a PR:** `git revert` the merge commit → deploy `main`. Feature branches preserved.
- **Restore prior baseline:** `main` at `bffa36b` (025E) / `2ab2d87` (reconciliation) / `dbf8d12` (pre-reconciliation).
- **PSG:** unassign, then destructive-deploy if removing entirely.

## Audit evidence (preserve, do not delete)
`OA_Connector_Run__c`, `OA_AI_Request_Log__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`; decisions + rationale on `OA_Opportunity_Signal__c`; git history; deploy IDs.

## Incident escalation
Governance anomaly (auto-Opportunity, unreviewed Lead write, FLS bypass, unexpected scheduled job) → **execute the relevant stop above, notify Louis, capture evidence (record/job IDs, logs), do not fix-forward without review.**
