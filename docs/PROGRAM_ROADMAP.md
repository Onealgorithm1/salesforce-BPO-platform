# Program Roadmap — Salesforce BPO Platform

_Baseline as of Lead Enrichment Platform v1.0 · 2026-07-07 · Org 00Dbn00000plgUfEAI_

| Program | Status | Notes |
|---|---|---|
| **Lead Enrichment Platform v1.1** | ✅ **COMPLETE / CERTIFIED (2026-07-07)** | Production-hardened + certified for controlled/manual enrichment. 68 Leads enriched, audited, reversible; both acceptance defects fixed (Awarding_Agencies__c → Long Text Area; writer SaveResult handling); 261 tests green. `RELEASE_1.1.md` + `PRODUCTION_CERTIFICATION.md`; tag `lead-enrichment-v1.1`. v1.0 baseline `485f7dc`. |
| **Operational Automation** (Lead Enrichment) | 🔧 **Enablement track (parallel)** | Gates scheduled/batch/24×7 only: provision least-privilege runtime user (replace MAD `oauser`); deploy `OA_EnrichmentOrchestrator`; deploy monitoring dashboards; SAM/Census/SEC credentials. Does NOT block v1.1 certification for controlled use. | Async orchestrator (`OA_EnrichmentOrchestrator`/`OA_EnrichmentQueueable`) + `OA_ProposalAdapter` **MERGED to `main` 2026-07-07** (fast-forward `485f7dc..59f9df0`, validated `0AfPn00000235zhKAA`, pushed). USASpending connectivity **proven live (HTTP 200)**. Census + SEC NCs prepared + validated (`0AfPn00000236CbKAI`), not deployed. **Remaining before pilot:** deploy the Sprint 17 execution layer to prod (currently count = 0 in org), enable USASpending connector, activate a fill-empty policy → run 25-Lead **preview** then commit. **Remaining before 24/7:** least-privilege runtime user (replace MAD `oauser`); Census/SEC NC deploy; SAM principal access + prod endpoint + key; monitoring dashboards; 25→100 pilots. No new platform code required. Detail: `SPRINT19_LIVE_PILOT_REPORT.md`. |
| **Opportunity Intelligence** | 🔭 **Future (next program)** | The next development epic after Lead Enrichment. Early design concepts exist on `design/lead-enrichment-platform` (External Intelligence Framework, `OA_Opportunity_Signal__c`) — deferred, not on `main`. |
| **Procurement Automation** | 🔭 **Future** | Deferred. |
| **Grant Management** | 🔭 **Future** | Dormant Grants.gov opportunity-signal connector prototype on branch `feature/grantsgov-lead-enrichment-staging` (not merged); design in `GRANT_MANAGEMENT_ROADMAP.md` on the design branch. Deferred. |
| **AI Decision Support** | 🔭 **Future** | Human-approval-mandatory recommendation layer; design (`ADR-011`, AI-layer doc) on the design branch. Deferred. |
| **Commercial Enrichment** | 🔬 **Future / Research only** | D&B, Crunchbase, ZoomInfo, GovWin, GovTribe — licensing/ToS/cost/PII review required before any build. |

## Standing constraints (carry forward to every program)
- Human-review governance and no-auto-write invariants remain (ADR-008; ADR-012 for enrichment).
- Named/External Credential for all callouts; secrets only in External Credentials (git-ignored).
- Least-privilege runtime user is the intended security model; the MAD `oauser` exception is temporary
  (`RUNTIME_USER_EXCEPTION.md`) and is the top standing operational risk.
- CMDT record files require `xmlns:xsd` on the root element (deployment learning).

## Where design/vision docs live
Early architecture/vision docs (External Intelligence Framework, connector registry architecture,
unified dedupe, governance standards, Grant/AI/Opportunity designs, `ADR-011`/`ADR-012`) are on the
`design/lead-enrichment-platform` branch — retained as historical design reference, **deferred**, and
not part of the v1.0 `main` baseline.
