# Enterprise Opportunity Acquisition — Connector Architecture (Program 023A)

**Org 00Dbn00000plgUfEAI · Branch feature/authoritative-connector-architecture · 2026-07-09**
**Design/architecture only — no automation, no scheduled jobs, no deployment, no merge.** Repositions the platform around **authoritative systems of record**; Outlook becomes notification/reconciliation only.

## 1. Executive Summary
The acquisition platform must be built on **authoritative APIs**, not email. The decisive architectural insight: **~100 government portals run on a small set of underlying eProcurement PLATFORMS**, and the **vast majority of federal opportunities are published to just two authoritative APIs (SAM.gov + Grants.gov)**. Therefore the enterprise design is **not** N portal scrapers — it is:
- **2 authoritative federal API connectors** (SAM.gov, Grants.gov) covering most federal contract + grant opportunities across every agency;
- **~8–10 platform adapters** (Jaggaer, Ivalua, SAP Ariba, Coupa, OpenGov, Ion Wave, Bonfire, Periscope/mdf, Vendor Registry, BidNet) that each certify dozens of state/local portals via one integration + config;
- **1 paid aggregator option** (Deltek GovWin IQ) that can short-circuit state/local coverage with a single API;
- **Outlook as the notification/reconciliation/fallback layer only**;
- **Certification bodies handled as a compliance calendar** (renewal tracking), not connectors (no APIs);
- all riding on the **existing reusable connector SDK** (`OA_ConnectorRunner/Http/Persistence`), feeding the **existing review queue** (`OA_Opportunity_Signal__c`) under human gates.

This reduces an unbounded scraping problem to **~12 governed, ToS-clean integrations + config-driven source expansion**.

## 2. Production Audit (reuse-first)
| Asset | State | Role in this architecture |
|---|---|---|
| Connector SDK (`OA_ConnectorRunner`, `OA_ConnectorHttp`, `OA_ConnectorPersistence`, `OA_ConnectorContext`, `OA_IConnector*`) | built | **the framework** every adapter implements |
| `OA_Acquisition_Source__c` | 10 records | source registry (extend with platform + scorecard) |
| `OA_Opportunity_Signal__c` | deployed, 10 | canonical review queue |
| `OA_ComplianceScreen` | built | eligibility engine |
| `OA_Company_Profile__c` / Knowledge Foundation | 2 profiles | compliance + capability inputs |
| `OA_AI_Gateway` + log | certified, 14 logs | document/AI extraction |
| SAM connector classes (`OA_SAMOpportunities_*`) | built | reference connector (needs NC + key) |
| Grants.gov connector | built, dormant | authoritative grants |
| Named Credentials | OA_SAM, OA_Census, OA_SEC, OA_USASpending, OA_Anthropic, OA_OpenRouter×3, OA_Meta, OA_LinkedIn, OpenAI, OA_HdrEcho* | *OA_HdrEcho = leftover debug NC, recommend delete |
| Scheduled jobs | **none** | governance clean (no unattended automation) |

## 3. Source Inventory & Platform Grouping (the key reduction)
**Federal — 2 authoritative APIs cover the field.** Every federal agency (DoD/Army/Navy/Air Force, DOE, DOT, HHS/NIH, NSF, VA, EPA, USDA, Commerce, Interior, Justice, Treasury, DLA, NASA SEWP) publishes **contract** opportunities to **SAM.gov** and **grant/assistance** opportunities to **Grants.gov**. FedConnect/GSA eBuy largely mirror SAM. So "20 federal agencies" = **SAM.gov API + Grants.gov API** (+ SBIR.gov API for SBIR/STTR). Agency portals are fallbacks, not primary.

**State/Local — collapse to platforms.** (portal → underlying platform)
| Platform | Portals it powers (examples) | Supplier integration |
|---|---|---|
| **Jaggaer** | PA (SRM), many state/university systems | Buyer-side REST API mature; supplier discovery via portal/email |
| **Ivalua** | OhioBuys, several states | Buyer-side API; supplier via portal |
| **SAP Ariba** | large commercial + some gov | **Ariba Discovery** (supplier alerts + API, membership-gated) |
| **Coupa** | commercial + gov | Coupa Supplier Portal; API buyer-side |
| **Oracle Procurement** | some states/agencies | iSupplier portal; API enterprise-gated |
| **OpenGov (ProcureNow)** | many municipalities | Vendor portal + email; limited public API |
| **Ion Wave** | municipal/state (e.g. some TX/MO) | Vendor portal + email alerts |
| **Bonfire** | municipal/higher-ed | Vendor portal + email invitations; limited API |
| **Periscope / mdf commerce** | COMMBUYS (MA), BidNet Direct | **BidNet has a paid API** + email; Periscope buyer-side |
| **Vendor Registry** | many county/city | Registration + email bid notices |
Certifying **one adapter per platform** covers **all** portals on that platform (config = base URL + credentials per instance).

**Commercial aggregators:** BidNet Direct (mdf) — paid API + email; **Deltek GovWin IQ** — paid intelligence API spanning federal/state/local (highest coverage, subscription cost).

**Partner ecosystems (APIs, credential-gated):** Salesforce (PRM API), Zendesk (REST+token), AWS (Partner Central API), Microsoft (Partner Center API), Google (Partner Advantage), ServiceNow, Oracle, Cisco, Adobe, Red Hat — each a partner-intelligence feed into Knowledge Foundation, not opportunity intake.

**Certifications/registrations (NO APIs → compliance calendar):** SBA (SAM entity reflects socioeconomic), WBENC (WBENCLink), NMSDC, VA SWaM (SBSD), NC HUB, NY VendRep — portal-only; tracked as **renewal deadlines**, never scraped.

## 4. Connector Certification Matrix (by class)
Full per-source detail in `SOURCE_CERTIFICATION_MATRIX.md`. Summary of certified integration paths (highest-governance available):
- **API (GO):** SAM.gov, Grants.gov, SBIR.gov, BidNet Direct (paid), GovWin IQ (paid), Ariba Discovery (membership), Zendesk/AWS/MS partner APIs.
- **Buyer-side API only / supplier via portal+email (PLATFORM ADAPTER + email reconcile):** Jaggaer, Ivalua, Coupa, Oracle, OpenGov, Ion Wave, Bonfire, Periscope, Vendor Registry.
- **Email alert + authoritative reconcile:** anything whose portal lacks a supplier API — the email tells us *what* exists; the authoritative platform/API (or portal export) provides the *record + documents*.
- **Compliance calendar (no connector):** all certification bodies.
- **Never:** scraping where any supported path exists; browser automation where an API exists.

## 5. Canonical Opportunity Model
One normalized model across all sources (maps to `OA_Opportunity_Signal__c` + extensions):
**Required:** source, source system-of-record ID, solicitation/notice number, title, agency/buyer, type (RFP/RFQ/RFI/IFB/Sources Sought/Grant/Award), posted date, response deadline, canonical key (dedup), URL, review status.
**Optional/enriched:** NAICS, PSC/commodity codes, set-aside, place of performance/geography, estimated value/funding, contract vehicle, point of contact, submission instructions, evaluation criteria, amendment number + parent, incumbent, attachments manifest.
**Document sub-model:** file name, type (PDF/DOCX/XLSX/ZIP), authoritative URL, version/amendment, checksum, retrieved-at, storage ref (Salesforce Files).
**Compliance sub-model:** eligibility decision, rationale, missing requirements, required certs, teaming requirement.
All sources normalize into this; source-specific fields live in a raw-payload reference for audit.

## 6. Document Strategy
Retrieve documents from the **authoritative source**, never from email attachments when the source provides them (email attachments = backup only). Per platform: SAM.gov (attachment API + resource links, honor download rules), Grants.gov (package download), platform adapters (authenticated export/download of the bid package), Bonfire/OpenGov (portal document download via authenticated session, ToS permitting). Preserve originals in **Salesforce Files** linked to the signal; extract structured fields via **AI Gateway** (one call/txn). Never depend on email for a document the system of record offers.

## 7. Compliance Architecture
`OA_ComplianceScreen` (built) generalized: evaluate **EDWOSB / WOSB / MBE / SWaM / HUB / SDVOSB / 8(a) / HUBZone** vs set-aside; **contract-vehicle** eligibility (GSA schedule, GWAC, IDIQ); **geography** (place of performance vs registrations); **agency requirements**; **security clearances**; **NAICS/PSC** size standard; **experience/past-performance** (from Company Profile); **partner requirement**. Output **GO / NO-GO / TEAMING / REVIEW REQUIRED** + rationale + missing requirements. Deterministic + auditable; AI only explains. Consumes the Self Company Profile (One Algorithm = EDWOSB) + registration/certification renewal state (compliance calendar).

## 8. Connector Framework (reusable — every connector implements)
Extend the existing SDK with a standard lifecycle interface:
`Authenticate() → Enumerate() → Fetch() → Normalize() → DownloadDocuments() → Extract() → Validate() → Deduplicate() → Compliance() → Knowledge() → OpportunityIntelligence() → ReviewQueue() → Audit()` — cross-cut by `Retry()`, `Telemetry()`, and `FailureHandling()`. Registry-driven (`OA_Acquisition_Source__c` gains `Platform__c`, config, and scorecard fields); `Type.forName` dispatch (no per-source branches), **callout-before-DML**, ≤50 records/txn, idempotent upsert on Canonical_Key (reuse `OA_ConnectorPersistence`). No connector auto-creates an Opportunity; all publish to the review queue as `Pending`.

## 9–13. Telemetry / Retry / Security / Credential Architecture
- **Telemetry:** every run → `OA_Connector_Run__c` (records fetched/normalized/deduped/errors, latency, source, checkpoint); every AI call → `OA_AI_Request_Log__c` (tokens/cost). Dashboards read these.
- **Retry:** exponential backoff on 429/5xx; per-source rate-limit config; **dead-letter** to an exception queue (reuse `OA_Enrichment_Exception__c` pattern); checkpoint + resume via incremental sync token (last posted-date / cursor) stored on the source registry.
- **Security:** least-privilege permsets per subsystem (pattern established); no secrets in code/logs/docs; documents stored in Salesforce Files with object-level sharing.
- **Credentials:** **all** auth via Named/External Credentials (never passwords in code). API keys/OAuth/certs per source as External Credentials; partner + paid-aggregator tokens are **gated secrets** (provisioned by Louis, never created here). data.gov key + `OA_SAM_Opportunities` NC is the immediate gate. `OA_HdrEcho` debug NC → delete.

## 14. Governance Review
Human approval is the **only** production decision point (ADR-018): system writes `Pending`; a human promotes to CRM Opportunity (G5). No scheduled/unattended AI without explicit approval (scheduling is a STOP). No auto-Opportunity. No scraping. No ToS violation. Read-only for email. This design **adds no automation** — it is the blueprint; each connector is a separately-approved, dormant-first build.

## 15. Failure Mode Analysis (nothing silent)
No API → platform adapter or email reconcile; auth failure → dead-letter + alert; rate limit → backoff + checkpoint; ToS prohibits → email/deadline only; missing solicitation# → flagged REVIEW; duplicate → Canonical_Key upsert; document unreadable → staged, "missing docs"; ineligible set-aside → NO-GO/TEAMING; expired cert → compliance missing-requirement; source down → run marked failed, resumes from checkpoint; AI failure → gateway reason logged, deterministic parts proceed; budget exceeded → gateway non-success, logged.

## 16. Recommended Engineering Sequence (ROI-ranked)
- **Immediate (highest ROI, lowest risk):** activate **SAM.gov** (data.gov key + NC) + **Grants.gov** (already built) → authoritative federal coverage across all agencies. Effort: low (code exists). Impact: high.
- **Near-term:** **BidNet Direct API** (paid — covers many local govts already in the inbox) + **email→SAM/Grants reconciliation** (turn the 146 emails/10d into authoritative records). Effort: medium.
- **Medium-term:** platform adapters in inbox-frequency order — **Ivalua (OhioBuys), Bonfire, Jaggaer, OpenGov, Ion Wave**; **Zendesk/AWS/MS partner APIs** → Knowledge Foundation. Effort: medium each, reused across portals.
- **Long-term / optional:** **Deltek GovWin IQ** (paid, broad state/local) as a coverage accelerator; **Ariba Discovery**; compliance-calendar automation for renewals. Effort/cost: high.

## 17. Outlook Repositioning
Outlook is demoted to: **notification** (first signal a solicitation exists) · **fallback ingestion** (when no API/adapter yet) · **amendment detector** (cross-check "Addendum" emails vs source) · **cross-check/reconciliation** (verify authoritative record captured) · **attachment backup**. **Never** the authoritative record. Every email is reconciled to a system-of-record entry where one exists.

## 18–19. Technical Debt / Risks
Debt: SAM NC + data.gov key (gate); platform-adapter builds; incremental-sync/checkpoint fields on registry; document-extraction build; partner-API credentials; `OA_HdrEcho` cleanup. Risks: low (design only) — but each connector build carries ToS + credential + maintenance risk, mitigated by the highest-governance-path rule and dormant-first deployment.

## 20. Verdict — PASS (architecture)
Every source class certified for its highest-governance path · every source rankable (scorecard) · engine built around authoritative systems (SAM/Grants + platform adapters) · Outlook strictly notification/reconciliation · no unsupported automation recommended · no ToS violated · reusable framework · human approval the only production decision point.
