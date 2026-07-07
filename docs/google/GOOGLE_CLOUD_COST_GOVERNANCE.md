# Google Cloud Cost Governance — `onealgorithm-bpo`

**Sprint 2** · **Verified 2026-07-07.**

## Track F — Cost governance (verified)

| Control | State | Notes |
|---|---|---|
| **Budget** | ✅ `onealgorithm-bpo Monthly 25 USD` (`billingAccounts/016AE0-5E6BCD-6799EF/budgets/c70c4f83-4a00-42cb-b3e2-e4a9b8bbd18a`) | Created this workstream |
| **Amount** | **25 USD / month**, scope `projects/885034473642` | Verified |
| **Alert thresholds** | **50% / 75% / 90% / 100%** (`0.5;0.75;0.9;1.0`) | Verified |
| **Alert recipients** | Default → billing account admins (`onealgorithm@gmail.com`) | No custom channel |
| **Billing export to BigQuery** | **Not configured** (0 BQ datasets) | Recommend later for detailed cost analysis |
| **Cost anomaly detection** | Available automatically at billing-account level (GCP built-in) | Review in Billing console; no setup required |

## Recommendations
1. **Optional:** add a Pub/Sub or email notification channel to the budget for programmatic alerting (currently default email only).
2. **Later:** enable **billing export to a BigQuery dataset** for granular cost/usage analysis (needs a dataset → gated, and BigQuery storage is billable at scale).
3. **Watch the alerts:** at $25/month with no workloads, spend should be ~$0; any alert = investigate immediately (likely an accidentally-created billable resource).
4. Re-evaluate the budget amount when real workloads are provisioned.

## Verdict
Cost governance is **in place and verified** for an empty project. The budget is the primary guardrail while the project has no workloads.
