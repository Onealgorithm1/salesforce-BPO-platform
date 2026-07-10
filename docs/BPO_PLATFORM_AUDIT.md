# BPO Platform — Complete Audit & Context Brief

*A granular, self-contained audit of everything built in the `salesforce-BPO-platform` repo and the production org. Purpose: drop this into a fresh Claude (or any new operator) so it understands what this platform is, what it's trying to achieve, what exists, what's live vs dormant, and the rules for operating it safely.*

**Compiled:** 2026-07-10 · **Production Org:** `00Dbn00000plgUfEAI` (Enterprise Edition, `USA350`, My Domain `onealgorithmllc.my.salesforce.com`) · **Repo:** `Onealgorithm1/salesforce-BPO-platform`.

> **Memory note:** the assistant's persistent memory store for this project is **empty** (no saved memories). This document + the repo `docs/` are the source of truth.

---

## 1. Mission — what we're trying to achieve

**One Algorithm LLC** is an **EDWOSB** (Economically Disadvantaged Women-Owned Small Business) and **Salesforce ISV Partner** running a **Salesforce-native BPO + technology platform**. Five business lines: internal CRM operations, client platform deployments, ISV products, AI-augmented processes, and **government-contracting support (EDWOSB compliance + federal procurement outreach)**.

**The concrete revenue engine is federal-contracting teaming outreach.** The platform:
1. **Sources** companies from public federal data (SAM.gov is the lead source).
2. **Enriches** each Lead with authoritative public data (SAM entity/certs, USASpending awards, IRS, SEC, Census) to answer *"who is this company?"*
3. **Runs governed email outreach** to prime contractors, positioning One Algorithm's EDWOSB set-aside status for teaming/subcontracting.
4. **Captures responses** (replies, booked meetings, Teams transcripts) and resolves them.
5. **(Future) ranks opportunities** — turning the firehose of public solicitations into an explainable, human-reviewed pursuit pipeline.

**Scale today:** 13,302 Leads (13,279 with a UEI), 6 Campaigns, one active outreach campaign with 406 CampaignMembers, 1 Opportunity. The repo itself also exists to put previously un-version-controlled production metadata under git with an audit trail (before June 2026 all changes were made directly in production).

**Everything is human-gated and governed.** The design principle throughout: automate discovery and preparation, but keep a human review gate before anything is written to a Lead, an Opportunity is created, or an email pattern changes.

---

## 2. Governance — READ THIS FIRST (standing rules, non-negotiable)

These are enforced every session (`CLAUDE.md`). A fresh operator must obey them:

1. **Approval authority is Louis.** Never set a staging/proposal row to `Approved` and never write to a Lead without **explicit approved numbers from Louis in the current session**.
2. **Verify Org ID = `00Dbn00000plgUfEAI` by ID** before any org operation. Mismatch = STOP.
3. **Path A is the ONLY certified Lead-enrichment write path:** `OA_USASpendingEnrichmentService` → `OA_USASpending_Staging__c` (review-gated) → `OA_LeadWritebackService`. **Path B's ungated commit (`OA_EnrichmentWriter commitWrites=true`) must NEVER be used** for committed Lead writes (tech debt, pending disable).
4. **All connectors return to dormant** (`OA_Connector_Registry__mdt.*.Enabled__c=false`) before any session ends.
5. **No** schedules created/enabled · **no** Opportunity creation · **no** Lead conversion · **no** campaign sends · **no** secrets in output/commits/docs — without explicit approval.
6. At session start, read the latest `docs/SESSION_STATE_*` note and resume from it.

**Autonomy tiers:** 🟢 GREEN (read-only, source-only feature-branch work, PRs) proceed freely · 🟡 YELLOW (additive/reversible metadata) proceed + report · 🔴 RED (production deploys, `main` merges, any DML to live records, permission-set assignments, scheduling jobs, batch writes, campaign changes, Named/External Credentials, secrets, M365/Graph, Cloudflare/DNS) **STOP for explicit Louis approval**.

**Protected automations (do not modify without approval):** `OA_EDWOSB_Outreach_Sequence`, `OA_Reply_Detection`, `OA_PostMeeting_Nurture`, `OA_EmailSender`, Lead write-back, all Named/External Credentials, M365/Graph/Bookings/Teams, production data, Cloudflare/DNS, `www.onealgorithm.com`.

**Top standing risk — the runtime user:** all automation runs as `oauser@pboedition.com` (display name "Louis Rubino", `005bn00000BP9zUAAT`) which holds **System Administrator / Modify All Data**. This weakens the FLS/least-privilege guardrail. Root cause: **0 spare Salesforce licenses** (Integration seats can't run internal scheduled Apex compliantly — see the email/audit sessions). The least-privilege `OA_Runtime_Operations` PSG is **built + validated but unassigned** (no user to assign it to). This bounds the safety of unattended automation and gates 24/7 scheduling.

---

## 3. Architecture — how the subsystems connect

```
SAM.gov (lead source)
   │  Leads (LeadSource='SAM.gov', 13k+)
   ▼
CRM Leads ──► LEAD ENRICHMENT (who is this?)      ──► review-gated write-back (Path A only)
   │           USASpending / SAM / IRS / SEC / Census      to 16 Lead fields
   │
   ▼
CAMPAIGN AUTOMATION (EDWOSB outreach)  ── OA_DripScheduler enrolls Wave-1 SAM.gov leads
   │   Flow OA_EDWOSB_Outreach_Sequence → Day 1 Sent (OA_EmailSender, native email)
   │   OA_FollowUpScheduler → Day 3/5/10 Sent   (OA_SendGovernor caps + business-day gate)
   ▼
RESPONSE HANDLING
   ├─ OA_Reply_Detection (flow)  → Replied / Unsubscribed  → stops sequence
   ├─ OA_BookingPoller (M365 Graph) → Meeting Booked        → stops sequence
   └─ OA_ArtifactPoller + AI summary (Teams transcripts)
   ▼
ENGAGEMENT RESOLUTION ENGINE (ERE) — observe-only shadow log of every signal
   ▼
ANALYTICS (funnel snapshots, executive dashboards)
   ▼
OPPORTUNITY INTELLIGENCE (design-only) — ranked pursuit pipeline from public solicitations
```

Shared plumbing across all of it: the **Connector SDK** (source-agnostic fetch/parse/map/persist), **telemetry** (`OA_Connector_Run__c`, `OA_AI_Request_Log__c`), **exception routing** (`OA_Enrichment_Exception__c`), and **audit/rollback** (`OA_ChangeLogService` + before-snapshots).

---

## 4. Live production state (as-built, 2026-07-10)

| Metric | Value |
|---|---|
| Leads | **13,302** (13,279 with UEI `UEI_Unique_entity_Identifier__c`) |
| Campaigns / CampaignMembers | 6 / 406 |
| Opportunities | **1** |
| Contacts / Accounts | 9 / 2 |
| OA staging/telemetry data | USASpending staging 16 · Engagement Resolutions 49 · Opportunity Signals 31 · Opportunity Intelligence 2 · Comm Preferences 7 · Connector Runs 18 |
| Deployed Apex classes (non-managed) | **185** |
| Active Flows | **80** |
| Reports / Dashboards | 85 / 9 |
| Active users | 8 |
| Connectors enabled | **0** (all 6 dormant) |
| Scheduled jobs (live) | Booking Poller ×4 (15-min), OA Artifact Poller (hourly), OA EDWOSB Follow-Up Daily, OA_DripScheduler_Wave1 (+ platform/managed jobs) |

> **Repo ≠ org.** The repo mirrors the OA-authored platform (108 classes, 3 flows, 29 objects, 25 permsets, 150 docs / 16 ADRs), but the **org holds more** (185 classes, 80 flows) — standard/managed/directly-deployed content not fully source-controlled here. Treat the org as authoritative for "what's running," the repo as authoritative for "what we built and how."

---

## 5. Subsystems (detail)

### 5.1 Campaign Automation / EDWOSB Outreach — **LIVE** (the production heart)
Campaign **"EDWOSB Teaming Outreach – Prime Subcontract"**, Id **`701Pn00001ZOyj8IAD`** (hard-coded in the drip scheduler, follow-up scheduler, and outreach flow).
- **`OA_DripScheduler`** (Schedulable) — the *only* enroller. Enrolls a Lead iff `LeadSource='SAM.gov'` AND `Outreach_Cohort__c='Wave 1'` AND `Is_Test_Lead__c=false` AND `HasOptedOutOfEmail=false` AND `IsConverted=false` AND `Email!=null` AND not already a member. Business-day gate; `MAX_SYNC_BATCH=50`.
- **`OA_EDWOSB_Outreach_Sequence`** (Flow, record-triggered on CampaignMember create) — sends Day-1 template (branches Teaming Partner vs EDWOSB Sub Prospect) via `OA_EmailSender`, sets status **"Day 1 Sent"**. Does not enroll.
- **`OA_FollowUpScheduler`** (Schedulable) — advances **Day 1→3→5→10 Sent**, sending `Follow_Up_Day3/5/10` templates via `OA_EmailSender`; **only advances status on a successful send**; halts on stop-statuses (Replied, Meeting Booked, Interested, Not Interested, Unsubscribed, Call Completed). Uses Org-Wide Email Address `0D2Pn00000013wjKAA`.
- **`OA_EmailSender`** (`@InvocableMethod`) — renders a stored HTML `EmailTemplate`, injects a tokenized HTTPS unsubscribe link (`…my.site.com/…/oa/unsubscribe`, 90-day TTL), sends via **native `Messaging.sendEmail`** (NOT an external provider). Cap 50/invocation.
- **`OA_SendGovernor`** — daily send cap (`OA_Campaign_Settings__c.Daily_Send_Cap__c` = 100), shared `Sends_Today__c` counter, business-day + federal-holiday gate, `checkAndReserve()` throws `CapExceededException`.
- **Email templates (5):** `EDWOSB_Sub_Prospect_Email_1`, `Teaming_Partner_Email_1`, `Follow_Up_Day3/5/10`.

### 5.2 Lead Enrichment Platform — **LIVE code, DORMANT runtime** (v1.2 certified, maintenance mode)
Metadata-driven, connector-agnostic. Add a source = Request + Parser + Mapper + Connector + CMDT row (no platform-code change).
- **Framework:** `OA_IEnrichmentConnector` / `OA_ConnectorRunner` (registry-driven `Type.forName`) / `OA_ConnectorResult`, plus the newer **Connector SDK** (`OA_IConnector/Request/Parser/Mapper`, `OA_ConnectorEngine`, `OA_ConnectorPersistence`, `OA_ConnectorMock`).
- **Canonical + engines:** `OA_CanonicalOrg`, `OA_NameNormalizer`, `OA_FieldWritePolicyEngine`, `OA_QualificationRuleEngine`, `OA_ConfidenceEvaluator`, `OA_SourcePrecedenceEngine`, `OA_SourceFusion`, `OA_DiscoveryQualificationEngine`.
- **Governed write:** `OA_EnrichmentWriter` (per-field policy, USER_MODE FLS, before-snapshot — **Path B, ungated commit must never run**), `OA_ChangeLogService` (audit + rollback), `OA_ExceptionRoutingService` (review queue).
- **Execution:** `OA_EnrichmentOrchestrator` (Batch+Stateful+AllowsCallouts) + `OA_EnrichmentQueueable`; `commitWrites=false` by default.
- **The certified write path (Path A):** `OA_USASpendingEnrichmentService.enrich(name, limit, persist, leadId)` → maps awards to `OA_USASpending_Staging__c` (Pending) → human approval → `OA_LeadWritebackService.writeBack(...)` writes the 16 Lead fields, snapshot-first, FLS-gated, idempotent, one-winner-per-Lead.

### 5.3 Connectors (6, all dormant `Enabled__c=false`)
| Connector | Source | Access | State |
|---|---|---|---|
| USASpending | Federal award history | Public POST `spending_by_award` (no auth) | READY (Path A live via service) |
| IRS | Tax-Exempt EO BMF | **Bulk CSV, no callout** | READY |
| SAM.gov | Entity registration/UEI/certs | data.gov X-Api-Key | Needs endpoint + EC principal + key confirmation |
| Census | County Business Patterns | Public API (key optional) | Needs `OA_Census` NC |
| SEC EDGAR | Filings/CIK | Public (needs User-Agent) | Needs `OA_SEC` NC |
| State Registry | SoS business registries | Per-state | Template only, not built |

Registry: `OA_Connector_Registry__mdt` — 8 rows (adds GrantsGov, SAM_Opportunities for the OI program), all `Enabled__c=false`, `Review_Required__c=true`.

### 5.4 Engagement Resolution Engine (ERE) — **LIVE but observe-only / dormant**
Normalizes every engagement signal (inbound email reply, meeting Event) into a common shape, runs a deterministic match hierarchy (L1 exact Lead email · L2 Contact email · L3 corporate domain · L6 human review), and writes **one shadow-log row per signal to `OA_Engagement_Resolution__c`** — its ONLY DML. Never touches Lead/Contact/CampaignMember/Event/EmailMessage/Task. Config in `OA_Engagement_Config__mdt.EDWOSB_Default` (`Observe_Only=true`, campaign-scoped). No trigger/schedule; entry is a manual admin batch (`OA_EngagementResolverBatch`). Reviewer permset is read-only.

### 5.5 Booking / M365 Graph — **LIVE**
`OA_BookingPoller` (Schedulable, 4 jobs / 15-min) closes the gap where EAC-synced "Book with me" Events arrive with `WhoId=null`: reads attendee email via MS Graph (application permission, Named Credential/config), matches the Lead, links Event→Lead, sets CampaignMember **"Meeting Booked"** (stops drip), stamps `Meeting_Booked_Date__c` / `Relationship_Status__c`, creates a prep Task (or an alert Task if unmatched). Config from Custom Metadata (`OA_Graph_Config__mdt`) — **not hard-coded**.

### 5.6 Meeting Capture / AI summaries — **PARTIAL** (marketing module)
`OA_ArtifactPoller` (hourly) pulls Teams recording/transcript artifacts for confirmed meetings → `OA_AISummaryService`/`OA_AISummaryQueueable` (Anthropic) → Lead `AI_Summary__c` + follow-up Task. `OA_ReplayBookingService` re-arms a Lead for re-processing. The `Meeting_Record__c` object is still forward design.

### 5.7 Communication Preferences / Unsubscribe — **LIVE**
`OA_CommPreferenceService` + objects `OA_Communication_Preference__c` / `_Audit__c` / `_Token__c`; public REST `OA_UnsubscribeEndpoint` (`/oa/unsubscribe/*`), `OA_UnsubscribeTokenService` (hash-based signed tokens), platform event `OA_Unsubscribe_Request__e`, trigger `OA_UnsubscribeRequestTrigger` (**the one active Apex trigger**). Rule: **GET never unsubscribes** (render/validate only); **POST** performs the token-based unsubscribe. Guest access minimal via `OA_Unsubscribe_Guest_Access`.

### 5.8 AI Gateway + Intelligence engines — **LIVE gateway, engines manual-only**
`OA_AI_Gateway` (single entry point, routing + fallback + token logging to `OA_AI_Request_Log__c`; Named Credentials `OA_OpenRouter`, `OA_Anthropic`), `OA_AI_ModelRegistry`. Engines (deployed, **manually invocable only**): `OA_OpportunityIntelligence` (Program 020), `OA_KnowledgeIntelligence` (021), `OA_ComplianceScreen` (023 EDWOSB Go/No-Go), `OA_OpportunityQualification` / `OA_PursuitInvestment` / `OA_PartnerIntelligence` (024A/B), `OA_DocumentIntelligence` / `OA_EvidenceCitation` (024C/D), `OA_FederalOpportunityAcquisition` (Grants.gov intake, direct URL `api.grants.gov`).

### 5.9 Executive / Campaign Analytics — **LIVE**
Campaign-agnostic analytics: object `Campaign_Funnel_Snapshot__c` (daily reporting snapshot, forward-only), report types `OA_Email_Messages` + `OA_Campaign_Funnel_Snapshots`, 6 reports in `OA Executive Analytics`, dashboard `Executive Campaign Analytics`, permset `OA_Executive_Analytics_Access`. Declarative only (no Apex/Flow).

### 5.10 Opportunity Intelligence (OI) — **DESIGN ONLY** (Phase 0, not deployed to main)
Reuses the certified connector SDK; new grain = `OA_Opportunity_Signal__c` (a solicitation — noticeId/NAICS/set-aside/deadline). Pipeline fetch→parse→map→dedupe→(optional persist, `commit=false`)→human review queue; six phases each behind a human gate; Phase 5 creates CRM Opportunities on human approval only. Hard out-of-scope: auto-Opportunity creation, any outreach change, external writes, AI decisioning (v1).

---

## 6. Data model (custom objects & key fields)

**Lead** carries ~50 enrichment/outreach custom fields, grouped: federal identity (`UEI__c`, `UEI_Unique_entity_Identifier__c` (the bulk-imported one, 13k populated), `CAGE_Code__c`, `EIN__c`, `CIK__c`, `SIC_Code__c`, `NTEE_Code__c`, `Ticker__c`, `Entity_Type__c`, …); SAM (`SAM_Registration_Status__c`, `Business_Types__c`, `Socioeconomic_Certifications__c`, `Federal_Contractor__c`); awards (`Award_Count__c`, `Total_Award_Amount__c`, `Awarding_Agencies__c`); **USASpending write-back block** (`USASpending_UEI__c`, `_Latest_Award_Amount__c`, `_Latest_Award_ID__c`, `_Awarding_Agency__c`, `_Awarding_Sub_Agency__c`, `_Contract_Type__c`, `_Performance_State__c`, `_Source_Run_ID__c`, `_Last_Enriched__c`, `_Latest_Award_Desc__c`); **UEI verification** (`UEI_Verification_Status__c`, `_Source__c`, `_Run_ID__c`, `_Evidence__c`, `UEI_Verified_By__c`, `UEI_Verified_Date__c`); outreach (`Relationship_Status__c`, `Outreach_Segment__c`, `Outreach_Cohort__c`, `Meeting_Booked_Date__c`, `Is_Test_Lead__c`). Marketing module adds `AI_Summary__c`, `Transcript_Content__c`, `Teams_Meeting_Id__c`, `Recording_Retrieved__c`, `Meeting_Outcome__c`.

**Custom objects (17 `__c`):**
- **Enrichment/staging:** `OA_USASpending_Staging__c` (award proposals, review-gated → write-back), `OA_SAM_Entity_Staging__c` (dormant), `OA_Discovered_Organization__c` (net-new orgs), `OA_Connector_Run__c` (run telemetry), `OA_Enrichment_Change_Log__c` (before/after audit + rollback snapshot), `OA_Enrichment_Exception__c` (review queue).
- **Engagement/comms:** `OA_Engagement_Resolution__c` (ERE shadow log), `OA_Communication_Preference__c` / `_Token__c` / `_Audit__c`.
- **Opportunity/knowledge (AI):** `OA_Opportunity_Signal__c` (solicitation grain, ~50 fields), `OA_Opportunity_Intelligence__c` (scorecard, observe-only), `OA_Company_Profile__c` (canonical org intel), `OA_Knowledge_Relationship__c` (graph edges), `OA_Knowledge_Document__c` (evidence), `OA_Acquisition_Source__c` (source registry), `OA_AI_Request_Log__c` (AI telemetry).
- **Analytics:** `Campaign_Funnel_Snapshot__c`.

**Custom settings (2):** `OA_Campaign_Settings__c` (send cap/counter), `OA_Graph_Credential__c` (MS Graph client id/secret/tenant — **security debt: secret stored as Text**). **Platform event (1):** `OA_Unsubscribe_Request__e`.

**Custom metadata types (10) / 51 records** — all sample/dormant: `OA_Connector_Registry__mdt` (8 rows, all disabled), `OA_Engagement_Config__mdt` (EDWOSB_Default, active/observe-only), `OA_Enrichment_Pipeline__mdt` (10 sample steps, disabled), `OA_Enrichment_Source__mdt` (6 precedence rows, inactive), `OA_Field_Write_Policy__mdt` (22 sample policies, dormant), `OA_Qualification_Rule__mdt` (2 EDWOSB rules), `OA_AI_Model__mdt`, `OA_Graph_Config__mdt` (marketing, active).

---

## 7. Automation inventory (what runs)

**Scheduled Apex (Schedulable):** `OA_BookingPoller` (×4, 15-min; config from CMDT), `OA_DripScheduler` (enroll; hard-coded Campaign `701Pn00001ZOyj8IAD`), `OA_FollowUpScheduler` (Day 3/5/10; hard-coded Campaign + OWA `0D2Pn00000013wjKAA`), `OA_ArtifactPoller` (hourly, module), `OA_FederalAcquisitionScheduler` (dormant, unscheduled).
**Batchable:** `OA_EnrichmentOrchestrator` (+AllowsCallouts), `OA_EngagementResolverBatch` (observe-only).
**Queueable:** `OA_EnrichmentQueueable`, `OA_CandidateDiscoveryQueueable`, `OA_EngagementResolverQueueable`, `OA_AISummaryQueueable`.
**Invocable:** `OA_EmailSender` ("OA Send Template Email to Lead").
**Flows (3, all active, record-triggered):** `OA_EDWOSB_Outreach_Sequence` (CampaignMember create → Day 1), `OA_Reply_Detection` (EmailMessage create → Replied/Unsubscribed), `OA_PostMeeting_Nurture` (Lead update → Call Complete tasks).
**Trigger (1 active):** `OA_UnsubscribeRequestTrigger` (platform event).

**HTTP callouts:** Named-Credential-routed → `OA_OpenRouter`, `OA_Anthropic`, `OA_SAM`, `OA_USASpending`, `OA_Census`, `OA_SEC`, `OA_GrantsGov`, per-state registry. Direct hard-coded URLs → `OA_USASpendingClient` (api.usaspending.gov, **dead/legacy code**), `OA_FederalOpportunityAcquisition` (api.grants.gov), `OA_BookingPoller`/`OA_ArtifactPoller` (graph.microsoft.com + OAuth token endpoint).

**Email authentication (verified, closed 2026-07-10):** `onealgorithm.com` SPF authorizes M365 + Salesforce (`v=spf1 include:spf.protection.outlook.com include:_spf.salesforce.com ~all`); M365 DKIM (selector1/2) + Salesforce DKIM (salesforce1/salesforce2, live in Cloudflare, DNS-only) both resolve; DMARC `p=quarantine`. Separate outreach stack on `mycrm.onealgorithm.com` (Mailgun + GoHighLevel, DMARC `p=none`).

---

## 8. Security model

**Named Credentials (9):** `OA_Anthropic`, `OA_Census`, `OA_GrantsGov`, `OA_LinkedIn`, `OA_Meta`, `OA_SAM`, `OA_SAM_Opportunities`, `OA_SEC`, `OA_USASpending`. **External Credentials (5):** `OA_LinkedIn`, `OA_OpenRouter` (+ Development/Management), `OA_SAM`. **Remote sites (3):** MicrosoftGraph, MicrosoftLogin, OA_USASpending. Secrets live only in External Credentials (ADR-008) — **except** the `OA_Graph_Credential__c.Client_Secret__c` Text-field anti-pattern (open debt).

**Permission sets (24) + 1 PSG** — all additive/least-privilege; none grant Modify All / Customize App; only `OA_Unsubscribe_Guest_Access` grants Apex-class access. Key ones: `OA_Lead_Enrichment_Runtime` (99 fields, no delete/viewAll), `OA_Lead_Writeback_Automation` (16 write-back fields — SENSITIVE, keep unassigned), `OA_Lead_Writeback_Reviewer` (read + edit only Review_Status__c), `OA_Connector_Staging`, `OA_Engagement_Reviewer` (read-only), `OA_Executive_Analytics_Access`, plus credential-principal-only sets. **PSG `OA_Runtime_Operations`** bundles 11 runtime permsets for a future least-privilege integration user — **built, validated, unassigned** (0 spare licenses).

**External access:** a **Claude MCP Connector** (External Client App, OAuth) was connected 2026-07-10 to the org's Salesforce Hosted MCP `sobject-all` (full CRUD) server — the Claude app now has full read/write to production bounded by the login user's permissions. Use read-only prompts for audits; there is no review gate on that path.

---

## 9. Program / sprint history (chronological)

- **Phase 0 — Foundation** (2026-06-19, tag `foundation-v1`): EAC operational; SFDX 3-package project; ADR-001–004; security gate (found unidentified OAuth apps `tbid.digital`, `OIQ_Integration`, MFA gaps).
- **Phase 1 — Metadata retrieval** (Core → Marketing → PBO); **M365/Bookings** deployed 2026-06-23.
- **Lead Enrichment epic (Sprints 12–35):** framework → SAM → Wave 1 (USASpending/Census/IRS) → Wave 2 (SEC/State) → canary/pilot (`v1.0`) → async orchestrator → live pilot → production hardening (`v1.1`, **68 Leads enriched**) → program closure (Sprint 29) → callout-after-DML fix (Sprint 35) → **`v1.2`** (2026-07-08, DML bulkification, DML ~84→4 per run) → **Maintenance Mode**.
- **Program 024 series:** 024C Grants.gov pilot; **024F Production Reconciliation** (main proven == production, 41 AI/intelligence classes reconciled, superseded reverse-drift classes removed).
- **Program 025 series (activation → repair → certification):**
  - **025C — Operational Baseline** (authoritative ops doc): main==production; full suite 873 pass/7 fail (test-isolation only); `OA_Runtime_Operations` PSG built.
  - **025E — Manual ops launch** + kill switches + runtime provisioning.
  - **025F — Runtime repair:** the "0 proposals" was a measurement error; the real defect was `deriveInput` reading `Lead.UEI__c` (79) instead of `UEI_Unique_entity_Identifier__c` (13,278). Fixed with a fallback chain.
  - **025G-A — Write-back certification (attempt 1):** decision to **certify Path A only**; stopped on two mapper defects (blank `Recipient_UEI__c`, unlinked `Lead__c`).
  - **025G-B — Mapper repair + certification:** fixed both (snake_case `recipient_uei` → title-case `Recipient UEI`; added `leadId` overload); **Louis-approved cohort certification — 3 of 4 Leads written back** (Zolon Tech $97.44M / 1 Source $78.50M / 1 Sync $3.90M; @Orchard excluded — fuzzy false-positive). Cert matrix 12 PASS · 3 WARN · 0 FAIL. Found & fixed a NEW defect: `OA_LeadWritebackService` duplicate-Id abort on >1 Approved row/Lead → **one-winner-per-Lead dedupe (highest award, tie-break caller-first), deployed + merged (PR #95)**.
- **Parallel/uncommitted:** Meta/Facebook, LinkedIn/Auth, Meeting Tracking, Opportunity Intelligence design — on feature/backup branches, not main.

---

## 10. Architectural Decisions (ADRs on `main`)
- **ADR-001** Namespace: no namespace until Phase 3 (register `onealgo` ~Q1 2027).
- **ADR-002** Client isolation: one dedicated org per client; no shared multi-tenancy.
- **ADR-003** Package boundaries: Core → Module → Client Overlay; depend only same/lower layer.
- **ADR-004** Metadata retrieval: three sequential passes; read-only retrieval is the only work allowed directly on `main`.
- **ADR-005** Connector framework: one reusable SDK; NC auth; staging with human `Review_Status__c` gate; mockable ≥75%; idempotent; async/governor-safe.
- **ADR-006** Canonical data model (`OA_CanonicalOrg`).
- **ADR-007** Entity resolution: deterministic-first + mandatory human review; read-only Account association.
- **ADR-008** Security: Named/External Credentials for all callouts; no secrets in objects/CMDT/Apex/git.
- **ADR-009** Metadata registry. **ADR-010** Definition of Ready.
- **ADR-015–019 (proposed, OI, feature branch):** OI as a separate program on the shared platform; new grain/new object; human-in-the-loop is the product; keyless-first sourcing. *(ADR numbering 011–015 is unreconciled across branches — open governance item.)*

---

## 11. Operations
- **Schedulers:** 7 live cron jobs (Booking Poller ×4, Artifact Poller, Follow-Up Daily, Drip Wave-1). **No enrichment/acquisition schedule is enabled.**
- **Kill switches** (fastest-first): abort job (`System.abortJob`) → remove Runtime PSG → deactivate runtime user → revoke NC principal → disable connector (`Enabled__c=false`). Data rollback via `OA_LeadWritebackService`/`OA_ChangeLogService` snapshots; metadata rollback via `git revert` (baselines `bffa36b`/`2ab2d87`/`dbf8d12`).
- **Daily sweep** (read-only): failed jobs, exceptions, API %, cron states, campaign funnel, sends/bounces/unsubs, ERE zero-write guardrail. Escalation: bounce ≥5% or unsubscribe ≥3% cumulative → hard stop + rollback.
- **Monitoring:** telemetry objects populated; **proactive alerting not yet configured.**

---

## 12. Live vs Dormant (quick matrix)

| Status | Components |
|---|---|
| **LIVE** | EDWOSB campaign automation (drip/follow-up/governor/email/Flow); Booking Poller ×4 + Artifact Poller; unsubscribe trigger/endpoint/comm-prefs; Executive/Campaign Analytics; AI Gateway; Lead Enrichment code (v1.2, deployed) |
| **LIVE but observe-only / dormant** | ERE Phase 1 (writes shadow log only on manual batch); intelligence engines + Grants.gov intake + USASpending enrichment (deployed, **manual invocation only**) |
| **DORMANT** | All 6 connectors (`Enabled__c=false`); Lead write-back (validated, only 3 real Leads ever written); `OA_FederalAcquisitionScheduler`; **Path B ungated commit (must never run)** |
| **NOT deployed (design/branch)** | Opportunity Intelligence; `Meeting_Record__c`; SAM.gov connector in prod; Meta/LinkedIn/Auth |

---

## 13. Known tech debt / open risks
1. **Runtime user = System Admin / Modify All Data** (0 spare licenses; `OA_Runtime_Operations` PSG unassigned) — bounds unattended-automation safety, gates 24/7 scheduling. **Top risk.**
2. **Path B ungated commit** (`OA_EnrichmentWriter commitWrites=true`) — never use; candidate for disable/removal.
3. **Legacy `OA_USASpendingClient`** — same snake_case UEI latent bug; **dead code**, left untouched per Louis.
4. **Write-back deferred-rows caveat:** dedupe leaves extra same-Lead rows Approved but they won't auto-write (idempotency skip on same `Enrichment_Run_ID__c`).
5. **Field-history tracking OFF** on the 16 write-back fields → 0 `LeadHistory`; audit relies on staging snapshot (accepted).
6. **No Sandbox (TD-001, Critical)** — all changes go direct to production.
7. **TD-003 flow-state contradiction** — some docs say `OA_EDWOSB_Outreach_Sequence` deactivated; the committed flow + org show it Active (it IS active).
8. **Unidentified OAuth apps** `tbid.digital` / `OIQ_Integration` (SEC-INT-01/02).
9. **`OA_Graph_Credential__c.Client_Secret__c` stored as Text** — migrate to Named/External Credential.
10. **`OA_BookingPoller` duplicated** across `force-app` and `modules/marketing-automation` (layer-boundary violation).
11. SAM.gov data.gov key unconfirmed; Census/SEC Named Credentials not yet created.
12. Proactive monitoring/alerts not configured; 7 non-parallel-safe Apex tests could fail a future RunLocalTests deploy gate; repo lives in OneDrive (sync-risk); Salesforce Hosted MCP `sobject-all` connector gives the Claude app un-gated full CRUD to prod.

---

## 14. For a fresh operator — how to be useful safely
- **Read `docs/SESSION_STATE_025G-B.md` and this file first.** Verify Org ID `00Dbn00000plgUfEAI`.
- **Default to read-only.** Any Lead write, `Approved` status, deploy, merge, schedule, or credential change is RED → needs explicit Louis approval with numbers.
- **Enrichment writes go through Path A only**, one Approved row per Lead.
- **Return every connector to `Enabled__c=false` before ending a session.**
- The platform's job: **enrich → govern → outreach → capture → (future) rank opportunities**, all human-gated. When in doubt, choose the more restrictive tier and ask Louis.
