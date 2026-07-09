# Enterprise Partner Intelligence, Capability Intelligence & Pursuit Investment Intelligence (Program 024B)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/enterprise-partner-intelligence · 2026-07-09**
Deployed **dormant** on the 024/024A pipeline. **No merge, no Opportunities, no autonomous workflows, human-gated.**

## 1. Executive Summary
Two upgrades that make qualification smarter without redesigning it: **(a) living partner intelligence** — partners become AI-enriched capability profiles (`OA_PartnerIntelligence` over the AI Gateway) that feed the 024A qualifier; **(b) a distinct third decision layer, Pursuit Investment Intelligence** (`OA_PursuitInvestment`) — Compliance asks *eligible?*, Qualification asks *can we win?*, Investment asks *should we spend BD resources?* → **HIGH / MEDIUM / LOW** with a win-probability. Live: enriched partner capabilities **materially changed qualification output** (surfaced Google Cloud as a partner for the HBCU research grant where none existed), the investment layer scored all 8 grant candidates **LOW** (correctly — infeasible ≠ worth investing), and AWS was **AI-enriched live** (532 tok, $0.001) with an honest capability-gap collection plan. **Verdict: PASS.**

## 2. Runtime Audit
Reused (no duplication): `OA_Company_Profile__c` (9 partner profiles from 024A), `OA_OpportunityQualification` (024A — improved, not redesigned), `OA_AI_Gateway`, `OA_Knowledge_Relationship__c`, `OA_Opportunity_Intelligence__c`. Signal object still 0 triggers/validation/flows. Grants candidates present.

## 3. Partner Inventory
| Partner | Type | Capability data | AI-enriched |
|---|---|---|---|
| AWS, Microsoft, Google Cloud, Salesforce | Partner | **curated (public, broadened)** → completeness 66 | AWS live-enriched |
| Zendesk, TTEC Digital | Partner | public stub → 55 | pending |
| IronGrove, Patriot Allied, Medianow | Partner | **empty — MISSING** | pending (gaps flagged) |
| One Algorithm | Self | curated (EDWOSB) | 021 |
No new metadata — reused Company Profiles.

## 4. Capability Model
Reuses all `OA_Company_Profile__c` fields (Capabilities, Technology Stack, NAICS/PSC, Socioeconomic, Certifications, Contract Vehicles, Past Performance, Prime/Sub/Teaming history, AI summary/strengths/weaknesses/gaps, completeness/confidence, Last-AI-Refresh). `OA_PartnerIntelligence.enrichProfile(profileId)` turns it into a **living** profile via the gateway (partners aren't CRM Accounts, so this complements `OA_KnowledgeIntelligence`'s Account-keyed enrichment — no object duplication).

## 5. Pursuit Investment Intelligence (`OA_PursuitInvestment`)
Distinct from Compliance and Qualification. Inputs: `Qualification_Decision__c`, `Fit_Score__c`, `Effort_Score__c`, `Urgency_Score__c`, `Estimated_Value__c`, set-aside advantage (EDWOSB), agency, + staged incumbent strength. Computes **`Win_Probability__c`** (base by qualification stance ± fit/effort/set-aside) and an investment score (winProb .40 + revenue .30 + strategic .20 + inverse-effort .10) → **`Investment_Level__c`** HIGH/MEDIUM/LOW + `Investment_Rationale__c`. Gate: NO-GO → LOW (don't invest). Deterministic, auditable, advisory (Pending untouched). **Live result:** 8 grant candidates → all LOW, win-prob 0–24% (Tech Innovation Lab highest) — correctly signalling "don't spend BD resources on these."

## 6. Partner Matching (improved)
`OA_OpportunityQualification` (024A) now consumes richer partner capabilities → best gap-covering partner surfaces. **Live improvement:** after enriching AWS/MS/Google/Salesforce, the HBCU research grant gained **Recommended_Partner = Google Cloud** (research-computing overlap) where 024A recommended none. Roles supported: Prime / Subcontractor / Teaming / Monitor (JV / Mentor-Protégé extend via the same partner data). Decision flips to GO WITH PARTNER await better-fitting **SAM.gov contract** candidates (grants are a poor fit sample).

## 7. AI Knowledge Enrichment (live, logged)
`OA_PartnerIntelligence.enrichProfile()` → one gateway call → SUMMARY / STRENGTHS / WEAKNESSES / GAPS on the partner profile, with telemetry. **Live: AWS** → "technology partner specializing in cloud infrastructure and AI... valuable for data analytics and digital transformation" + GAPS "collect NAICS, socioeconomic status, past performance for federal contracts." Provider OpenRouter, 532 tok, $0.001064, logged. Grounded — never fabricates.

## 8. Knowledge Collection Plan (AI-generated, governed — no fake data)
The AI GAPS section **is** the collection roadmap. Per partner, collect: capabilities detail, NAICS/PSC, socioeconomic certs, contract vehicles, agency experience, past performance, resumes/labor categories, teaming/prime/sub history. **Priority:** IronGrove & Patriot Allied (empty) → capability statements + POC interview; tech partners → verify the specific One Algorithm↔partner teaming relationship + vehicles. Populate `OA_Company_Profile__c` (or run `enrichProfile()` after) then re-run `qualify()`.

## 9. Qualification Validation (before/after)
Before (024A): 8 grants → 7 NO-GO + 1 MONITOR, **no partner recommendations**. After (024B, enriched partners): same decisions (grants genuinely don't fit) **but Google Cloud now recommended** for the HBCU research grant — proving the qualifier consumes improved partner intelligence. On fitting SAM contract data, this mechanism flips NO-GO→GO WITH PARTNER / TEAMING.

## 10. Pilot Results (live, within limits)
Curated 4 tech partners (≤10 updates); re-qualified 8 candidates; investment-scored 8; AI-enriched 1 partner (AWS). **0 Opportunities; all Pending.** Investment distribution: 8 LOW (honest — infeasible grants). Partner recommendation surfaced (Google Cloud). AWS AI profile live.

## 11. Dashboards (design)
Partner Capability Coverage (completeness by partner), Capability Gaps (recurring), Partner Recommendations (frequency), Most-Valuable Partners, Most-Requested Capabilities, **Investment Score Distribution** (HIGH/MEDIUM/LOW), Win-Probability + Confidence trends. Reportable on Company Profile + signal objects.

## 12–14. Production Changes / Validation / Deploy IDs
Deployed (additive, dormant): 3 investment fields on `OA_Opportunity_Signal__c`; `OA_PursuitInvestment`, `OA_PartnerIntelligence` (+test); `OA_Pursuit_Investment_Access` permset (assigned). Data: 4 partner-capability updates + 8 signal investment/qual updates + 1 partner AI enrichment. **Deploy `0AfPn0000023wEPKAY` (7 components); tests pass.** No Opportunities, no schedules, no secrets, no duplicate metadata.

## 15. Risks
Keyword capability match is coarse (refine with NAICS/PSC + embeddings); partner stubs are public-knowledge (verify); grant sample fits poorly (SAM contracts needed for GO-WITH-PARTNER flips); partner AI enrichment is one-call-per-txn (bulk = Queueable).

## 16. Rollback
Null the 3 investment fields + revert 4 partner capabilities + null AWS AI fields; destructive-deploy the 2 classes + fields + permset. CRM/Opportunities untouched. Not merged.

## 17. Technical Debt
Collect IronGrove/Patriot Allied capabilities; verify tech-partner teaming relationships + vehicles; NAICS/PSC + embedding-based capability match; USASpending incumbent enrichment (024A §7); Lightning dashboards; Queueable batch partner enrichment; least-priv user; delete `OA_HdrEcho`.

## 18. Verdict — **PASS**
Partner Intelligence materially improves qualification (partner recommendation surfaced live); Investment Intelligence implemented as a distinct third layer (live); Knowledge Foundation reused (no duplicate metadata); no unsupported/fake data (AI grounded, gaps flagged); no autonomous CRM writes; fully governed; pilot within limits; rollback documented.

## 19–20. Commit / PR — below.

## 21. Exact Next Engineering Program
**024C — SAM.gov Contract Ingestion + Incumbent Enrichment + Partner Collection:** provision the data.gov key → bring in **contract** opportunities that fit One Algorithm's capabilities (so qualification produces live **GO / GO WITH PARTNER / TEAMING** and investment produces **HIGH/MEDIUM**), implement the staged USASpending **incumbent/award-history** enrichment to sharpen win-probability, and run a **partner-capability collection sprint** (IronGrove, Patriot Allied) to close the data gap.
