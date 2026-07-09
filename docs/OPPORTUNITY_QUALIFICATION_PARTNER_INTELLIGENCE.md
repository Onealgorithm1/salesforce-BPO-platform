# Opportunity Qualification Intelligence & Partner Capability Matching (Program 024A)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/opportunity-qualification-partner-intelligence · 2026-07-09**
Deployed **dormant** on the Program-024 pipeline. **No merge, no Opportunities, human-gated, advisory-only.**

## 1. Executive Summary
The pipeline now answers a **business** question, not just a legal one: *can One Algorithm, alone or with a partner, realistically win this?* A deterministic **`OA_OpportunityQualification`** engine matches each candidate's domain against One Algorithm's capability profile **and** partner capability profiles, producing **GO / GO WITH PARTNER / TEAMING / MONITOR / REVIEW REQUIRED / NO-GO** with a recommended partner + role + fit/effort/urgency scores + capability gaps. Live pilot on the 8 free Grants.gov candidates correctly **filtered 7 ill-fitting research/diplomatic grants to NO-GO and 1 to MONITOR** — proving the principle that *eligible ≠ feasible*. The engine's full range is unit-proven (GO/GO-WITH-PARTNER/TEAMING/NO-GO). **Verdict: WARN** — the engine/model/pilot are complete, but **partner capability data is incomplete** (IronGrove & Patriot Allied capabilities unknown; tech-partner profiles are public-stub) — collection plan below.

## 2. Production Audit
Program-024 Grants.gov pipeline live (8 candidates). Reused: `OA_ComplianceScreen` (eligibility), `OA_Company_Profile__c` (Knowledge Foundation — capability source), `OA_Opportunity_Signal__c` (review queue), `OA_USASpendingEnrichment`. Partner inventory thin: only One Algorithm (Self, EDWOSB) + Medianow (Partner, empty). Existing `OA_QualificationRuleEngine`/`OA_DiscoveryQualificationEngine` are for **org discovery** (BLO), not opportunities → new engine justified (pattern reused).

## 3. Target-State Validation
`OA_Opportunity_Signal__c`: **0 triggers, 0 validation rules, 0 record-triggered flows** → safe field updates. Restricted picklists respected. Added qualification fields (justified — enable the richer decision + dashboards) rather than overloading `Compliance_Decision__c` (which stays as the *eligibility* layer). No duplicate metadata.

## 4. Partner Inventory (reuses `OA_Company_Profile__c`)
| Partner | Type | Capabilities on file | Data quality |
|---|---|---|---|
| Salesforce, Microsoft, AWS, Google Cloud | Partner | cloud / CRM / AI / data (public) | **stub (public knowledge)** |
| Zendesk, TTEC Digital | Partner | CX / contact center / BPO (public) | stub (public) |
| **IronGrove, Patriot Allied Solutions** | Partner | **none — unknown** | **MISSING (collect)** |
| Medianow | Partner | none | existing, empty |
| One Algorithm | Self | AI-BPO; Salesforce eng; federal BD; enrichment (EDWOSB) | curated |
8 partner profiles seeded (≤10). **No duplicate metadata** — reused the Company Profile object.

## 5. Partner Capability Model
Reuses `OA_Company_Profile__c` (Capabilities, NAICS, Socioeconomic, Past Performance, completeness/confidence) + `OA_Knowledge_Relationship__c` (relationships). The engine answers: pursue alone? (self-fit ≥55 → GO Prime) · should we team? (self-fit low + partner covers domain → GO WITH PARTNER) · which partner fills the gap? (best gap-coverage partner) · prime or sub? (set-aside → team under a qualifying partner = Subcontractor) · missing certs/vehicles? (Capability_Gaps + Missing_Requirements) · who to contact first? (Recommended_Partner).

## 6. Qualification Scoring Engine (`OA_OpportunityQualification`)
Deterministic, auditable (no AI in the decision). Inputs: title/agency/NAICS/set-aside/deadline/value + `Compliance_Decision__c` + Self capability keywords + partner capability keywords + partner socioeconomic. Logic: eligibility-first (NO-GO set-aside → TEAMING if a partner holds the status, else NO-GO) → self-fit ≥55 → **GO (Prime)** → self-fit <25 → **GO WITH PARTNER** if a partner covers ≥50% of the gap, else **NO-GO** → 25–55 → **GO WITH PARTNER** (partner ≥40%) or **MONITOR**. Outputs: `Qualification_Decision__c`, `Recommended_Partner__c`, `Recommended_Role__c`, `Fit_Score__c`, `Effort_Score__c`, `Urgency_Score__c` (deadline-driven), `Capability_Gaps__c`, `Qualification_Rationale__c` (with self-fit %, partner-gap-cover %, urgency, "advisory — human decides"). **Human review mandatory** (Review_Status untouched = Pending).

## 7. USASpending Enrichment Improvement
**Live now:** toptier-agency resolution (`OA_USASpendingEnrichment`, Program 024, needs `Accept: application/json`). **Staged with exact path** (award-history / incumbent lookup): `POST https://api.usaspending.gov/api/v2/search/spending_by_award/` with body `{"filters":{"time_period":[{"start_date":"2023-01-01","end_date":"2026-07-09"}],"award_type_codes":["A","B","C","D"],"naics_codes":[<NAICS>],"agencies":[{"type":"awarding","tier":"toptier","name":"<agency>"}]},"fields":["Recipient Name","Award Amount","Awarding Agency","Award Type"],"limit":10,"sort":"Award Amount","order":"desc"}` → top recipients = **likely incumbents/competitors**, award totals = **contract-size signal**. Implementation path: add `enrichAwards(signal)` to the provider (callout + parse `results[].Recipient Name`/`Award Amount`), write to `Qualification_Rationale__c`/`Capability_Gaps__c`. Not faked — endpoint + body documented.

## 8. Pilot Results (live, within limits)
Qualified the 8 Grants.gov candidates (updates ≤10; 0 Opportunities). Result: **1 MONITOR** (Tech Innovation Lab, fit 40%) + **7 NO-GO** (fit 0–22%: Qubit Collaboratory, Lunar Payload, US-Mission tech fairs, HBCU research) — correctly rejecting research/diplomatic grants that don't fit a BPO/Salesforce services firm. **This is the value:** the qualifier filters the firehose so humans don't review 8 dead-ends. Full range proven by tests (GO Prime for a Salesforce-automation opp; GO WITH PARTNER when BuildCo covers a construction opp; TEAMING under VetPrime for an SDVOSB set-aside; NO-GO for out-of-domain). All candidates **Pending**.

## 9. Review Queue UX
Reviewer sees (existing + new fields): source, agency, title, deadline, `Compliance_Decision__c` (eligibility), **`Qualification_Decision__c`** (feasibility), `Qualification_Rationale__c`, `Recommended_Partner__c`, `Recommended_Role__c`, `Capability_Gaps__c`, `Missing_Requirements__c`, `Urgency_Score__c`, `Effort_Score__c`, `Fit_Score__c`, `Confidence__c`, `URL__c`. Recommendation: a **List View** "Pursue Queue" filtered `Review_Status=Pending AND Qualification_Decision IN (GO, GO WITH PARTNER, TEAMING)` sorted by Urgency — no new metadata needed.

## 10. Dashboards (design — business questions)
GO-WITH-PARTNER count, most-recommended partners, recurring capability gaps, strongest NAICS/PSC, MONITOR list, NO-GO reasons, agency↔partner alignment, immediate-outreach queue (GO WITH PARTNER + high urgency), most-valuable partner certifications. All reportable on the signal + Company Profile objects.

## 11–14. Changes / Validation / Deploy IDs / Tests
Deployed (additive, dormant): 8 qualification fields on `OA_Opportunity_Signal__c`, `OA_OpportunityQualification` (+test), `OA_Opportunity_Qualification_Access` permset (assigned). Data: 8 partner Company Profiles + 8 signal qualification updates. **Deploy `0AfPn0000023vtRKAQ` (11 components); tests pass.** No Opportunities, no schedules, no portal changes, no secrets.

## 15. Risks
Capability match is keyword-based (deterministic + auditable, but coarse — refine with NAICS/PSC + AI narrative later); partner stubs (public knowledge) need verification; IronGrove/Patriot Allied capabilities unknown; grant candidates are a poor fit sample (SAM.gov contracts will show GO/GO-WITH-PARTNER live).

## 16. Technical Debt
Collect real partner capabilities (see plan); implement USASpending award-history (§7); NAICS/PSC-based capability match; AI-narrated rationale via gateway; Lightning dashboards; least-priv user; delete `OA_HdrEcho`; merge/close open PRs.

## 17. Rollback
`DELETE OA_Company_Profile__c WHERE Profile_Type__c='Partner' AND CreatedDate=TODAY` (8 seeded partners); null the 8 qualification fields on Grants signals; destructive-deploy the engine + fields + permset. CRM/Opportunities untouched. Not merged.

## 18. Verdict — **WARN** (engineering complete; partner data incomplete)
PASS on: org verified, constraints inspected, partner model defined, qualifier richer than GO/NO-GO (6 outcomes), Grants candidates evaluated, self + partner fit assessed, USASpending improved/staged, 0 auto-Opportunities, human review mandatory, no duplicate metadata, pilot within limits, rollback documented. **WARN** on: **partner capability data incomplete** — collection plan:
1. **IronGrove & Patriot Allied Solutions** — capture capabilities, NAICS/PSC, socioeconomic certs, contract vehicles, agency experience, past performance, teaming role (source: partner POC / capability statements).
2. **Verify tech-partner stubs** (Salesforce/MS/AWS/Google/Zendesk/TTEC) — confirm the specific One Algorithm↔partner teaming relationship + contract vehicles.
3. Populate `OA_Company_Profile__c` fields (or run `OA_KnowledgeIntelligence.profile()` per partner Account) + set `Knowledge_Completeness`/`Confidence`. Then re-run `OA_OpportunityQualification.qualify()` for data-driven partner matches.

## 19–20. Commit / PR — below.

## 21. Exact Next Engineering Program
**024B — SAM.gov Activation + Award-History Enrichment:** provision the data.gov key + `OA_SAM_Opportunities` NC/EC to bring in **contract** opportunities (which fit One Algorithm's IT/BPO capabilities → live GO / GO WITH PARTNER / TEAMING), and implement the staged USASpending **award-history/incumbent** enrichment (§7) to feed competition signals into qualification. Parallel: **Partner Capability Collection** (fill the WARN gap).
