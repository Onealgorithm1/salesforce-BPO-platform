# Production Readiness Review — {WORKSTREAM}

**Version:** _fill_
**Date:** _YYYY-MM-DD_
**Owner:** _fill_
**Reviewer(s):** _fill_
**Status:** ☐ Not ready ☐ Conditionally ready ☐ Ready — awaiting go-live approval
**Governed by:** [GOVERNANCE_MODEL.md](../GOVERNANCE_MODEL.md) · [CLAUDE.md](../../CLAUDE.md)

> The gate before anything is enabled **live** (a schedule activated, a write path turned on, a
> credential granted). Enabling live operation is 🔴 RED. Do not enable until every **Required**
> item is `[x]`. `☐` = to do; `N/A — reason` = deliberately excluded.

---

## 1. Runtime user & security
- [ ] Runtime user identified; permission set **assigned and kept assigned** (count verified).
- [ ] **Least-privilege** runtime user (not a shared admin/MAD) — or exception documented + accepted (e.g. [RUNTIME_USER_EXCEPTION.md](../RUNTIME_USER_EXCEPTION.md)). _Flag if this is the top standing risk._
- [ ] Elevated/staging permission sets **unassigned** except just-in-time (verified 0).
- [ ] FLS correct: reportable fields visible via permission set, not profile edits.

## 2. Credentials & integrations
- [ ] All Named / External Credentials exist, current, correct auth method (no Remote Site, no hardcoded endpoint).
- [ ] Principal access granted only where required (JIT); data classification declared ([SECURITY_BASELINE.md](../SECURITY_BASELINE.md)).
- [ ] Integration recorded in [INTEGRATION_REGISTRY.md](../INTEGRATION_REGISTRY.md).

## 3. Execution & scheduling
- [ ] Execution components built + check-only validated (validate ID: _fill_; tests ≥75%).
- [ ] Batch sizes / limits set per [PERFORMANCE_VALIDATION.md](../PERFORMANCE_VALIDATION.md).
- [ ] First live cycle runs in **preview / no-write** mode, then flips to commit.
- [ ] No schedule activated until manual + small-batch pilots pass (current live job count = _fill_).

## 4. Monitoring & alerts
- [ ] Dashboards built ([MONITORING_DASHBOARDS.md](../MONITORING_DASHBOARDS.md)).
- [ ] Alert thresholds + subscriptions wired ([OPERATIONAL_ALERTS.md](../OPERATIONAL_ALERTS.md)); failure notification target set.
- [ ] Daily monitoring report owner assigned ([DAILY_MONITORING_REPORT_TEMPLATE.md](DAILY_MONITORING_REPORT_TEMPLATE.md)).

## 5. Backup & rollback
- [ ] Change-log + before-snapshot audit built and **proven** (pilot restored N/N).
- [ ] Rollback is deterministic and **rehearsed** against a live pilot before scaling.

## 6. Source control & release
- [ ] Baseline tag / commit recorded; `main == origin/main`.
- [ ] Deployment serialized (no parallel production deploys from multiple sessions).
- [ ] Release notes prepared ([RELEASE_CHECKLIST_TEMPLATE.md](RELEASE_CHECKLIST_TEMPLATE.md)).

## 7. Risk & compliance
- [ ] Open risks logged in [OPERATIONAL_RISK_REGISTER.md](../OPERATIONAL_RISK_REGISTER.md) with owners.
- [ ] No unapproved change to a [protected area](../../CLAUDE.md).
- [ ] Retention / audit obligations considered ([Governance §5](../GOVERNANCE_MODEL.md)).

## 8. Go / no-go
| Reviewer | Role | Decision (Go / No-go / Conditional) | Date |
|----------|------|-------------------------------------|------|
| _fill_ | _fill_ | _fill_ | _fill_ |

**Conditions to clear before go-live:** _fill_
**🔴 Go-live approval (Louis):** _explicit approval text / link — required to enable live operation._
