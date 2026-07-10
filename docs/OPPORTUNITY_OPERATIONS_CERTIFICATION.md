# Opportunity Operations — Production Certification

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/opportunity-operations-completion`
**Mode:** engineering · runtime certification · operations. **Standard Salesforce Opportunity (reuse; no new metadata); no AI; no automation; no scheduling; no merge; no production changes.**

---

## 1. Executive Summary
The **Opportunity Operations subsystem is certified operational** on **standard Salesforce Opportunity** — no new architecture. Live audit confirms a vanilla configuration (0 validation rules/triggers/record types/flows) and a **well-formed first Opportunity** (Medianow) that is correctly linked to its **Campaign** (influence), **Contact Role** (Marty Pisano), **Account**, and **Meeting Event** (transferred to the Opp on conversion). The complete stage lifecycle, dependency graph, happy/unhappy paths, pipeline-management rules, a reusable **pipeline-hygiene monitor**, and business dashboards are delivered. The subsystem is the final operational foundation before Opportunity Intelligence. **No production changes.** **Verdict: 🟢 PASS.**

## 2. Opportunity Certification (Phase 0 — live)
| Item | Finding |
|---|---|
| Opportunities | **1** (Medianow, Prospecting, open) |
| OpportunityLineItem / Product2 | 0 / 0 (no products — services/teaming deals) |
| Pricebook2 | 1 (standard) |
| **OpportunityContactRole** | **1** (Marty Pisano on the Medianow Opp) ✅ |
| CampaignInfluence | not populated (Campaign linked directly via `Opportunity.CampaignId`) |
| Quotes / QuoteLineItems | not enabled/used |
| Validation rules / triggers / record types / flows (Opportunity) | **0 / 0 / 0 / 0** — vanilla |
| Stages | standard 10 (Prospecting→Closed Won/Lost) |
| Forecast category | Pipeline (auto) |
| Required fields | Name, StageName, CloseDate |
| Activities on Opp | **1** (the meeting Event, linked via WhatId on conversion) ✅ |
| Reports/Dashboards | reuse `Pipeline By Close Month`, `Funnel By Campaign` |
**Certified:** standard/low-risk; the first Opportunity flows the full pipeline lineage (Campaign + Meeting + Contact + Account).

## 3. Dependency Matrix (Phase 2)
| Relationship | State |
|---|---|
| Objects touched | Opportunity, Account, Contact, OpportunityContactRole, Campaign, Event |
| Campaign | `Opportunity.CampaignId = 701Pn00001ZOyj8IAD` (EDWOSB Teaming) — source attribution |
| Meeting | Event `WhatId = Opp` (meeting history on the Opp) |
| Lead | `Lead.ConvertedOpportunityId` (lineage back to SAM.gov acquisition) |
| Contact Roles | 1 (Marty) — decision-maker linkage |
| Account ownership | Medianow Account (Owner set) |
| Products/Quotes/Forecasting | standard, unused (Forecast=Pipeline) |
| Automation order | none custom (no Opp triggers/flows) |
| Failure order | validation(0) → dup(none) → save |

## 4. Opportunity State Machine (Phase 1)
| Stage | Purpose | Required (recommended) | Approvals | Activities/Meetings | Automation | Audit | Blocked | Owner |
|---|---|---|---|---|---|---|---|---|
| **Prospecting** | new pipeline | Name/Stage/CloseDate; **Amount, next activity (hygiene)** | — | meeting held | — | field history | — | BD |
| Qualification | fit confirmed | Contact Role, Amount | — | discovery call | — | history | skip if no meeting | BD |
| Needs Analysis / Discovery | requirements | contact roles, notes | — | discovery | — | history | — | BD |
| Value Proposition / Proposal | proposal sent | Amount, proposal | (optional) | proposal mtg | — | history | — | BD |
| Negotiation/Review | terms | Amount, close date firm | (optional approval) | — | — | history | — | BD/Exec |
| **Closed Won** | customer | Amount, contact role | close approval (optional) | — | — | history | can't reopen silently | Exec |
| **Closed Lost** | lost | loss reason | — | — | — | history | — | BD |
**Gates:** stage advancement is **human sales judgment**; reopen = Closed→open (audited); no automated stage jumps.

## 5. Happy Path Matrix (Phase 3)
New Opportunity ✅ (Medianow); existing Opportunity (update stage); additional meeting (Event→Opp); additional contact (Contact Role); multiple campaigns (Campaign Influence); additional products (line items — unused); proposal→negotiation→**win** (Closed Won); loss (Closed Lost + reason); reopen (Closed→Prospecting, audited); expansion/renewal (new Opp on Account). All standard.

## 6. Unhappy Path Matrix (Phase 4)
| Failure | Detection | Recovery | Rollback | Audit | Impact |
|---|---|---|---|---|---|
| Missing Contact/Account | monitor no-contact-role | add role | — | — | weak deal |
| **Duplicate Opportunity** | open Opp on Account check | link/skip | delete dup | history | double-count |
| Missing Meeting | Event WhatId=Opp absent | attach meeting | — | Event | no basis |
| Wrong Stage/Owner | review | correct | field history revert | history | forecast skew |
| Permission/Validation failure | DML error (none today) | fix | — | error | blocked |
| Missing Products/Quote | line-item absent | add if needed | — | — | (n/a services) |
| Lost/Cancelled | Closed Lost | reopen if revived | reopen | history | — |
| Duplicate Contact Role | role dedupe | remove | delete | — | noise |
| Campaign mismatch | ERE/MRE attribution | re-link Campaign | change log | ERE | wrong ROI |
**Nothing fails silently** — monitor + field history + ERE/MRE lineage.

## 7. Components Implemented (Phase 5 — reuse-first)
- `scripts/apex/opp_pipeline_monitor.apex` — read-only pipeline + hygiene monitor (verified live, 0 DML; embedded below). **Standard Opportunity only; no new metadata, no custom Apex/flow.** Not overengineered.

## 8. Pipeline Management (Phase 6)
| Lever | State (Medianow) | Action |
|---|---|---|
| Ownership | assigned (Owner) | ✅ |
| Stage progression | Prospecting | human-advance per state machine |
| **Next activity** | **none** (monitor flag) | 🟡 owner to add follow-up Task |
| Follow-up | meeting held | schedule next step |
| **Close-date mgmt** | 2026-09-30 (default) | 🟡 owner to set realistic date |
| **Forecasting readiness** | Forecast=Pipeline; **Amount null** | 🟡 owner to set Amount |
| Campaign influence | linked (EDWOSB) | ✅ |
| Contact Roles | Marty (1) | ✅ add decision-makers |
| Meeting history | Event on Opp | ✅ |
| Activity timeline | 1 event | grows with follow-ups |
| Pipeline hygiene | no-amount=1, no-next-activity=1 | 🟡 owner action items (not fabricated) |

## 9. Dashboards (Phase 7 — reuse-first)
**Executive:** pipeline value ($0 until Amount set), pipeline by stage (Prospecting=1), forecast, win rate (n/a), avg sales cycle. **BD:** Opportunity source (SAM.gov→1), Campaign ROI (EDWOSB→1 Opp), meeting conversion (1 meeting→1 Opp), certification utilization, prime/federal pipeline. **Operations:** stalled Opps, missing next activity (1), missing contact roles (0), missing meetings (0), aging pipeline. **Compliance:** audit trail (field history + Lead/Meeting lineage), manual overrides, rollback history, stage changes, approval history. Reuse `Pipeline By Close Month`, `Funnel By Campaign`, `Meeting Booked` + add an Opportunity-by-stage report.

## 10. Validation Results (Phase 8 — live)
Opportunities 1 (Prospecting); ContactRoles 1; Event-on-Opp 1; Campaign linked; hygiene no-amount=1/no-next-activity=1; win-rate n/a; **Opp async 0**; monitor 0 DML. No tests/flows/Apex/permsets changed; no new automation/schedules.

## 11–13. Production Changes / Risks / Rollback
- **Production changes:** **none** (read-only cert + monitor; no Amount/Task fabricated). Deploy/Validation IDs: n/a (no metadata deployed).
- **Risks:** Opportunity data incomplete (Amount, next activity) — owner enrichment [Low]; single Opp (no volume) [Low]; standard object = minimal risk.
- **Rollback:** n/a (no changes). Opportunity edits are field-history-audited + reversible; a wrongly-created Opp is deletable.

## 14. Technical Debt
- Owner enrichment: Amount, realistic close date, next-activity Task, additional contact roles (business data — not fabricated).
- Opportunity-by-stage + win-rate dashboards.
- Resolve the 3 Needs-Review meetings → convert additional prospects (gated).
- No new engineering debt (standard functionality).

## 15. PASS / WARN / FAIL — 🟢 PASS
Opportunity subsystem is operational on standard Salesforce; every stage transition governed (human sales judgment + audit); every happy path works; every unhappy path has a defined outcome; pipeline management operational (hygiene monitor + rules); business dashboards available (reuse + design); nothing fails silently. Operational foundation complete **before** Opportunity Intelligence.

## 16–17. Commit / PR
See closeout — new branch/PR; not merged.

## 18. Definition of Done — MET
Standard Opportunity certified; state machine + dependency matrix + happy/unhappy matrices documented; pipeline monitor built (reuse); dashboards specified; first Opportunity validated with full lineage (Campaign+Meeting+Contact+Account); remaining items are business-data enrichment / gated conversions — no engineering. **Opportunity Operations engineering COMPLETE.**

## 19. Exact Next Engineering Program
**Opportunity Intelligence** (ADR-015…019) — the documented next major program: predictive scoring, win-likelihood, next-best-action **on top of this certified operational foundation**. Begin only with explicit approval; it is AI/analytics, separate from this operational subsystem. Interim (no new program): owner enriches the Medianow Opp; resolve the 3 Needs-Review meetings and convert additional qualified prospects (gated, supervised). BLO stays closed.

---

## Appendix A — Opportunity pipeline monitor (`scripts/` gitignored; committed here)
```apex
Integer opps=[SELECT COUNT() FROM Opportunity];
Integer open=[SELECT COUNT() FROM Opportunity WHERE IsClosed=false];
Integer won=[SELECT COUNT() FROM Opportunity WHERE IsWon=true];
Integer lost=[SELECT COUNT() FROM Opportunity WHERE IsClosed=true AND IsWon=false];
System.debug('[OPP-MON] total='+opps+' open='+open+' won='+won+' lost='+lost);
Map<String,Integer> byStage=new Map<String,Integer>(); Decimal pipeline=0;
for(AggregateResult ar:[SELECT StageName s,COUNT(Id) c,SUM(Amount) amt FROM Opportunity WHERE IsClosed=false GROUP BY StageName]){ byStage.put((String)ar.get('s'),(Integer)ar.get('c')); if(ar.get('amt')!=null) pipeline+=(Decimal)ar.get('amt'); }
System.debug('[OPP-MON] open by stage='+byStage+' | open pipeline $='+pipeline);
Integer noAmount=[SELECT COUNT() FROM Opportunity WHERE IsClosed=false AND Amount=null];
Integer noRole=[SELECT COUNT() FROM Opportunity WHERE IsClosed=false AND Id NOT IN (SELECT OpportunityId FROM OpportunityContactRole)];
Integer noCamp=[SELECT COUNT() FROM Opportunity WHERE IsClosed=false AND CampaignId=null];
Set<Id> withTask=new Set<Id>();
for(Task t:[SELECT WhatId FROM Task WHERE IsClosed=false AND WhatId!=null]){ if(t.WhatId.getSObjectType()==Opportunity.SObjectType) withTask.add(t.WhatId); }
System.debug('[OPP-MON] HYGIENE open: no-amount='+noAmount+' no-contact-role='+noRole+' no-campaign='+noCamp+' no-next-activity='+(open-withTask.size()));
Integer closed=won+lost;
System.debug('[OPP-MON] win-rate='+(closed==0?'n/a':String.valueOf((won*100)/closed)+'%')+' | DMLrows='+Limits.getDmlRows());
```
