# Monitoring & Alerting — Lead Enrichment (authoritative)

_Sprint 27 · consolidates and supersedes `OPERATIONAL_ALERTS.md` (Sprint 17, now historical)._

All signals derive from existing objects — no new code, only report-subscription / notification wiring at go-live. Severity: 🔴 Critical (page owner) · 🟠 Warning (daily digest) · 🔵 Informational (dashboard/weekly).

| # | Alert | Condition | Severity | Action |
|---|---|---|---|---|
| 1 | **Connector Failure** | `OA_Connector_Run__c.Status__c='Failed'` | 🔴 Critical | Run already stopped; investigate before re-enabling. |
| 2 | **API Failure** | `HTTP_Errors__c>0` on ≥3 runs/1h (same source) | 🔴 Critical | Check endpoint/credential/rate; pause source. |
| 3 | **Credential Failure** | 401/403 pattern in `Messages__c` | 🔴 Critical | Re-grant EC principal access / rotate key (`OPERATIONS_GUIDE.md`). |
| 4 | **Rollback Failure** | rollback run where restored < requested | 🔴 Critical | Freeze writes; manual data review. |
| 5 | **High Exception Rate** | `Exceptions_Raised__c / Requested__c > 20%` in a run | 🟠 Warning | Work exception queue; check policy/config. |
| 6 | **Slow Runtime** | run duration > 2× 7-day median | 🟠 Warning | Callout latency / batch too large → lower size. |
| 7 | **No Successful Runs** | 0 `Status='Succeeded'` in an expected window | 🟠 Warning | Verify connectors/policies enabled; check scheduler. |
| 8 | **Scheduler Failure** | expected scheduled job missing/aborted in `CronTrigger` | 🟠 Warning | Re-schedule; check Apex Jobs (N/A while dormant). |
| 9 | **Data Quality Drop** | Data Quality Score (KPI 17) below threshold, or audit-consistency < 100% | 🟠 Warning | Investigate conflicts / silent write failures. |
| 10 | **Policy Misconfiguration** | any **active Overwrite** policy, or active policy on an unintended field | 🔴 Critical | Deactivate immediately; fill-empty only is the invariant. |
| 11 | **Rollback Event (any)** | any `Change_Type__c='Rollback'` | 🔵 Info | Confirm intentional. |
| 12 | **Zero-Enrichment Run** | `Status='Succeeded'` but `Records_Enriched__c=0` for a cycle | 🔵 Info | Policies inactive or scope empty. |

## Notification wiring (at go-live)
1. **Primary (no-code):** Salesforce Report Subscriptions on the Ops reports → email Louis on threshold breach.
2. **Critical (near-real-time):** Flow on `OA_Enrichment_Exception__c` create (Critical) → email/Chatter.
3. **Escalation:** Critical → immediate email; Warning → daily digest; Info → weekly dashboard review.
4. **Channel:** `lronealgorithm@gmail.com`; add Slack/Chatter later.

## Hard safety monitors (must-be-zero)
- Active Overwrite policies = 0 · writes-without-snapshot = 0 · audit-consistency = 100% · connectors enabled without authorization = 0.

**Status:** designed, **not wired** (no reports/dashboards deployed yet — see gaps in `LEAD_ENRICHMENT_OPERATIONAL_READINESS.md`).
