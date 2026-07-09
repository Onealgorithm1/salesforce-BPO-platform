# Free Federal Opportunity Acquisition & Enrichment Foundation (Program 024)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/free-federal-acquisition-enrichment · 2026-07-09**
First production-ready acquisition pipeline on FREE authoritative federal data. Deployed **dormant** (manual invocation; no schedule). **No merge, no Opportunities, human-gated.**

## 1. Executive Summary
The free federal pipeline is **built, deployed, and live-piloted**: a **Grants.gov** connector (public API, no credential) discovers opportunities, normalizes them to an **OCDS-aligned** candidate on the existing `OA_Opportunity_Signal__c` review queue, dedupes idempotently, runs the deterministic **compliance go/no-go**, and publishes as **Pending** — never creating an Opportunity. An extensible **enrichment registry** (`OA_IEnrichmentProvider`) is in place with a live **USASpending** provider (agency/award-history resolution). A dormant **Schedulable** wrapper makes it **cloud-runnable with Louis's PC off** (activation gated). **SAM.gov** is skeletoned with its exact blocker (a data.gov key). Live pilot: **8 real Grants.gov opportunities staged, compliance-screened, 0 Opportunities created.**

## 2. Production Audit
Dependencies confirmed **in the org** (from prior sprints): `OA_Opportunity_Signal__c` (queue, **0 triggers/validation/flows** — safe to insert), `OA_ComplianceScreen`, `OA_Acquisition_Source__c` (registry, 10 rows), `OA_Company_Profile__c` (Self=EDWOSB), `OA_Opportunity_Intelligence__c`, AI Gateway, `OA_USASpending` NC. No Graph/SAM_Opportunities NC. 0 scheduled jobs; 5 Schedulable classes.

## 3. Target-State Validation (Phase 1)
`OA_Opportunity_Signal__c`: **no Apex triggers, no validation rules, no record-triggered flows** → inserts have no side effects (no accidental automation). Restricted picklists verified: `Source__c` ∈ {Grants.gov, SAM.gov, SBIR, Federal Register, Outlook Email}; `Type__c` ∈ {Grant, Contract, SBIR, Notice}; `Review_Status__c` default **Pending**; `Confidence__c` ∈ {High, Medium, Low}. Design fit the existing schema → **no new fields created**.

## 4. Canonical Opportunity Model (OCDS-aligned)
Mapped to existing fields (raw JSON in `Raw_Payload_Ref__c` for fidelity): source→`Source__c`, canonical key→`Canonical_Key__c` (`grants:{id}`), title→`Title__c`, agency→`Agency__c`/`Agency_Code__c`, type→`Type__c`, solicitation#→`Opportunity_Number__c`, NAICS/PSC→`NAICS__c`/`PSC__c` (SAM), set-aside→`Set_Aside__c` (SAM), posted→`Posted_Date__c`, deadline→`Response_Deadline__c`, value/funding→`Estimated_Value__c`, assistance listing→`Assistance_Listing__c`, URL→`URL__c`, confidence→`Confidence__c`, compliance→`Compliance_Decision__c/Rationale/Missing`, review→`Review_Status__c`. **No unnecessary fields added.**

## 5. Enrichment Registry (extensible)
`OA_IEnrichmentProvider` interface — each provider declares `providerName()`, `isFree()`, `isAuthoritative()`, and `enrich(signal)` (callout-only, never throws, returns a summary/`[provider: reason]`). New providers plug in **without changing the acquisition engine**; providers **enrich, never own** the candidate. First concrete provider: **`OA_USASpendingEnrichment`** (free, authoritative — resolves the buyer agency against USASpending toptier data, unlocking award-history/incumbent lookups). Registry records live in `OA_Acquisition_Source__c` (access method / priority / risk tier already modeled).

## 6. Federal Source Certification
| Source | Access | Credential | Status |
|---|---|---|---|
| **Grants.gov search2** | `POST https://api.grants.gov/v1/api/search2` (public) | **none** | **IMPLEMENTED + LIVE** (Remote Site `OA_GrantsGov`) |
| **SAM.gov Opportunities v2** | `api.sam.gov/opportunities/v2/search` | **data.gov api_key (BLOCKED)** | **SKELETON** (connector code exists; NC/EC + key required) |
| **USASpending** | `callout:OA_USASpending/api/v2/...` (needs `Accept: application/json`) | none | **IMPLEMENTED (enrichment) + LIVE** |
| FPDS | ATOM feed | none | REFERENCE (USASpending covers award history) |
| SBIR/STTR, Federal Register, GSA eLibrary/CALC, Regulations.gov, Census, SEC EDGAR, NIH RePORTER, NSF | public APIs | none/key | **DEFERRED — pluggable via `OA_IEnrichmentProvider`** (see §9) |

## 7. Connectors Implemented
- **`OA_FederalOpportunityAcquisition.grantsGov(keyword, maxRows≤10)`** — callout-before-DML, OCDS-normalize, idempotent dedup on `Canonical_Key__c`, insert Pending candidates, run compliance. **Live-proven.**
- **`OA_FederalAcquisitionScheduler`** (Schedulable, **dormant** — not scheduled) — cloud/PC-off execution wrapper.
- **SAM.gov**: `OA_SAMOpportunities_*` classes exist; activation = deploy `OA_SAM_Opportunities` NC + External Credential (api_key AuthHeader) + Louis's **data.gov key**. Not faked.

## 8. Enrichment Providers Implemented
**USASpending** (`OA_USASpendingEnrichment`) — live: fetches toptier agencies, matches the candidate's buyer, returns a summary + flags sub-agencies for deeper lookup. Free, authoritative, graceful-fail.

## 9. Enrichment Providers Deferred (pluggable, with path)
Federal Register (rule/notice context), SBIR/STTR (topic detail), GSA eLibrary/CALC (vehicle + labor rates), SEC EDGAR (partner/entity financials), NIH RePORTER / NSF Award Search (research award history), Census/BLS/BEA (market context), Regulations.gov. **Why not now:** avoid slowing the core; each is a modular `OA_IEnrichmentProvider` (public API + `Accept: application/json`, cache by key, graceful-fail). **Future path:** implement `enrich()`, register in `OA_Acquisition_Source__c`, invoke in the enrichment pass (separate txn from acquisition — callout-after-DML rule).

## 10. Document Retrieval Strategy
**Grants.gov**: opportunity detail + package at `grants.gov/search-results-detail/{id}` (`URL__c`) — store link now; package download via a future `OA_DocumentIntelligence` (Files + checksum + AI extraction). **SAM.gov**: `resourceLinks` attachment API (honor download rules) → Salesforce Files. **Storage**: original preserved in ContentVersion, SHA-256 + source URL + retrieved-at + version; link Document→Signal. **No unsupported scraping.** Full download deferred to Doc Intelligence; links + strategy certified now.

## 11. Compliance Go/No-Go Results (live)
All 8 pilot candidates screened via `OA_ComplianceScreen` → **GO** (grants are full-and-open; EDWOSB eligible) with rationale + missing-requirements (verify SAM registration). Outputs are GO/NO-GO/TEAMING/MONITOR(→REVIEW)/REVIEW REQUIRED with rationale, confidence, source attribution, next action. **Human review mandatory** (all Pending).

## 12. Opportunity Intelligence Handoff
OI (`OA_OpportunityIntelligence`) runs on **Opportunities**, post-human-promotion (a signal → human promote → Opportunity → OI). For candidates, the enrichment payload (agency/award-history, NAICS/PSC, set-aside, deadline, value, document complexity) is staged on the signal for OI to consume at promotion. **No auto-promotion.**

## 13. Cloud Execution Readiness
`OA_FederalAcquisitionScheduler` (Schedulable) + Remote Site/`Named Credential` + Apex = **runs with Louis's PC off, no browser** for Grants.gov/USASpending. **Not scheduled** (activation is a governance stop — requires Louis approval). Retry/failure: `Result.error` captured per run; add dead-letter (`OA_Enrichment_Exception__c` pattern) + `OA_Connector_Run__c` telemetry at activation. Runtime user = oauser (least-priv user is standing debt).

## 14. Dashboards / Reports (design — business questions)
On `OA_Opportunity_Signal__c` (reportable): Opportunities discovered (by day/source), Source productivity, GO/NO-GO/TEAMING mix, most-active agencies, NAICS/PSC volume, **review backlog (Pending)**, missing-documents, enrichment failures, closest-to-deadline, incumbent-intelligence coverage. Object is report-ready; Lightning build is the remaining UI step.

## 15. Pilot Results (live, within limits)
`grantsGov('information technology', 8)` → **fetched 8, inserted 8, duplicates 0, error none**. Real opportunities: Army Materiel Command (LQC, HBCU research), Food & Nutrition Service (CN Tech Innovation), US Missions (Morocco/UAE/DR tech labs, Lunar Payload). All **Grant / Pending / GO**, deadlines normalized (2026-07-10 … 2027-04-30). **0 Opportunities created.** USASpending enrichment live-resolved an agency. Before: 10 signals; After: 18 (8 new Grants candidates). ≤10 cap honored.

## 16. Production Changes
Deployed (additive, **dormant**): Remote Site `OA_GrantsGov`; classes `OA_FederalOpportunityAcquisition`, `OA_IEnrichmentProvider`, `OA_USASpendingEnrichment`, `OA_FederalAcquisitionScheduler` (+ test). 8 pilot candidate records inserted. **No** Opportunities, no schedules, no external portal changes, no new fields/objects, no secrets.

## 17–19. Validation / Deploy IDs / Test Results
Check-only `0AfPn0000023vBtKAI`; deploy **`0AfPn0000023vGjKAI`** (6 components) + `0AfPn0000023vNBKAY` (USASpending Accept-header fix). Tests **4/4 pass** (governed intake, idempotent dedup, USASpending enrichment, scheduler). Live pilot evidence above.

## 20. Risks
Grants.gov API stability (public, generally reliable); USASpending needs `Accept: application/json` (fixed); SAM blocked on key; scheduling = unattended AI (gated); grant-source has no set-aside so compliance is coarse-GO (expected — grants are open); least-priv runtime user (standing).

## 21. Technical Debt
SAM data.gov key + NC/EC; document-download build (Doc Intelligence); enrichment providers §9; dead-letter + `OA_Connector_Run__c` telemetry; Lightning dashboards; least-priv user; delete `OA_HdrEcho`; merge/close open PRs (#69–78 + this).

## 22. Rollback Plan
`DELETE FROM OA_Opportunity_Signal__c WHERE Source__c='Grants.gov' AND CreatedDate=TODAY` (removes 8 pilot candidates); remove the 5 classes + Remote Site via destructive deploy. No schedules to unschedule (none created). CRM/Opportunities untouched. Not merged.

## 23. Verdict — PASS
Org verified · target constraints inspected before design · OCDS-aligned canonical model (no new fields) · enrichment registry implemented · **Grants.gov connector implemented + live** · SAM.gov skeletoned with exact blocker · USASpending enrichment implemented + live · candidates human-gated · **0 Opportunities auto-created** · document retrieval certified · compliance wired · OI handoff staged · cloud readiness documented (dormant) · pilot within limits · rollback documented · no unsupported scraping.

## 24–25. Commit / PR — below.

## 26. Exact Next Engineering Program
**024B — SAM.gov Activation + Document Intelligence:** provision the **data.gov key + `OA_SAM_Opportunities` NC/EC** (gated — Louis), activate the built SAM connector into the same OCDS pipeline (NAICS/set-aside filters + `resourceLinks`), and build **`OA_DocumentIntelligence`** (Files + checksum + AI-Gateway extraction) for both SAM and Grants documents. Then **024C — Email-Intake + Cloud Scheduling** (app-only Graph NC to detect portal/Bonfire invitations server-side; enable dormant scheduler on approval).
