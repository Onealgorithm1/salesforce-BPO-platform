# Lead Enrichment Platform — Go-Live Checklist (Track H)

_v1.0 · Org 00Dbn00000plgUfEAI · gate for enabling live enrichment · every item requires sign-off_

Do **not** enable live enrichment until every **Required** item is checked. Current status shown; ☐ = to do.

## 1. Runtime user & security
- [x] `OA_Lead_Enrichment_Runtime` permission set **assigned** to the runtime user and **kept assigned** (1 assignment).
- [x] Runtime-user exception documented + accepted (`RUNTIME_USER_EXCEPTION.md`) — temporary `oauser` (MAD).
- [ ] **(Required before scheduled/24-7)** Dedicated **least-privilege runtime user** provisioned (needs a Salesforce license). *Top standing risk.*
- [x] `OA_Connector_Staging` / SAM connector permset **unassigned** except JIT (verified 0).

## 2. Credentials (`CREDENTIAL_STATUS.md`)
- [x] USASpending NC + endpoint (public) — ready.
- [x] IRS — no credential needed (bulk CSV).
- [ ] **SAM:** set NC endpoint + grant EC principal access (JIT) + confirm data.gov key valid.
- [ ] **Census:** create NC `OA_Census` → `https://api.census.gov`.
- [ ] **SEC:** create NC `OA_SEC` → `https://data.sec.gov` (User-Agent).

## 3. Execution & scheduling (`SCHEDULING_PLAN.md`)
- [x] Orchestrator (`OA_EnrichmentOrchestrator`) + Queueable built, validated (validate id `0AfPn0000023185KAA`, 6/6 tests).
- [ ] Batch sizes set per `PERFORMANCE_VALIDATION.md` (50 callout / 200 IRS / start 20).
- [ ] First schedule runs **`commitWrites=false`** (preview) for one cycle, then flips to commit.
- [ ] No schedule activated until manual canary + 25-Lead + 100-Lead pilots pass. *(0 enrichment jobs today.)*

## 4. Monitoring & alerts
- [ ] Dashboards built from `MONITORING_DASHBOARDS.md` (Executive + Platform Health).
- [ ] Alert thresholds + subscriptions wired (`OPERATIONAL_ALERTS.md`); failure email to `lronealgorithm@gmail.com`.

## 5. Backup & rollback
- [x] Change-log + before-snapshot audit built and **proven** (Sprint-16 canary + 5-Lead pilot, 5/5 restored).
- [x] `OA_ChangeLogService.rollback(...)` verified deterministic.
- [ ] Rollback rehearsed once against a live pilot run before scaling.

## 6. Source control & release
- [x] v1.0 baseline: tag `lead-enrichment-v1.0` = `485f7dc` (pushed; not retagged).
- [x] **Sprint 17 MERGED to `main` (2026-07-07, Sprint 19)** — fast-forward `485f7dc..59f9df0`, validated `0AfPn00000235zhKAA` (6/6), pushed to origin. `main = origin/main = 59f9df0`.
- [x] Platform frozen — Sprint 17 added only operational classes (no platform/connector edits).
- [ ] **Sprint 17 execution layer NOT yet deployed to the org** (orchestrator/queueable/adapter count = 0 in prod; only check-only validated). Required before any pilot.
- [x] Census + SEC Named Credentials prepared + check-only validated (`0AfPn00000236CbKAI`); not deployed.

## 7. Deployment history (for the record)
| Deploy / validate | ID | Result |
|---|---|---|
| Lead enrichment fields (29) | `0AfPn0000022znpKAA` | 29/29 |
| Platform types | `0AfPn0000022zz7KAA` | 184/184 |
| CMDT records (44) | `0AfPn000002308nKAA` | 44/44 |
| Runtime permset (4 obj + 99 field) | `0AfPn00000230aDKAQ` | 1/1 |
| Full-platform validation | `0AfPn0000022zW5KAI` | 86 tests, 97.21% |
| Sprint-17 orchestrator validation | `0AfPn0000023185KAA` | 6 tests, 0 errors |

## 8. Support contacts
- **Owner / decision-maker:** Louis (`lronealgorithm@gmail.com`).
- **Platform escalation:** Salesforce Support — **not warranted** for the known FLS behavior
  (`SALESFORCE_SUPPORT_PACKAGE.md`); open only for a genuine FLS-independent anomaly.

## Go/No-Go
**GO for controlled pilots** (manual/canary/25/100, once §2 credentials for the chosen source are closed).
**NO-GO for scheduled / 24-7 enrichment** until §1 least-priv user, §2 all credentials, §3 pilots, and §4
monitoring are complete.
