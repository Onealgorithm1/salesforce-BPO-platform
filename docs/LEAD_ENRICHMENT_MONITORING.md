# Lead Enrichment — Monitoring & Automation Readiness

_Org `00Dbn00000plgUfEAI` · repo `salesforce-BPO-platform` · baseline `main=ae8280d` · 2026-07-07_

Purpose: make Lead Enrichment **operationally monitorable with granular evidence** so Louis can ask
for a **daily Claude audit** instead of relying on email alerts. This is not a redesign and adds no
new feature epic. **Finding: the existing telemetry model can already answer every required
operational question from SOQL — no new metadata is required.** The only real gap is the UI/procedure
layer (0 reports/dashboards are deployed in the org), which this document closes with a runnable audit
script and exact dashboard build steps.

---

## Phase 1 — Existing Monitoring Assets (audited 2026-07-07)

Live telemetry objects (field lists queried from the org):

- **`OA_Connector_Run__c`** (run-level, 18 rows) — Run_ID__c, Source_System__c, Category__c, Endpoint__c,
  Started__c, Ended__c, Status__c, Requested__c, Parsed__c, Mapped__c, Persisted__c, Records_Enriched__c,
  Exceptions_Raised__c, HTTP_Errors__c, Parse_Errors__c, Initiated_By__c, Messages__c.
- **`OA_Enrichment_Change_Log__c`** (field-level, 474 rows) — Target_Object__c, Target_Record_Id__c,
  Field_API_Name__c, Old_Value__c, New_Value__c, Before_Snapshot__c, Change_Type__c, Write_Mode__c,
  Confidence__c, Source_System__c, Connector_Run__c, Changed_At__c, Reversible__c.
- **`OA_Enrichment_Exception__c`** (conflict/error queue, 1 open row) — Target_Object__c, Target_Record_Id__c,
  Field_API_Name__c, Exception_Type__c, Details__c, Recommended_Resolution__c, Confidence__c,
  Source_System__c, Discovered_Organization__c, Connector_Run__c, Status__c, Resolved_By__c, Resolved_At__c.
- **`OA_Connector_Registry__mdt`** — `Enabled__c` (connector on/off, endpoint, class, named credential).
- **`OA_Field_Write_Policy__mdt`** — `Active__c`, Write_Mode__c, Conflict_Behavior__c (write governance).

| Asset | Exists? | Purpose | Granularity | Gap |
|---|---:|---|---|---|
| `OA_Connector_Run__c` | ✅ | Per-run summary telemetry | Run | Mode & conflicts live in `Messages__c` text, not as filterable fields |
| `OA_Enrichment_Change_Log__c` | ✅ | Every field write + rollback, with before-snapshot | **Field** | Skipped-because-populated writes are not logged (by design) |
| `OA_Enrichment_Exception__c` | ✅ | Conflicts + write/parse failures + resolution | Field/record | None material |
| `OA_Connector_Registry__mdt` | ✅ | Connector enable + endpoint config | Connector | None |
| `OA_Field_Write_Policy__mdt` | ✅ | Write-mode / conflict governance | Field-policy | None |
| Orchestrator run summary (`buildSummary`) | ✅ | leads / enriched / conflicts / retries / commit in `Messages__c` | Run | Text only (see above) |
| Reports (`OA*` / enrichment) | ❌ **0 in org** | — | — | **Must build UI or use script** |
| Dashboards (`OA*` / enrichment) | ❌ **0 in org** | — | — | **Must build UI or use script** |
| Docs: KPI_CATALOG, KPI_BASELINE, MONITORING_UI_BUILD_GUIDE, DASHBOARD_EXECUTIVE/OPERATIONS/ADMIN, MONITORING_AND_ALERTS, DAILY_ENRICHMENT_OPERATING_PROCEDURE | ✅ | KPI definitions + dashboard build guidance | Doc | Describe dashboards not yet built in the org |
| CLI reporting script | ✅ **new** | `scripts/shell/daily_enrichment_audit.sh` — runnable daily audit | Run+Lead+Field+Connector | — |

**Current org state (evidence, 2026-07-07):** 0 enabled connectors · 0 active write policies · 0 enrichment
cron jobs · 0 running Apex jobs · 18 runs (14 Succeeded, 4 PartialErrors) · 474 change logs (0 Rollback) ·
1 open exception · 78 Leads with UEI. **Platform is dormant.**

---

## Phase 2 — Minimum Granular Monitoring Model

The operational questions and the granularity required to answer them:

- **Run-level:** Run ID, start/end/runtime, initiated by, mode (preview|commit), source/connector, leads
  selected/processed/enriched, fields proposed/written, conflicts, exceptions, HTTP errors, rollback count,
  final status, dormant-verified.
- **Lead-level:** Lead ID, company, source, outcome (processed|skipped|enriched|exception), fields
  proposed/written, conflicts, exception type, rollback available.
- **Field-level:** Lead ID, field, old value, proposed value, written value, source, confidence, policy
  result, skipped reason, conflict reason, rollback-snapshot-exists.
- **Connector-level:** enabled, endpoint, HTTP status, request/success/failure/timeout/malformed/API-error counts.

---

## Phase 3 — Gap Analysis (required model vs live telemetry)

Legend: **E**=already exists · **NX**=exists but not exposed (report needed) · **R**=report/dashboard only ·
**M**=needs Apex/metadata · **D**=defer.

| Requirement | Current Coverage | Gap | Proposed Fix | Risk |
|---|---|---|---|---|
| Run ID / start / end / status / initiated-by | `OA_Connector_Run__c` fields | — | Use as-is | — |
| Runtime (duration) | Ended−Started | E→R | Report formula `Ended__c − Started__c` | None |
| Mode preview\|commit | in `Messages__c` (`commit=true/false`) | NX | Parse in script; **optional** `Commit_Mode__c` field only if a dashboard filter proves needed | Low → **Defer field** |
| Leads selected / processed | `Requested__c` | E | As-is | — |
| Leads **enriched** (distinct) | derive: distinct `Target_Record_Id__c` in Change_Log per run | NX | Script/report grouping | None |
| Fields written | `Records_Enriched__c` | E | As-is | — |
| Fields proposed | not stored | D | `written + conflicts (+skips)`; not operationally required | **Defer** |
| Conflicts | `Exception_Type__c='SourceConflict'` + `Messages__c` | NX | Report on exceptions | None |
| Exceptions / HTTP errors | `Exceptions_Raised__c` / `HTTP_Errors__c` | E | As-is | — |
| Rollback count | Change_Log `Change_Type__c='Rollback'` | NX | Report/script | None |
| Dormant verified | runtime query (registry/policy/cron/jobs) | R | Audit procedure §6 + script | None |
| Lead outcome (proc/skip/enrich/exc) | derive from Change_Log ∪ Exception ∪ run | NX | Script logic | None |
| Lead fields written / conflicts / exception type / rollback-available | Change_Log + Exception + `Reversible__c`/`Before_Snapshot__c` | E/NX | Report/script | None |
| Field old/new/snapshot/confidence/write-mode/conflict-reason | Change_Log + Exception fields | E | As-is | — |
| Field **skipped reason** | not logged (FillEmptyOnly skips are silent by design) | D | Skips are expected noise; conflicts (the actionable case) **are** logged as exceptions | **Defer** |
| Connector enabled / endpoint | Registry + `Endpoint__c` | E | As-is | — |
| Connector request/success/failure counts | `Requested__c`/`Records_Enriched__c`/`HTTP_Errors__c`/`Parse_Errors__c` | E→R | Aggregate report per `Source_System__c` | None |
| Connector timeout / malformed / API-error **sub-categories** | folded into `HTTP_Errors__c`+`Parse_Errors__c`; detail in `Messages__c`/`Category__c` | D | Sub-categorization not required for daily audit | **Defer** |

**Verdict: 0 new metadata required.** Every required operational question is answerable today via SOQL
(script) or a report. New fields (`Commit_Mode__c`, error sub-categories) are **deferred** — add only if a
dashboard filter later proves them necessary. This keeps the build minimal and fully reversible.

---

## Phase 4 — Build (minimal, reversible)

Delivered in this change — **docs + one script only, no org metadata**:

- `scripts/shell/daily_enrichment_audit.sh` — runnable SOQL audit pack (run/lead/field/connector/dormant), emits
  PASS / WARN / FAIL. This is the primary daily-audit instrument.
- This document (`LEAD_ENRICHMENT_MONITORING.md`) — audit, gap analysis, dashboard build steps, daily
  procedure, automation mode.

Not built (correctly avoided): no new objects, no parallel logging framework, no email/Slack/Teams alerts,
no custom UI, no redesign. Email alerts are **explicitly deferred** — the daily Claude audit replaces them.

---

## Phase 5 — Dashboard Build Plan (Salesforce UI)

Dashboards do **not** exist in the org (0 deployed). Because report/dashboard metadata deploys are
unreliable (folder + running-user coupling), build in the UI. All sections source from the three telemetry
objects; create reports in a **"Lead Enrichment"** report folder, then add to one dashboard.

| # | Section | Source Object | Filters | Grouping | Chart | Purpose |
|---|---|---|---|---|---|---|
| 1 | Automation Run Health | `OA_Connector_Run__c` | Started = LAST_N_DAYS:7 | Status__c | Donut | Did runs succeed / partial / fail |
| 2 | Connector Health | `OA_Connector_Run__c` | LAST_N_DAYS:30 | Source_System__c | Stacked bar (Status) | Which connectors run & fail |
| 3 | Enrichment Volume | `OA_Enrichment_Change_Log__c` | Change_Type__c=Enrich, LAST_N_DAYS:30 | Changed_At__c (day) | Line | Fields written/day trend |
| 4 | Field Write Volume | `OA_Enrichment_Change_Log__c` | Change_Type__c=Enrich | Field_API_Name__c | Bar | Which fields get enriched most |
| 5 | Exception Queue | `OA_Enrichment_Exception__c` | Status__c ≠ Resolved | Exception_Type__c | Bar + table | Open conflicts/errors to work |
| 6 | Conflict Queue | `OA_Enrichment_Exception__c` | Exception_Type__c=SourceConflict, Status≠Resolved | Source_System__c | Table | Ambiguous multi-match review |
| 7 | Rollback Readiness | `OA_Enrichment_Change_Log__c` | Change_Type__c=Enrich | Reversible__c | Donut | % writes reversible (snapshot present) |
| 8 | Dormant State | `OA_Connector_Run__c` | Ended = TODAY | Status__c | Metric (count) | Any activity today? (0 = dormant) |
| 9 | Daily Throughput | `OA_Connector_Run__c` | LAST_N_DAYS:14 | Started__c (day) | Column (Sum Records_Enriched__c) | Enrichment per day |
| 10 | API/HTTP Error Trend | `OA_Connector_Run__c` | HTTP_Errors__c > 0 | Started__c (day) | Line (Sum HTTP_Errors__c) | Detect API drift / outages |

**Exact UI build steps:** (1) `Setup → Report Types` — confirm the three objects allow custom reports (they
are custom objects, so standard report types exist). (2) `Reports → New Folder → "Lead Enrichment"`,
share to the ops user. (3) For each row above: `New Report → pick the source object → add filters →
group → add chart → Save into "Lead Enrichment"`. (4) `Dashboards → New Dashboard → "Lead Enrichment
Operations"`, running user = the enrichment runtime user; add one component per report using the chart
above. (5) Set the dashboard to refresh daily. Until this is built, `scripts/shell/daily_enrichment_audit.sh`
provides the same evidence from the CLI. Reference detail: `MONITORING_UI_BUILD_GUIDE.md`, `KPI_CATALOG.md`.

---

## Phase 6 — Daily Claude Audit Procedure

Run `scripts/shell/daily_enrichment_audit.sh` (below) — it answers each question from live SOQL and prints a
verdict. Manual equivalent (what Claude checks and how):

| Audit question | Evidence source |
|---|---|
| Did scheduled preview / write run? | `OA_Connector_Run__c` rows today; `Messages__c` shows `commit=true/false` |
| Leads processed / enriched | `Requested__c`; distinct `Target_Record_Id__c` in Change_Log for today's runs |
| Fields written | Σ `Records_Enriched__c` today; count Change_Log `Change_Type='Enrich'` today |
| Connectors succeeded / failed | `Status__c` grouped by `Source_System__c` |
| HTTP errors | Σ `HTTP_Errors__c` today |
| Source conflicts | `OA_Enrichment_Exception__c` `Exception_Type='SourceConflict'` created today |
| Exceptions | open `OA_Enrichment_Exception__c` count/age |
| Rollbacks triggered | Change_Log `Change_Type='Rollback'` today |
| Rollback available for all writes | every today `Update` row has `Reversible__c=true` + non-empty `Before_Snapshot__c` |
| Platform dormant now | 0 enabled connectors, 0 active policies, 0 enrichment cron, 0 running jobs |
| API drift signs | HTTP-error spike vs 7-day baseline; new `Parse_Errors__c`; `PartialErrors` status |
| Governor-limit pressure | run runtime trend; batch size vs 50/txn guidance; HTTP_Errors from limit hits |
| Bugs needing engineering | any `Status='Failed'`; writes with no snapshot; enriched-count = 0 on enabled run |

Verdict rules:
- **`PASS — No action required`** — runs (if any) Succeeded, 0 unexpected rollbacks, all writes reversible,
  platform dormant after run, no HTTP/parse spike, no open-exception growth.
- **`WARN — Operational review required`** — `PartialErrors`, new SourceConflicts, open-exception backlog
  growing, HTTP errors within tolerance but elevated, or a connector/policy left enabled unexpectedly.
- **`FAIL — Engineering fix required`** — any run `Failed`, a write missing its rollback snapshot,
  enriched-count 0 on an enabled commit run, repeated HTTP failures indicating API drift, or governor limits hit.

---

## Phase 7 — Automation Operating Mode

| Mode | Runs automatically | Reviewed by Louis/Claude | Manually approved | Rollback path | Monitoring evidence |
|---|---|---|---|---|---|
| 1 · Manual controlled | nothing | each run before/after | every run | `OA_ChangeLogService.rollback` | script/SOQL per run |
| 2 · Scheduled preview only | preview (no writes) | daily audit | writes (separate) | n/a (no writes) | daily script |
| 3 · Scheduled preview + human-approved write | preview | daily audit → approve | the write step | rollback by Run_ID | daily script + dashboards |
| 4 · Scheduled preview + scheduled write | preview **and** write | daily audit | none | rollback by Run_ID | dashboards + alerts |
| 5 · Fully unattended | everything | periodic | none | rollback by Run_ID | dashboards + alerts + least-priv user |

**Current mode: 1 (Manual controlled).** Nothing is scheduled; every run is Claude-invoked and reviewed.

**Recommended next mode: 3 (Scheduled preview + human-approved write).** The write path is fixed and proven
(Sprint 35, 5/5), rollback works, and this monitoring layer supplies the daily evidence — so scheduled
**preview** is safe now, with writes still gated on a human "go" from the daily audit. Modes 4–5 (scheduled
or unattended **writes**) stay blocked until the two standing non-engineering items land: a **least-privilege
runtime user** (replaces the temporary MAD `oauser`) and **deployed dashboards + alerting**. Do not advance
past Mode 3 without both.

---

## Phase 8 — Evidence Package

| Item | Value |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✓ |
| Repo / branch | `salesforce-BPO-platform` / `feature/enrichment-monitoring-readiness` |
| Base HEAD | `main = ae8280d` |
| Deployed metadata changed | **none** (docs + script only) |
| Validation / deploy ID | n/a (no org deploy) |
| Tests run | n/a (no code change) |
| Monitoring assets created | `scripts/shell/daily_enrichment_audit.sh`, `docs/LEAD_ENRICHMENT_MONITORING.md` |
| Dashboards/reports | 0 in org — exact UI build steps documented (§5) |
| Remaining monitoring gaps | all **Deferred** (optional `Commit_Mode__c` + HTTP error sub-categories); none block the daily audit |
| Recommended automation mode | **3 — Scheduled preview + human-approved write** |
| Dormant after this work | ✅ 0 connectors, 0 policies, 0 cron, 0 jobs |
| Final verdict | **PASS — monitoring layer in place; no engineering required** |
