# Google Cloud Implementation Roadmap

**Project:** `onealgorithm-bpo`. Ordered, gated sprints. Each is small and reversible; billable/
credential-creating steps are explicitly flagged and require approval.

| Sprint | Name | Scope | Creates billable/creds? |
|---|---|---|---|
| **0** (this) | **CLI Foundation** | Install SDK; set project; docs; read-only audit prep | No |
| **1** | **Authenticate & Full Audit** | User runs `gcloud auth login` + ADC; run read-only audit; reconcile API/IAM tables | No (read-only) |
| **2** | **IAM Hardening** | Strip default-SA Editor; define admin group; least-privilege review | IAM changes (gated) |
| **3** | **Admin SA + Impersonation** | Create `claude-cli-admin` SA (no key) + token-creator grant; config impersonation | SA + IAM (gated) |
| **4** | **Secret Manager** | Enable API; create secret containers (no secret values yet) | API + resources (gated) |
| **5** | **OAuth foundation** | Consent screen; per-connector OAuth client pattern | OAuth creds (gated) |
| **6** | **Workspace Connector** | Enable specific Workspace APIs; first connector | API + OAuth (gated) |
| **7** | **Analytics (GA4)** | GA4 Data API connector | API + OAuth (gated) |
| **8** | **Business Profile** | Performance API (needs Google approval) | API + OAuth (gated) |
| **9** | **Search Console** | Search Console API connector | API + OAuth (gated) |
| **10** | **Google Ads** | Ads API + developer token | API + OAuth (gated) |
| **11** | **Gemini / Vertex AI** | Enable Vertex; least-priv SA; first AI workload | API + resources (gated) |
| **12** | **BigQuery** | Datasets + Storage; per-connector loader SAs | Datasets/buckets (gated, billable) |
| **13** | **YouTube** | Data/Analytics/Reporting connector | API + OAuth (gated) |
| **14** | **Terraform IaC** | Terraform under impersonation; GCS state | Bucket (gated, billable) |
| **15** | **CI/CD (WIF)** | Workload Identity Federation for GitHub; keyless deploys | WIF + IAM (gated) |
| **16** | **Automation & Monitoring** | Scheduler/Pub/Sub/alerting for live connectors | Resources (gated, billable) |

**Rule:** no billable resource, credential, key, or OAuth client is created until its sprint is
explicitly approved. Foundation (0–3) is keyless and near-zero-cost.
