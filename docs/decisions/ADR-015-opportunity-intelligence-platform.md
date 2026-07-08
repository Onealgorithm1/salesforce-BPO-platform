# ADR-015 — Opportunity Intelligence Platform (Charter)

**Status:** Proposed (design-only; awaiting Louis's approval — gate G0)
**Date:** 2026-07-08 (supersedes the design-branch ADR-015 @ `1b558d0`, expanded for Phase 0)
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Program:** 2 (after Lead Enrichment v1.x, certified/closed)
**Relates:** ADR-005 (connector framework), ADR-006 (canonical model), ADR-007 (entity resolution),
ADR-008 (security/credential), ADR-009 (metadata registry), ADR-010 (definition of ready),
ADR-011 (External Intelligence vision, design branch). See [ADR-INDEX.md](ADR-INDEX.md) for numbering.

---

## Context

Lead Enrichment (Program 1) answers *"who is this company"* — it enriches existing Leads/Accounts
from public data and is certified/closed/in maintenance mode. The org has a **certified,
source-agnostic connector SDK**, dormant Lead-Writeback plumbing, USASpending (reused, keyless),
and a dormant SAM **Entity** connector. The next roadmap program is **Opportunity Intelligence
(OI)** — *"what should we pursue"* — which discovers and ranks federal/state funding & contract
opportunities for human go/no-go decisions. A readiness audit (2026-07-08) confirmed ~80% of the
required machinery already exists and is dormant-safe.

## Decision

**Build Opportunity Intelligence as a separate program on the shared, certified platform.** It
reuses the connector SDK, telemetry, exception routing, and audit/rollback; it writes to **new
Opportunity-Intelligence objects only**; and it is **dormant-by-default, read-only at the source,
human-gated for every decision, explainable (no AI in v1), and reversible.**

Core decisions:
1. **Reuse, don't rebuild.** New sources = registry config + thin Request/Parser/Mapper classes on
   the existing `OA_ConnectorRunner`. No framework edits. (Detail: ADR-016.)
2. **New grain, new object.** Opportunities stage into `OA_Opportunity_Signal__c` (a solicitation),
   never into entity staging or Lead/Account. (Detail: ADR-017.)
3. **Human-in-the-loop is the product.** Everything lands in a review queue as `Pending`; the
   system never sets a final decision or creates a CRM record autonomously. (Detail: ADR-018.)
4. **Security inherits ADR-008.** Read-only sources, secrets only in External Credentials,
   least-privilege permset, MAD-`oauser` carryover documented as the top standing risk.
   (Detail: ADR-019.)
5. **Sequence keyless-first.** Phase 1 leads with **Grants.gov** (public, no key) to prove the full
   pipeline before depending on the historically-unresolved SAM data.gov key. SAM.gov Opportunities
   is an identical-shape Phase-2 fast-follow.

## Scope

**In:** fetch → normalize → dedupe → (P3) score → (P4) route to human pursuit workflow → (P5,
gated) create CRM Opportunities on human approval.
**Out (hard):** auto-Opportunity creation, outreach/CampaignMember changes, proposal/grant
*submission* or any external write, AI decisioning (v1), and any change to Lead Enrichment / ERE /
Analytics / Meta / LinkedIn / Auth work.

## Consequences

- **Positive:** reuses a proven, certified platform; explainable/auditable; safe (read-only,
  human-gated); incremental; small net-new footprint (one object + one thin connector for the MVP).
- **Negative / risks:** SAM Opportunities key is unresolved (mitigated by Grants.gov-first); scoring
  quality (P3) depends on curated OA NAICS/capability lists; cross-source dedupe is non-trivial
  (mitigated by source-scoped `Canonical_Key__c`).
- **Reversible:** Phase 0 is design-only — nothing built or deployed. MVP is insert-only and
  delete-by-run reversible.

## Status of related docs
Architecture, connector inventory, data model, reuse analysis, security, review-queue, and staging
designs accompany this ADR in `docs/` (see `OPPORTUNITY_INTELLIGENCE_PHASE0.md`).
