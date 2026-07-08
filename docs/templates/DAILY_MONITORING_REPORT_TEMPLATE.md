# Daily Monitoring Report — {YYYY-MM-DD}

**Operator:** _fill_
**Org ID:** `00Dbn00000plgUfEAI` `[verify by ID]`
**Overall:** ☐ 🟢 PASS ☐ 🟡 WARN ☐ 🔴 FAIL
**Governed by:** [MONITORING_AND_ALERTS.md](../MONITORING_AND_ALERTS.md) · [DAILY_ENRICHMENT_OPERATING_PROCEDURE.md](../DAILY_ENRICHMENT_OPERATING_PROCEDURE.md)

> Read-only snapshot (🟢 GREEN). Do not remediate from this report without the appropriate tier
> gate. Prefer generating from a read-only script (e.g. `scripts/shell/daily_enrichment_audit.sh`)
> and pasting evidence. Every line is PASS / WARN / FAIL with the query or command behind it.

---

## 1. Preflight
- Org verified by ID = `00Dbn00000plgUfEAI`: ☐
- Report is read-only (no DML, no deploy): ☐

## 2. Campaign & outreach (EDWOSB)
| Check | Expected | Observed | P/W/F |
|-------|----------|----------|-------|
| Sends in last 24h vs cap | ≤ cap (100/day) | _fill_ | _ |
| Drip / follow-up schedulers active | present, on schedule | _fill_ | _ |
| Unsubscribe rate | ~baseline (<~1%) | _fill_ | _ |
| Bounces / send errors | ~0 | _fill_ | _ |
| CampaignMember count | stable / expected | _fill_ | _ |

## 3. Enrichment & connectors
| Check | Expected | Observed | P/W/F |
|-------|----------|----------|-------|
| Enrichment jobs run / status | per schedule (or dormant=0) | _fill_ | _ |
| Records processed / enriched | _fill_ | _fill_ | _ |
| Connector HTTP errors (non-2xx) | 0 | _fill_ | _ |
| Records routed to Review | expected | _fill_ | _ |
| Exceptions logged | 0 new (or explained) | _fill_ | _ |

## 4. Platform health
| Check | Expected | Observed | P/W/F |
|-------|----------|----------|-------|
| Apex async jobs failed | 0 | _fill_ | _ |
| Scheduled jobs (CronTrigger) present & healthy | expected set | _fill_ | _ |
| API / storage / async limits headroom | comfortable | _fill_ | _ |
| SetupAuditTrail — unexpected admin changes | none | _fill_ | _ |

## 5. Anomalies / follow-ups
_List any WARN/FAIL with the evidence and the proposed action (and its tier). Escalate 🔴 items to Louis; log persistent issues in [OPERATIONAL_RISK_REGISTER.md](../OPERATIONAL_RISK_REGISTER.md)._

## 6. Sign-off
**Result:** 🟢 / 🟡 / 🔴 · **Time:** _fill_ · **Escalated?** _y/n — to whom_
