# Google Cloud Platform — Baseline

**Project:** `onealgorithm-bpo` — intended permanent Google integration hub for One Algorithm
**Sprint:** GREEN — Infrastructure & CLI Foundation (2026-07-07)
**Execution mode:** install tooling + read-only audit + documentation. **No billable resources, no credentials, no keys, no deploy.**
**Branch:** `feature/google-cloud-foundation` (isolated worktree; NOT pushed, NOT merged to main)

> Evidence over assumptions. Every live-project fact that requires an authenticated API call is
> marked **`[Needs Verification]`** until `gcloud auth login` is completed (interactive; see
> `GOOGLE_CLI_SETUP.md`). Nothing below is assumed.

## Verified this sprint

| Item | Evidence | Status |
|---|---|---|
| Google Cloud SDK installed | winget `Google.CloudSDK` 575.0.0 → "Successfully installed" | ✅ **Verified** |
| `gcloud` | `Google Cloud SDK 575.0.0`, core 2026.06.26 | ✅ **Verified** |
| `bq` | `bq 2.1.33` | ✅ **Verified** |
| `gsutil` | `gsutil 5.37` | ✅ **Verified** |
| Install path | `C:\Users\User\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin` | ✅ **Verified** |
| gcloud auth | `gcloud auth list` → **"No credentialed accounts."** | ✅ **Verified (unauthenticated)** |
| ADC | no `%APPDATA%\gcloud\application_default_credentials.json` | ✅ **Verified (absent)** |
| Default project config | `gcloud config set project onealgorithm-bpo` → `core/project = onealgorithm-bpo` | ✅ **Verified (local config only)** |

## Pending — requires interactive authentication (user action)

The following cannot be completed by an automated/non-interactive shell because
`gcloud auth login` opens a browser consent flow:

- Phase 2: `gcloud auth login` + `gcloud auth application-default login`
- Phase 3 verification: authenticated account, **billing status**, **project number**
- Phase 4: the complete read-only inventory (enabled APIs, IAM, service accounts, API keys,
  OAuth clients, Secret Manager, Storage, BigQuery, Cloud Run/Functions, Pub/Sub, Scheduler,
  Artifact Registry, Logging, Monitoring, Organization, Folder, Quotas)

All of these are marked **`[Needs Verification]`**. Run `docs/google/gcp-readonly-audit.sh`
(read-only) immediately after authenticating to fill them in.

## Structural caveat `[High Confidence]`

The owning identity context is a **consumer Gmail (`lronealgorithm@gmail.com`)**. If `onealgorithm-bpo`
was created under a bare Gmail, **no GCP Organization or Folder resources exist** (those need Cloud
Identity/Workspace on `onealgorithm.com`). Whether an Organization exists is `[Needs Verification]`
(`gcloud organizations list`) and determines whether a folder hierarchy and Org Policies are possible.

## Companion documents

- `GOOGLE_CLI_SETUP.md` — install + interactive auth + impersonation config
- `GOOGLE_SECURITY_ARCHITECTURE.md` — service accounts, IAM, ADC, impersonation, WIF, Terraform/GitHub/Claude readiness
- `GOOGLE_API_BASELINE.md` — enabled-API classification (KEEP/OPTIONAL/REMOVE/ENABLE LATER)
- `GOOGLE_IAM_STRATEGY.md` — least-privilege IAM model
- `GOOGLE_ROADMAP.md` — ordered future sprints
- `gcp-readonly-audit.sh` — one-shot read-only inventory
