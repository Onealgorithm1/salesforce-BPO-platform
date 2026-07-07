# Google Cloud CLI Setup — Administration Workstation

**Goal:** a keyless, least-privilege gcloud environment so Claude Code can safely administer
`onealgorithm-bpo` following Google's current recommendations. **No service account JSON keys.**

## 1. Install (DONE this sprint)

- Installed via `winget install --id Google.CloudSDK` → SDK **575.0.0** (`gcloud`, `bq 2.1.33`, `gsutil 5.37`).
- Binaries: `C:\Users\User\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin`.
- New shells pick up gcloud on PATH automatically (installer adds it). In this session's existing
  shells, call it by full path or open a new terminal.

## 2. Authenticate (USER — interactive, run these yourself)

These open a browser and require your consent; an automated shell cannot complete them. In this
session you can run them with the `!` prefix:

```
! gcloud auth login
! gcloud auth application-default login
! gcloud config set project onealgorithm-bpo     # already set this sprint
```

- `gcloud auth login` → your **user identity** for gcloud commands.
- `gcloud auth application-default login` → **Application Default Credentials (ADC)** for local
  tools/SDKs/Terraform. `[Verified — Google recommends ADC for local dev]`
- **Do NOT** create or download a service account key. `[Verified — Google: "avoid using service account keys whenever possible"]`

## 3. Verify (after auth)

```
gcloud auth list
gcloud config list
gcloud projects describe onealgorithm-bpo --format="value(projectId,projectNumber,lifecycleState)"
gcloud billing projects describe onealgorithm-bpo
```

## 4. Impersonation (FUTURE — after the admin SA exists; design only)

Google's recommended model for elevated administration is **impersonation, not keys**
`[Verified — Service Account Credentials API for temporary privilege elevation]`:

```
# One-time (by an owner): grant your user permission to impersonate the admin SA
#   roles/iam.serviceAccountTokenCreator on claude-cli-admin@onealgorithm-bpo.iam.gserviceaccount.com
# Then, per-session or per-command:
gcloud config set auth/impersonate_service_account claude-cli-admin@onealgorithm-bpo.iam.gserviceaccount.com
#   or per-command:  gcloud <cmd> --impersonate-service-account=claude-cli-admin@onealgorithm-bpo.iam.gserviceaccount.com
```

This yields **short-lived tokens** with no key material on disk. Terraform uses the same via the
provider's `impersonate_service_account` setting.

## 5. Read-only audit

After auth, run `docs/google/scripts/gcp-readonly-audit.sh` — it executes only `list`/`describe`
calls and writes an inventory. It creates nothing.
