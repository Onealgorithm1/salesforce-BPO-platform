# Enterprise Knowledge Foundation — Program 021

**Org:** 00Dbn00000plgUfEAI · **Branch:** feature/enterprise-knowledge-foundation · **2026-07-09**
Builds on the certified AI Platform (019) and Opportunity Intelligence (020). Consumes `OA_AI_Gateway` only.

## 1. Purpose
Turn every organization into a **governed living intelligence profile** that continuously improves and that every future subsystem (Opportunity, Proposal, Capture, Partner, Executive, Meeting Intelligence) consumes. Reuse-first: identity/enrichment already exist; only the knowledge/AI layer is new.

## 2. Runtime audit (reuse review)
| Existing | Holds | Verdict |
|---|---|---|
| `OA_Discovered_Organization__c` | identity + enrichment + qualification (UEI, CAGE, NAICS, EIN, matched Account/Lead, confidence) | **REUSE** as identity source (linked) — not a knowledge profile |
| `Account` (One Algorithm, Medianow) | CRM company, **zero custom fields** | REUSE as CRM anchor (linked) |
| `OA_AI_Gateway` / request log | governed AI + telemetry | REUSE (all AI routes here) |
No existing object holds capabilities / past performance / certs / AI summaries / gaps → **new metadata justified**.

## 3. Architecture
```
Account  ─┐   (reused identity, no duplication)
OA_Discovered_Organization__c ─┤
                               ▼
   OA_Company_Profile__c  ── the canonical living profile (capabilities, tech, NAICS/PSC, socioeconomic,
        │                     certs, past performance, vehicles, prime/sub/teaming history, AI summary,
        │                     strengths/weaknesses/gaps, completeness, confidence, last-refresh)
        │  ◄── OA_KnowledgeIntelligence.profile(accountId): deterministic completeness + ONE gateway
        │        AI call (SUMMARY/STRENGTHS/WEAKNESSES/GAPS), grounded — never fabricates; upsert one/account
        │
        ├─►  consumed by OA_OpportunityIntelligence (Capability/Partner Match now data-driven)
        └─►  OA_Knowledge_Relationship__c  ── typed edges (Teaming/Prime/Sub/Customer/Competitor) between
                 profiles, optionally in an Opportunity context = the knowledge graph (standard lookups, no new tech)
```

## 4. Metadata review (every new item justified)
- **`OA_Company_Profile__c` (31 fields)** — the knowledge layer that does not exist anywhere; separate from Account so the profile can cover partners/primes/agencies that are not CRM Accounts and so AI narrative never pollutes CRM. Links to Account + Discovered Org (reuse).
- **`OA_Knowledge_Relationship__c` (7 fields)** — the relationship graph; a junction is the minimal correct pattern for many-to-many company relationships. Reuses standard lookups (no graph DB).
- **`OA_KnowledgeIntelligence`** — the AI service. **`OA_Knowledge_Foundation_Platform`** permset — FLS, least privilege, assigned.

## 5. Company Intelligence
Capabilities, Technology Stack, Industries, NAICS, PSC, Contract Vehicles, Socioeconomic Status, Certifications, Locations, Prime Experience, Agencies Served + AI Summary/Strengths/Weaknesses/Gaps + Completeness/Confidence/Last-Refresh. Deterministic completeness (9 knowledge dimensions) drives confidence; AI writes narrative only.

## 6. Partner Intelligence
Same object, `Profile_Type__c = Partner/Prime Contractor/Subcontractor`, plus Past Performance, Subcontract History, Teaming History, Relationship Strength, and AI Gaps. Partner-match feeds Opportunity Intelligence. `OA_Knowledge_Relationship__c` records teaming/prime/sub edges with strength + AI summary.

## 7. Document Intelligence (design)
Reuse Salesforce **Files (ContentDocument/ContentVersion)** linked to a profile — no new storage object. Design: `OA_Knowledge_Document__c` (thin) capturing Document_Type (Capability Statement/Resume/Past Performance/Technical Volume/Proposal Section), Company Profile lookup, AI_Summary (via gateway), Version, Opportunity link. Ingestion = gateway summary of extracted text → profile enrichment. Phased (not built this sprint): keeps the foundation lean.

## 8. AI Knowledge Services (all via gateway, logged)
`Knowledge_Company_Summary` — one structured call → Summary/Strengths/Weaknesses/Gaps. Extensible workflows (Partner Summary, Capability Summary, Past-Performance Summary, Relationship Summary, Document Summary) reuse the same pattern. Every call logs workflow/provider/model/tokens/cost/latency/status/failure. One gateway call per transaction (gateway logs after callout); bulk/batch = Queueable.

## 9. Relationship model (knowledge graph)
`OA_Knowledge_Relationship__c` connects Company Profiles to each other and to Opportunities with a typed, weighted, AI-summarized edge. Companies↔People (Contacts), Companies↔Opportunities (existing lookups), Companies↔Campaigns/Awards (future edges) — the platform can traverse "who relates to whom" without new technology.

## 10–11. Happy / Unhappy paths
**Happy:** build/refresh profile → completeness + confidence → grounded AI summary → consumed by OI (proven live: Capability Match 63.3 from Self profile). Curate knowledge → completeness rises → richer AI (proven: One Algorithm 0%→33%, Low→Medium).
**Unhappy:** missing documents/past performance/capabilities → low completeness, Low confidence, AI puts them under **GAPS** (never fabricates); duplicate companies → upsert one profile per Account; merged orgs → relationship edges + re-link; conflicting capabilities → human curation (Status/Reviewer); AI/gateway failure/budget → gateway non-success, narrative carries the reason, deterministic completeness still written, fallback retry — **nothing silent**.

## 12. Dashboards (design, report-ready)
Company Intelligence · Partner Intelligence · Capability Coverage · Knowledge Completeness (avg + distribution) · Document Coverage · Relationship Strength · AI Knowledge Usage (cost/tokens by workflow) · Knowledge Confidence. Objects are reportable + history-tracked; Lightning build is the remaining UI step.

## 13. Production pilot
- **One Algorithm LLC (Self):** 0%→**33.3%** completeness (Low→Medium) after curating EDWOSB + capabilities + tech stack; AI summary now grounded ("EDWOSB specializing in AI-assisted BPO, Salesforce engineering, federal BD").
- **Medianow, INC. (Partner):** profile created, AI honestly flags missing NAICS/capabilities/past performance under GAPS.
- **OI consumption (proven):** Medianow assessment Capability Match **63.3** (from Self profile completeness) + Partner Match 45.0 (from partner profile) — cited in Score_Rationale; AI gap narrative grounded in EDWOSB status.
- AI via **OpenRouter** gpt-4o-mini, ~480–544 tok/profile, logged (retry=0). Accounts unchanged.

## Debt / next
Document Intelligence object + Files ingestion; Lightning dashboards; async Queueable for bulk profiling; relationship-edge auto-suggestion; partner-match from capability *overlap* (not just completeness); knowledge freshness/decay policy.
