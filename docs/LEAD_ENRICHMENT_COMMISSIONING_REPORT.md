# Lead Enrichment — Operational Commissioning Report (Sprint 28)

_2026-07-07 · Org 00Dbn00000plgUfEAI · v1.1 · Salesforce CLI evidence · platform returned DORMANT after validation_

## Executive summary
The **execution layer (orchestrator) is now deployed** to production, validated, and dormant. The **operational rehearsal passed** with zero writes. **Monitoring reports/dashboards were NOT deployed** — they are UI-built artifacts and do not deploy reliably as hand-authored metadata; they remain a documented ~30-minute admin-UI task (specs in the Sprint-27 dashboard docs). Interim monitoring is fully available via CLI/SOQL. **Verdict: READY WITH CONDITIONS** — controlled/manual production use is GO; scheduled/24×7 remains NO-GO.

## Track A — Operational verification (no drift)
Org `00Dbn00000plgUfEAI` ✓ · main `a0c8bd0` · dormant: 0 enabled connectors, 0 active policies (of 22), 0 enrichment jobs · runtime permset assigned (oauser) · 68 Leads enriched / 414 change logs / 1 exception · rollback service present. No drift since Sprint 27.

## Track E — Execution layer deployment ✅
`OA_EnrichmentOrchestrator`, `OA_EnrichmentQueueable`, `OA_ProposalAdapter` **deployed and Active** (deploy Succeeded, 4 components, 6 tests, 0 errors). No code modified. Scheduler left disabled. Dormant (nothing invokes them).

## Track B/C — Monitoring deployment ⚠️ NOT DEPLOYED (documented UI task)
- Attempted to deploy report/dashboard metadata; **failed validation** ("invalid report type") — Salesforce reports/dashboards are UI-first artifacts and are unreliable as hand-authored metadata (would need custom report types + fragile dashboard XML). **No partial/broken metadata was deployed; org unaffected** (check-only only).
- **Decision:** build the 3 dashboards + supporting reports via the **admin UI** using the exact specs in `DASHBOARD_EXECUTIVE.md` / `DASHBOARD_OPERATIONS.md` / `DASHBOARD_ADMIN.md` (folder "OA Enrichment Ops" → reports R1–R10 → 3 dashboards → subscriptions). Est. ~30 min, no code.
- **Interim monitoring (available now):** all KPIs are queryable via CLI/SOQL over `OA_Connector_Run__c` / `OA_Enrichment_Change_Log__c` / `OA_Enrichment_Exception__c` (see `DASHBOARD_ADMIN.md` snippets + `KPI_CATALOG.md`). The platform **is** monitorable today via CLI; the gap is only the *visual* dashboards.

## Track D — Alert validation ⚠️ DEFERRED (UI/runtime config)
Alerts (report subscriptions, Flow notifications) are per-user runtime/UI configuration, not deployable metadata. **Active alerts: none** (no reports deployed yet). **Deferred (wire in UI at go-live):** Connector Failure, API Failure, High Exception Rate, Rollback Failure, Credential Failure, Scheduler Failure, Slow Runtime, Policy Disabled — all designed in `MONITORING_AND_ALERTS.md` with conditions/severity. Wiring depends on the reports (Track B) existing.

## Track F — Operational rehearsal ✅ (preview only, no writes)
| Component | Rehearsal | Result |
|---|---|---|
| Deployed orchestrator | `processScope` (connector disabled → Skipped) | 3 leads processed, telemetry built, 0 writes ✓ |
| Deployed ProposalAdapter | `toLeadProposals('USASPENDING', org)` | 3 proposals resolved ✓ |
| Live connector + writer | direct in-memory-cfg preview (no activation) | 3 callouts, 0 HTTP errors, 0 writes ✓ |
| Audit / rollback | objects queryable; before-snapshot pattern proven | ready ✓ |
| Monitoring data | telemetry shape validated | ready ✓ |
No connector activated; **dmlRows=0**; production unchanged (68 Leads / 414 logs). A canary write was **not required** — the write+audit+rollback loop is already certified (Sprints 23–25).

## Track G — Performance (measured this sprint)
CPU 87 ms (3 leads), 1 SOQL, 3 callouts, **0 DML**, heap 4.3 KB, wall 1.1 s. Consistent with Sprint-27 estimates (~25 ms CPU/Lead, 1 SOQL/chunk, callout-bound, 50/txn safe). Governor margin: huge on CPU/SOQL/DML/heap; callouts remain the binding limit. No differences from Sprint 27.

## Track H — Security review
- **Runtime user:** `oauser@pboedition.com` — **System Administrator + Modify-All-Data** (the temporary exception; **top standing risk** — MAD weakens the FLS guardrail even though writes use USER_MODE).
- **Permission sets:** `OA_Lead_Enrichment_Runtime` assigned to oauser (1); `OA_SAM_Connector`/`OA_Connector_Staging` = 0.
- **Named Credentials:** OA_USASpending (public, ready), OA_SAM (alpha, principal access unresolved), OA_Anthropic (unrelated). Census/SEC NCs **not deployed**.
- **External Credentials:** OA_SAM (Custom + X-Api-Key), OA_Anthropic. Secrets only in ECs.
- **What remains before replacing the temporary runtime user** (no licensing/profile work this sprint): (1) acquire a Salesforce license; (2) create a Minimum-Access integration user (no MAD); (3) assign `OA_Lead_Enrichment_Runtime` (FLS on trusted fields only); (4) grant EC principal access for secret connectors; (5) migrate execution to that user; revoke from oauser.

## Track I — Production readiness scorecard
| Area | Rating | Evidence |
|---|---|---|
| Deployment (execution layer) | 🟢 READY | Orchestrator deployed + Active + tested. |
| Performance | 🟢 READY | Measured; governor margin huge; capacity documented. |
| Operations | 🟡 READY WITH CONDITIONS | Rehearsal passed; scheduler off by design. |
| Supportability | 🟡 READY WITH CONDITIONS | Runbooks + CLI monitoring; visual dashboards pending UI build. |
| **Monitoring** | 🔴 NOT READY (visual) | Dashboards/reports not deployed (UI task); CLI monitoring available. |
| Security | 🟡 READY WITH CONDITIONS | Least-priv intent; MAD `oauser` is the gap. |
| Documentation | 🟢 READY | Complete + consolidated. |
| **Overall** | 🟡 **READY WITH CONDITIONS** | Controlled/manual GO; scheduled/24×7 NO-GO. |

## Known risks
1. MAD `oauser` runtime user (top). 2. Visual monitoring not deployed (UI build pending). 3. Alerts unwired (depend on #2). 4. Census/SEC NCs + SAM key incomplete. 5. Scheduler intentionally off.

## Go / No-Go
🟢 **GO** — controlled/manual production enrichment (proven, certified, now with the execution layer deployed).
🔴 **NO-GO** — scheduled/batch/24×7 until: visual monitoring + alerts wired, least-privilege runtime user, and credentials completed.

## Remaining operational tasks (ordered)
1. Build monitoring dashboards + reports in the admin UI (Sprint-27 specs) + wire alert subscriptions.
2. Provision least-privilege runtime user (needs a license) → migrate off `oauser`.
3. Complete Census/SEC NCs + SAM key/principal access.
4. Then enable scheduled enrichment per `SCHEDULING_PLAN.md`.
