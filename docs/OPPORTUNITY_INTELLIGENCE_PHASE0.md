# Opportunity Intelligence — Phase 0 (Architecture Approval Package)

**Program:** 2 (Opportunity Intelligence) · **Phase:** 0 — Architecture Approval
**Status:** Proposed · design/documentation only · **awaiting Louis's approval**
**Branch:** `feature/opportunity-intelligence` (off `main` @ `8793f1f`)
**Author session:** readiness audit + Phase 0 design (2026-07-08)

> **Phase 0 is documentation only.** Nothing in this package is deployed, merged, or executed.
> No production data, metadata, Apex, connector, credential, schedule, or CRM record is created or changed.
> Approval of this package (gate **G0**) is the sole prerequisite to begin Phase 1 (build, dormant).

---

## What Opportunity Intelligence is

Lead Enrichment (Program 1, certified/closed) answers **"who is this company."**
Opportunity Intelligence (OI, Program 2) answers **"what should we pursue"** — it discovers,
normalizes, deduplicates, and (later) scores **federal/state funding & contract opportunities**
into a **ranked, explainable, human-reviewed pursuit pipeline**, without ever auto-committing
the business to anything.

## The one-sentence design

*Point the already-certified, source-agnostic connector engine at opportunity feeds instead of
company feeds, and land the results in a new human-review inbox (`OA_Opportunity_Signal__c`)
instead of on Leads — reusing telemetry, exception routing, and audit/rollback as-is, and
touching nothing that Lead Enrichment, ERE, or Analytics owns.*

## Phase 0 deliverables (this package)

| # | Objective | Document |
|---|---|---|
| 1 | Architecture documentation | [OPPORTUNITY_INTELLIGENCE_ARCHITECTURE.md](OPPORTUNITY_INTELLIGENCE_ARCHITECTURE.md) |
| 2 | Connector inventory + source readiness | [OI_CONNECTOR_INVENTORY.md](OI_CONNECTOR_INVENTORY.md) |
| 3 | Data model | [OI_DATA_MODEL.md](OI_DATA_MODEL.md) |
| 4 | Reuse analysis | [OI_REUSE_ANALYSIS.md](OI_REUSE_ANALYSIS.md) |
| 5 | ADRs | [decisions/ADR-015…ADR-019](decisions/ADR-INDEX.md) |
| 6 | Security model | [OI_SECURITY_MODEL.md](OI_SECURITY_MODEL.md) |
| 7 | Review queue design | [OI_REVIEW_QUEUE_DESIGN.md](OI_REVIEW_QUEUE_DESIGN.md) |
| 8 | Staging design | [OI_STAGING_DESIGN.md](OI_STAGING_DESIGN.md) |

## Governing principles (carried from Lead Enrichment v1.x)

- **Dormant by default** — connectors `Enabled__c=false`, permsets unassigned, objects ship empty.
- **Read-only sources** — all external APIs are GET-only; OI submits nothing anywhere.
- **Human-gated decisions** — no CRM `Opportunity`, no outreach, no submission without a human.
- **Explainable & auditable** — rule-based (no AI in v1); every run has telemetry + provenance.
- **Reversible** — MVP is insert-only into a dormant object; later writeback reuses rollback.
- **Reuse the certified SDK** — no framework redesign; new sources are config + thin classes.
- **No blast radius** — OI writes only new OI objects; never Lead/Account/Campaign/ERE/Analytics.

## Hard no-touch list (guardrails)

- Lead Enrichment classes, objects, policies (maintenance mode).
- `OA_LeadWritebackService` (deployed dormant, unauthorized).
- ERE (`OA_Engagement_*`, `OA_Engagement_Resolution__c`, `OA_Engagement_Config__mdt`).
- Analytics (`Campaign_Funnel_Snapshot__c`, executive analytics reports/permsets).
- Meta / LinkedIn / Auth branches and credentials.
- The connector SDK internals (`OA_ConnectorRunner`, `OA_ConnectorHttp`, interfaces) — reuse, never edit.

## Roadmap at a glance (detail in the architecture doc)

| Phase | Scope | Gate to enter |
|---|---|---|
| **0** | Architecture approval (this package) | — |
| **1** | Public source ingestion MVP (keyless Grants.gov → review queue), dormant | G0 |
| **2** | Second source (SAM.gov Opportunities, on data.gov key) + review UI | G1/G2 + G3 (key) |
| **3** | Explainable scoring / matching (`OA_Opportunity_Score__c`) | G4 |
| **4** | Pursuit-candidate workflow + dashboard | Phase 3 sign-off |
| **5** | Controlled CRM `Opportunity` creation / writeback — **only if approved** | G5 |

## Recommended first live source: Grants.gov (not SAM)

The prior design (ADR-015) led with SAM.gov Opportunities, which needs an unresolved data.gov API
key. Phase 0 recommends **leading Phase 1 with keyless, public Grants.gov** to prove the full
pipeline (fetch → signal → dedupe → review queue) with **zero external-credential dependency**.
SAM becomes an identical-shape fast-follow once Louis provisions a valid key. See
[ADR-015](decisions/ADR-015-opportunity-intelligence-platform.md) §Sequencing.

## Approval gates

| Gate | Approves | Blocks |
|---|---|---|
| **G0** | This Phase 0 package + object-model freeze | all build |
| **G1** | Phase 1 dormant deploy (empty objects, connector `Enabled__c=false`, permset unassigned) | Phase 1 deploy |
| **G2** | First *commit* run into the review queue (after preview inspection) | first data persist |
| **G3** | data.gov key provisioned in an External Credential | Phase 2 (SAM) |
| **G4** | Scoring ruleset + curated NAICS/capability lists | Phase 3 |
| **G5** | CRM `Opportunity`/writeback + least-privilege runtime user | Phase 5 |

---

**Next action on approval:** begin Phase 1 in an isolated worktree/branch
`feature/opportunity-intelligence-grants-slice`, build dormant, validate check-only, stop at G2.
