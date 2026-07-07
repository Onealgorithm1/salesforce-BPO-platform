# Google Cloud Production Hardening — `onealgorithm-bpo`

**Sprint 3** · **Executed 2026-07-07** (authenticated `onealgorithm@gmail.com`; identity verified before each mutating action)
**This is the current production-baseline source of truth** (supersedes the Sprint-2 audit docs where facts changed).

## Changes made (all verified)

| # | Track | Change | Evidence |
|---|---|---|---|
| B | Audit logging | **Data Access audit logs ENABLED** — `allServices`: ADMIN_READ + DATA_READ + DATA_WRITE. Owner binding preserved (verified). | `get-iam-policy auditConfigs` |
| E | Security APIs | **Enabled `cloudasset` + `recommender`** (appropriate for a standalone project). SCC + Org Policy **not** enabled (require an Organization — none exists). | `services list` |
| C | IAM | **Created SA `claude-cli-admin@onealgorithm-bpo.iam.gserviceaccount.com`** (keyless). Roles: `iam.securityReviewer`, `logging.viewer`, `monitoring.editor`, `cloudasset.viewer`. Impersonation: `user:onealgorithm@gmail.com` → `roles/iam.serviceAccountTokenCreator` on the SA. **No JSON key** (verified 0 user-managed keys). | `service-accounts list`, `keys list` |
| F | Monitoring | **Created email notification channel** "OA Cloud Alerts (email)" → `onealgorithm@gmail.com` (`…/notificationChannels/17233246956606637029`). | `channels list` |
| D | API cleanup | **Disabled 8** unused APIs; **kept 2** (have dependents). | `services list` before/after |

### Track D — before/after inventory
- **Disabled (8):** `retail`, `dataplex`, `dataform`, `analyticshub`, `bigqueryconnection`, `bigquerydatapolicy`, `bigquerymigration`, `bigqueryreservation`.
- **Kept (2, justified):** `datastore` and `sql-component` — gcloud reported **enabled dependents**; disabling would require `--force` and risk breaking the dependent service → **not "completely safe"**, so left enabled per the rules.
- **Enabled count:** 49 → (+2 security) 51 → (−8) **43**.

## Production IAM model (Track C design)

```
Owner (break-glass): user:onealgorithm@gmail.com  = roles/owner   [unchanged — see note]
      │ roles/iam.serviceAccountTokenCreator on claude-cli-admin
      ▼ impersonate (short-lived tokens, no key)
claude-cli-admin SA  = securityReviewer + logging.viewer + monitoring.editor + cloudasset.viewer
Future automation/CI ─ Workload Identity Federation (GitHub OIDC) ─► dedicated SA (no key)
Future workloads     ─ attached per-workload SA + ADC (no key)
```

**Owner intentionally NOT reduced.** Full least-privilege (reduce owner → break-glass only, admin
via impersonation) requires a **second human admin** first; on a single-owner consumer-Gmail project
with no Organization, reducing the sole owner risks an **unrecoverable lockout** (no org admin to
restore access). This is deferred with evidence, not overlooked.

## Final production baseline (verified 2026-07-07)

| Item | State |
|---|---|
| Identity | `onealgorithm@gmail.com` (owner) + `claude-cli-admin` SA (keyless, impersonation) |
| Project | `onealgorithm-bpo` #885034473642 ACTIVE |
| Billing / Budget | enabled `016AE0-5E6BCD-6799EF`; budget $25/mo 50/75/90/100% |
| Organization | none (consumer Gmail) |
| Enabled APIs | **43** |
| IAM | owner (1) + `claude-cli-admin` SA (4 scoped roles) |
| SA keys / API keys | **0 / 0** |
| Audit logging | Admin Activity + **Data Access (allServices)** |
| Security APIs | `secretmanager`, `cloudasset`, `recommender` on; SCC/Org-Policy N/A (no org) |
| Monitoring | email notification channel created; alert policies recommended (below) |
| Public access | none |

## Recommended alert policies (create when appropriate — notification channel is ready)
1. **Service-account key created** (log-based) — should be ~never; strong tripwire.
2. **IAM policy changed / owner role granted** (log-based).
3. **Budget already covers spend alerts** (50/75/90/100%).

## Remaining roadmap (gated)
1. Add a **second human admin** / break-glass → then reduce the sole owner and move admin to impersonation-only.
2. Enable **Workload Identity Federation** for GitHub CI (keyless).
3. Create the recommended **alert policies**.
4. Optional: **billing export** to BigQuery for cost analytics.
5. Per-workload service accounts (attached, no keys) when workloads are introduced.
6. Review Data Access **DATA_READ** log volume/cost once high-traffic data services (BigQuery/Storage) go live.

## Honest readiness statement
The project is **clean, keyless, budget-guarded, audit-logged, monitored (channel), and least-privilege
on APIs** — a strong production-hardened *foundation* safe to host future workloads (each with its own
per-workload SA). It is **not** at full enterprise governance: **no Organization** (so no SCC/Org-Policy)
and a **single human owner** (resilience gap). Those two are the only material gaps and both are
documented with the reasons they weren't changed autonomously (lockout risk / requires an Org).
