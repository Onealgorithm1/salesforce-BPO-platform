# Google Cloud IAM Strategy (Least Privilege)

**Project:** `onealgorithm-bpo`. **Current IAM state = `[Needs Verification]`**
(`gcloud projects get-iam-policy onealgorithm-bpo`). Strategy below is the target model.

## Principles (verified against Google docs)

- **`[Verified]`** No basic roles (`roles/owner`, `roles/editor`, `roles/viewer`) on service accounts.
- **`[Verified]`** No automatic role grants to default service accounts; strip the default-SA Editor if present.
- **`[Verified]`** Prefer **predefined roles** scoped per service; run **IAM Recommender** to remove unused permissions.
- Humans hold their own identity + narrow, purpose-scoped roles; elevation is via **impersonation**,
  not standing broad grants.

## Role model (target)

| Principal | Type | Roles | Notes |
|---|---|---|---|
| Louis (owner) | user | `roles/owner` (bootstrap only) | Reduce to admin-group + break-glass later |
| Claude/admin operator | user | `roles/iam.serviceAccountTokenCreator` on `claude-cli-admin` | Impersonates the admin SA; no standing project-wide power |
| `claude-cli-admin` | SA | Only actively-used admin roles (e.g. `serviceusage.serviceUsageAdmin`, `iam.securityReviewer`) | **No key**; grows only as needed |
| `sa-<workload>` | SA | Only that workload's roles | Attached to its resource; ADC |
| `sa-ci-deployer` | SA | Deploy-scoped roles | Reached via WIF; no key |

## Audit cadence

- Quarterly: `gcloud projects get-iam-policy` review + IAM Recommender.
- Alert on new key creation (Org Policy `iam.disableServiceAccountKeyCreation` if an Org exists — `[Needs Verification]`).
- No new principal gets a basic role; PRs/changes reviewed.

## Break-glass

One documented, monitored owner/break-glass path; everything else least-privilege + impersonation.

**Not modified this sprint (STOP GATE): no IAM bindings created or changed.**
