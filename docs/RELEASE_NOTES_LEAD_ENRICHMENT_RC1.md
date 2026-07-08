# Release Notes — Lead Enrichment RC1

**Release Candidate:** RC1 · **Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI`
**Engine baseline:** `lead-enrichment-v1.2` (`f4894e9`) · **RC1 = PRs #25–#31** · **Status:** deployment-ready, not deployed, not merged
**Certification:** [LEAD_ENRICHMENT_RC1_CERTIFICATION.md](LEAD_ENRICHMENT_RC1_CERTIFICATION.md)

---

## Major Deliverables
- **Operational documentation suite:** Production Readiness Package, Rollback Checklist, Repository/Governance/Deployment certifications, Operations Guide, Maintenance, Risk Register (normalized to v1.2).
- **Live production verification:** read-only audit confirming the platform is deployed and dormant (78 enriched Leads, baseline intact).
- **Analytics package (deployable metadata):** 4 custom report types, 9 reports, 3 dashboards (Executive, Operations, Business Development) — in the existing `OA_Executive_Analytics` folder.
- **Lead Quality Score:** configurable 0–100 model (report/formula, no new schema), validated on production.
- **KPI framework:** 24-KPI catalog + operational thresholds + 10 KPIs validated against production data.
- **Lead Intake Roadmap:** future acquisition pipeline (architecture only, human-gated).

## Business Value
One Algorithm can — after a gated analytics deploy — **immediately see**: lead quality, enrichment coverage,
connector health, review queue, campaign performance, meetings generated, opportunity influence, and business-development
metrics (agency/NAICS/certification/source distributions) — **without enabling any enrichment automation**. The
platform is measurable, monitorable, auditable, and reversible.

## Technical Summary
- Enrichment engine unchanged (v1.2, dormant): single connector SDK, 6 connectors, 2-phase orchestrator, FillEmptyOnly
  policy engine, before-snapshot audit + proven multi-field rollback, exception routing, telemetry.
- Analytics built entirely by **reuse** (existing folders/objects); only 4 missing enrichment report types added.
- No new objects/fields/automation; Lead Quality Score computed via report/formula.

## Production State
🟢 **DORMANT / unchanged.** 0 connectors enabled, 0 write policies active, 0 enrichment jobs; baseline 78 enriched
Leads / 474 change logs / 1 exception. RC1 introduces **no** production change (docs + un-deployed metadata only).

## Deployment Sequence (all 🔴 Louis-gated; after merge)
1. **Unit A — Report Types** (`reportTypes/`) — validated green (`0AfPn0000023bBZKAY`). Deploy first.
2. **Unit B — Reports** (`reports/OA_Executive_Analytics/LE_*`) — deploy after A (resolves the two-phase "invalid report type").
3. **Unit C — Dashboards** (`dashboards/OA_Executive_Analytics/Lead_Enrichment_*`, `Business_Development`) — deploy after B.
4. **Access** — assign existing `OA_Executive_Analytics_Access` permset for visibility.
Each unit is independently check-only validatable once its predecessor is live.

## Rollback Strategy
- **Metadata (analytics):** additive; roll back by deploying the prior commit/tag or by removing the report types/reports/dashboards (destructive metadata, gated). No data impact.
- **Enrichment data (if ever activated):** `OA_ChangeLogService.rollback(<logs for Run_ID>)` — per-field, proven ([ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md)).
- **Kill switch:** disable connectors + deactivate policies → dormant.
- RC1 itself needs no rollback (nothing deployed).

## Open Risks
| # | Risk | Severity | Note |
|---|------|----------|------|
| R1 | Runtime user is MAD `oauser` | 🔴 High | non-engineering (license); gates *active* enrichment only |
| R2 | SAM data.gov key + JIT EC grant | 🔴 High | non-engineering (external); SAM connector only |
| R9 | Monitoring alerts not deployed | 🟡 Med | analytics package addresses dashboards; alert subscriptions still a UI/gated step |
| — | Two-phase deploy order (A→B→C) | 🟡 Low | documented; not a defect |
| — | Repo↔org drift (OpenAI NC/EC; OI/social ECs) | 🟡 Low | out of Lead-Enrichment scope; reconcile before full-package deploy |

## What RC1 does NOT include
No new features, connectors, or dashboards beyond the approved analytics package; no Opportunity Intelligence expansion;
no LinkedIn/Meta/Website/Campaign changes; no production deployment, connector activation, permission assignment,
scheduled jobs, or data changes.
