# Salesforce BPO Platform — End-to-End Business Development System Certification

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-live-pilot` (PR #49)
**Mode:** enterprise integration certification — live-org inventory + documentation. **No production writes · no automation · no scheduling · no new connectors · no merge · no Opportunity Intelligence.**
**Verification order:** live org → runtime → repository → docs.

---

## 1. Executive Summary
The platform's **discovery-through-campaign half is built, deployed, and proven end-to-end** (external source → candidate → dedup → identity → fusion → completeness → review, then Lead → enrichment → campaign, with 306 campaign members live). Cross-cutting subsystems — **connector framework, queueable framework, telemetry (18 runs), audit (474 change logs), policy engine, exception logging, engagement resolution (44 shadow rows), rollback** — are deployed and operational. There is **one genuine engineering integration gap: no Approved-Candidate → Lead conversion bridge** (the candidate object links to existing Leads for *dedup*, but nothing converts an approved candidate into a new Lead). The **close half (Opportunity → Customer) is not started** (Opportunities = 0) and belongs to a separate, gated program. Governance holds: **no AI writes Leads automatically, review-before-Lead is preserved, nothing is scheduled.** **Verdict: 🟢 PASS (certification) with 🟡 WARN — one lifecycle bridge missing.**

## 2. Platform Inventory (live)
| Subsystem | Implemented | Prod-deployed | Dormant | Operational | Integrated | Key components |
|---|---|---|---|---|---|---|
| Lead Acquisition / Candidate Discovery | ✅ | ✅ | ✅ (connectors off) | ✅ (pilots) | ✅ | `OA_CandidateDiscovery(+Service,+Queueable)`, `OA_DiscoveryQualificationEngine` |
| Identity Resolution | ✅ | ✅ | — | ✅ | ✅ | `OA_IdentityResolution`, `OA_NameNormalizer`, `OA_CanonicalOrg` |
| Source Fusion | ✅ | ✅ | — | ✅ (1st prod fusion) | ✅ | `OA_SourceFusion`, `OA_SourcePrecedenceEngine`, `OA_ConfidenceEvaluator` |
| Completeness Scoring | ✅ | ✅ | — | ✅ | ✅ | `OA_LeadCompleteness` |
| Review Queue | ✅ | ✅ | — | ✅ (1 exception, 6 Needs Review) | ⚠ manual | `OA_Enrichment_Exception__c`, `OA_ExceptionRoutingService` |
| Lead Enrichment | ✅ | ✅ (v1.2 certified) | gated | ✅ | ✅ | `OA_EnrichmentOrchestrator/Queueable/Writer`, `OA_USASpendingEnrichmentService` |
| Connector Framework | ✅ | ✅ | ✅ | ✅ | ✅ | active `OA_IEnrichmentConnector`+`OA_ConnectorRunner`; **legacy gen still present (dead)** |
| Queueable Framework | ✅ | ✅ | ✅ | ✅ | ✅ | `OA_CandidateDiscoveryQueueable`, `OA_EnrichmentQueueable`, `OA_AISummaryQueueable`, `OA_EngagementResolverQueueable/Batch` |
| Monitoring / Telemetry | ✅ | ✅ | — | ✅ (18 `OA_Connector_Run__c`) | ✅ | run records + httpErrors/parseErrors |
| Audit | ✅ | ✅ | — | ✅ (474 `OA_Enrichment_Change_Log__c`) | ✅ | `OA_ChangeLogService` |
| Proposal Engine | ✅ | ✅ | ✅ | — | ⚠ partial | `OA_ProposalAdapter`, `OA_AISummaryService` |
| Policy Engine | ✅ | ✅ | — | ✅ | ✅ | `OA_FieldWritePolicyEngine` (`OA_Field_Write_Policy__mdt`), `OA_QualificationRuleEngine` (`OA_Qualification_Rule__mdt`) |
| Exception Logging | ✅ | ✅ | — | ✅ | ✅ | `OA_Enrichment_Exception__c`, `OA_ExceptionRoutingService` |
| Rollback | ✅ | ✅ | — | ✅ (writeback rollback, fusion fill-empty reversible) | ✅ | `OA_LeadWritebackService`, `OA_ReplayBookingService` |
| Canonical Mapping | ✅ | ✅ | — | ✅ | ✅ | `OA_CanonicalOrg`, per-source `OA_*_Mapper` |
| Engagement Resolution (ERE) | ✅ | ✅ | observe-only | ✅ (44 rows) | ✅ | `OA_EngagementResolver(+Batch,+Queueable)`, `OA_Engagement_Resolution__c` |
| Send governance / Campaign | ✅ | ✅ | — | ✅ (306 members) | ✅ | `OA_SendGovernor`, `OA_EmailSender`, `OA_DripScheduler`, `OA_FollowUpScheduler`, flow *OA EDWOSB Outreach Sequence* |

**Objects (12):** candidate `OA_Discovered_Organization__c`; telemetry `OA_Connector_Run__c`; audit `OA_Enrichment_Change_Log__c`; review `OA_Enrichment_Exception__c`; ERE `OA_Engagement_Resolution__c`; comms `OA_Communication_Preference(_Audit/_Token)__c`; `OA_Campaign_Settings__c`; `OA_Graph_Credential__c`; legacy staging `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c`.
**CMDT (7):** `OA_Connector_Registry__mdt`, `OA_Engagement_Config__mdt`, `OA_Enrichment_Pipeline__mdt`, `OA_Enrichment_Source__mdt`, `OA_Field_Write_Policy__mdt`, `OA_Graph_Config__mdt`, `OA_Qualification_Rule__mdt`.
**Active flows (4):** OA EDWOSB Outreach Sequence, OA New Website Lead Notification, OA PostMeeting Nurture, OA Reply Detection.

## 3. Business Lifecycle Status
| Transition | Status | Evidence |
|---|---|---|
| External Source → Candidate | ✅ Implemented | connectors → `OA_CandidateDiscoveryService` (USASpending/SEC/SAM proven) |
| Candidate → Duplicate Detection | ✅ Implemented | payload-hash + canonical-key dedup (skip=exact-dup verified) |
| → Identity Resolution | ✅ Implemented | `OA_IdentityResolution` bulk-safe, cross-identifier |
| → Source Fusion | ✅ Implemented | first prod cross-source fusion (USASpending × SAM) |
| → Completeness Score | ✅ Implemented | `OA_LeadCompleteness` (23→47 proven) |
| → Review | ✅ Implemented | candidates land `Needs Review`; exception queue |
| → Approved Candidate | ⚠ Partial | `Qualification_Status__c` exists; **no approval workflow/UI** (manual status edit only) |
| **→ Lead** | ❌ **Missing** | **no candidate→Lead conversion service**; `Matched_Lead__c` is *dedup link* only; 0 candidates converted |
| Lead → Lead Enrichment | ✅ Implemented | enrichment v1.2 certified; USASpending writeback |
| → Campaign | ✅ Implemented | EDWOSB flow; 306 CampaignMembers |
| → Meeting | ⚠ Partial | booking pollers + 132 Events; meeting-tracking flow **Draft**; ERE resolves engagement |
| → Opportunity | ❌ Not started | **Opportunities = 0**; no meeting→Opp automation |
| → Customer | ❌ Not started | Accounts = 1; no Opp→Customer path |

**The chain is continuous from Source → Campaign except the one broken link: Approved Candidate → Lead.** The close half (Opportunity → Customer) is a separate future program.

## 4. Integration Gap Matrix (genuine gaps only — no invented work)
| # | Gap | Class | Business impact | Risk | Complexity | Priority |
|---|---|---|---|---|---|---|
| 1 | **Approved Candidate → Lead conversion bridge** | **Engineering** | **High** (connects acquisition→enrichment→campaign) | Med | Low–Med | **P1** |
| 2 | Candidate approval workflow/UI (list view, approve action, status governance) | Configuration/Ops | High | Low | Low | P2 |
| 3 | Acquisition review dashboards + monitoring | Operations | Med | Low | Low | P2 |
| 4 | Least-privilege runtime user (replace `oauser`/MAD) | Administration | Med (security) | High if automated | Low | P2 |
| 5 | SAM permset consolidation + credential hygiene | Configuration/Admin | Med | Low | Low | P2 |
| 6 | Org Matching/Duplicate rules (empty scaffolds) | Configuration | Med | Low | Low | P3 |
| 7 | Legacy connector dead-code (2 generations) | Engineering (cleanup) | Low | Low | Low | P3 (separate PR) |
| 8 | Meeting → Opportunity → Customer (close half) | Future (OI-adjacent) | High (long-term) | — | High | Deferred program |

## 5. KPI Framework (dashboard design only — no deployment)
**Executive:** Candidates Discovered · Approved Candidates · Candidate→Lead Conversion Rate · Lead Quality (completeness bands) · Enrichment Coverage % · Meetings Booked · Opportunities Created · Pipeline $.
**Operations:** Connector Health (`OA_Connector_Run__c` httpErrors/parseErrors) · Queue Health (async depth) · Review Queue aging (`Needs Review` count/age) · Exceptions (`OA_Enrichment_Exception__c`) · Fusion Success (fusionCount) · Duplicate Detection rate (skipped/matched) · Completeness Distribution · Callout Latency.
**Business Development:** by Federal Agency · Prime Contractors · by NAICS · UEI Coverage % · CAGE Coverage % · Award Recipients · Campaign Conversion · Meeting Conversion · Opportunity Conversion.
*Build path:* extend RC1 analytics (report-type → reports → dashboard, two-phase); source objects already exist (`OA_Discovered_Organization__c`, `OA_Connector_Run__c`, CampaignMember, Event). No new object required.

## 6. AI Governance Review
| AI-assisted component | Human approval | Automated | Dormant | Prod-ready | Notes |
|---|---|---|---|---|---|
| `OA_AISummaryService` / `OA_AISummaryQueueable` (proposal/summary) | ✅ required | ❌ | ✅ | ⚠ | generates summaries; no Lead write |
| `OA_ProposalAdapter` | ✅ | ❌ | ✅ | ⚠ | draft/adapter only |
| Candidate qualification (`OA_QualificationRuleEngine`) | ✅ (Needs Review) | ❌ | — | ✅ | rule-based, not generative; routes to review |
| Identity/fusion/completeness | n/a (deterministic) | n/a | — | ✅ | not AI; auditable |

**Verified:** no AI bypasses governance; **no AI writes production Leads automatically** (no candidate→Lead path exists at all); **no AI bypasses review** — all candidates land `Needs Review`; AI summary/proposal outputs are advisory and dormant.

## 7. Platform Reuse Review (Phase 4)
**Maximum reuse achieved on the core:** the candidate epic **reused** the pre-existing `OA_Discovered_Organization__c` object, the connector registry/runner, policy engine, telemetry, audit, and exception queue — **no duplicate object/field/CMDT created** for acquisition (net-new to main = 6 service classes only).
**Duplication found (legacy, dead — do not delete this sprint):** two connector generations coexist — legacy `OA_IConnector`/`OA_ConnectorEngine`/`OA_ConnectorHttp`/`OA_ConnectorPersistence` + legacy per-source (`OA_SAMConnector`/`OA_SAMRequest`/`OA_SAMParser`/`OA_SAMMapper`, `OA_USASpendingConnector`/`OA_USASpendingClient`) vs active `OA_IEnrichmentConnector`/`OA_ConnectorRunner` + `OA_SAM_Connector`/`OA_SAM_Request`/`OA_SAM_ResponseParser`. Legacy staging objects `OA_SAM_Entity_Staging__c`/`OA_USASpending_Staging__c` unused. → **track for a separate dead-code cleanup PR** (already in the debt register); reuse for all *new* work is confirmed.

## 8. Technical Debt (classified; non-code removed from engineering)
- **Engineering:** (a) **Candidate→Lead conversion bridge** (the one genuine gap); (b) legacy connector dead-code removal (separate PR); (c) optional NAICS/E2.
- **Configuration:** candidate approval action/list views; SAM permset consolidation + header hygiene; org Matching/Duplicate rules.
- **Administration:** least-privilege runtime user; retire `OA_SAM_Temp_Principal`; RC1 merges.
- **Operations:** acquisition dashboards; monitoring/alerting; review staffing; enqueue cadence.
- **Future:** Meeting→Opportunity→Customer (close half); additional sources; UEI↔CIK crosswalk; fusion field-precedence.

## 9. Platform Certification (Phase 7 — definitive)
- **Is Lead Acquisition complete?** **Yes for the discovery engine** (discover→dedup→identity→fusion→completeness→review, deployed + proven). Missing only the downstream **Candidate→Lead** bridge (a lifecycle-integration gap, not an acquisition-engine gap).
- **Is Lead Enrichment complete?** **Yes** — v1.2 prod-certified, operational.
- **Is the Candidate pipeline complete?** **Yes to Review; No to Lead** (conversion bridge missing).
- **Is the Review model complete?** **Functionally yes** (Needs Review + exception queue); **approval UX partial** (manual).
- **Is the Connector Framework complete?** **Yes** (active generation); legacy generation is redundant dead code.
- **Is the Monitoring Framework complete?** **Yes** (telemetry live, 18 runs); dashboards/alerting are operational add-ons.
- **Is the Audit Framework complete?** **Yes** (474 change logs; provenance in `Discovery_Metadata__c`).
- **What remains before business-development operations can begin?** The **Candidate→Lead conversion bridge** (P1 engineering) + candidate approval action (config) + least-privilege runtime user (admin) + acquisition dashboards (ops). None require new connectors or Opportunity Intelligence.

## 10. Readiness Scores
| Dimension | Score | Basis |
|---|---:|---|
| **Platform Readiness** | **74** | Source→Campaign complete + subsystems operational; Candidate→Lead + close-half missing |
| **Business Readiness** | 70 | Campaign live (306), enrichment certified; no candidate→Lead flow; 0 opportunities |
| **Engineering Readiness** | 84 | Core engines complete/tested/deployed; 1 real gap (conversion) + legacy dead-code |
| **Operations Readiness** | 62 | Telemetry/audit/ERE live; no acquisition dashboards; manual review; runtime-user risk |
| **Security Readiness** | 72 | No secrets, governance gating, review-before-Lead, EC safe; MAD runtime user + temp permset |

## 11. PASS / WARN / FAIL → 🟢 PASS (with 🟡 WARN)
Platform inventoried; lifecycle validated; genuine integration gaps identified; **no duplicate metadata created** (legacy dup is pre-existing, flagged); KPI framework designed; governance validated (no auto-Lead, no review bypass); debt classified; roadmap produced. **No production writes; no automation; no schedules; no merge; no new connectors.** **WARN:** one engineering lifecycle bridge (Candidate→Lead) is missing; close-half not started; least-privilege runtime user outstanding.

## 12. Roadmap (ranked by business value)
1. **Business Lifecycle Completion — Candidate→Lead conversion bridge** (P1 engineering): converts approved candidates into governed Leads (with dedup guard + provenance), connecting the two certified halves. Highest value, low-med complexity.
2. **Operational Dashboards** (acquisition KPIs + review): enables supervised operation at scale.
3. **Controlled Automation** (enqueue cadence, still gated): only after least-privilege user + hardening.
4. **Opportunity Intelligence** (Meeting→Opportunity, close half): separate gated program (ADR-015) — not now.
5. **Website Acquisition / Marketing Intelligence / Future Connectors**: future.

## 13. Recommended Next Program (exact)
**Business Lifecycle Completion — the Approved-Candidate → Lead conversion bridge.** It is the single genuine engineering integration gap, unblocks the end-to-end Source→Campaign→(pipeline) flow, reuses the existing candidate object + policy engine + writeback patterns (no new object/connector), and preserves review-before-Lead (conversion only on human approval, never automatic). Pair it with the candidate approval action (config) and, before any volume, the least-privilege runtime user (admin). **Do not** begin Opportunity Intelligence, add connectors, or enable automation/scheduling until this bridge and pre-volume hardening land.
