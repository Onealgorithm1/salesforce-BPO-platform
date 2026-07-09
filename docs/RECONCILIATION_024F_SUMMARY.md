# Program 024F — Production Reconciliation Summary

**Org (source of truth):** 00Dbn00000plgUfEAI · **Branch:** chore/production-reconciliation (off `main` dbf8d12)
**Action:** source-only reconciliation of `main` to production. **No merge, no deploy, no activation, no production deletion.**

## What was done
1. Branched from `main`.
2. Retrieved authoritative source from production via manifest (ApexClass, ApexTrigger, CustomObject, PermissionSet — OA scope): **804 files** (164 classes, 1+1 triggers, 28 objects, 420 fields, 25 permsets).
3. Removed reverse-drift source (on `main`, confirmed absent from production) — documented in `RECONCILIATION_REMOVED_SOURCE.md`.
4. Preserved all documentation (`docs/`, 138 files) and git-only artifacts.
5. Ran check-only validation against production (parity proof).

## Diff summary (vs `main`)
| Change | Count |
|---|---|
| Files added | 239 |
| Files modified | 286 |
| Files removed (reverse-drift) | 25 (12 class `.cls` + 12 `.cls-meta` + 1 permset) |
| **New Apex classes reconciled onto `main`** | **41** (24 non-test + 17 test) |

**New non-test classes** (deployed in prod, previously missing from `main`): OA_AI_Gateway, OA_AI_ModelRegistry, OA_ComplianceScreen, OA_OpportunityIntelligence, OA_OpportunityQualification, OA_PartnerIntelligence, OA_PursuitInvestment, OA_DocumentIntelligence, OA_EvidenceCitation, OA_KnowledgeIntelligence, OA_FederalOpportunityAcquisition, OA_FederalAcquisitionScheduler, OA_USASpendingEnrichment, OA_IEnrichmentProvider, OA_CandidateDiscovery(+Service/Queueable), OA_CandidateApprovalService, OA_IdentityResolution, OA_SourceFusion, OA_LeadCompleteness, OA_LeadCreationService, OA_BusinessLifecycleService, OA_LifecycleStates.

**Modified** = field/picklist/FLS drift on existing objects (OA_Opportunity_Signal__c, OA_Discovered_Organization__c, …) and permsets reconciled to the production versions.

## Removed (reverse-drift — documented; NOT in production)
- 12 superseded connector classes: `OA_GrantsGov*` (6), `OA_SAMOpportunities_*` (6) — replaced by the Program 024 acquisition path.
- 1 orphaned permset: `OA_Opportunity_Intelligence_Runtime`.
All recoverable from `main` history (dbf8d12) and source branches.

## Out of scope (intentionally not touched this sprint)
- **NamedCredential `OA_GrantsGov`** — on `main`, not in production (orphaned), but a *different* metadata type outside this reconciliation's retrieve scope, and credentials are protected. **Deferred to the connector cleanup sprint.**
- NamedCredentials / ExternalCredentials (secrets), Flows, Reports, Dashboards, Remote Site Settings, Custom Metadata *records* — not part of the code-drift reconciliation; a follow-up parity pass can cover them.
- Duplicate connector generations (SAM ×3, USASpending ×2–3, connector framework ×2) — retained as-is (they exist in production); consolidation is a separate cleanup sprint.

## Validation
Check-only validation against production `00Dbn00000plgUfEAI` (RunLocalTests) — **Validation ID: 0AfPn0000023x2PKAQ** (679/679 components, 0 component errors; full local test suite). Parity confirmed: the reconciled source deploys clean to production.

## Rollback
Nothing merged, nothing deployed. Abandon the branch to fully revert. `main` (dbf8d12) is unchanged. Removed files remain in `main` history. Production is untouched throughout (retrieve is read-only).
