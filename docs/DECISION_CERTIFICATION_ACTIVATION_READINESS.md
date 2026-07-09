# Granular Decision Certification & Activation Readiness (Program 023C)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/decision-certification-activation-readiness · 2026-07-09**
**Research/certification only — no features, objects, fields, connectors, deploys, or merges.** Converts 023A/023B into an executable Program 024 sequence.

## 1. Executive Summary
The decision is settled and evidence-backed: **Program 024 builds two authoritative federal API connectors (Grants.gov — public, no key, buildable today; SAM.gov — gated on a data.gov key), normalizes both to an OCDS-aligned shape that the existing `OA_Opportunity_Signal__c` review queue already supports (no new fields required for MVP), runs documents through the AI Gateway, and integrates HigherGov's free API for SLED long-tail — not custom adapters.** One decision is blocked (HigherGov API redistribution/AI-use terms — sales-gated) but does not block the federal build. The single credential that unblocks the highest-value work is a **data.gov API key + `OA_SAM_Opportunities` Named Credential**. Everything else is READY or Claude-executable.

## 2. Production / Repository Audit (exact evidence)
- Org **00Dbn00000plgUfEAI** ✓ · **26** custom objects · **86** Apex classes (non-test) · **13** permsets · **0** scheduled jobs · **0** pending async jobs (governance clean).
- Named Credentials: `OA_Anthropic, OA_Census, OA_HdrEcho*, OA_LinkedIn, OA_Meta, OA_OpenRouter (+_Development,_Management), OA_SAM, OA_SEC, OA_USASpending, OpenAI`. **Missing: `OA_SAM_Opportunities`, `OA_GrantsGov`.** *(`OA_HdrEcho` = leftover debug NC → delete.)*
- Acquisition assets present (repo): `OA_Acquisition_Source__c`, `OA_Opportunity_Signal__c`, `OA_Opportunity_Intelligence__c`, `OA_Company_Profile__c`, `OA_Knowledge_Relationship__c`, `OA_AI_Request_Log__c`, `OA_Connector_Run__c`; connector SDK; `OA_ComplianceScreen`; SAM/Grants connector classes (built).
- Open PRs: **#69–#75** (AI cert, OI, Knowledge, Sources, Acquisition Engine, Architecture, Ecosystem) — all **unmerged**. Older #57–#68 also open.

## 3. Commercial Integration Certification (ranked)
| Platform | API | MCP | Free tier | Auth | Pricing | Coverage | Disposition |
|---|---|---|---|---|---|---|---|
| **HigherGov** | Yes | — | **Yes** + API | key | free → ~$500/yr | Fed opps/awards/contacts; some SLED | **INTEGRATE** *(conditional — verify redistribution/AI-use terms; see Blockers)* |
| **GovTribe** | Yes | **Yes (GovCon MCP, 50+ tools)** | trial | key | ~$1,350–1,800/yr | Fed + SLED, forecasts, contacts | **INTEGRATE** (MCP → AI Gateway; fast-follow) |
| **Deltek GovWin IQ** | Yes | — | no | enterprise | $2–5k+/mo | Fed+SLED+analyst pre-RFP | **PURCHASE (DEFER)** — only if pipeline scale justifies |
| **BidNet Direct** | Paid API | — | no | key | paid | local-gov aggregator | **INTEGRATE (near-term)** or email-reconcile now |
| **Bonfire / OpenGov / Ion Wave / Ivalua / Jaggaer / Ariba / Coupa / Oracle** | buyer-side / limited supplier API | — | — | OAuth/portal | — | single-platform | **DEFER/REJECT building adapters** — covered by aggregator; email-reconcile if in inbox |
| **Vendor Registry** | limited | — | — | portal | — | county/city | **DEFER** (email) |
| **Zendesk Partner** | REST | — | — | token | subscription | partner ecosystem | **INTEGRATE (partner intel → Knowledge Foundation)** — token gated |
| **Salesforce Partner (PRM)** | Yes | — | — | OAuth | — | partner | **REFERENCE/DEFER** |
| **Microsoft Partner Center** | Yes | — | — | OAuth | — | partner | **DEFER** |
| **AWS Partner Central / Marketplace** | Yes | — | — | role/OAuth | — | partner | **DEFER** |
**Ranking:** HigherGov (1, value+free) → GovTribe (2, MCP-native) → BidNet (3) → Zendesk partner (4) → GovWin (5, cost-gated) → platform adapters (reject-building).

## 4. Federal API Deep Certification (readiness matrix)
| API | Endpoint | Auth | Incremental | Docs/Attach | Set-aside/NAICS/PSC | Rate limit | NC/EC | Readiness |
|---|---|---|---|---|---|---|---|---|
| **SAM.gov Opportunities v2** | `https://api.sam.gov/opportunities/v2/search` | **api_key** (data.gov) | `postedFrom/To` (MM/dd/yyyy, ≤1yr); **no modified-date** → re-poll window for amendments | **Yes** (`resourceLinks` + description) | `typeOfSetAside` (SBA/8A/HZC/WOSB), `ncode` NAICS, PSC in payload | **role-based daily request cap** (non-federal ~10/day; mitigate: `limit=1000` + narrow NAICS = 10k records/day capacity) | **`OA_SAM_Opportunities` NC + EC (api_key)** — **BLOCKED on key** | **PARTIAL — code built, credential blocked** |
| **Grants.gov search2** | `https://api.grants.gov/v1/api/search2` | **none (public)** | `openDate/closeDate` filters; date windows | package links | assistance listings (CFDA); no NAICS/set-aside | generous (public) | `OA_GrantsGov` NC (public URL) | **READY — buildable today** |
| **FPDS** | atom/xml feed | none | LAST_MOD_DATE | — (awards) | PSC/NAICS in data | feed | NC | REFERENCE (awards, not opps) |
| **USASpending** | REST (`OA_USASpending` NC exists) | none | date | — | NAICS/PSC | generous | present | REUSE (awards/spend enrichment) |
| **SBIR.gov** | REST | none | date | links | — | — | NC | NEAR-TERM |
| **GSA eLibrary / CALC** | REST | key/none | — | — | schedules/labor | — | NC | REFERENCE (vehicle/labor-rate) |
| **GSA eBuy** | holder portal, no open API | login | — | portal | — | — | — | REJECT (portal-only) |
| **FedConnect** | no public API | — | — | portal/email | — | — | — | REJECT (mirrors SAM; reconcile) |
**Design constraints locked:** SAM incremental = daily posted-date window with overlap for late postings; amendment detection = re-fetch recent window (no modified filter); pagination = limit=1000/offset; documents = fetch `resourceLinks` honoring SAM download rules → Salesforce Files.

## 5. OCDS Canonical Mapping (field-level; SAM/Grants → OCDS → Signal)
| Concept | SAM field | Grants field | OCDS path | `OA_Opportunity_Signal__c` | Status |
|---|---|---|---|---|---|
| Canonical id | `noticeId` | `id` | `ocid`/`id` | `Canonical_Key__c` | **present** |
| Solicitation # | `solicitationNumber` | `opportunityNumber` | `tender.id` | `Opportunity_Number__c` | **present** |
| Title | `title` | `title` | `tender.title` | `Title__c` | **present** |
| Agency | `fullParentPathName`/department | `agencyName` | `buyer.name`/`parties` | `Agency__c` | **present** |
| Sub-agency/office | `subtier`/`office` | — | `parties[]` | `Agency_Code__c` (+ raw) | present (partial) |
| NAICS | `naicsCode` | — | `tender.items.classification` (scheme=NAICS) | `NAICS__c` | **present** |
| PSC | `classificationCode` | — | `...additionalClassifications` (scheme=PSC) | `PSC__c` | **present** |
| Set-aside | `typeOfSetAside` | — | `tender.otherRequirements` | `Set_Aside__c` | **present** |
| Place of perf | `placeOfPerformance` | — | `tender.deliveryLocation` | `Place_of_Performance__c` | **present** |
| Posted date | `postedDate` | `openDate` | `tender.datePublished` | `Posted_Date__c` | **present** |
| Response deadline | `responseDeadLine` | `closeDate` | `tender.tenderPeriod.endDate` | `Response_Deadline__c` | **present** |
| Value/funding | award `amount` | `estimatedFunding` | `tender.value`/`award.value` | `Estimated_Value__c` | **present** |
| Type | `ptype` | `docType` | `tender.status`/method | `Type__c` | **present** |
| Assistance listing | — | `cfdaList` | `planning.budget` | `Assistance_Listing__c` | **present** |
| Source URL | `uiLink` | opportunity link | `tender.documents.url` | `URL__c` | **present** |
| Documents/attachments | `resourceLinks[]` | package links | `tender.documents[]` | **Salesforce Files** (link via `Raw_Payload_Ref__c`) | **strategy set** |
| Raw fidelity | full JSON | full JSON | full release | `Raw_Payload_Ref__c` → stored JSON/File | **present** |
| Compliance | derived | derived | (n/a) | `Compliance_Decision/Rationale/Missing__c` (PR #73) | present (unmerged) |
| Audit/review | — | — | (n/a) | `Review_Status/Reviewed_By/At`, `Source_Run_ID`, `Confidence` | **present** |
**Recommendation (evidence-backed): NO new fields for MVP.** The queue already covers every OCDS-critical field; store full OCDS/raw JSON in `Raw_Payload_Ref__c` (or a linked File) for fidelity. **Defer** (do not add yet): point-of-contact, full description, amendment number/parent, Q&A, procurement-method, incumbent — add only when a dashboard/compliance/OI need is proven. Compliance + OI + dashboards are already satisfied by present fields.

## 6. Document Intelligence Architecture
Storage: **Salesforce Files (ContentVersion)** linked to the signal; preserve **original** (never email copy when source provides it); **SHA-256 checksum** + source URL + retrieved-at for citation/provenance; version per amendment. Extraction: **AI Gateway first** (OpenRouter) with a structured-JSON prompt (due date, agency, solicitation#, NAICS, PSC, set-aside, scope, submission instructions, eval criteria, mandatory certs, attachment list) + confidence; **deterministic pre-parse via optional Apache-2.0 sidecar (Tika/Unstructured/pdfplumber) only for scanned/complex PDFs**; **OCR** only when a PDF is image-only (sidecar). Amendment comparison = diff extracted fields across versions. Failure: unreadable → staged "document unreadable", human review; low confidence → REVIEW. Cost control: extract on-demand at review (not bulk), cheapest capable model, cache by checksum. **Reject PyMuPDF (AGPL).**

## 7. AI Model Benchmark Plan (no paid bulk runs without approval)
Tasks × recommended role:
| Task | Recommended model class | Structured-JSON | Notes |
|---|---|---|---|
| Solicitation classification, NAICS/PSC/set-aside/deadline extraction | **cheap fast** (gpt-4o-mini / Haiku-class via OpenRouter) | required (JSON mode) | high volume, low cost |
| Compliance-requirement + eligibility summary, go/no-go explanation | **mid** (Sonnet-class) | required | reasoning + citations |
| Opportunity/executive summary, amendment comparison, doc Q&A | **mid/large** (Sonnet/Opus-class) | partial | quality-sensitive |
Compare (via existing gateway/registry): OpenRouter catalog (340+ models) covering Anthropic/OpenAI/Google/open models. Dimensions per class: accuracy (spot-check set), cost/1k tok, latency, context length (need ≥32k for full RFPs), JSON reliability, citation reliability. **Evaluation dataset:** a 20–30 solicitation gold set (hand-labeled: correct NAICS/PSC/set-aside/deadline) drawn from the 10 staged pilot signals + SAM samples once the key is live. Metric: field-level exact-match + deadline accuracy. Run **small, gated** (≤ a few $ ) — not bulk.

## 8. Opportunity Intelligence Benchmark (vs commercial)
| Capability | One Algorithm | HigherGov/GovTribe/GovWin | Decision |
|---|---|---|---|
| Opportunity summary / scorecard / next-best-action / go-no-go | **Yes (OI + Compliance, governed, AI)** | partial (GovWin analyst-rich) | **differentiator (governed + Salesforce-native)** |
| Company/partner knowledge profiles + gap analysis | **Yes (Knowledge Foundation)** | limited | **differentiator** |
| Recompete/incumbent/award history/agency forecast | **No** | **Yes (esp. GovWin)** | **INTEGRATE** (USASpending/FPDS for award history; GovTribe/GovWin for forecast) |
| Buyer/contact discovery | partial (Contacts) | Yes | INTEGRATE (HigherGov/GovTribe contacts) |
| Contract-vehicle analysis, teaming recs, pipeline forecast, bid/no-bid, win-theme | partial (teaming via Knowledge; compliance go/no-go) | Yes | **build later** (teaming/win-theme = Proposal Intelligence) / integrate forecast |
| Competitor tracking | No | Yes | ignore for now (integrate later) |
**Gaps to integrate (not build):** recompete/incumbent/forecast/award-history/contacts → USASpending (have) + HigherGov/GovTribe. **Differentiators to keep building:** governed OI scorecard, Knowledge Foundation, compliance go/no-go, Salesforce-native review + human gate. **Ignore for now:** competitor tracking, deep analyst forecasts (GovWin territory).

## 9. Financial ROI Model (build-vs-buy)
Assumptions (order-of-magnitude, to be tuned with Louis): eng ≈ $150/hr equiv; SAM+Grants connector ≈ 40–60 hr (code exists → ~20 hr to activate/harden); each custom SLED adapter ≈ 40–80 hr + ongoing maintenance ≈ 1–2 hr/mo/portal (brittle); AI extraction ≈ $0.002–0.01/opportunity; Salesforce storage marginal; HigherGov ≈ $0–500/yr; GovTribe ≈ $1.4k/yr; GovWin ≈ $30–60k/yr.
| Scenario | One-time | Annual run | Coverage | Maintenance risk | Verdict |
|---|---|---|---|---|---|
| **1. Federal build + commercial SLED integrate** | low (activate SAM/Grants) | ~$0–1.8k (HigherGov/GovTribe) + tokens | Fed authoritative + broad SLED | **low** | **RECOMMENDED** |
| 2. Federal build + build SLED adapters | **high** (N×40–80hr) | high maintenance | Fed + partial SLED | **high (brittle)** | reject |
| 3. Commercial aggregator first (skip federal build) | low | subscription | broad but not authoritative-first | low | not authoritative-first → no |
| 4. Email-first fallback only | ~0 | ~0 | noisy, coarse | low | violates rules (email≠source) |
| 5. **Hybrid authoritative-first** (= Scenario 1 + email reconcile + GovTribe MCP) | low | ~$0–1.8k + tokens | best | low | **RECOMMENDED (=1 refined)** |
**Break-even:** custom SLED adapters never break even vs a ~$500–1,800/yr aggregator once maintenance is counted. **Recommended financial path: Scenario 1/5** — build federal (near-zero marginal, code exists), integrate HigherGov (free) for SLED, add GovTribe (~$1.4k) when MCP value proven. **Executive summary:** authoritative federal build is cheap and already coded; SLED is cheaper to rent than to build and maintain.

## 10. Production Activation Readiness (Program 024)
| Item | Status | Owner | Next action |
|---|---|---|---|
| data.gov API key (SAM) | **BLOCKED** | **Louis** | request at api.data.gov / SAM account |
| `OA_SAM_Opportunities` Named+External Credential | **PARTIAL** | Claude (build) + Louis (secret) | Claude deploys NC/EC skeleton; Louis enters key (UI, like OpenRouter) |
| `OA_GrantsGov` Named Credential (public URL) | **READY** | Claude | deploy (no secret) |
| SAM/Grants connector code | **READY** (built) | Claude | validate + activate dormant |
| Review queue `OA_Opportunity_Signal__c` (+compliance fields) | **PARTIAL** (main has 26; +5 on PR #73) | Louis (merge) / Claude (redeploy) | merge #73 or redeploy fields |
| Compliance engine | **READY** (PR #73) | — | reuse |
| AI Gateway / model registry | **READY** | — | reuse |
| Permission sets / FLS / object perms | **READY** (patterns exist) | Claude | acquisition permset assign |
| Least-privilege runtime user | **PARTIAL** | Louis | reuse oauser or provision least-priv (open risk noted in prior programs) |
| Scheduled jobs / polling | **NOT NEEDED yet / BLOCKED by governance** | Louis | scheduling requires explicit approval (STOP) — manual/Queueable pilot first |
| Monitoring / dashboards | **PARTIAL** (objects reportable) | Claude | build Lightning dashboards (design done) |
| Exception / retry / dead-letter | **PARTIAL** | Claude | reuse `OA_Enrichment_Exception__c` pattern |
| Audit logging | **READY** (`OA_Connector_Run__c` + AI log) | — | reuse |
| Rollback / backup / test / pilot plan | **READY** (documented) | Claude | per work packages below |
| Human review procedure / runbook | **PARTIAL** | Claude | write runbook |
| Business + compliance owner approval, production deploy approval | **BLOCKED** | **Louis** | approve per work package |

## 11. Risk Register
| Risk | Tier | Mitigation |
|---|---|---|
| SAM non-federal 10 req/day cap | **med** | limit=1000 + narrow NAICS; few daily requests; federal-role key if available |
| No SAM modified-date filter (amendment latency) | med | re-poll recent posted-date window; diff on re-fetch |
| HigherGov redistribution/AI-use terms unknown | med | **verify before storing/redistributing** (blocker) |
| data.gov key = personal, 90-day expiry | med | store in External Credential; rotation runbook |
| Least-priv runtime user still MAD/oauser | med (standing) | provision least-priv before 24/7 |
| Scheduling = unattended AI | gov | keep manual/Queueable + explicit approval |
| Document volume/token cost | low | on-demand extraction, checksum cache, cheap models |
| Legacy vs active connector generations | low | consolidate (connector-cleanup audit) |

## 12. Technical Debt Register
Delete `OA_HdrEcho` debug NC · merge/close the 7 open acquisition PRs (#69–75) to avoid drift · consolidate legacy connector generation (OA_IConnector/OA_ConnectorEngine vs active OA_IEnrichmentConnector/OA_ConnectorRunner) · add incremental-sync/checkpoint fields to `OA_Acquisition_Source__c` when connectors activate · least-priv runtime user · Lightning dashboards for OI/Knowledge/Acquisition.

## 13. Build / Integrate / Buy / Defer / Reject Matrix
**BUILD (Apex, now):** SAM.gov (gated), Grants.gov (today). **INTEGRATE:** HigherGov (conditional terms), GovTribe (MCP), USASpending (have), Zendesk partner, SAM/Grants docs→Files. **BUY (defer):** GovWin IQ, BidNet API. **REUSE:** AI Gateway, Compliance, Knowledge, review queue, connector SDK, Salesforce Files/Cache/Named-Creds/Flow, OCDS standard, NAICS+PSC. **REFERENCE:** FPDS, GSA eLibrary/CALC, MIT SAM clients, Singer patterns, Tika/Unstructured (optional sidecar). **DEFER:** platform adapters, MS/AWS/SF partner APIs, vector search, competitor tracking. **REJECT:** all scrapers, PyMuPDF (AGPL), OpenMetadata/DataHub, GSA eBuy/FedConnect (portal-only), email-first architecture, auto-Opportunity creation.

## 14. Blockers (explicit, per protocol)
1. **SAM.gov data.gov API key + `OA_SAM_Opportunities` NC** — *what:* live federal contract ingestion; *why:* secret not provisioned (NC absent, probed); *evidence missing:* the key value; *who:* **Louis** (api.data.gov / SAM account); *decision now:* build NC/EC skeleton + activate Grants.gov (no key) in parallel.
2. **HigherGov API redistribution / caching / AI-use terms** — *what:* whether we can store/redistribute/AI-process HigherGov data in Salesforce; *why:* API docs/terms sales-gated (docs.highergov.com behind demo/account; not publicly fetchable); *evidence missing:* the API ToS/DPA; *who:* **Louis** (HigherGov account/sales) or Claude if given a doc URL/login; *decision now:* disposition = **INTEGRATE-conditional** — do not store/redistribute until terms confirmed; free-tier eval is fine.
3. **Production deploy + merge approvals** — *who:* Louis; *decision now:* all builds staged dormant + PRs; no deploy without approval.

## 15. Decisions Louis Must Make
1. Provision the **data.gov API key** (+ approve `OA_SAM_Opportunities` NC). 2. Confirm/obtain **HigherGov API terms** (or a subscription) before data storage. 3. Approve **merging** the acquisition PRs (#69–75) or keep dormant-on-branches. 4. Approve the **least-privilege runtime user** vs continuing on oauser. 5. Decide on **GovTribe (~$1.4k/yr)** subscription for MCP + SLED. 6. Approve each **production deploy** in the 024 sequence.

## 16. Decisions Claude Can Execute (no new blockers)
Activate **Grants.gov** (public, no secret); deploy the **`OA_SAM_Opportunities` NC/EC skeleton** (Louis adds the key, like OpenRouter); validate/harden the built SAM/Grants connector code; wire connectors → OCDS-normalized signal (no new fields); reuse compliance + OI + review queue; build dashboards; write the runbook; delete `OA_HdrEcho`. All dormant-first, human-gated.

## 17. Exact Program 024 Work Breakdown
- **024A — Grants.gov Authoritative Ingestion (READY, no credential).** Objective: activate the built Grants.gov connector → OCDS-normalized `OA_Opportunity_Signal__c` (Pending) + compliance screen. Deps: none. Creds: none. Objects: signal (reuse). Code: `OA_GrantsGov*` + `OA_GrantsGov` NC. Tests: connector mapping + dedup + compliance. Validation: staged signals + run log. Rollback: delete signals, remove NC. Risk: **low**. Complexity: **S**. Success: N grant opportunities staged, deduped, screened, 0 Opportunities created. Stop: production deploy approval.
- **024B — SAM.gov Credential Skeleton + Activation (BLOCKED on key).** Objective: deploy `OA_SAM_Opportunities` NC/EC (api_key AuthHeader pattern, like OpenRouter); Louis enters key; activate built SAM connector with limit=1000 + NAICS filters + posted-date window + `resourceLinks` capture. Deps: 024A patterns. Creds: **data.gov key (Louis)**. Objects: signal (reuse). Code: `OA_SAMOpportunities_*`. Tests: mapping/pagination/dedup/amendment re-poll. Validation: live pilot ≤10 signals. Rollback: remove NC/signals. Risk: **med** (rate cap). Complexity: **M**. Success: live SAM opportunities staged + documents linked. Stop: **credential + deploy approval**.
- **024C — Document Intelligence (AI Gateway).** Objective: fetch `resourceLinks`/Grants packages → Salesforce Files (checksum/provenance) → AI-Gateway structured extraction (on-demand at review) → enrich signal + compliance. Deps: 024A/B. Creds: none (gateway live). Code: new `OA_DocumentIntelligence` (Files + gateway; one call/txn). Tests: extraction mock + confidence + failure path. Risk: **med**. Complexity: **M**. Success: a solicitation's documents parsed to structured fields with citations. Stop: deploy approval; bulk-AI cost approval.
- **024D — SLED Integration (HigherGov) [conditional].** Objective: integrate HigherGov free API → OCDS-normalized signals for SLED. Deps: **HigherGov terms (Blocker 2)**. Creds: HigherGov key (Louis). Code: `OA_HigherGov*` adapter on the SDK. Risk: **med (terms)**. Complexity: **M**. Success: SLED opportunities staged, source-linked, human-gated. Stop: **terms + credential**.
- **024E — Dashboards + Runbook + Least-Priv (ops).** Objective: Lightning dashboards (intake/compliance/review-backlog/source-health), runbook, least-priv runtime user. Deps: 024A+. Risk: low. Complexity: S–M. Success: operational visibility + governed runtime.
Sequence: **024A now → 024B on key → 024C → 024D on terms → 024E**. Each dormant-first, PR-gated, human-approved.

## 18. Recommended Immediate Next Action
**Start 024A (Grants.gov) — it is READY today with no credential** — while Louis provisions the **data.gov key** to unblock 024B (SAM). This delivers live authoritative federal grant ingestion immediately and proves the full pipeline (normalize → dedup → compliance → review queue) end-to-end before the gated SAM work.

## 19. Verdict — PASS
Every commercial platform evaluated + disposition assigned · every federal API deep-certified (endpoints/auth/limits/incremental/docs) · OCDS mapping is **field-level** (and shows no new fields needed for MVP) · document intelligence actionable · AI benchmark specific + measurable with a gold-set plan · financial ROI modeled across 5 scenarios · activation readiness granular (READY/PARTIAL/BLOCKED/NOT NEEDED + owner + next action) · next sequence broken into executable work packages 024A–E · blockers explicit · no scraping · email = notification/reconciliation only · human review = approval gate · no production changes.

## 20–22. Repository / Commit / PR
`docs/DECISION_CERTIFICATION_ACTIVATION_READINESS.md` · commit + PR below.

## 23. Final One-Paragraph Executive Recommendation
Build the two authoritative federal API connectors and rent the rest: activate **Grants.gov today** (no credential), stand up the **SAM.gov** connector the moment Louis provides a **data.gov API key**, normalize both to an **OCDS-aligned** shape the existing review queue **already supports without new fields**, extract documents through the **AI Gateway** into Salesforce Files, and **integrate HigherGov/GovTribe** for the state-local long-tail instead of building brittle adapters — all dormant-first, human-gated, with email strictly as notification/reconciliation. This is the lowest-cost, lowest-debt, authoritative-source-first path, and it is executable now starting with Program 024A.
