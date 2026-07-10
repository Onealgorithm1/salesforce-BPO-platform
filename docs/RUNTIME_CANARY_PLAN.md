# Runtime Canary Plan — Program 025E

Execute **immediately after** Louis provisions the OA Runtime user (Salesforce Integration license) and assigns `OA_Runtime_Operations`. **Do not execute under `oauser`.** Org `00Dbn00000plgUfEAI`.

## Prereqs
- OA Runtime user active; `OA_Runtime_Operations` assigned; Named Credential principal access granted.
- Claude runs the canaries **as the runtime user** (via a tooling session or by Louis running `sf apex run` authenticated as OA Runtime, or an authorized delegated run). Not as oauser.

## A. Security canary (run first)
Prove least privilege holds:
```apex
// Expect: FALSE for MAD/ViewAll; TRUE for the granted object perms.
System.debug('MAD='   + [SELECT PermissionsModifyAllData FROM Profile WHERE Id=:UserInfo.getProfileId()][0].PermissionsModifyAllData);
System.debug('canReadLead='   + Schema.sObjectType.Lead.isAccessible());
System.debug('canEditSignal=' + Schema.sObjectType.OA_Opportunity_Signal__c.isUpdateable());
System.debug('canDeleteLead=' + Schema.sObjectType.Lead.isDeletable());   // expect FALSE
```
Pass = MAD false, ViewAll false, Lead delete false, required objects accessible.

## B. Grants.gov canary (≤5 candidates)
```apex
OA_FederalOpportunityAcquisition.Result r = OA_FederalOpportunityAcquisition.grantsGov('information technology', 5);
System.debug('fetched='+r.fetched+' inserted='+r.inserted+' dupes='+r.duplicates);
// then, separate transactions:
// OA_OpportunityQualification.qualify(newIds);  OA_PursuitInvestment.evaluate(newIds);
```
Validate: API callout succeeds under the runtime user; ≤5 signals created Pending; dedupe works; compliance/qualification/investment populate; evidence citable; telemetry (`OA_Connector_Run__c`, `OA_AI_Request_Log__c`) written; **0 Opportunities**; visible in the review queue.
Rollback: `DELETE [SELECT Id FROM OA_Opportunity_Signal__c WHERE Source__c='Grants.gov' AND Review_Status__c='Pending' AND CreatedDate=TODAY]`.

## C. Lead Enrichment canary (≤5 Leads, preview only)
```apex
List<Lead> leads = [SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead
                    WHERE IsConverted=false AND UEI__c!=null LIMIT 5];
List<OA_Connector_Run__c> tel = new List<OA_Connector_Run__c>();
OA_EnrichmentOrchestrator.Metrics m = OA_EnrichmentOrchestrator.processScope(leads,'USASpending',null,false,1,tel);
System.debug('proposed='+m.recordsEnriched+' http='+m.httpErrors+' committed='+m.committed);
```
Validate: runtime user has Lead read + connector access; **committed=false**; **zero Lead writes** (compare SystemModstamp); no FLS violation; telemetry written.
> **Known limitation (025E):** with the current registry the USASpending Lead connector (`OA_USASpending_Connector`, legacy generation) produces no live callout → expect proposed=0. This canary proves *access + safety*, not proposal value. Proposal value requires connector rewiring (engineering, out of current scope).

## Pass criteria
Security canary passes (no MAD/ViewAll, denied ops denied, allowed ops succeed); Grants canary creates a governed queue with 0 Opportunities; enrichment canary makes zero writes with no FLS violations. Any failure → do not proceed to scheduling; capture evidence; see `OPERATIONAL_KILL_SWITCHES.md`.
