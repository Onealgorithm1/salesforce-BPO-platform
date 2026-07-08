# Lead Enrichment Platform — Production Readiness Package

**Release under review:** `lead-enrichment-v1.2` (maintenance mode)
**Date:** 2026-07-08
**Org:** `00Dbn00000plgUfEAI` (verify by **ID**)
**Prepared by:** Lead Platform Architect (readiness review)
**Status:** 🟡 **Conditionally ready** — engineering complete & certified for *controlled manual / preview*
operation; *scheduled / 24×7 write* automation remains gated on a small set of non-engineering RED items.
**Governed by:** [CLAUDE.md](../CLAUDE.md) · [GOVERNANCE_MODEL.md](GOVERNANCE_MODEL.md)

> **What this document is.** The single index that ties the Lead Enrichment readiness artifacts together
> with one gap analysis and one go/no-go. It links — it does not replace — the authoritative source docs.
> It was produced from a full read-only audit of `main` (connectors/SDK, dormancy, secrets, least-privilege,
> credentials, and operations documentation). **No Apex, metadata, or connector behavior was changed.**

---

## 0. Package index (the A–F artifacts)

| # | Artifact | Authoritative doc(s) | Status |
|---|----------|----------------------|--------|
| A | Production Readiness Checklist | [§1 below](#1-production-readiness-checklist) · [GO_LIVE_CHECKLIST.md](GO_LIVE_CHECKLIST.md) · [PRODUCTION_CERTIFICATION.md](PRODUCTION_CERTIFICATION.md) · [FINAL_OPERATIONAL_READINESS.md](FINAL_OPERATIONAL_READINESS.md) | ✅ complete |
| B | Deployment Checklist | [§2 below](#2-deployment-checklist) · [DEPLOYMENT_PACKAGE.md](DEPLOYMENT_PACKAGE.md) · [templates/DEPLOYMENT_CHECKLIST_TEMPLATE.md](templates/DEPLOYMENT_CHECKLIST_TEMPLATE.md) | ✅ complete |
| C | Rollback Checklist | [§3 below](#3-rollback-checklist) · **[ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md)** (new) · [ROLLBACK_DEFECT_FIX.md](ROLLBACK_DEFECT_FIX.md) | ✅ complete (gap filled) |
| D | Operations Runbook Checklist | [§4 below](#4-operations-runbook-checklist) · [LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md](LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md) · [DAILY_ENRICHMENT_OPERATING_PROCEDURE.md](DAILY_ENRICHMENT_OPERATING_PROCEDURE.md) · [MAINTENANCE.md](MAINTENANCE.md) | ✅ complete |
| E | Monitoring Checklist | [§5 below](#5-monitoring-checklist) · [MONITORING_AND_ALERTS.md](MONITORING_AND_ALERTS.md) · [LEAD_ENRICHMENT_MONITORING.md](LEAD_ENRICHMENT_MONITORING.md) · `scripts/shell/daily_enrichment_audit.sh` | 🟡 design complete, **0 deployed in org** |
| F | Remaining Risks | [§6 below](#6-remaining-risks) · [OPERATIONAL_RISK_REGISTER.md](OPERATIONAL_RISK_REGISTER.md) · [RUNTIME_USER_EXCEPTION.md](RUNTIME_USER_EXCEPTION.md) | ✅ complete |

**Audit verdict (all PASS):** SDK consistent · registry dormant (8/8 `Enabled__c=false`) · pipeline dormant
(11/11) · write policies dormant (27/27 `Active__c=false`) · sources dormant (6/6) · write-back off by default
(`commitWrites` null-safe false everywhere) · no secrets in git · least-privilege runtime permset · NCs secret-free.

---

## 1. Production Readiness Checklist
`[x]` verified this review · `[ ]` outstanding · `N/A` excluded. (Structure mirrors
[templates/PRODUCTION_READINESS_REVIEW_TEMPLATE.md](templates/PRODUCTION_READINESS_REVIEW_TEMPLATE.md).)

### 1.1 Runtime user & security
- [x] Runtime FLS permset `OA_Lead_Enrichment_Runtime` exists; kept **assigned** (fields hide if revoked).
- [ ] **Least-privilege runtime user** (not shared admin/MAD). **Exception accepted:** runs as MAD `oauser@pboedition.com`
      ([RUNTIME_USER_EXCEPTION.md](RUNTIME_USER_EXCEPTION.md)). **Top standing risk (R1).** Blocked on a Salesforce license.
- [x] Elevated permsets **unassigned** (`OA_Lead_Writeback_Automation` marked "keep UNASSIGNED"; `OA_SAM_Connector` 0 assigns).
- [x] FLS granted via permission set, not profile edits (Read/Create/Edit only; **no Delete/ViewAll/ModifyAll**).

### 1.2 Credentials & integrations
- [x] NCs exist, secret-free (`OA_USASpending`/`OA_Census`/`OA_SEC` NoAuth public; `OA_SAM` SecuredEndpoint → EC).
- [x] External Credentials hold the secrets and are **gitignored** (never tracked).
- [ ] SAM EC **principal access** granted only JIT (currently 0 — required before any SAM run). **R2.**
- [x] Integrations recorded in [INTEGRATION_REGISTRY.md](INTEGRATION_REGISTRY.md).

### 1.3 Execution & scheduling
- [x] Execution components (`OA_EnrichmentOrchestrator`/`OA_EnrichmentQueueable`/`OA_EnrichmentWriter`) built,
      deployed, safe-by-default (`commitWrites=false`), 279 tests at v1.2.
- [x] Batch limits set per [PERFORMANCE_VALIDATION.md](PERFORMANCE_VALIDATION.md) (callouts binding; batch 50 / IRS 200).
- [x] First live cycle runs **preview / no-write**, then flips to commit (proven Sprint 20→23).
- [x] **No schedule active** — 0 enrichment cron/Queueable/Batch/trigger references the writer (verified).

### 1.4 Monitoring & alerts
- [x] Monitoring & alerts **designed** ([MONITORING_AND_ALERTS.md](MONITORING_AND_ALERTS.md), 12 alerts; KPI catalog).
- [x] Interim monitoring available now: `scripts/shell/daily_enrichment_audit.sh` (PASS/WARN/FAIL).
- [ ] **Dashboards / reports / alerts deployed in org** — currently **0 deployed** (design-only). UI build. **R9.**

### 1.5 Backup & rollback
- [x] Change-log + before-snapshot on every write; **rollback proven** 30/30 fields at v1.2 (per-field).
- [x] Rollback is deterministic + rehearsed; itemized procedure now in [ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md).

### 1.6 Source control & release
- [x] Baseline tag recorded (`lead-enrichment-v1.2`); `main == origin/main` (`dbf8d12` at this review).
- [x] Deployment serialized; excluded WIP files understood and untracked (R7).
- [x] Release notes: [RELEASE_1.2.md](RELEASE_1.2.md).

### 1.7 Risk & compliance
- [x] Open risks logged with owners ([OPERATIONAL_RISK_REGISTER.md](OPERATIONAL_RISK_REGISTER.md), R1–R11).
- [x] No unapproved change to a [protected area](../CLAUDE.md).

### 1.8 Go / no-go
| Scope | Decision |
|-------|----------|
| Controlled **manual / preview** enrichment | 🟢 **GO** (certified v1.2) |
| Scheduled / batch / **24×7 write** automation | 🔴 **NO-GO** until R1 (least-priv user), monitoring deploy, SAM key/JIT are closed |

**🔴 Go-live approval (Louis):** _required to enable any live write beyond a supervised manual pilot._

---

## 2. Deployment Checklist
Full itemized version: [DEPLOYMENT_PACKAGE.md](DEPLOYMENT_PACKAGE.md) (§4 pre-deploy, §5 runtime-user, §6 EC,
§7 permset, §8 NC) and [templates/DEPLOYMENT_CHECKLIST_TEMPLATE.md](templates/DEPLOYMENT_CHECKLIST_TEMPLATE.md).
Deployment sequence (order matters):

1. Objects + fields (`OA_Connector_Run__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`, `OA_Discovered_Organization__c`).
2. CMDT **types** (definitions only, no records).
3. Apex — SDK + `OA_IEnrichmentConnector` + `OA_ConnectorRunner` + `OA_ConnectorResult`, then the 6 active connectors + tests.
4. Named Credentials (secret-free) — after org-side External Credentials exist for keyed sources.
5. Permission sets (**unassigned**).
6. CMDT **records LAST, in a separate deploy** — all `Enabled__c=false` / `Active__c=false` (dormant).

**Gate reminders:** check-only validation first (🟢); a non-`--dry-run` production deploy is 🔴; CMDT type+records
in one transaction throws `UNKNOWN_EXCEPTION` → two-phase; bundle an FLS permset with any new reportable field.

---

## 3. Rollback Checklist
Now a dedicated, itemized runbook: **[ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md)** (this package's new deliverable).
Summary of levers:
- **Data write:** `OA_ChangeLogService.rollback(<logs for the Run_ID>)` — merges all per-field snapshots, restores prior
  values, verify **per field** (not by record count). Executing it is 🔴 (production data write).
- **Metadata:** kill switch (`Enabled__c=false` / `Active__c=false`) → redeploy prior tag → (rarely) destructive removal.
- **Invariant:** no write without a `Before_Snapshot__c`; rollback rehearsed before scaling.

---

## 4. Operations Runbook Checklist
Authoritative: [LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md](LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md),
[DAILY_ENRICHMENT_OPERATING_PROCEDURE.md](DAILY_ENRICHMENT_OPERATING_PROCEDURE.md) (has `[ ]` checkboxes),
[MAINTENANCE.md](MAINTENANCE.md), [OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md) (incident authority).

- [x] **Daily:** run `daily_enrichment_audit.sh`; work down open exceptions; check run `Status` for Failed/PartialErrors; verify dormant after any run.
- [x] **Weekly:** throughput; rollback health (every write has a snapshot / `Reversible__c=true`); API/HTTP-error trend; connector success + latency.
- [x] **Monthly:** Salesforce seasonal-release review; connector API-compatibility review; DML/CPU headroom vs `PERFORMANCE_VALIDATION.md`.
- [x] **Emergency stop / kill switch:** disable connectors + deactivate policies (deploy with **quoted** `--source-dir`; verify active policies = 0).
- [x] **Reopen criteria:** defect / platform change / API change / security / governor regression **only** — no features.

---

## 5. Monitoring Checklist
Authoritative: [MONITORING_AND_ALERTS.md](MONITORING_AND_ALERTS.md) (12 alerts, Crit/Warn/Info),
[LEAD_ENRICHMENT_MONITORING.md](LEAD_ENRICHMENT_MONITORING.md), [KPI_CATALOG.md](KPI_CATALOG.md).

**Health checks (available now via CLI/audit script):**
- [x] Dormant-state check (0 enabled connectors, 0 active policies, 0 enrichment cron).
- [x] Integrity check (every change log has a before-snapshot; no orphan logs).
- [x] Run-status check (no `Failed` / `PartialErrors` unreviewed).
- [x] Exception-queue check (conflict/error queue worked down).

**Alerting (designed, must-be-zero tiles):** writes-without-snapshot = 0 · active Overwrite policies = 0 ·
repeated HTTP 401/403 · run `Status=Failed` · rollback failures.

**Gap (🟡):** dashboards, reports, and alert subscriptions are **designed but not deployed** (0 in org). Deploying
them (Salesforce UI + report/dashboard metadata) is required before any schedule. Until then, the audit script is
the monitoring surface. See [MONITORING_UI_BUILD_GUIDE.md](MONITORING_UI_BUILD_GUIDE.md).

---

## 6. Remaining Risks
Full register with scores + mitigations: [OPERATIONAL_RISK_REGISTER.md](OPERATIONAL_RISK_REGISTER.md). Top items:

| # | Risk | Sev | Gate it blocks |
|---|------|-----|----------------|
| R1 | Runtime user is MAD `oauser` (weakens FLS guardrail) | 🔴 High | scheduled/24×7 write — needs least-priv user (license) |
| R2 | SAM data.gov key unconfirmed / previously exposed | 🔴 High | any SAM run — rotate key + JIT EC principal grant |
| R3 | Prod data corruption via wrong/overwrite policy | 🟠 Med | mitigated: FillEmptyOnly + snapshot + proven rollback |
| R9 | Monitoring/alerting not deployed (0 in org) | 🟡 Low | scheduled write — build dashboards/alerts first |
| — | **Registry-integrity (new, latent):** `GrantsGov` & `SAM_Opportunities` registry records point at LEGACY `OA_IConnector` classes that do **not** implement `OA_IEnrichmentConnector`; if ever enabled in the enrichment runner they would throw a cast error. Dormant today (0 impact). | 🟡 Low | move OI records out of the enrichment registry, or guard the runner cast (eng, gated) |
| — | **Dead legacy LE code (new):** `OA_USASpendingConnector`/`OA_SAMConnector` + their mapper/parser/request/service are superseded by the `_Connector` versions and unreferenced (except tests). Cleanup candidate; reversible. | 🟡 Low | optional destructive cleanup (RED to deploy) |

**Standing invariants:** connectors dormant by default · `commitWrites=false` first cycle · FillEmptyOnly + snapshot
+ rehearsed rollback for pilots · runtime permset stays assigned / Automation permset stays unassigned · secrets only
in External Credentials, SAM principal JIT then revoked · no scheduled write until R1 + credentials + monitoring +
25→100 pilots are closed.

---

## 7. Recommended Deployment Sequence
The platform is already deployed dormant at v1.2. This is the sequence to **activate** live operation safely — each
step past the dormant baseline is gated.

1. 🟢 **Confirm dormant baseline** — audit script PASS; 0 enabled/active/scheduled; `main == origin/main`.
2. 🔴 **Provision least-privilege runtime user** (R1) — dedicated integration user, Minimum-Access profile (no MAD),
   full SF license, enrichment permsets JIT. *Blocked on license procurement.*
3. 🔴 **Deploy monitoring** — reports + dashboards + alert subscriptions to org (R9); wire failure-notification target.
4. 🔴 **Credentials for keyed sources** — rotate SAM data.gov key into the `OA_SAM` External Credential; grant EC
   principal access JIT (R2). (Census/SEC/USASpending are public, already live.)
5. 🔴 **Enable ONE connector** (start USASpending) — `Enabled__c=true` for that source only.
6. 🔴 **Activate FillEmptyOnly policies** for the target fields (`Active__c=true`; **no Overwrite active**).
7. 🟢→🔴 **Preview pilot** (`commitWrites=false`) → review → **controlled write** 25 Leads → verify audit + rehearse
   rollback → **return to dormant**. Then 100-Lead acceptance. (Both proven paths exist: Sprints 22–25.)
8. 🔴 **Only after pilots pass + R1/R2/R9 closed:** schedule recurring enrichment per [SCHEDULING_PLAN.md](SCHEDULING_PLAN.md).

Kill switch at every step: disable connector + deactivate policies → dormant.

---

## 8. Estimated Remaining Engineering Effort

| Item | Type | Effort | Gate |
|------|------|--------|------|
| Rollback Checklist doc | Docs | **Done this review** | — |
| Consolidated Readiness Package (this doc) | Docs | **Done this review** | — |
| Version-drift refresh (v1.1→v1.2 in certification / readiness / risk-register docs) | Docs | ~0.5 day | 🟢 |
| Registry-integrity fix (move OI records out of enrichment registry **or** guard runner cast) | Apex/CMDT | ~0.5 day | 🔴 deploy |
| Dead legacy LE connector removal (optional cleanup) | Destructive | ~0.5 day | 🔴 deploy |
| Monitoring dashboards/reports/alerts build | SF UI + metadata | ~1 day | 🔴 deploy |
| Least-privilege runtime user | Config | small — **blocked on license** | 🔴 non-eng |
| SAM key rotation + JIT principal grant | Credentials | small — **external (data.gov)** | 🔴 non-eng |

**Core platform engineering: COMPLETE (v1.2 certified).** Remaining *engineering* is ~2–3 days of optional
hardening/cleanup + a ~1-day monitoring UI build — **none blocks the certified manual/preview scope**. The true
blockers to 24×7 automation (least-priv user, SAM key) are **non-engineering** (a license and an external key).

---

_This package links the authoritative docs; it does not supersede them. Update the linked docs, not their copies here._
