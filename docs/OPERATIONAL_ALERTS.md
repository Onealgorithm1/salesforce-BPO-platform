# Operational Alerts (Track E) — Sprint 17

> **🕰 HISTORICAL — superseded by `MONITORING_AND_ALERTS.md` (Sprint 27), the authoritative monitoring & alerting reference.** Retained for provenance; do not extend this file.

_Design + thresholds · Org 00Dbn00000plgUfEAI · alerts are recommendations, none activated_

All signals derive from data the platform already persists — `OA_Connector_Run__c` (telemetry),
`OA_Enrichment_Exception__c` (review queue), `OA_Enrichment_Change_Log__c` (writes/rollbacks) — so alerts
need **no new platform code**, only report-subscription / notification wiring.

| Alert | Condition (per run or rolling window) | Severity | Recommended action |
|---|---|---|---|
| **Connector failure** | `OA_Connector_Run__c.Status__c = 'Failed'` | 🔴 High | Orchestrator already stops the run; investigate before re-enabling. |
| **Repeated API failures** | `HTTP_Errors__c > 0` on ≥ 3 runs in 1 hr (same source) | 🔴 High | Check endpoint/credential/rate-limit; pause that source. |
| **Authentication failure** | HTTP 401/403 pattern in `Messages__c` | 🔴 High | EC principal access / key expired → re-grant/rotate (`CREDENTIAL_STATUS.md`). |
| **High exception rate** | `Exceptions_Raised__c / Requested__c > 20%` in a run | 🟠 Med | Review exception queue; likely source-conflict or low-confidence spike. |
| **Rollback event** | any `OA_Enrichment_Change_Log__c` with `Change_Type__c = 'Rollback'` | 🟠 Med | Confirm intentional; if not, freeze writes and investigate. |
| **Long runtime** | run duration (`Ended__c − Started__c`) > 2× 7-day median | 🟡 Low | Callout latency / batch too large; lower batch size. |
| **Queue backlog** | Apex flex-queue / `AsyncApexJob` pending enrichment jobs > 5 | 🟡 Low | Concurrency or a stuck job; check `Setup → Apex Jobs`. |
| **Zero-enrichment run** | `Status__c = 'Succeeded'` but `Records_Enriched__c = 0` across a whole cycle | 🟡 Low | Policies inactive or scope empty; verify config. |

## Recommended notification path
1. **Primary (no-code):** Salesforce **Report Subscriptions** on the ops reports (see
   `MONITORING_DASHBOARDS.md`) emailing Louis on threshold breach (native "when metric meets condition").
2. **Failures (near-real-time):** an admin **Report Notification** or a simple **Flow** on
   `OA_Enrichment_Exception__c` create (High severity) → email/Chatter to Louis.
3. **Escalation:** High-severity → email; Medium → daily digest; Low → weekly review in the dashboard.
4. **Channel:** email to `lronealgorithm@gmail.com` initially; add Slack/Chatter later if desired.

## Notes
- Thresholds are starting points — tune after the first weeks of live telemetry.
- Keep alerts **advisory**; the orchestrator's built-in stop-on-`Failed` is the hard safety control.
- No alert is wired yet; activation happens in the go-live window alongside the dashboards.
