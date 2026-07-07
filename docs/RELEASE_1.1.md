# Lead Enrichment Platform — RELEASE 1.1 (Production Hardened & Certified)

_Release v1.1 · 2026-07-07 · Org 00Dbn00000plgUfEAI · tag `lead-enrichment-v1.1`_

## What v1.1 is
v1.1 is the **production-hardened, certified** Lead Enrichment Platform. It builds on v1.0 (`lead-enrichment-v1.0` = `485f7dc`) with: the Sprint-17 operational layer merged, live production enrichment proven (Sprints 23–24), and the two acceptance-test defects eliminated and certified (Sprint 25).

## Delta v1.0 → v1.1
- **Operational layer merged** (Sprint 17): `OA_EnrichmentOrchestrator`/`OA_EnrichmentQueueable`/`OA_ProposalAdapter` on `main` (built + validated; deployed only where needed).
- **First production write** (Sprint 23): 8 Leads; root-caused the callout-before-DML transaction rule.
- **100-Lead acceptance** (Sprint 24): 54/60 enriched; KPI baseline set; 2 defects found.
- **Hardening** (Sprint 25):
  - **Defect #1:** `Awarding_Agencies__c` `Text(255)` → **Long Text Area(32768)** (multi-agency contractors no longer overflow).
  - **Defect #2:** `OA_EnrichmentWriter` now **inspects `Database.SaveResult`** — failed writes route an exception and never leave misleading audit.
  - 6 failed Leads repaired; full test suite (261) green.

## Certified state
- **68 Leads enriched** in production, fully audited & reversible, 0 overwrites.
- **Certified for manual/controlled enrichment** (25/100/daily). See `PRODUCTION_CERTIFICATION.md`.
- Platform **dormant by default** (0 active policies, 0 enabled connectors, 0 schedules).

## Not in v1.1 (carried forward — operational automation track)
- Least-privilege runtime user (replace temporary MAD `oauser`) — needs a Salesforce license.
- `OA_EnrichmentOrchestrator` deployment (for batch/scheduled) + scheduler.
- Monitoring dashboards deployment.
- SAM / Census / SEC credential provisioning.
These gate **scheduled/batch/24×7** only; they do not block v1.1 certification for controlled use.

## Baselines
- v1.0 baseline: `RELEASE_1.0.md` (`485f7dc`, tag `lead-enrichment-v1.0`).
- KPI baseline: `KPI_BASELINE.md`. Operations: `OPERATIONS_GUIDE.md`. Go-live gate: `GO_LIVE_CHECKLIST.md`.

**Epic status:** Lead Enrichment build + hardening **COMPLETE / CERTIFIED**. Next engineering program: **Opportunity Intelligence** (`PROGRAM_ROADMAP.md`).
