# Google Cloud API Baseline — Recommended Posture

> ⚠️ **HISTORICAL (Sprint 1).** Current: **43 enabled** (8 of the disable-candidates disabled in Sprint 3; `datastore`+`sql-component` kept). See **`GOOGLE_CLOUD_API_INVENTORY.md`** / **`GOOGLE_CLOUD_HARDENING.md`**.

**Project:** `onealgorithm-bpo`. **Verified 2026-07-07: 48 APIs enabled** (`gcloud services list
--enabled`, authenticated as `onealgorithm@gmail.com`). The recommendation table below is now
reconciled against that live list.

## Verified: REMOVE recommendations (~11 APIs — gated, NOT disabled)

Enabled but **not on any stated goal** → recommend disabling in a gated "API trim" sprint (attack
surface + quota reduction). **Not disabled this sprint.**

`retail.googleapis.com`, `datastore.googleapis.com`, `dataplex.googleapis.com`,
`dataform.googleapis.com`, `analyticshub.googleapis.com`, `bigqueryconnection.googleapis.com`,
`bigquerydatapolicy.googleapis.com`, `bigquerymigration.googleapis.com`,
`bigqueryreservation.googleapis.com`, `sql-component.googleapis.com` (+ `bigquerydatatransfer` =
ENABLE-LATER until transfers are scheduled).

**Not enabled (so no resources possible):** `run`, `cloudfunctions`, `pubsub`, `cloudscheduler`,
`artifactregistry`, **`aiplatform` (Vertex AI)**, `compute`. Vertex AI must be enabled before any
Gemini-on-Vertex workload.

**Principle `[Verified]`:** least privilege applies to APIs — enable an API **only when a workload
needs it**. Enable the foundational/governance set now; **ENABLE LATER** the product/data APIs
per-connector, as each connector is built.

| API | Recommendation | Why |
|---|---|---|
| Cloud Resource Manager | **KEEP** | Project/IAM/folder management foundation |
| IAM | **KEEP** | Role/policy management |
| **IAM Credentials** | **KEEP** | **Required for impersonation** — the keyless model depends on it |
| Service Usage | **KEEP** | List/enable APIs |
| Secret Manager | **KEEP** | Secure secret storage |
| Cloud Logging | **KEEP** | Audit + observability |
| Cloud Monitoring | **KEEP** | Health/alerting |
| Cloud Trace | **OPTIONAL / ENABLE LATER** | Only once services are deployed |
| Gemini API (Vertex `aiplatform` / `generativelanguage`) | **KEEP (if AI active)** | Core to AI goals |
| Gemini for Google Cloud (`cloudaicompanion`) | **OPTIONAL** | Dev assistant, not a workload dependency |
| BigQuery | **KEEP** | Stated data-warehouse goal |
| BigQuery Storage | **KEEP** | Performant reads |
| BigQuery Data Transfer | **ENABLE LATER** | Only when scheduling transfers |
| Google Ads | **ENABLE LATER** | Needs developer token + OAuth; enable at connector build |
| Analytics Data (GA4) | **ENABLE LATER** | Per-connector |
| Search Console | **ENABLE LATER** | Per-connector |
| Business Profile Performance | **ENABLE LATER** | Requires Google allow-listing/approval |
| Tag Manager | **ENABLE LATER** | Per-connector |
| Drive / Docs / Sheets / Slides / Forms / People / Calendar / Meet / Gmail | **ENABLE LATER (per-connector)** | Enable only the specific Workspace APIs a built integration uses |
| YouTube Data / Analytics / Reporting | **ENABLE LATER** | Enable when the YouTube connector is built |

**REMOVE** = any API found enabled that is **not** in the KEEP set **and** not tied to an active
build → candidate to disable after confirming no dependency (verify enabled list first; cannot name
specifics without it).

**Governance-set to keep enabled now (explicit answer to the review list):** Cloud Resource Manager,
IAM, IAM Credentials, Secret Manager, Service Usage, Cloud Logging, Cloud Monitoring = **KEEP**.
Cloud Trace = **OPTIONAL/ENABLE LATER**. All product/data/Workspace/YouTube APIs = **ENABLE LATER**
per-connector. Gemini API = **KEEP if AI active**, Gemini for Google Cloud = **OPTIONAL**.
