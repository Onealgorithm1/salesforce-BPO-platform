# Google Cloud API Baseline — Recommended Posture

**Project:** `onealgorithm-bpo`. **Current enabled-API state = `[Needs Verification]`** (run
`gcloud services list --enabled` after auth). The table below is the **recommended target posture**;
reconcile it against the verified list once available.

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
