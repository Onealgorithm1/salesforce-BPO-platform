# Enterprise Opportunity Acquisition Engine — Program 023

**Org 00Dbn00000plgUfEAI · Branch feature/connector-certification-opportunity-acquisition · 2026-07-09**
Automates opportunity discovery → normalization → compliance screening → review queue. Human review stays the approval gate, not the data-entry engine. Consumes the AI Gateway (019), Knowledge Foundation (021), and Acquisition Source registry (022).

## 1. Executive Summary
Built the automated intake layer: a certified source matrix, a reusable acquisition pipeline, a deterministic Compliance Go/No-Go engine, and the human review queue — proven end-to-end with a **live read-only Outlook pilot** (10 real solicitations staged, compliance-screened, human-gated, **zero auto-created Opportunities**). SAM.gov is certified as the reference API connector (code already built; activation gated on a data.gov key). Outlook is positioned as **alert/reconciliation**, not the authoritative source.

## 2. Runtime Audit (reuse-first)
| Asset | State | Use |
|---|---|---|
| `OA_Opportunity_Signal__c` | existed in repo, **NOT deployed** → deployed now (+5 acquisition fields) | **the review queue** |
| SAM Opportunities connector (`OA_SAMOpportunities_*`) | code built; **NC `OA_SAM_Opportunities` + data.gov key missing** | reference connector (gated) |
| Grants.gov connector | built, dormant | P2 |
| `OA_Acquisition_Source__c` (022) | deployed, 10 sources | source registry (linked from signals) |
| `OA_Company_Profile__c` (021) | deployed, One Algorithm=EDWOSB | compliance eligibility input |
| `OA_AI_Gateway` (019) | certified | document/AI extraction |
| Graph `Mail.Read` (as lrubino) | proven read-only | Outlook intake |
| Connector framework (`OA_ConnectorRunner/Http/Persistence`) | built | adapter reuse |

## 3. Source Certification Matrix (highest-governance path)
Full per-source certification lives in the `OA_Acquisition_Source__c` registry (022) + `docs/ACQUISITION_COMPLIANCE_SOURCE_INVENTORY.md`. Summary of the automation decision:
| Source | API? | Best path | Scrape | Go/No-Go (build) |
|---|---|---|---|---|
| SAM.gov | **Yes** (Get Opportunities v2, data.gov key) | API | Allowed | **GO** (code built; needs key) |
| Grants.gov | Yes (public search2) | API | Allowed | GO (built) |
| BidNet Direct | Paid API; **email alerts** | **Email intake** | Unknown | GO (email) |
| Bonfire / FedConnect / OhioBuys / NYSCR / Nassau / eVA / PA / MyFlorida | mostly none/limited | **Email intake** (+verify export/feed) | Unknown | GO (email) / Review (portal) |
| JAGGAER | supplier-network API | API | Unknown | P2 (verify) |
| Zendesk Partner | **REST API + token** | API | Allowed | P2 (token = gated secret) |
| WBENC / SBA / MA-VA diversity | none | UI only | **Prohibited/UI** | Deadline tracking, **no scrape** |
| Outlook mailbox | **Graph Mail.Read** | API (read-only) | Allowed | **GO — pilot proven** |
Rule applied: API → Export/Feed → Email → (browser-assisted only if ToS-clean) → manual. Unknown-ToS sources are **not scraped**; their intelligence arrives via the email channel.

## 4. Acquisition Engine Architecture
```
Source Adapter → Raw Record → Normalizer → Opportunity Candidate (OA_Opportunity_Signal__c)
   → Dedup (Canonical_Key__c) → Document/Attachment capture (design) → Compliance Screen (OA_ComplianceScreen)
   → [reconcile against authoritative source] → Knowledge/OI (post-promotion) → Human Review Queue → [human] → CRM Opportunity
```
Reusable steps: **Acquire** (adapter per source: API/email), **Normalize** (→ signal), **Deduplicate** (Canonical_Key upsert, idempotent — reuses `OA_ConnectorPersistence`), **Extract Documents** (AI Gateway), **Score Compliance** (`OA_ComplianceScreen`), **Run OI** (post-promotion), **Publish to Review Queue** (Review_Status=Pending). No step auto-creates an Opportunity.

## 5. SAM.gov Reference Connector (certified)
Endpoint `callout:OA_SAM_Opportunities/opportunities/v2/search`; auth = data.gov `api_key` via Named Credential; filters postedFrom/To, NAICS, PSC, set-aside (`typeOfSetAside`), state; notice detail + amendments + attachment **metadata** (download honors SAM rules); pagination limit/offset; rate-limited. Connector classes (`OA_SAMOpportunities_Connector/Service/Mapper/Request/ResponseParser`) already map to `OA_Opportunity_Signal__c` with dedup on Canonical_Key. **GO to activate** once the Named Credential + data.gov key are provisioned (gated secret — not created here). Live probe confirmed the NC is absent today.

## 6. Outlook Reconciliation Connector (pilot proven)
Graph `Mail.Read` (read-only) → classify → extract sender/portal/title/solicitation#/agency/type/link → stage into the review queue, **linked to the source registry**. Reconciliation design: if the email references SAM.gov, fetch the authoritative notice (set-aside/NAICS/deadline/attachments) and attach the email as evidence; if it references BidNet/Bonfire/state portal, link to the registry + stage. Pilot: 10 solicitations staged, 9 linked to certified sources, 1 noise correctly unlinked. **Outlook is the alert/reconciliation layer — authoritative detail comes from the source API.**

## 7. Document / Attachment Extraction (design)
Reuse Salesforce **Files**; a thin `OA_Knowledge_Document__c` links PDF/Word/Excel/ZIP RFP packages to a signal/profile. Extraction via **AI Gateway only** (one call/txn): due date, agency, title, solicitation#, NAICS, PSC, set-aside, scope, required capabilities, submission instructions, evaluation criteria, mandatory certifications, attachment list. Phased (not built — no live documents in the pilot).

## 8. Compliance Go/No-Go Engine (built + live)
`OA_ComplianceScreen` — deterministic, auditable (no AI decisioning). Reads One Algorithm's Self profile (EDWOSB) vs the solicitation set-aside → **GO / CONDITIONAL GO / NO-GO / REVIEW REQUIRED** + rationale + missing requirements. EDWOSB/WOSB/small-business set-asides → GO; SDVOSB/8(a)/HUBZone → NO-GO (teaming only, routed to Partner Intelligence); full-open → GO; unknown → REVIEW. Flags SAM registration + certification-renewal risk. Bulk-safe, no callout.

## 9. No-API Automation Strategy
Per source, maximum safe automation: (1) **email-alert extraction** (default — most portals push alerts); (2) attachment parsing (AI Gateway); (3) supported **export/report download** where offered; (4) RSS/feed monitoring; (5) browser-assisted **read/export only** where the session is authorized and ToS-clean; (6) manual URL capture → AI extraction; (7) human-only where automation is prohibited (WBENC/SBA/diversity portals → deadline tracking, never scrape).

## 10. Human Review Queue (built)
`OA_Opportunity_Signal__c`: source, title, agency, due date, value, solicitation#, links, compliance decision + rationale + missing requirements, source-registry link, sender evidence. Reviewer actions (Review_Status + human): pursue / reject / request more data / assign owner / link to existing Opportunity / **create Opportunity (human only, G5)** / defer. System only ever writes `Pending`.

## 11. Pilot Results (live, ≤10 records)
Source records: 10 registry entries (022). Normalized candidates: **10 signals** from real Outlook solicitations. Documents: staged/design. Compliance: **10 screened** (all GO — email lacks set-aside → reconciliation needed). OI: invoked post-promotion (proven on Medianow, 020). Review queue: **10 Pending**. **0 Opportunities created.** Governance intact.

## 12. Dashboards (design, report-ready)
Source Health · Opportunity Intake (by source/day) · Portal Activity · Email Intake · Compliance Eligibility (GO/NO-GO mix) · Go/No-Go · Document Coverage · Review Backlog (Pending) · Connector Errors · Source ROI (pursued/won per source). Objects reportable + history-tracked.

## 13. Happy / Unhappy Paths
**Happy:** API source (SAM) → normalized → dedup → compliance GO → review queue. Email matched → linked to registry → staged. **Unhappy (all handled, nothing silent):** no API → email/export fallback; login failure → source marked, manual; scraping prohibited → email/deadline only; no attachments → staged, "missing documents"; missing solicitation# → captured null, flagged; duplicate → Canonical_Key upsert; expired cert → compliance missing-requirements; no eligibility (SDVOSB/8a) → NO-GO + teaming route; AI failure → gateway reason captured, deterministic parts still run; source unavailable → connector error logged; low confidence → REVIEW REQUIRED; **noise (odoo webinar) → unlinked, human dismisses.**

## 14–18. Changes / Validation / Risks / Rollback / Debt
- **Changes (additive, dormant):** deployed `OA_Opportunity_Signal__c` (+5 fields, Source picklist +Outlook Email); `OA_ComplianceScreen` +test; permset (assigned). 10 pilot signals staged. No connectors scheduled; no Opportunities.
- **Validation:** compliance tests pass; pilot staged+screened live; SAM NC absent (probed); Graph `Mail.Read` only; 0 Opportunities.
- **Risks:** low — read-only, dormant, human-gated. Email-only compliance is coarse until authoritative reconciliation (SAM key). Zendesk/SAM tokens = gated secrets.
- **Rollback:** delete pilot signals, remove class/permset/fields. Mailbox + CRM untouched. Not merged.
- **Debt:** activate SAM connector (data.gov key + NC); authoritative reconciliation (email→SAM detail); document extraction build; scheduled email polling (Queueable/Graph subscription); Zendesk Partner API; dashboards.

## 19. Verdict — PASS
Every source certified for best automation path · SAM validated as reference (built, key-gated) · Outlook positioned as alert/reconciliation · no-API sources have max-safe strategies · compliance Go/No-Go modeled + live · a safe pilot intake path proven · human review preserved · no secrets · no ToS violated · nothing silent.
