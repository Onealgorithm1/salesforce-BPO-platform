# Google Cloud Baseline Inventory — `onealgorithm-bpo`

**Sprint 2 — Foundation Finalization** · **Verified 2026-07-07** (live `gcloud`, authenticated `onealgorithm@gmail.com`)
**Companion audits:** `GOOGLE_CLOUD_API_INVENTORY.md`, `GOOGLE_CLOUD_IAM_AUDIT.md`, `GOOGLE_CLOUD_SECURITY.md`, `GOOGLE_CLOUD_COST_GOVERNANCE.md`
**Note:** point-in-time audit; complements the Sprint-1 architecture docs (`GOOGLE_PLATFORM_BASELINE.md` etc.).

## Track A — Baseline (all Verified)

| Item | Value |
|---|---|
| Logged-in account | `onealgorithm@gmail.com` |
| Project ID | `onealgorithm-bpo` |
| Project number | **885034473642** |
| Lifecycle | ACTIVE |
| Billing account | `billingAccounts/016AE0-5E6BCD-6799EF` (billing enabled = True) |
| Organization / Folder | **none** (consumer Gmail → no Org, no Folders, no Org Policies) |
| Enabled APIs | **49** (see `GOOGLE_CLOUD_API_INVENTORY.md`) |
| IAM principals | **1** — `roles/owner` → `user:onealgorithm@gmail.com` |
| Service accounts | **0** |
| User-managed SA keys | **0** (no SAs exist) |
| Budget | `onealgorithm-bpo Monthly 25 USD`, thresholds 50/75/90/100% |
| Regions | none set / no regional resources (no Compute/Run/etc.) |
| Audit logging | Admin Activity **always-on**; Data Access logs **not configured** |
| Quotas | default (no custom overrides; no workloads consuming quota) |

## Resource inventory (all Verified empty)
Secret Manager: 0 · Cloud Storage: 0 buckets · BigQuery: 0 datasets · Cloud Run / Functions / GKE / Pub-Sub / Scheduler / Artifact Registry / Vertex AI / Compute: **none (APIs not enabled)** · Logging sinks: built-in `_Required` / `_Default` only · API keys: 0 · OAuth clients: 0.

## Summary
A **clean, empty, billing-guarded project** with a broad API surface and owner-only IAM. No workloads, no credentials, no keys. Ready to host future workloads once IAM hardening + per-workload service accounts are added (see roadmap).
