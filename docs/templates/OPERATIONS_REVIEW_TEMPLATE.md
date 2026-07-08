# Operations Review — {PERIOD}

**Date:** _YYYY-MM-DD_
**Facilitator:** _fill_
**Attendees:** _fill_
**Period covered:** _fill_
**Status:** ☐ Draft ☐ Final
**Governed by:** [GOVERNANCE_MODEL.md §5](../GOVERNANCE_MODEL.md)

> A periodic (recommended monthly) read-only review of how production is running. Reading and
> reporting is 🟢 GREEN. Any remediation it schedules follows the normal tier gates.

---

## 1. Health summary
_One paragraph: overall state, notable trends, anything that needs attention._
**Overall:** ☐ Healthy ☐ Watch ☐ At risk

## 2. Incidents & emergencies this period
| Date | Severity | Summary | Root cause | Post-mortem link | Status |
|------|----------|---------|-----------|------------------|--------|
| _fill_ | _fill_ | _fill_ | _fill_ | _fill_ | ☐ Open ☐ Closed |

_Emergency changes must have a post-mortem within 5 business days ([Governance §2.4](../GOVERNANCE_MODEL.md))._

## 3. Changes since last review
| Change | Category | Deploy ID | Approved by | Production? | Reversible? |
|--------|----------|-----------|-------------|-------------|-------------|
| _fill_ | _fill_ | _fill_ | _fill_ | y/n | y/n |

- [ ] All production changes trace to a PR + explicit approval ([SetupAuditTrail](../GOVERNANCE_MODEL.md) cross-check done).

## 4. Access & security audit ([Governance §5.1](../GOVERNANCE_MODEL.md))
- [ ] **Permission-set assignments** reviewed — all changes authorized (this is a 🔴 action, so each should be traceable).
- [ ] Service accounts / integration users reviewed ([INTEGRATION_REGISTRY.md](../INTEGRATION_REGISTRY.md)).
- [ ] SetupAuditTrail scanned for unauthorized admin actions.
- [ ] Named Credential currency checked (rotation if overdue).

## 5. KPIs & platform metrics
| KPI ([KPI_CATALOG.md](../KPI_CATALOG.md)) | Baseline | This period | Trend | Note |
|-----|----------|-------------|-------|------|
| _fill_ | _fill_ | _fill_ | ↑/↓/→ | _fill_ |

- Org limits headroom (API, storage, async): _fill_
- Campaign health (sends, unsub rate, bounces): _fill_

## 6. Risk register review ([OPERATIONAL_RISK_REGISTER.md](../OPERATIONAL_RISK_REGISTER.md))
- [ ] Top standing risks re-confirmed (owner, status, mitigation). Notable: _fill (e.g., runtime-user MAD)_
- [ ] New risks added; closed risks marked.
- [ ] Technical debt reviewed ([TECHNICAL_DEBT.md](../TECHNICAL_DEBT.md)).

## 7. Action items
| # | Action | Owner | Tier | Due | Status |
|---|--------|-------|------|-----|--------|
| 1 | _fill_ | _fill_ | 🟢/🟡/🔴 | _fill_ | ☐ |

## 8. Sign-off
**Reviewed by:** _fill_ · **Date:** _fill_ · **Next review due:** _fill_
