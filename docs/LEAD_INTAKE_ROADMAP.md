# Lead Intake Roadmap — Future Acquisition Pipeline (Architecture Only)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Status:** 🔵 **ARCHITECTURE ONLY — NOT ACTIVATED, NOT BUILT**
**Hard constraints:** no automatic lead creation · no scheduled imports · no production writes · no new connector framework

> Phase 5. The future-state workflow for acquiring and onboarding new Leads, reusing the existing enrichment platform.
> **Nothing here is implemented or scheduled.** Every write/creation stage is human-gated. This is a design to review,
> not a system to switch on.

---

## 1. Pipeline (design)

```
External Source (public API / list / referral)
        ↓   [connector fetch — reuse OA_ConnectorRunner; NO auto-run]
Candidate Company  → OA_Discovered_Organization__c (existing staging object; reuse)
        ↓   [Duplicate Detection — match vs existing Lead/Account]
Duplicate Detection → Salesforce Matching/Duplicate Rules (org-side) + UEI/name/domain match
        ↓   [HUMAN REVIEW GATE 🔴]
Human Review        → OA_Enrichment_Exception__c queue (existing review queue; reuse) — approve/reject
        ↓   [Lead Creation — MANUAL / approved only, never automatic]
Lead Creation       → Lead (created only on human approval)
        ↓   [Enrichment — existing certified platform, dormant until enabled]
Enrichment          → OA_EnrichmentOrchestrator → connectors → FillEmptyOnly writes + audit
        ↓
Campaign Assignment → existing EDWOSB campaign enrollment (protected automation; unchanged)
        ↓
Outreach            → existing drip/follow-up schedulers (protected; unchanged)
        ↓
Meeting             → CampaignMember "Meeting Booked" (existing meeting-tracking flow)
        ↓
Opportunity         → standard Lead conversion (human)
        ↓
Customer
```

## 2. Reuse map (no new infrastructure)
| Stage | Reuses (existing, deployed) | New? |
|---|---|---|
| Candidate ingestion | `OA_ConnectorRunner` + `OA_IEnrichmentConnector` connectors | No |
| Candidate staging | `OA_Discovered_Organization__c` | No |
| Duplicate detection | org Matching/Duplicate Rules + UEI/domain match | Config only |
| Human review | `OA_Enrichment_Exception__c` review queue | No |
| Lead creation | standard `Lead` (manual/approved) | No |
| Enrichment | certified enrichment platform (dormant) | No |
| Campaign/outreach/meeting | existing EDWOSB automations (protected) | No |

## 3. Hard gates (all 🔴, human-in-the-loop)
1. **No source auto-runs** — connectors stay dormant; ingestion is invoked deliberately, gated.
2. **No automatic Lead creation** — a candidate becomes a Lead only after human review + explicit approval.
3. **No scheduled imports** — no CronTrigger/scheduled Apex introduced.
4. **No production writes** without approval — enrichment writes remain FillEmptyOnly + audited + reversible.
5. **Duplicate-first** — every candidate is matched against existing Leads/Accounts before creation.

## 4. Phasing (future, each gated)
- **Intake-0 (design):** this document. ✅
- **Intake-1:** duplicate-detection config + review-queue extension for candidate triage (no auto-create). Gated build.
- **Intake-2:** one supervised source (e.g. SAM Opportunities or a curated list) → candidate → review → manual create → enrich. Gated pilot.
- **Intake-3:** volume + quality-score gating on which candidates become Leads. Gated.
- **Intake-4 (only after ops maturity):** consider assisted (still human-approved) creation for high-confidence, high-quality-score candidates. Gated.

## 5. Dependencies & prerequisites
- Least-privilege runtime user (R1) before any volume creation/enrichment.
- Duplicate/matching rules configured (currently the `duplicateRules`/`matchingRules` folders are empty scaffolds).
- Quality-score model live (Option A) to gate candidate promotion.
- Monitoring deployed (R9) before any recurring intake.

**This roadmap creates nothing. It documents how the future intake pipeline reuses the certified platform with human
gates at every write. Activation of any stage is a separate, explicit, Louis-approved decision.**
