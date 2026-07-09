# Enterprise Ecosystem Research & Build-vs-Reuse Certification (Program 023B)

**Org 00Dbn00000plgUfEAI · Branch feature/ecosystem-certification-build-vs-reuse · 2026-07-09**
**Research/certification only — no features, objects, fields, connectors, deploys, or merges.** Extends 023A architecture + the OSS deep dive. Challenges the assumption that One Algorithm should build everything.

## 1. Executive Summary
The ecosystem survey produces **three architecture-changing recommendations that cut technical debt sharply**:
1. **Align the canonical opportunity model to the Open Contracting Data Standard (OCDS)** — a mature JSON-schema international standard (50+ governments). Do **not** invent a model. Map US sources (SAM/FPDS) into OCDS's tender/award/document/organization structure.
2. **INTEGRATE the SLED (state/local) long-tail via a commercial aggregator — HigherGov (free/low-cost API) and/or GovTribe (which shipped the first GovCon MCP server, Feb 2026, directly consumable by our Claude/OpenRouter AI Gateway)** — instead of BUILDING dozens of platform adapters (Jaggaer/Ivalua/Bonfire/OpenGov/Ion Wave). This is the single largest technical-debt reduction available.
3. **BUILD only the two authoritative federal API connectors (SAM.gov + Grants.gov) in Apex** (already coded); **REUSE** the AI Gateway (+ optional Apache-2.0 doc sidecar) for extraction; **REUSE** Salesforce-native primitives (Files, Platform Cache, Named Credentials, Flow/Queueable) for storage/cache/auth/workflow. Invent nothing that a mature standard or platform primitive already provides.
Net: the platform shrinks from "~100 scrapers + custom everything" to **2 federal API connectors + 1 commercial SLED integration + standards alignment + Salesforce-native plumbing**, with human approval the only production gate. **Authoritative-source-first is preserved** (aggregators cite authoritative IDs; we reconcile).

## 2. Platform Audit (already exists — reuse-first)
26 custom objects, 86 Apex classes, a mature **connector SDK** (`OA_ConnectorRunner/Http/Persistence/Context/Engine`, `OA_IConnector*`), 13 permsets, ~12 Named Credentials, certified **AI Gateway** (OpenRouter), **Knowledge Foundation**, **Opportunity Intelligence**, **Compliance engine**, **Review queue**, **Acquisition Source registry**. Zero scheduled jobs. **Most subsystems already exist** — the remaining gap is *authoritative ingestion*, which this program shows is largely a standards + integration problem, not a build problem.

## 3. Open-Source Survey (beyond GitHub)
- **Standards bodies:** Open Contracting Partnership (**OCDS** — the key finding), Open311/OpenReferral/CKAN (civic data; not procurement-core), Data Standards Directory.
- **Integration/ETL (CNCF/Apache/Linux Foundation):** Apache Camel, Apache NiFi, Airbyte, Singer (Apache-2.0), Meltano (MIT), n8n, Node-RED — **reference the incremental-sync/tap patterns**; do not run external ETL (keeps data flow in-org, auditable).
- **Document/AI:** Apache Tika (Apache-2.0), Unstructured (Apache-2.0), pdfplumber (MIT), LlamaIndex/LangChain (reference only, where appropriate) — **reuse via the AI Gateway or optional sidecar**; **reject PyMuPDF (AGPL-3.0)**.
- **Metadata/catalog:** OpenMetadata, DataHub — over-engineered for this scope; **reject** (Salesforce reports + registry suffice).
- **Government OSS:** GSA `srt-fbo-scraper` (gov public domain — NLP reference), USDR `entity-api`, `makegov/awesome-procurement-data` (catalog), 18F/USDS archives — **reference**, not adopt (wrong runtime).
- **Search/vector:** OpenSearch — heavyweight; defer (Salesforce SOSL + AI Gateway embeddings if ever needed).

## 4. Commercial Platform Survey
| Platform | What | Access | Cost | Verdict |
|---|---|---|---|---|
| **HigherGov** | Federal opps/awards/contacts aggregator | **Free tier + API** | free → ~$500/yr | **INTEGRATE** (best value; API-first) |
| **GovTribe** | Fed+SLED aggregator, ML recs, **MCP server (50+ tools, Claude/Copilot)** + API | **MCP + API** | ~$1,350–1,800/yr | **INTEGRATE** (MCP plugs into our AI stack) |
| **Deltek GovWin IQ** | Analyst pre-RFP intel, 46M txns, 100k+ SLED | API (enterprise) | $2–5k+/mo | **PURCHASE only if** analyst pre-RFP intel justifies cost (long-term) |
| BidNet Direct | Local-gov aggregator | Paid API + email | paid | Integrate (near-term) or email |
| eProcurement platforms (Jaggaer/Ivalua/Ariba/Coupa/Oracle/OpenGov/Ion Wave) | portal software | buyer-side APIs | — | **Avoid building adapters** if a commercial aggregator covers them |
| Salesforce/Microsoft/Zendesk/AWS/Azure Marketplaces + Partner APIs | ecosystems | APIs | varies | Integrate for **partner intelligence** (→ Knowledge Foundation) |
**Key:** a single **HigherGov/GovTribe** subscription likely covers more SLED opportunities, more reliably and legally, than a year of custom adapter engineering — and GovTribe's **MCP server** is natively consumable by the platform's Claude/OpenRouter layer.

## 5. Government Reference Implementations
Authoritative federal APIs: **SAM.gov Get Opportunities** (data.gov key), **Grants.gov search2**, **FPDS** (ATOM/XML), **USASpending** (REST — already have `OA_USASpending` NC), **SBIR.gov**, **GSA CALC/eLibrary**. These are the systems of record; MIT reference clients (sam-search, pysam) validate field mappings. Auth = API key/none; incremental sync via date cursors; retry/telemetry are our responsibility (Singer pattern reference).

## 6–7. Industry & Procurement Standards
- **Canonical model → OCDS** (JSON schema; releases with tender/award/contract/document/organization; supports `itemClassificationScheme`). **Adopt as the target structure.**
- **Classification:** **NAICS** (industry/"who", US) + **PSC** (product-service/"what", US federal/FPDS) are **US-authoritative** — store both. **UNSPSC** (global) + **CPV** (EU) are optional crosswalks for commercial/international alignment; crosswalks are imperfect (no perfect official map) — store the authoritative code, map opportunistically. **Do not invent taxonomies.**
- Identifiers: use **UEI/CAGE** (already in `OA_Discovered_Organization__c`) for orgs; OCDS `party`/`organization` id scheme for interop.

## 8. Enterprise Architecture Assessment
Integration points: **AI Gateway** ← GovTribe MCP + document extraction; **Knowledge Foundation** ← HigherGov/GovTribe entity + partner-API data; **Acquisition Engine** ← SAM/Grants APIs (build) + aggregator API (integrate) → **Review Queue** (OCDS-normalized `OA_Opportunity_Signal__c`); **Compliance Engine** ← NAICS/PSC/set-aside from normalized signals; **Microsoft Graph** = notification/reconciliation only. Everything terminates at the human-gated review queue.

## 9. Build vs Reuse Matrix (every major subsystem)
| Subsystem | Decision | Why |
|---|---|---|
| Federal acquisition (SAM/Grants) | **BUILD (Apex)** — done | authoritative APIs; no SF-native option; code exists |
| SLED acquisition (state/local) | **INTEGRATE** (HigherGov/GovTribe) | aggregator cheaper + legal + broader than N adapters |
| Connector framework | **REUSE (own SDK)** | already built + governed |
| Canonical opportunity model | **REUSE standard (OCDS)** | mature; don't invent |
| Classification taxonomy | **REUSE (NAICS+PSC)** | US-authoritative; UNSPSC optional |
| Document extraction / PDF / OCR / metadata | **REUSE (AI Gateway + optional Apache-2.0 Tika/Unstructured sidecar)** | permissive, mature; reject PyMuPDF (AGPL) |
| Compliance engine | **REUSE (own `OA_ComplianceScreen`)** | deterministic, auditable, built |
| Knowledge graph / relationship intel | **REUSE (own Company Profile + relationships)** | built; OpenMetadata/DataHub over-engineered → reject |
| Search / vector storage | **DEFER/REUSE (Salesforce SOSL; AI Gateway embeddings if needed)** | OpenSearch heavyweight |
| Workflow / scheduling | **REUSE (Salesforce Flow/Queueable/Scheduled Apex)** | native; scheduling is a governance STOP |
| Telemetry / monitoring | **REUSE (own `OA_Connector_Run__c` + AI log + Salesforce reports)** | built |
| Retry / dead-letter | **BUILD-lite (platform)** | thin layer on the SDK + exception object |
| Deduplication / entity resolution | **REUSE (Canonical_Key + UEI/CIK patterns)** | built in enrichment/BLO |
| Document storage | **REUSE (Salesforce Files/ContentVersion)** | native, versioned |
| Authentication / secrets | **REUSE (Named/External Credentials)** | never passwords in code |
| Rate limiting / caching | **BUILD-lite / REUSE (Platform Cache)** | native cache; per-source limits in registry |
| ETL orchestration | **REFERENCE (Singer patterns); do not run external ETL** | keep data in SF governance |

## 10. Licensing Matrix
| License | Examples | Verdict |
|---|---|---|
| MIT / BSD / Apache-2.0 | sam-search, pysam, pdfplumber, Tika, Unstructured, Singer, Meltano core | **SAFE** (reference or self-host) |
| MPL-2.0 / LGPL | some libs | Acceptable if not statically linked into distributed code (we don't distribute) |
| **AGPL-3.0** | **PyMuPDF** | **REJECT** (network-use source disclosure) |
| **Elastic License v2 / BSL** | some Airbyte connectors, some DBs | **CAUTION** — not OSI; verify per-use; avoid offering-as-service |
| GPL-3.0 | various | Avoid embedding in proprietary code |
| Commercial | HigherGov/GovTribe/GovWin, Tika-commercial N/A | **SUBSCRIPTION** (integrate, no code risk) |
| US-gov public domain | GSA repos | Safe (reference) |

## 11. Security Assessment
Nothing is adopted into the org, so **no in-org supply-chain exposure**. Commercial APIs (HigherGov/GovTribe) and optional doc sidecars are reached via **Named Credential** (secrets in External Credentials, callout-audited). Reject anything needing stored portal passwords or headless-browser credentials, or with stale maintenance/known CVEs. Auditability preserved (every callout + AI call logged). Aggregator tokens/keys = **gated secrets** (provisioned by Louis).

## 12. Long-Term Maintenance Assessment
- **Lowest maintenance:** standards alignment (OCDS) + commercial aggregator integration (vendor maintains the scrapers/coverage) + Salesforce-native primitives.
- **Highest maintenance (avoid):** custom per-portal adapters (brittle to portal changes), self-run ETL, embedded document libraries.
- **Our-code maintenance:** SAM/Grants Apex connectors (stable APIs), compliance engine (rules), AI Gateway (stable). Acceptable.

## 13. Technology Risk Matrix
| Tech | Legal | Security | Maintenance | Strategic | Overall |
|---|---|---|---|---|---|
| SAM/Grants APIs | low | low | low | high value | **LOW — build** |
| HigherGov/GovTribe integration | low (subscription) | low (API) | low (vendor) | high | **LOW — integrate** |
| OCDS alignment | none | none | low | high | **LOW — adopt** |
| Custom SLED adapters | ToS medium | brittle | **high** | low | **HIGH — avoid** |
| PyMuPDF / AGPL | **high** | — | — | — | **REJECT** |
| Bid scrapers | **high (ToS)** | brittle | high | low | **REJECT** |
| GovWin IQ | low | low | low | high | cost-gated |

## 14. Strategic Opportunities
GovTribe **MCP server** ↔ our **AI Gateway/Claude** = a native, low-code opportunity-intelligence feed. HigherGov **free API** = immediate SLED coverage at ~$0. **OCDS** alignment future-proofs interop and any future data-sharing. Partner-ecosystem APIs (Salesforce/MS/AWS) → Knowledge Foundation partner intelligence.

## 15. Technologies Rejected
PyMuPDF (AGPL) · all bid scrapers (ToS/brittle) · OpenMetadata/DataHub (over-engineered) · self-run external ETL (governance) · headless-browser credentialed automation · any unstated-license project.

## 16. Technologies Recommended
**Adopt-as-standard:** OCDS, NAICS+PSC. **Integrate:** HigherGov API, GovTribe (MCP+API), SAM/Grants/USASpending/SBIR APIs, partner APIs. **Reuse (self-host optional, permissive):** Apache Tika / Unstructured / pdfplumber. **Reference:** Singer patterns, MIT SAM clients, awesome-procurement-data.

## 17. Integration Opportunities
SAM/Grants → Acquisition Engine · HigherGov/GovTribe API + **GovTribe MCP → AI Gateway** · Tika/Unstructured → document extraction · partner APIs → Knowledge Foundation · Graph → notification/reconciliation. All → OCDS-normalized review queue.

## 18. Five-Year Technology Roadmap
- **Yr 1:** SAM+Grants Apex connectors (build, gated key) · **HigherGov free API integration** (SLED coverage) · OCDS canonical alignment · document extraction via AI Gateway.
- **Yr 2:** GovTribe MCP/API integration into AI Gateway · partner-ecosystem APIs → Knowledge Foundation · compliance-calendar automation · optional Tika/Unstructured sidecar.
- **Yr 3:** evaluate GovWin IQ (analyst pre-RFP) if pipeline scale justifies · deeper OCDS interop · vector search only if volume demands.
- **Yr 4–5:** monitor OCDS US-adoption (DATA Act amendments), federal procurement modernization, MCP-standardized GovCon data, AI infra (OpenRouter model economics). **Avoid:** proprietary lock-in, AGPL, custom SLED scrapers.
**Monitor:** OCDS US adoption, GovCon MCP ecosystem, HigherGov/GovTribe API evolution, Salesforce AI/Agentforce, OpenRouter pricing. **Avoid:** scraping frameworks, copyleft doc libs, heavyweight catalogs.

## 19. Engineering Recommendations
1. Build **only** SAM + Grants (authoritative federal). 2. **Integrate**, don't build, SLED (HigherGov/GovTribe). 3. **Adopt OCDS** for the canonical model (a future additive field-mapping, human-approved). 4. Extraction via AI Gateway (+ optional Apache-2.0 sidecar). 5. Reuse Salesforce-native storage/cache/auth/workflow. 6. Reject scrapers + AGPL.

## 20. Technical-Debt Reduction Opportunities
Replacing custom SLED adapters with a commercial API removes the single largest future maintenance liability. OCDS alignment prevents a bespoke-schema debt. Salesforce-native plumbing avoids external-infra debt. Cleanup: delete leftover `OA_HdrEcho` NC; consolidate connector generations (legacy vs active) per the connector-cleanup audit.

## 21. Verdict — PASS (research/certification)
Comprehensive OSS + commercial + government survey done · standards identified (OCDS/NAICS/PSC) and preferred over invention · licensing + security + maintenance reviewed · every major subsystem has a Build-vs-Reuse decision · recommendations cut technical debt · architecture stays authoritative-source-first · human approval remains the only production decision point.

## Sources
open-contracting.org/data-standard · standard.open-contracting.org · en.wikipedia.org/wiki/Open_Contracting_Data_Standard · HigherGov/GovTribe/GovWin comparisons (jorpex.com, fed-spend.com, g2.com) · UNSPSC/NAICS/PSC/CPV (ungm.org, buildingradar.com, taxonomymap.ai) · github.com/makegov/awesome-procurement-data · apache/tika · Unstructured-IO/unstructured · (023A OSS deep dive).
