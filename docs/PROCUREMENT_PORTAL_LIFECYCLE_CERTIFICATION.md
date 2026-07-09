# Procurement Portal Lifecycle Certification (Program 023D)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/procurement-portal-lifecycle-certification · 2026-07-09**
**Certification/architecture only — no production changes, deployments, merges, objects, fields, or automation.** Grounded in a LIVE authenticated audit of Bonfire/Euna + prior federal-API certification (023A–C).

## 1. Executive Summary
**Answer to the core question:** One Algorithm **can** run the complete procurement lifecycle **from discovery through proposal preparation and submission *support*** within supported APIs, exports, authenticated-session access, and Terms of Service — **with one hard boundary: the actual bid *submission*, receipt confirmation, and award remain portal-only and human-performed.** Salesforce becomes the **system of record for the pursuit** (discovery, qualification, compliance, knowledge, documents, opportunity intelligence, review, capture, proposal prep, tracking); the **portal remains the system of record for the official solicitation, submission, and award**. No stage requires unsupported scraping when the pattern below is followed. Live evidence: Bonfire/Euna exposes opportunity lists + vendor profile via an authenticated (cookie-session) API and documents via each buyer's portal — usable for **authenticated-session export**, not as a sanctioned hands-off connector; federal (SAM/Grants) provides true public APIs; commercial aggregators (HigherGov/GovTribe) provide sanctioned cross-portal discovery.

## 2. Production Audit (Phase 0)
Confirmed present: connector SDK (`OA_ConnectorRunner/Http/Persistence/Context/Engine`), review queue `OA_Opportunity_Signal__c`, `OA_Company_Profile__c` (Knowledge), `OA_Opportunity_Intelligence__c`, `OA_ComplianceScreen` (org/PR #73), certified **AI Gateway** (OpenRouter), **Salesforce Files** (native), Acquisition Source registry. 0 scheduled jobs. The platform already has every subsystem the operating model needs except live connectors (intentionally dormant).

## 3. Portal Certification Matrix
Legend: SupplierAPI = a sanctioned API a *vendor* can use hands-off. AuthExport = authenticated-session read/export (browser-assisted, your own account). PASS = lifecycle manageable within ToS; WARN = manageable via AuthExport/email/aggregator (no clean supplier API); FAIL = portal-only, no supported automation.
| Portal | Supplier API | Auth model | Docs access | Export | ToS for automation | Verdict |
|---|---|---|---|---|---|---|
| **SAM.gov** | **Yes (public)** | api_key | attachment API (`resourceLinks`) | JSON | **allowed** | **PASS** |
| **Grants.gov** | **Yes (public)** | none | package download | JSON | allowed | **PASS** |
| **Bonfire / Euna** *(live-certified)* | **No** (internal cookie API `…-internal.bonfirehub.com/v1.0/vendor/{id}/projectInvites`) | **cookie session** | buyer subdomain `{buyer}.bonfirehub.com/opportunities/{id}` | via authenticated session | **automation ToS-sensitive** → AuthExport + human | **WARN** |
| **BidNet Direct** | Paid API | key | via portal/API | CSV (paid) | allowed w/ subscription | **WARN** (paid) |
| **OpenGov / Ion Wave** | limited/none | portal | portal | some export | portal-oriented | **WARN** (AuthExport/email) |
| **Jaggaer / Ivalua / Oracle** | **buyer-side API only** | OAuth/portal | portal | buyer-side | supplier=portal | **WARN/FAIL** (use aggregator) |
| **SAP Ariba** | Ariba Discovery (membership) | membership | portal | via Discovery | membership-gated | **WARN** (paid) |
| **Coupa** | buyer-side | portal | portal | buyer-side | supplier=portal | **FAIL** (portal-only) |
| **Vendor Registry** | none | portal | portal/email | limited | portal | **WARN** (email) |
| **Aggregators (HigherGov / GovTribe)** | **Yes (sanctioned)** | key/MCP | links to source docs | JSON/MCP | allowed | **PASS** (discovery; no submission) |

## 4. Document Retrieval Matrix
| Portal | Solicitation/RFP | Attachments/package | Amendments/addenda | Q&A | How |
|---|---|---|---|---|---|
| SAM.gov | Yes (description link) | **Yes** (`resourceLinks`, honor download rules) | re-poll posted window (no modified filter) | limited | **public API** |
| Grants.gov | Yes | Yes (package) | via updates | — | **public API** |
| Bonfire/Euna | Yes (buyer opp page) | **Yes** (authenticated vendor download on `{buyer}.bonfirehub.com/opportunities/{id}`; some public, full after invite acceptance) | portal (addenda notices via email + page) | portal | **AuthExport** |
| BidNet/OpenGov/others | Yes | Yes (portal/API) | portal/email | portal | portal/API/email |
**Recommended storage & integrity (all portals):** preserve the **original** file in **Salesforce Files (ContentVersion)**, never rely on the email copy when the source provides it; capture **SHA-256 checksum + source URL + retrieved-at + version/amendment** for provenance/citation; link Document → Signal → (buyer) Company Profile. Amendment tracking = version chain + field diff. **Document ownership stays with the issuing agency** — we store for pursuit use, not redistribution.

## 5. Procurement Lifecycle — automation level per stage
| Stage | Level | Where |
|---|---|---|
| Opportunity published | **Automated** (federal API) / **AuthExport** (Bonfire) | Portal/API → SF |
| Vendor invitation | **AuthExport** (Bonfire `projectInvites`) | Portal API → SF |
| Document download | **Automated** (SAM/Grants) / **AuthExport** (portal) | Portal → SF Files |
| Qualification | **Automated** (normalize → dedup) | Salesforce |
| Compliance review (go/no-go) | **Semi-auto** (`OA_ComplianceScreen` recommends) → **Human approves** | SF + human |
| Capability match | **Semi-auto** (Knowledge Foundation) | Salesforce |
| Teaming | **Semi-auto** (Partner Intelligence recommends) → **Human** | SF + human |
| Question submission | **Human** (portal) — SF drafts | Portal + human |
| Amendment monitoring | **Semi-auto** (re-poll/email detect) → **Human review** | SF + portal |
| Proposal development | **Semi-auto** (AI assists) → **Human authors** | SF + human |
| Proposal review | **Human** | SF + human |
| **Submission** | **PORTAL-ONLY + HUMAN** (never automated) | Portal + human |
| Receipt confirmation | **Portal** (SF records) | Portal → SF |
| Clarifications | **Human** (portal) | Portal + human |
| Award | **Portal/notification** (SF records) | Portal → SF |
| Contract / performance / closeout | **SF as SoR** (human-driven) | Salesforce |

## 6. System-of-Record Matrix
| Concern | Authoritative system |
|---|---|
| Official solicitation record, amendments, submission, receipt, award | **Portal / agency** |
| Original documents (preserved copy) | **Salesforce Files** (provenance to portal) |
| Discovery, qualification, dedup, pursuit pipeline | **Salesforce (`OA_Opportunity_Signal__c`)** |
| Eligibility / go-no-go recommendation | **Compliance Engine** (human decides) |
| Company/partner capability + knowledge | **Knowledge Foundation** |
| Scoring / next best action / brief | **Opportunity Intelligence** |
| AI extraction/telemetry | **AI Gateway + logs** |
| Notifications / amendment alerts (secondary) | **Email (Graph)** — notification/reconciliation only |
| Go/No-Go, teaming, submission decisions | **Human reviewer** (approval gate) |

## 7. Administrative Capability Matrix (authenticated vendor account — live-certified on Bonfire/Euna)
| Capability | Support level (Bonfire evidence) |
|---|---|
| View / search / filter opportunities | **API** (`projectInvites`) |
| Download documents | **AuthExport** (buyer opp page) |
| Bookmark / watch lists / notifications | Portal + `vendors/me` (`isOptedInToNotifications`) |
| Commodity/keyword management | **API** (`vendors/me`: `keywords`, `excludedKeywords`) |
| Profile management | **API** (`vendors/me` full profile) |
| Opportunity / status / submission / award history | Portal (dashboard counters: Invitations/WIP/Submitted/Awarded/Contracts) — **AuthExport** |
| Question / submission history | Portal — **AuthExport / manual** |
Officially-supported public API for hands-off third-party automation: **No** (internal API); authenticated-session export: **Yes**; manual/browser: **Yes**.

## 8. Document Intelligence Assessment
AI Gateway (OpenRouter, structured-JSON) can reliably extract, with confidence + manual-review thresholds: agency, solicitation number, NAICS, PSC, set-aside, submission deadline, place of performance, contract value, deliverables, evaluation criteria, mandatory certifications, required documents, questions, amendments. **Deterministic fields** (dates, IDs, NAICS/PSC) → high confidence (cheap model + regex cross-check); **semantic fields** (requirements, eval criteria, win themes) → mid model + **human review below a confidence threshold**. Extraction on-demand at review; checksum cache; cheapest capable model; optional Apache-2.0 sidecar (Tika/Unstructured) for scanned PDFs; **reject PyMuPDF (AGPL)**.

## 9. Salesforce Operating Model
Salesforce runs the **Business Development Operating System**: Discovery (connectors + AuthExport → `OA_Opportunity_Signal__c`) → Qualification (dedup/normalize) → Compliance (go/no-go) → Knowledge (capability/partner) → Documents (Files + AI extraction) → Opportunity Intelligence (score/NBA/brief) → Review queue (human gate) → Assignments/Tasks → Proposal prep (AI-assisted) → Portal + Amendment tracking → Executive dashboards → Capture → Contract transition. The portal is a **spoke** (source + submission surface); Salesforce is the **hub** (pursuit SoR). Email is a **notification/reconciliation** spoke.

## 10–11. Legal & Governance Review
**Legal (per portal):** SAM/Grants public APIs — automation allowed, documents are US-gov works. Bonfire/Euna — internal API + portal; **automated third-party access is ToS-sensitive**, so use **authenticated-session export for your own account** (as done here) and **human-performed** submission; do not redistribute agency documents. Aggregators — sanctioned APIs under subscription terms (verify redistribution/AI-use). **Governance:** human approval is the only production decision point; system writes `Pending`; no auto-Opportunity; no auto-submission; no scraping where a supported path exists; read-only email; credentials in Named/External Credentials (never in code); audit every callout + AI call; retain documents with provenance.

## 12. Automation Boundaries (what MAY be automated)
Discovery, retrieval (via API/AuthExport), normalization, dedup, document extraction, compliance *recommendation*, capability/partner *matching*, scoring, brief generation, amendment *detection*, notification, dashboards, pursuit tracking.

## 13. Human Approval Boundaries (what must NOT be automated)
**Go/No-Go decision, teaming commitment, question/clarification submission, proposal authoring sign-off, and — absolutely — bid SUBMISSION, pricing commitment, and any binding action on a portal.** These are legal/binding and remain human + portal-only.

## 14. Risks
Bonfire internal-API/ToS (mitigate: AuthExport + human, not hands-off connector); SAM 10-req/day + no modified-date (mitigate: large limit + re-poll); credential/session fragility (Named Credentials, no stored passwords); document redistribution (store-not-redistribute); aggregator terms (verify); over-automation of submission (hard-blocked by design).

## 15. Technical Debt
Delete `OA_HdrEcho` debug NC; merge/close open PRs (#69–76 + this); provision SAM data.gov key; least-privilege runtime user; Lightning dashboards; document-intelligence build; incremental-sync fields on the registry.

## 16. Recommended Architecture
**Hub-and-spoke, authoritative-source-first:** Federal API connectors (SAM/Grants) + aggregator integration (HigherGov/GovTribe) + **authenticated-session export** for portals like Bonfire (your account, read/export) → OCDS-normalized `OA_Opportunity_Signal__c` → Compliance + Knowledge + OI → human review → (human) proposal + **portal submission**. Documents → Salesforce Files with provenance. Email → notification/reconciliation. Nothing binding is automated.

## 17. Exact Automation Opportunities
1. SAM/Grants federal ingestion (API). 2. Aggregator SLED discovery (HigherGov/GovTribe API). 3. Bonfire authenticated-session **export of invitations** (`projectInvites`) + profile/keywords (`vendors/me`). 4. Document extraction (AI Gateway → structured fields). 5. Compliance go/no-go recommendation. 6. Amendment detection (re-poll/email). 7. Executive dashboards + pursuit tracking.

## 18. Exact Manual Steps Remaining
Accepting an invitation; final Go/No-Go; teaming commitment; submitting portal questions; authoring/sign-off of the proposal; **the bid submission itself**; pricing commitment; clarification responses; anything binding on the portal.

## 19. Portal-by-Portal PASS/WARN/FAIL
SAM.gov **PASS** · Grants.gov **PASS** · HigherGov/GovTribe **PASS** (discovery) · Bonfire/Euna **WARN** (AuthExport + human; no hands-off connector) · BidNet **WARN** (paid) · SAP Ariba **WARN** (membership) · OpenGov/Ion Wave/Vendor Registry **WARN** (AuthExport/email) · Jaggaer/Ivalua/Oracle **WARN/FAIL** (buyer-side only → aggregator) · Coupa **FAIL** (portal-only). **Submission at every portal: portal-only + human (by design).**

## 20–22. Repository / Commit / PR
`docs/PROCUREMENT_PORTAL_LIFECYCLE_CERTIFICATION.md` · commit + PR below.

## 23. Exact Next Engineering Program
**024 — Federal Authoritative Ingestion (Grants.gov now; SAM.gov on data.gov key)** into the OCDS-normalized review queue with document capture to Salesforce Files + AI extraction + compliance go/no-go — the first live, ToS-clean lifecycle slice (discovery→documents→qualification→compliance→review), human-gated, no submission automation. Bonfire/aggregator export is a fast-follow (024D).

---
**Certification verdict — PASS:** every major portal certified (Bonfire/Euna live), document retrieval understood, full lifecycle mapped, system-of-record assigned per stage, Salesforce's role defined (pursuit hub), automation + human boundaries explicit (submission always human), no unsupported automation recommended, no ToS violated, and the design supports a future end-to-end Business Development Operating System.
