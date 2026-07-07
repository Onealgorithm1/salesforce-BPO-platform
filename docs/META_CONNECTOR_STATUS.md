# Meta Marketing API Connector (INT-011) — Build Status

**Sprint:** GREEN implementation — dormant infrastructure only
**Date:** July 7, 2026
**Branch:** `feature/meta-connector-int011` (isolated git worktree; NOT merged to main)
**Org validated against:** `00Dbn00000plgUfEAI` (oauser@pboedition.com)
**Architecture:** [[META_MARKETING_INTEGRATION_PLAN]], [[ADR-013-LinkedIn-OAuth-Architecture]], [[ADR-014-Enterprise-Authentication-Standard]]

## State (explicit)

- **DORMANT.** `OA_Connector_Registry__mdt.Meta` has `Enabled__c = false`, `Status__c = Dormant`. The dispatcher skips it.
- **No authentication configured.** No Auth Provider, no OAuth, no principal token.
- **No secrets stored.** No App Secret, no System User token, no bearer value anywhere in source or metadata.
- **No API communication implemented.** `OA_MetaConnector.sync()` throws `OA_ConnectorException` ("dormant foundation"); it makes no callout.
- **No scheduler, no Flow, no automation, no Lead write-back.**

## Components (validated, check-only — NOT deployed)

| Component | Notes |
|---|---|
| `ExternalCredential OA_Meta` | **Custom** auth protocol + Named Principal `OA_Meta_Principal`. No Auth Provider, no secret. *(gitignored by repo policy `**/externalCredentials/` — org-only, like OA_SAM/OA_Anthropic.)* |
| `NamedCredential OA_Meta` | SecuredEndpoint → `OA_Meta` EC, host `https://graph.facebook.com`. |
| `PermissionSet OA_Meta_Connector` | Dormant, unassigned. EC principal access added in a future auth sprint. |
| `CustomMetadata OA_Connector_Registry.Meta` | INT-011 registry record, Enabled=false, Dormant. |
| `ApexClass OA_MetaConnector` | Skeleton; reuses SDK (`OA_ConnectorContext`, `OA_ConnectorException`). Does NOT implement `OA_IEnrichmentConnector` (Meta is ad-performance, not enrichment). All operational methods throw Not-Implemented. |
| `ApexClass OA_MetaConnector_Test` | 3 tests: metadata, SDK-context reuse, sync-throws. |

## Reuse (no framework duplicated)

`OA_ConnectorContext`, `OA_ConnectorException` (used), `OA_ConnectorHttp` (referenced as the future callout path, never invoked), `OA_Connector_Registry__mdt` (registration), `OA_Connector_Run__c` (future telemetry). No new HTTP/logging/secret framework created.

## Validation evidence

- `sf project deploy validate` → **Succeeded**, checkOnly=true, **Validation ID `0AfPn0000023Bx3KAE`**.
- Apex tests: **3 run, 0 failures**. `OA_MetaConnector` coverage **100% (11/11)**.
- PMD/Code Analyzer: Apex engine failed to instantiate (`UninstantiableEngineError` — environment/Java issue); **0 violations across 0 files** (not a code defect).

## Next sprint (future, separately approved)

Create the `OA_Meta` EC principal + non-expiring Business System User token (Custom header `Authorization: Bearer`) in the UI, grant EC principal access on `OA_Meta_Connector`, then implement read-only sync (Ad Accounts → Campaigns → Ad Sets → Ads → Insights). No App Review needed for own-account read (see plan Q1).

> The formal prose entry in `docs/INTEGRATION_REGISTRY.md` (INT-011) is intentionally deferred to merge time to avoid conflicting with the parallel session's active edits to shared docs. The connector is already registered in the live registry via the CMDT record above.
