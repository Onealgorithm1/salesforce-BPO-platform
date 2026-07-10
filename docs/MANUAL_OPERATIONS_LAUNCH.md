# Manual Operations Launch Package — Program 025E

The platform is **GO for manual operations today** (Grants.gov procurement + preview enrichment), under `oauser` until the OA Runtime user is provisioned. Org `00Dbn00000plgUfEAI`. Human review mandatory; no auto-Opportunity; no unreviewed Lead write.

## What can run manually now
| Activity | Who | Where | Limit | Result |
|---|---|---|---|---|
| **Invoke Grants.gov intake** | Claude (gated) | anonymous Apex `OA_FederalOpportunityAcquisition.grantsGov(keyword, ≤10)` | ≤10/run, manual | Pending signals, screened + qualified + investment-scored |
| **Review procurement queue** | Louis | `OA_Opportunity_Signal__c` list view, `Review_Status__c='Pending'` | — | read decisions + rationale + evidence |
| **Promote to Opportunity** | Louis (human) | Salesforce UI — create Opportunity, link signal, set `Review_Status__c='Approved'` | — | CRM Opportunity (never automatic) |
| **Reject candidate** | Louis | set `Review_Status__c='Rejected'` + reason | — | audit trail |
| **Invoke enrichment preview** | Claude (gated) | `OA_EnrichmentOrchestrator.processScope(leads, source, null, false, 1, tel)` | ≤10 leads, `commitWrites=false` | zero writes; proposals **only if a connector is enabled + functional** (see limitation) |
| **Review enrichment proposals** | Louis | `OA_Enrichment_Change_Log__c` / preview output | — | approve/reject (no committed write without approval) |

## Frequency (manual cadence)
Daily: review the Grants queue + promote/reject. Weekly: run a fresh Grants intake (≤10) on a chosen keyword; pipeline + cost review. Monthly: KPI + governance review.

## Expected results
Grants intake returns candidates (mostly NO-GO for research grants — correct capability filtering); each carries compliance/qualification/investment + evidence; **0 Opportunities auto-created**. Enrichment preview makes **0 Lead writes**.

## Failure response
Callout failure → retry later / check the Named Credential (no secrets). AI failure → gateway falls back automatically; pause if cost spikes. See `OPERATIONAL_KILL_SWITCHES.md`.

## Rollback
Delete Pending pilot signals (query in kill-switches doc). Preview enrichment has nothing to roll back.

## Escalation
Any auto-Opportunity, unreviewed Lead write, or FLS anomaly → stop, notify Louis, capture evidence.

## Known limitation
**Lead Enrichment produces proposals only once a functional connector is wired** — the registry currently points Lead enrichment at the legacy `OA_USASpending_Connector` (no live callout). Manual preview is safe (zero writes) but will show 0 proposals until connector rewiring (engineering, deferred). Grants.gov procurement is fully functional today.
