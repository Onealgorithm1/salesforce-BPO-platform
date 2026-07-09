# Enterprise Opportunity Intelligence — Program 020

**Org:** 00Dbn00000plgUfEAI · **Branch:** feature/enterprise-opportunity-intelligence · **2026-07-09**
Builds on the certified AI Platform (Program 019) and the OI charter/governance ADR-015…019 (esp. ADR-018 human gates).

## 1. Purpose & boundary
Turns a CRM `Opportunity` into a **governed, explainable pursuit assessment**: deterministic scores + AI narrative + a recommended action, for a human to decide on. It **recommends; it never acts**. Distinct from the earlier OI *ingestion* pipeline (`OA_Opportunity_Signal__c`, external solicitations) — this is decision-support on Opportunities already in the CRM.

## 2. Architecture
```
Opportunity (+ Account, Campaign, CampaignMember, ContactRole, Event, Task lineage)  ── read-only ──►
   OA_OpportunityIntelligence.generate(oppId)
        ├─ deterministic scores (0-100, auditable; AI never sets them)   → Score_Rationale__c
        ├─ ONE OA_AI_Gateway.complete() call  (OpenRouter default, Anthropic fallback; logged)
        │        → parsed into Brief / NBA / Gap / Partner / Risk
        └─ INSERT one OA_Opportunity_Intelligence__c  (Status = Draft)   ── human reviews ──► decision
   NEVER writes Opportunity/Account/Campaign · no trigger · manual/queued invocation only
```
- **Inputs:** Opportunity + lineage (source, stage, probability, close date, amount, campaign engagement, meetings, tasks, contact roles).
- **Outputs:** one `OA_Opportunity_Intelligence__c` (scorecard + AI narrative + telemetry), Status `Draft`.
- **Failure paths:** gateway failure → narrative field carries `[AI unavailable: <reason>]`, scores still computed, record still written (nothing silent); missing Opportunity → `OIException`.

## 3. Intelligence Scorecard (deterministic; 0-100)
| Score | Definition | Inputs | AI? | Override |
|---|---|---|---|---|
| Source Quality | trust of the origin | LeadSource (SAM.gov/Grants.gov=88) | no | human via Status/Notes |
| Campaign Signal | outreach traction | campaign link, meetings booked, responders | no | " |
| Meeting Signal | engagement depth | Event + Task counts | no | " |
| Relationship Strength | account footprint | contact roles, events, account | no | " |
| Win Probability | likelihood | native Probability + relationship + campaign | no | " |
| Urgency | time pressure | close-date proximity, stage | no | " |
| Capability / Partner Match | fit (conservative until partner KB exists) | teaming/source heuristic | no | " |
| Risk | downside | data incompleteness, missing contact role/amount/meetings | no | " |
| Pursuit Fit | weighted fit | source .30, campaign .25, rel .20, meeting .15, capability .10 | no | " |
| **Composite** | overall | pursuitFit .45, win .25, urgency .15, inverse-risk .15 | no | " |
| Data Completeness / Confidence | trust of the assessment | key-field coverage | no | " |
| Recommended Action | Pursue Now / Nurture / Qualify Further / Deprioritize / Escalate | composite, urgency, completeness, risk | no | " |
Every score's derivation is written to `Score_Rationale__c` for audit. **AI writes only the narrative (Brief, NBA, Gap, Partner, Risk); it never sets a number** — this keeps the scoring auditable and deterministic (ADR-011 "no AI decisioning v1").

## 4. Company / Partner Knowledge Foundation — phased (do not overbuild)
Today `Account` has **no custom fields** and partner capability data is unstructured. Phased design:
- **P1 (now):** consume what exists (Account, `OA_Discovered_Organization__c` enrichment, lineage); AI narrative names capability/partner *gaps* explicitly rather than fabricating a profile.
- **P2 (next):** a lightweight `OA_Company_Profile__c` (capabilities, NAICS/PSC, certifications, past performance, vehicles, agencies, strengths/gaps, confidence, last-updated) populated from enrichment + human curation — reused by both OI scoring and proposal readiness.
- **P3:** partner-match scoring driven by the profile (replaces today's conservative heuristic).

## 5. AI workflows implemented (all via OA_AI_Gateway, all logged)
`Opportunity_Intelligence` — one structured call producing Executive Brief, Next Best Action, Capability Gap, Partner Recommendation, Risk Assessment. Logged: workflow, provider, model, tokens, cost, latency, record, status, failure reason. (One call per transaction because the gateway logs after its callout — batching future multi-call workflows requires async/Queueable, noted as debt.)

## 6. Human governance (ADR-018 preserved)
AI may score, summarize, recommend. AI may **not** autonomously create Opportunities, move stages, commit pricing, assign partners, change forecast, or send external mail. The engine writes only `Status='Draft'`; Reviewed/Approved/Dismissed are human transitions. Gates: high-value pursuit, partner recommendation, proposal readiness, stage movement, AI strategy — all human.

## 7–8. Happy / Unhappy paths
**Happy (per source):** Lead / Campaign / Meeting / Partner / Solicitation / Existing-customer / Federal-subcontract / Prime-teaming → same flow (gather lineage → score → AI narrative → Draft → human decision → optional human Salesforce update → dashboard). Pilot proved the Solicitation/Teaming path (Medianow, SAM.gov).
**Unhappy:** insufficient/low data → low Data Completeness + Confidence, action `Qualify Further`; missing contact role/amount/meetings → higher Risk; weak fit → `Deprioritize`; high risk → `Escalate to Human`; AI timeout/model failure/budget → gateway returns non-success, narrative carries the reason, scores still produced, retry via fallback (retry=1) — **nothing silent**; duplicate/stale → one record per generation (dedupe/refresh policy = debt).

## 9. Dashboards / KPIs (report-ready on OA_Opportunity_Intelligence__c)
Executive Intelligence · Opportunity Priority (by Composite) · Win Probability · Partner Fit · Capability Gap · AI Cost by Opportunity (AI_Estimated_Cost__c) · Recommendation Acceptance (Status transitions) · Next-Best-Action queue (Status=Draft). KPIs: top pursuits, highest win prob, largest gaps, best partner matches, most urgent actions, AI spend/opportunity, acceptance rate. Object is reportable + history-tracked; Lightning dashboard build is the remaining UI step.

## 10. Pilot result (Medianow, 006Pn00001H86luIAB)
Composite 55.6 · Pursuit Fit 64.1 · Source 88 · Win 28.2 · Risk 23.4 · Completeness 83% · Confidence High · **Action: Nurture**. AI via **OpenRouter** gpt-4o-mini, 825 tok, $0.00165, logged (retry=0). Executive brief + 3-step next best action grounded in real data. Opportunity unchanged.

## Debt
Partner knowledge base (P2/P3); multi-call async workflow (Queueable) to exceed the one-callout-then-log limit; dedupe/refresh policy; Lightning dashboards; budget *enforcement* (spend logged, not gated).
