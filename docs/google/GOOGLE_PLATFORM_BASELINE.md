# Google Cloud Platform — Baseline

**Project:** `onealgorithm-bpo` — intended permanent Google integration hub for One Algorithm
**Sprint:** GREEN — Infrastructure & CLI Foundation (2026-07-07)
**Execution mode:** install tooling + read-only audit + documentation. **No billable resources, no credentials, no keys, no deploy.**
**Branch:** `feature/google-cloud-foundation` (isolated worktree; NOT pushed, NOT merged to main)

> Evidence over assumptions. **Live audit COMPLETED 2026-07-07** (authenticated as
> `onealgorithm@gmail.com`); verified findings recorded below. Only ADC (`application-default`)
> remains pending.

## Verified this sprint

| Item | Evidence | Status |
|---|---|---|
| Google Cloud SDK installed | winget `Google.CloudSDK` 575.0.0 → "Successfully installed" | ✅ **Verified** |
| `gcloud` | `Google Cloud SDK 575.0.0`, core 2026.06.26 | ✅ **Verified** |
| `bq` | `bq 2.1.33` | ✅ **Verified** |
| `gsutil` | `gsutil 5.37` | ✅ **Verified** |
| Install path | `C:\Users\User\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin` | ✅ **Verified** |
| gcloud auth | `gcloud auth list` → **`onealgorithm@gmail.com` (active)** | ✅ **Verified (authenticated 2026-07-07)** |
| ADC | `application_default_credentials.json` not yet created | ⏳ **Pending** (`gcloud auth application-default login`) |
| Default project config | `core/project = onealgorithm-bpo` | ✅ **Verified** |

## Verified live audit — 2026-07-07 (authenticated as `onealgorithm@gmail.com`)

| Item | Value | Status |
|---|---|---|
| Authenticated account | **`onealgorithm@gmail.com`** | ✅ Verified |
| Project ID / number | `onealgorithm-bpo` / **885034473642** | ✅ Verified |
| Lifecycle | **ACTIVE** | ✅ Verified |
| Billing | **ENABLED** → `billingAccounts/016AE0-5E6BCD-6799EF` | ✅ Verified |
| Organization | **none** (consumer Gmail — no Org / Folders / Org-Policies) | ✅ Verified |
| IAM | single binding: `roles/owner` → `user:onealgorithm@gmail.com` | ✅ Verified |
| Service accounts | **none** | ✅ Verified |
| API keys | **none** | ✅ Verified |
| Secret Manager secrets | **none** | ✅ Verified |
| Storage buckets | **none** | ✅ Verified |
| BigQuery datasets | **none** | ✅ Verified |
| Logging sinks | only built-in `_Required` / `_Default` | ✅ Verified |
| Cloud Run / Functions / Pub-Sub / Scheduler / Artifact Registry / Vertex AI / Compute | **none — APIs not enabled** | ✅ Verified |
| Enabled APIs | **48 total**; **~11 recommended for REMOVE** (see `GOOGLE_API_BASELINE.md`) | ✅ Verified |
| ADC | **pending** | ⏳ |

**Net:** zero user-created resources, zero service accounts, zero keys — a clean slate with a
**broad API surface**. Owner-only IAM on a consumer Gmail (no Org) is the main governance gap.

**Next recommended sprints:** (1) **API trim** — disable the ~11 unneeded APIs (retail, datastore,
dataplex, dataform, analyticshub, 4× advanced-BigQuery, sql-component); (2) **IAM hardening** —
create `claude-cli-admin` service account for **impersonation** (no JSON key). Both gated.

## Companion documents

- `GOOGLE_CLI_SETUP.md` — install + interactive auth + impersonation config
- `GOOGLE_SECURITY_ARCHITECTURE.md` — service accounts, IAM, ADC, impersonation, WIF, Terraform/GitHub/Claude readiness
- `GOOGLE_API_BASELINE.md` — enabled-API classification (KEEP/OPTIONAL/REMOVE/ENABLE LATER)
- `GOOGLE_IAM_STRATEGY.md` — least-privilege IAM model
- `GOOGLE_ROADMAP.md` — ordered future sprints
- `gcp-readonly-audit.sh` — one-shot read-only inventory
