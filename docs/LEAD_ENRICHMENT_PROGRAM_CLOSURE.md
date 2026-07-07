# Lead Enrichment — Program Closure (documentation map · repo cleanup · closure assessment)

_Sprint 29 · 2026-07-07 · Org 00Dbn00000plgUfEAI · **final Lead Enrichment sprint** · nothing deleted this sprint_

## Track E — Documentation authoritative map
| Domain | ✅ Authoritative | 🕰 Historical (keep) |
|---|---|---|
| **Roadmap** | `PROGRAM_ROADMAP.md` | `ROADMAP.md`, `PLATFORM_ROADMAP.md`, `CONNECTOR_FRAMEWORK_ROADMAP.md` (early/scoped) |
| **Operations** | `OPERATIONS_GUIDE.md` | pilot runbooks (`BPO_PILOT_OPERATOR_RUNBOOK.md`, `SPRINT13_CANARY_COMMISSIONING.md`) |
| **Monitoring** | `MONITORING_AND_ALERTS.md` + `MONITORING_UI_BUILD_GUIDE.md` | `OPERATIONAL_ALERTS.md`, `MONITORING_DASHBOARDS.md` |
| **Deployment/commissioning** | `LEAD_ENRICHMENT_COMMISSIONING_REPORT.md` | Sprint 19–24 pilot reports |
| **Certification** | `PRODUCTION_CERTIFICATION.md` | — |
| **KPIs** | `KPI_CATALOG.md` (defs) + `KPI_BASELINE.md` (values) | — |
| **Readiness** | `FINAL_OPERATIONAL_READINESS.md` | `LEAD_ENRICHMENT_OPERATIONAL_READINESS.md` (Sprint 27) |
| **Release** | `RELEASE_1.1.md` | `RELEASE_1.0.md` |
Recommendation: add a one-line "superseded by X" header to the historical roadmaps (`ROADMAP.md` etc.) in a future doc-only pass. **Do not delete** — provenance.

## Track F — Repository cleanup recommendations (RECOMMEND ONLY — nothing deleted)
| Candidate | Evidence | Recommendation |
|---|---|---|
| **Legacy connector framework** — `OA_USASpendingConnector`, `OA_USASpendingClient`, `OA_USASpendingParser/Request/Mapper`, `OA_USASpendingEnrichmentService`, `OA_SAMConnector/Mapper/Parser/Request` (non-underscore) | Used by the older `OA_IConnector` + `OA_ConnectorPersistence` path; the **v1.1 pipeline uses the underscore versions** (`OA_USASpending_Connector`, `OA_SAM_Connector`) referenced by the registry | Dead-code **candidate**; do a caller/test-coverage review, then retire in a dedicated cleanup sprint (they still have tests + interface deps). |
| **Duplicate roadmaps** (`ROADMAP.md`, `PLATFORM_ROADMAP.md`, `CONNECTOR_FRAMEWORK_ROADMAP.md`) | 4 roadmap docs | Keep `PROGRAM_ROADMAP.md` authoritative; mark others historical. |
| **ADR numbering** | ADR-011/012 on `design/lead-enrichment-platform`; ADR-013/014 (LinkedIn/Auth, untracked); ADR-015 (Opportunity Intelligence, design branch) | Reconcile ADR sequence when the design/LinkedIn branches merge. |
| **Stale branches** (~30 local): `feature/sprint12-16*`, `feature/wave1/2*`, `feature/connector-*`, `feature/usaspending-*`, `feature/lead-enrichment-foundation`, etc. | Superseded by v1.1 on main | Recommend deleting *merged* ones after confirming they're contained in main; **do not delete unmerged design/parallel branches** (`design/*`, `opportunity-intelligence-design`, `meta-connector-int011`, `meeting-tracking-link`). |
| **Excluded junk** (`apex-temp-*.json/.apex`, `lead_by_ramesh.flow-meta.xml`) | untracked, never committed | Keep gitignored/untracked. |
Repository health: 🟢 **healthy** — v1.1 clean on main; debt is isolated (legacy framework) and non-blocking.

## Track H — Program closure assessment
### Verdict: ✅ **GO — Lead Enrichment can be CLOSED / FROZEN**
Engineering is complete and certified; every remaining item is UI/license/credential (non-engineering). Freezing is safe.

### Remaining (non-engineering) enablement checklist (does NOT block closure)
1. Build monitoring dashboards/reports/alerts via UI (`MONITORING_UI_BUILD_GUIDE.md`).
2. Provision least-privilege runtime user (needs a license) → migrate off `oauser`.
3. Complete SAM key + Census/SEC NCs (external credentials / 1-command deploy).
4. Then enable scheduled enrichment.

### Recommended Git tag (operational baseline)
When the operational branches are merged to main: tag **`lead-enrichment-ops-v1.1`** on that merge commit (marks the operationally-commissioned baseline; keep `lead-enrichment-v1.0`/`v1.1` intact). Do not retag existing tags.

### Archive strategy
- Freeze the platform code (connector SDK + enrichment engine) — changes only via `CONNECTOR_DEVELOPER_GUIDE.md` (add sources, don't edit engines).
- Merge operational branches (`feature/lead-enrichment-operational-excellence` → `-operational-deployment` → `-final-commissioning`) to main via PR, then delete those merged branches.
- Retain all Sprint 17–29 reports as historical provenance (do not delete).

### Transition to Opportunity Intelligence
- Lead Enrichment enters **maintenance/operational mode** (enablement checklist above proceeds as ops tasks).
- **Program 2 (Opportunity Intelligence)** is designed (ADR-015 + roadmap on `feature/opportunity-intelligence-design`) and ready to begin per `SPRINT27_IMPLEMENTATION_PLAN.md` — **only on Louis's approval** + a data.gov Opportunities key. It reuses the frozen SDK and never modifies Lead Enrichment.

## Bottom line
Lead Enrichment is **engineering-complete, certified, operationally commissioned (with conditions), and safe to freeze.** The next sprint may begin Opportunity Intelligence.
