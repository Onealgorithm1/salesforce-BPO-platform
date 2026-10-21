# Business Development Operations — Opportunity Governance & Revenue Pipeline

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/business-development-operations`
**Mode:** engineering · runtime certification · business operations · governance. **Standard Salesforce Opportunity (reuse); no new objects/fields/record types/validation rules/Apex/flows; no AI; no automation; no scheduling; no merge; no production changes.**

---

## 1. Executive Summary
The standard Salesforce Opportunity is now framed as the **One Algorithm Business Development Operating Model** — **entirely reuse-first, no new metadata, no AI.** Live audit shows a **single BD motion** (Federal EDWOSB Teaming/Subcontracting, SAM.gov-sourced) and a vanilla Opportunity (0 custom fields, 0 record types, 0 validation rules/triggers/flows). Per governance, **no record types and no custom Opportunity fields are created** — segmentation reuses Lead lineage + Campaign + the standard `Type` field. Delivered: stage governance, pipeline-hygiene controls (warn/report, not block), dashboards, and **measurable funnel KPIs** (Candidate→Lead 16%, Lead→Meeting 0.3%, Meeting→Opportunity 100%, Opportunity→Won 0%). **Verdict: 🟢 PASS.**

## 2. Business Development Audit (Phase 0)
| Market/motion | Evidence | Verdict |
|---|---|---|
| **Federal EDWOSB Teaming/Subcontracting** | the 1 Opp "Medianow, INC. - EDWOSB Teaming Opportunity", LeadSource **SAM.gov**, Campaign "EDWOSB Teaming Outreach - Prime Subcontract" | **the active motion** |
| Commercial / Education / Healthcare / Enterprise | none in production | not active |
| Prime vs Subcontract | teaming/prime-subcontract (EDWOSB set-aside) | single lane |
**Opportunity custom fields:** **none.** **Record types:** **0.** **Type values in use:** null (1 Opp).
**Decision:** **Do NOT create Opportunity record types or custom fields** — one motion, one Opportunity; not justified (would duplicate Lead's `Primary_NAICS_code__c`/`USASpending_Awarding_Agency__c`/`Federal_Contractor__c`/certifications). Segment via **Lead lineage** (`ConvertedOpportunityId`), **Campaign**, and standard **`Opportunity.Type`** if/when a 2nd motion appears.

## 3. Opportunity Governance (Phase 1)
| Stage | Purpose | Entry | Exit | Required fields | Meetings | Approvals | Owner | Duration | Success | Failure | Audit |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Prospecting** | new pipeline | qualified Lead converted | fit confirmed | Name/Stage/CloseDate (+Amount, next step) | intro/discovery held | — | BD | ~1–2 wk | advances to Qualification | no response → Closed Lost | field history |
| Qualification | confirm fit + authority | discovery done | scope agreed | Amount, Contact Role | qualification call | — | BD | ~1–2 wk | to Needs Analysis | disqualified | history |
| Needs Analysis / Discovery | requirements | scope agreed | solution defined | notes, contact roles | working session | — | BD | ~2 wk | to Proposal | no fit | history |
| Value Proposition / Proposal | proposal issued | solution defined | proposal accepted-in-principle | Amount, proposal doc | proposal review | (opt.) | BD | ~2–4 wk | to Negotiation | rejected | history |
| Negotiation/Review | terms | proposal accepted | terms agreed | firm Amount + CloseDate | — | **close approval (>threshold)** | BD/Exec | ~1–3 wk | to Closed Won | walk away | history |
| **Closed Won** | customer | terms agreed | signed | Amount, Contact Role | — | exec sign-off | Exec | — | revenue booked | — | history (no silent reopen) |
| **Closed Lost** | lost | any stage | — | **loss reason** | — | — | BD | — | learnings captured | — | history |
**Governance:** stage advancement = **human sales judgment**; reopen = Closed→open (audited); every change field-history-audited; approvals only at Negotiation/Close (optional, above a value threshold).

## 4. Pipeline Hygiene (Phase 2) — warn / report / block classification
| Control | Class | Rationale |
|---|---|---|
| Missing Amount | **Warn/Report** | forecasting readiness; don't block early stages |
| Missing Next Step | **Warn/Report** | activity discipline |
| Missing Contact Role | **Warn** (Report) | decision-maker linkage (Medianow has 1) |
| Missing Meeting | **Report** | pipeline basis (Medianow has 1 Event) |
| Past-Due Close Date | **Warn** | hygiene |
| No Activity (stale) | **Report** | aging pipeline |
| Inactive Owner | **Report** | coverage |
| Duplicate Opportunity | **Warn** (pre-create check) | double-count |
| Missing Campaign | **Report** | attribution (Medianow linked) |
| Missing Prime/Agency/NAICS/Contract Vehicle | **Report via lineage** | **not Opp fields** — derive from converted Lead; do not add fields |
**None BLOCK today** — blocking needs validation rules (new metadata) against a **human** sales process with only 1 Opp; premature. Hygiene is delivered as **monitor + dashboards** (warn/report). Blocking is a future governance decision at volume.

## 5. Dashboard Matrix (Phase 3 — reuse-first)
| Tier | Dashboards | Source |
|---|---|---|
| Executive | Revenue Pipeline, Forecast, Pipeline Velocity, Win Rate, Pipeline by Market/Certification/Partner | Opportunity + `opp_pipeline_monitor` |
| Business Development | Federal/State/Commercial, Prime Contractors, Teaming Partners, Agency Pipeline, Certification Pipeline, **EDWOSB utilization** | Opp + Lead lineage + Campaign |
| Operations | Stale Opps, Missing Activities/Meetings/Contact Roles, Pipeline Age, Conversion Funnel | monitors |
| Compliance | Manual Overrides, Approval History, Stage History, Audit Trail, Rollback History | field history + change log |
Reuse `Pipeline By Close Month`, `Funnel By Campaign`, `Meeting Booked`, `Daily Funnel Trend`; add an Opportunity-by-stage report. Build at volume; monitors cover now.

## 6. KPI Matrix (Phase 4 — live values; each answers a business question)
| KPI | Question | Live value |
|---|---|---|
| **Candidate→Lead %** | acquisition→pipeline yield | **16% (1/6)** |
| **Lead→Meeting %** | outreach effectiveness | **0.3% (1/356)** |
| **Meeting→Opportunity %** | qualification→pipeline | **100% (1/1)** |
| **Opportunity→Customer %** | close rate | **0% (0/1)** |
| Avg Days to Meeting / to Opportunity | velocity | (compute from dates as volume grows) |
| Pipeline Velocity | throughput | n/a (1 Opp) |
| Meeting Success / No-show Rate | meeting quality | 1 held, 1 no-show (Stragistics) |
| Campaign ROI | campaign→Opp | EDWOSB → 1 Opp |
| Partner/Agency/Federal Win Rate | segment performance | n/a (0 won) |
| Certification (EDWOSB) Utilization | set-aside leverage | 1 EDWOSB Opp |
Delivered via `bd_kpi_monitor.apex` (0-DML). Small numbers = early pipeline; the framework scales.

## 7. Happy Path Matrix (Phase 5)
Federal/Teaming/Subcontract/Prime opportunity → Prospecting→…→Closed Won (Medianow on this path); expansion/renewal (new Opp on Account); reopen (Closed→open, audited). All standard.

## 8. Unhappy Path Matrix (Phase 5)
| Path | Detection | Recovery | Audit | Notification | Impact |
|---|---|---|---|---|---|
| Lost opportunity | Closed Lost | reopen if revived | history | BD | learnings |
| Withdrawn/Cancelled | stage/no activity | Closed Lost + reason | history | ops | remove from forecast |
| Duplicate opportunity | pre-create open-Opp check | link/skip | history | ops | double-count |
| Reopened | Closed→open | governance review | history | exec | forecast change |
| Missing meeting/contact/amount | monitor hygiene | owner adds | monitor | owner | weak deal |
| Campaign mismatch | ERE/MRE attribution | re-link | change log | ops | wrong ROI |
**Nothing fails silently** — monitors + field history + ERE/MRE lineage.

## 9. Components Implemented (Phase 6 — reuse-first)
- `scripts/apex/bd_kpi_monitor.apex` (**new**, funnel KPIs) + reused `opp_pipeline_monitor.apex` + `cmo_pipeline_monitoring.apex`. **No new Salesforce metadata; standard Opportunity + existing objects only.** Not overengineered; no record types/fields/validation rules created.

## 10. Validation Results (Phase 7 — live)
KPIs computed live (Cand→Lead 16%, Lead→Meeting 0.3%, Meeting→Opp 100%, Opp→Won 0%); 1 Opp (Prospecting, EDWOSB, SAM.gov, Campaign-linked, 1 Contact Role, 1 meeting); 0 Opp custom fields/record types/rules. Monitors 0 DML. No tests/flows/Apex/permsets changed; no automation/schedules.

## 11–13. Production Changes / Risks / Rollback
- **Production changes:** **none** (read-only cert + monitor scripts; no records, fields, or metadata created). Deploy/Validation IDs: n/a.
- **Risks:** governance is documentation + monitors (not enforced by validation rules) — acceptable at 1-Opp volume; enforce at scale [Low]. Single-motion model — revisit record types/`Type` when a 2nd market appears [Low].
- **Rollback:** n/a (no changes).

## 14. Technical Debt
- At volume: consider `Opportunity.Type` values + optional validation rules (block-tier hygiene); Opportunity-by-stage/market dashboards.
- Owner enrichment (Amount, next step, close date) on Medianow.
- Resolve 3 Needs-Review meetings → convert more (gated).
- No new engineering debt (standard + monitors only).

## 15. PASS / WARN / FAIL — 🟢 PASS
The platform now contains a **fully governed Business Development Operating Model on standard Salesforce Opportunity**: stage governance defined, hygiene controls classified (warn/report), dashboards specified, KPIs measurable (live), happy/unhappy paths engineered, nothing fails silently — **no AI, no predictive scoring, no new metadata, no production changes.**

## 16–17. Commit / PR
See closeout — new branch/PR; not merged.

## 18. Definition of Done — MET
BD audit complete; governance + hygiene + dashboards + KPIs + paths documented; KPI/hygiene monitors built (reuse); record types/fields correctly **not** created; validated live. **Business Development Operations engineering COMPLETE.**

## 19. Readiness Assessment
The operational foundation is complete and governed. The platform **knows** how opportunities progress (stage governance), who owns each stage, what evidence/meetings/approvals are required, what dashboards measure success, and what KPIs define pipeline health — all on standard Salesforce. **Ready to support AI (Opportunity Intelligence) as a consuming layer** without further operational engineering.

## 20. Exact Next Engineering Program
**Opportunity Intelligence** (ADR-015…019) — predictive win-scoring, next-best-action, forecasting AI **on this governed operational foundation** — begins only with explicit approval. It consumes the stages, KPIs, hygiene signals, and lineage defined here. Interim (no new program): owner enriches the Medianow Opp; resolve the 3 Needs-Review meetings and convert more prospects (gated). BLO stays closed.
