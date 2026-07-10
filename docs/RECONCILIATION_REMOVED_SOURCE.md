# Program 024F — Removed Source (documented)

These files existed on `main` but are **NOT present in production `00Dbn00000plgUfEAI`**
(verified by Tooling API query, 2026-07-09). They are reverse-drift — source the
production org does not have. Per the reconciliation mandate (production is the source
of truth), they are removed from source. **No production metadata is deleted** — these
components do not exist in production.

## Superseded connector classes (12 classes / 24 files)
Merged to `main` via PRs #22–#24 (early Opportunity Intelligence Grants/SAM connectors),
then **superseded** by the Program 024 acquisition path (`OA_FederalOpportunityAcquisition`,
which is live in production). Confirmed absent from production.

- OA_GrantsGovConnector, OA_GrantsGovMapper, OA_GrantsGovParser, OA_GrantsGovRequest,
  OA_GrantsGovService, OA_GrantsGov_Test
- OA_SAMOpportunitiesService, OA_SAMOpportunities_Connector, OA_SAMOpportunities_Mapper,
  OA_SAMOpportunities_Request, OA_SAMOpportunities_ResponseParser, OA_SAMOpportunities_Test

## Orphaned permission set (1 file)
- OA_Opportunity_Intelligence_Runtime — on `main`, not in production. (Production uses
  `OA_Opportunity_Intelligence_Platform`.) Confirmed absent from production.

## Recovery
All removed files remain in git history on `main` (HEAD dbf8d12) and on the source
branches. Nothing is lost; this only removes source that production does not have so
that `main` == production.
