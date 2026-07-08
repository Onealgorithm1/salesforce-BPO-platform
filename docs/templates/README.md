# Reusable Governance Templates

**Version:** 1.0
**Date:** July 8, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Quarterly, alongside [GOVERNANCE_MODEL.md](../GOVERNANCE_MODEL.md)
**Status:** Active

Copy-forward templates that operationalize the platform's governance. They exist so every
release, deployment, PR, decision, sprint, readiness review, and operational report follows the
same evidence-first, no-surprise-production discipline defined in
[`CLAUDE.md`](../../CLAUDE.md), [`GOVERNANCE_MODEL.md`](../GOVERNANCE_MODEL.md), and
[`DEFINITION_OF_READY.md`](../DEFINITION_OF_READY.md).

---

## How to use

1. **Copy** the template to its destination (see table). Never edit the template in place.
2. **Fill every field.** A blank field is an open question, not a pass. Delete nothing — mark
   `N/A` with a one-line reason so reviewers see it was considered.
3. **Keep confidence labels.** `[Verified from source]` vs `[Unverified]` per the DoR — a claim
   about production must carry command output, not memory.
4. **Respect the tiers.** 🟢 GREEN proceeds, 🟡 YELLOW proceeds with a report, 🔴 RED stops for
   explicit Louis approval ([`CLAUDE.md` §2](../../CLAUDE.md)). Every template surfaces its RED gate.

---

## Template index

| Template | Copy to | Use when | Primary tier gate |
|----------|---------|----------|-------------------|
| [Release Checklist](RELEASE_CHECKLIST_TEMPLATE.md) | `docs/releases/{release-id}.md` | Cutting a production release | 🔴 deploy + merge |
| [Deployment Checklist](DEPLOYMENT_CHECKLIST_TEMPLATE.md) | PR description or `docs/releases/` | Any production deployment | 🔴 deploy |
| [PR Checklist](PR_CHECKLIST_TEMPLATE.md) | PR description | Opening any PR | 🟡 / 🔴 on merge |
| [Architecture Decision (ADR)](ADR_TEMPLATE.md) | `docs/decisions/ADR-NNN-{slug}.md` | A hard-to-reverse decision | 🟡 additive doc |
| [Sprint](SPRINT_TEMPLATE.md) | `docs/SPRINT{NN}_{NAME}.md` | Planning/closing a sprint | 🟢 → gate per task |
| [Production Readiness Review](PRODUCTION_READINESS_REVIEW_TEMPLATE.md) | `docs/{WORKSTREAM}_OPERATIONAL_READINESS.md` | Before enabling anything live | 🔴 go-live |
| [Operations Review](OPERATIONS_REVIEW_TEMPLATE.md) | `docs/OPERATIONS_CHANGE_LOG.md` append or dated file | Periodic ops review | 🟢 read-only |
| [Daily Monitoring Report](DAILY_MONITORING_REPORT_TEMPLATE.md) | `docs/SESSION_SUMMARIES/` or ops log | Daily health snapshot | 🟢 read-only |
| [Weekly Health Report](WEEKLY_HEALTH_REPORT_TEMPLATE.md) | `docs/SESSION_SUMMARIES/` or ops log | Weekly rollup | 🟢 read-only |

## Related governance

- **Operating tiers & preflight/closeout:** [`CLAUDE.md`](../../CLAUDE.md)
- **Change categories, release artifacts, segregation of duties, audit schedule:** [`GOVERNANCE_MODEL.md`](../GOVERNANCE_MODEL.md)
- **Entry gate for any work:** [`DEFINITION_OF_READY.md`](../DEFINITION_OF_READY.md)
- **Decisions:** [`docs/decisions/`](../decisions/)
- **Standing risks:** [`OPERATIONAL_RISK_REGISTER.md`](../OPERATIONAL_RISK_REGISTER.md), [`TECHNICAL_DEBT.md`](../TECHNICAL_DEBT.md)
