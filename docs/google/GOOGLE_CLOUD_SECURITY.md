# Google Cloud Security Posture — `onealgorithm-bpo`

**Sprint 2** · **Verified 2026-07-07.** Recommendations only — no changes made.

## Track E — Security baseline (verified state)

| Control | State (verified) | Recommendation |
|---|---|---|
| **Audit Logging** | Admin Activity logs **always-on**; **Data Access logs NOT configured** (`auditConfigs` empty) | Enable Data Access audit logs for sensitive services (IAM, Secret Manager, Storage, BigQuery) before workloads handle real data |
| **Security Command Center** | **Not active** (`securitycenter` API absent; SCC needs an Organization) | Not available for a standalone consumer-Gmail project; revisit if a Cloud Identity org is created |
| **Cloud Asset Inventory** | **Not enabled** (`cloudasset` absent) | Enable (read-only, low cost) for asset history + IAM policy analysis in a future sprint |
| **Secret Manager** | API **enabled**, **0 secrets** | Ready. All future tokens/keys go here (never in code/keys) |
| **Organization Policies** | **N/A** — no Organization exists | Can't enforce constraints (e.g. `disableServiceAccountKeyCreation`) without an org → enforce keyless by discipline; consider Cloud Identity on `onealgorithm.com` |
| **Recommender / IAM Recommender** | **Not enabled** (`recommender` absent) | Enable when IAM grows, to prune unused permissions |
| **Public access** | **None** — no `allUsers`/`allAuthenticatedUsers`, no public buckets/resources | Maintain; review at each resource creation |
| **Credentials/keys** | **0 API keys, 0 SA keys** | Maintain keyless (impersonation/ADC/WIF) |

## Top security findings (priority order)
1. **No Organization → no org-level guardrails** (MEDIUM–HIGH). Mitigate: keyless discipline now; Cloud Identity later.
2. **Single owner on a consumer Gmail** (MEDIUM). Add a second admin / break-glass; move admin work to an impersonated least-priv SA.
3. **Data Access audit logs off** (LOW–MEDIUM). Turn on for sensitive services before real data flows.
4. **Broad API surface** (LOW–MEDIUM). Trim the 10 DISABLE-CANDIDATE APIs.

## Positives
Clean slate, zero keys, zero public access, budget-guarded, owner-only (no privilege sprawl). A strong, low-risk starting posture.
