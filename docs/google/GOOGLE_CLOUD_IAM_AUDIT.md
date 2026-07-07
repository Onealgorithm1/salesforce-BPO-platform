# Google Cloud IAM & Service Account Audit — `onealgorithm-bpo`

**Sprint 2** · **Verified 2026-07-07** (`get-iam-policy`, `iam service-accounts list`). **No access removed** — recommendations only.

## Track C — IAM principals

| Principal | Role | Required? | Assessment |
|---|---|---|---|
| `user:onealgorithm@gmail.com` | `roles/owner` | Yes (sole admin/bootstrap) | **Appropriate for now, but a single point of failure** |

**Only one binding exists.** No Editor, no Viewer, no service-account principals, no external members, no `allUsers`/`allAuthenticatedUsers` (no public access). This is minimal — but owner is the broadest role.

**Least-privilege recommendations (future, gated):**
1. Keep one **break-glass owner**; for day-to-day admin create a **`claude-cli-admin` service account** with only the predefined roles actually used, and grant your user `roles/iam.serviceAccountTokenCreator` on it → administer via **impersonation** (short-lived tokens, no key).
2. Add a **second human admin** (or a Google group) so the project isn't a single-account dependency.
3. Grant per-workload roles to per-workload service accounts, never broad roles.
4. No basic roles (`owner`/`editor`/`viewer`) on any service account.

## Track D — Service Account audit

| SA | Purpose | Last use | Required | Key status |
|---|---|---|---|---|
| — | **none exist** | n/a | n/a | **no user-managed keys (none possible)** |

**Zero service accounts** (no Compute/App Engine enabled → not even default SAs). Therefore: **no unused SAs, and no user-managed SA keys exist** — the desired keyless posture is currently true by default. Maintain it: when SAs are created, use impersonation/attached-SA/WIF, **never** downloaded JSON keys.

## Verdict
- **IAM appropriately scoped?** Minimal and no over-grants, **but** owner-only on one consumer account is a resilience/governance gap, not an over-privilege gap.
- **Unused service accounts?** None (zero SAs).
- **Keys?** None. ✅
