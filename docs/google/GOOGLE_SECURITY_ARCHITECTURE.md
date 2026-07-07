# Google Cloud Security Architecture (Design — DO NOT IMPLEMENT)

**Project:** `onealgorithm-bpo` · **Grounded in Google's current docs** (fetched 2026-07-07):
`iam/docs/best-practices-service-accounts`, `docs/authentication`. Confidence tags per finding.

## Guiding principles (verified)

- **`[Verified]`** *"We recommend that you avoid using service account keys whenever possible."*
  Orgs created after **2024-05-03** disable SA key creation by default.
- **`[Verified]`** Preferred auth, in order: **attached service accounts** (on-GCP) → **Workload
  Identity Federation** (external) → **impersonation** (human elevation) → keys (last resort only).
- **`[Verified]`** ADC is the recommended strategy; `gcloud auth application-default login` for local dev.
- **`[Verified]`** Least privilege: no basic roles (`owner`/`editor`/`viewer`) on SAs; no automatic
  role grants to default SAs; use IAM Recommender to prune unused permissions.

## Service Accounts (target design)

| SA | Purpose | Roles (least-privilege, per service) | Key? |
|---|---|---|---|
| `claude-cli-admin` | Human/Claude administration via impersonation | Only what's actively used (e.g. `roles/serviceusage.serviceUsageAdmin`, `roles/iam.securityReviewer` for audits) | **No key** |
| `sa-<workload>` (later, one per connector) | Runtime for a deployed workload | Only that workload's roles; **attached** to its Cloud Run/Function | **No key** (ADC) |
| `sa-ci-deployer` (later) | CI/CD from GitHub | Deploy-scoped roles | **No key** (WIF) |

## Authentication model

```
Human (gcloud auth login) ──► roles/iam.serviceAccountTokenCreator on claude-cli-admin
      │  gcloud auth application-default login (ADC)
      ▼  impersonate (short-lived token, IAM Credentials API)
Claude Code / gcloud / Terraform ──► onealgorithm-bpo  (no key on disk)

GitHub Actions (later) ──► Workload Identity Federation (OIDC) ──► sa-ci-deployer  (no key)
Deployed workload (later) ──► attached sa-<workload> + ADC  (no key)
```

## Secret Manager (design)

- All secrets (Meta/LinkedIn tokens, API keys, developer tokens) → **Secret Manager**, never in code,
  env files, or SA keys. `[Verified — best practice]`
- Access via least-privilege `roles/secretmanager.secretAccessor` on the specific secret, granted to
  the specific workload SA. No project-wide grants.
- **Not created this sprint** (STOP GATE: no secrets).

## API authentication & OAuth

- **Service-to-service / data APIs (BigQuery, Vertex/Gemini):** SA + ADC/impersonation.
- **User-context APIs (Workspace, GA4, Ads, Search Console, Business Profile, YouTube):** OAuth 2.0
  clients — created **per connector, when built**, with minimal scopes; refresh tokens in Secret
  Manager. **Not created this sprint** (STOP GATE: no OAuth credentials).

## Workload Identity Federation (design)

For GitHub Actions and any external automation: a WIF **pool + provider** trusts GitHub OIDC and maps
to `sa-ci-deployer` — **no downloaded key**. `[Verified — Google's recommended external-workload path]`
Design only; not created.

## Readiness

- **Terraform readiness:** run Terraform under **impersonation** (`impersonate_service_account`);
  state in a (future) GCS bucket; everything post-foundation as code. `[High Confidence]`
- **GitHub readiness:** WIF (above) → keyless CI. `[High Confidence]`
- **Claude CLI readiness:** installed + (after user auth) impersonation config → Claude administers
  keylessly with short-lived tokens. `[Verified — impersonation is Google's recommended elevation]`

## What this sprint did NOT create (STOP GATE)

No service accounts, no IAM bindings, no secrets, no keys, no OAuth clients, no WIF pools, no
Terraform state, no billable resources. Design only.
