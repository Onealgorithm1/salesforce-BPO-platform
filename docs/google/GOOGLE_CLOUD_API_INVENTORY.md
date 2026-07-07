# Google Cloud API Inventory — `onealgorithm-bpo`

**Sprint 2** · **Verified 2026-07-07: 49 APIs enabled.** Classification only — **nothing disabled** (gated).
Classes: **KEEP** (foundational, in use) · **KEEP FOR ROADMAP** (stated goal, not yet used) · **DISABLE CANDIDATE** (not on any goal) · **UNKNOWN**.

## KEEP — 15 (foundational / governance / in use)
`cloudresourcemanager`, `iam`, `iamcredentials` (impersonation), `serviceusage`, `servicemanagement`, `cloudapis`, `secretmanager`, `logging`, `monitoring`, `cloudtrace`, `telemetry`, `storage` (+`storage-api`,`storage-component`), `billingbudgets` (budget alert).
*Why:* core project/IAM/observability/secret plumbing + the budget that was created this workstream.

## KEEP FOR ROADMAP — 24 (stated goals; enable-in-place is fine, they map to planned connectors)
Data/AI: `bigquery`, `bigquerystorage`, `bigquerydatatransfer`, `generativelanguage` (Gemini API), `cloudaicompanion` (Gemini for Google Cloud).
Marketing: `analyticsdata` (GA4), `searchconsole`, `businessprofileperformance`, `tagmanager`, `googleads`.
Workspace: `drive`, `docs`, `sheets`, `slides`, `forms`, `people`, `calendar-json`, `meet`, `gmail`, `driveactivity`, `workspaceevents`.
YouTube: `youtube`, `youtubeanalytics`, `youtubereporting`.
*Why:* each maps to a stated integration goal. **Least-privilege note:** ideally enable per-connector at build time; since they're already on, keep + track usage.

## DISABLE CANDIDATE — 10 (not on any stated goal → recommend disabling in a gated API-trim sprint)
`retail`, `datastore`, `dataplex`, `dataform`, `analyticshub`, `bigqueryconnection`, `bigquerydatapolicy`, `bigquerymigration`, `bigqueryreservation`, `sql-component`.
*Why:* Retail/Datastore/CloudSQL aren't in scope; the advanced-BigQuery + data-governance APIs (`dataplex`/`dataform`/`analyticshub`/`bigquery{connection,datapolicy,migration,reservation}`) are unused surface/quota. **Reversible** — re-enable if a future need appears. **Not disabled this sprint.**

## UNKNOWN — 0
Every enabled API is classifiable from the stated goals. None require investigation.

## Not enabled (relevant gaps)
Workload APIs absent (so no such resources exist): `run`, `cloudfunctions`, `container` (GKE), `compute`, `pubsub`, `cloudscheduler`, `artifactregistry`, **`aiplatform` (Vertex AI)**. Security/governance absent: `securitycenter`, `cloudasset`, `orgpolicy`, `recommender`, `accessapproval` (see `GOOGLE_CLOUD_SECURITY.md`).
