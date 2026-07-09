# Open-Source Deep Dive (Program 023A / 024 Addendum)

**2026-07-09 · Mandatory pre-implementation OSINT before any connector build.** Grounds the build-vs-reuse decision in real, licensed, maintained projects. Governance rule preserved: authoritative-source-first, API over scraping, no ToS violations, no unsafe/abandoned/copyleft adoption.

## 1. Executive Summary
The open-source landscape confirms the architecture rather than replacing it. **No production-grade, Salesforce/Apex-native procurement connector exists** — every relevant project is Python/Java/Rust and external to Salesforce. Therefore "reuse" means **referencing API contracts, field mappings, incremental-sync patterns, and (optionally) calling permissively-licensed document-extraction engines as external sidecars** — *not* adopting foreign-runtime code into the org. The authoritative federal APIs (SAM.gov, Grants.gov, FPDS, USASpending, SBIR) are well-documented and have MIT-licensed reference clients that validate our already-built Apex `OA_SAMOpportunities_*` connector. **Every "bid scraper" found is scraping-first (ToS/legal/brittleness risk) and is rejected.** Document extraction should use the certified **AI Gateway** first, with **Apache Tika / Unstructured / pdfplumber (all permissive)** as optional sidecars — and **PyMuPDF (AGPL-3.0) is rejected** for SaaS.

## 2. Best Open-Source Projects Found
| Project | URL | What | Lang | License | Activity | Verdict |
|---|---|---|---|---|---|---|
| **makegov/awesome-procurement-data** | github.com/makegov/awesome-procurement-data | Curated catalog of US procurement data sources + official APIs (SAM, FPDS, USASpending, SBIR, CALC, FAR) | list | (list) | maintained | **REFERENCE** (authoritative source inventory) |
| **MindPetal/sam-search** | github.com/MindPetal/sam-search | Python client for SAM.gov **Get Opportunities** API (search by NAICS) | Python | **MIT** | 161 commits, active | **REFERENCE** (API contract + field mapping for our Apex connector) |
| **jpleger/pysam** | github.com/jpleger/pysam | Minimal Python SAM opportunities client | Python | **MIT** | 6 commits, 13★ — thin | **REFERENCE only** (too small to depend on) |
| **usdigitalresponse/entity-api** | github.com/usdigitalresponse/entity-api | GraphQL over SAM.gov + USASpending for **entity** lookup (reputable: US Digital Response) | — | check | maintained | **REFERENCE** (entity/knowledge enrichment pattern) |
| **GSA/srt-fbo-scraper** | github.com/GSA/srt-fbo-scraper | GSA's **own** ML pipeline over IT solicitations (Section 508) | Python | gov (public domain) | GSA-maintained | **REFERENCE** (gov-official; NLP classification ideas) |
| **Apache Tika** | github.com/apache/tika | Extracts text/metadata from 1000+ file types (PDF/DOCX/XLSX/ZIP) | Java | **Apache-2.0** | very active | **REUSE candidate** (optional document sidecar) |
| **Unstructured** | github.com/Unstructured-IO/unstructured | Parses PDF/HTML/Office into LLM-ready elements (14.9k★) | Python | **Apache-2.0** (core) | very active | **REUSE candidate** (optional document sidecar) |
| **pdfplumber** | github.com/jsvine/pdfplumber | PDF text + **tables** extraction | Python | **MIT** | active | **REUSE candidate** (best tables, permissive) |
| **Singer spec** | singer.io | Tap/target incremental-sync standard | spec | **Apache-2.0** | ecosystem | **REFERENCE** (incremental-sync/state pattern) |
| FPDS / USASpending / SBIR clients (via awesome list) | (various) | Official-API Python clients | Python | mixed/unstated | varies | **REFERENCE** (API contracts) |

## 3. Reusable Libraries (permissively licensed, safe)
- **Document extraction (external sidecar via Named Credential callout, only if AI-Gateway extraction is insufficient):** Apache Tika (Apache-2.0), Unstructured (Apache-2.0), pdfplumber (MIT), Extractous (Apache-2.0, Rust). All permissive — safe to self-host and call.
- **API contract references (to validate our Apex connectors):** sam-search (MIT), pysam (MIT).
- **Pattern references:** Singer (incremental sync/state/checkpoint), Airbyte/Meltano connector-lifecycle shape.

## 4. Projects Rejected and Why
| Project | Reason |
|---|---|
| **dobtco/openrfps-scrapers** | **Scraping-first** state procurement sites; authors themselves note fragility; ToS/legal risk, not auditable → REJECT |
| **Apify "BidNet Direct Government Bids Scraper"** | Commercial **scraping** service against BidNet; ToS risk; BidNet offers a paid API instead → REJECT (use BidNet API/email) |
| **OpenGov-Watch/opengov-scraper** | Different domain (blockchain "OpenGov" governance, not OpenGov *procurement*) + scraping → REJECT (not applicable) |
| **"SAM.gov Webscraper" (Google-Sheets)** | Scraping + not production-grade/auditable → REJECT |
| **PyMuPDF** | **AGPL-3.0** — network-use source-disclosure obligation (or $10k–50k/yr commercial license); incompatible with a proprietary SaaS platform → REJECT (use pdfplumber/Tika/Unstructured) |
| Any project with **unstated license** (e.g. procurement-tools, some FPDS clients) | Cannot verify redistribution rights → **not adopted**; reference-only until license confirmed |

## 5. License Review
- **Safe to reuse/self-host:** MIT (sam-search, pysam, pdfplumber), Apache-2.0 (Tika, Unstructured, Singer, Extractous), US-gov public-domain (GSA/srt-fbo-scraper).
- **Caution:** Airbyte connectors mix MIT + **Elastic License v2 (ELv2)** (not OSI-approved; restricts offering-as-a-service) — verify per-connector before any self-host; Meltano core = MIT.
- **Reject:** **AGPL-3.0** (PyMuPDF) for a proprietary platform; any **unstated/no-license** project (no grant of rights).

## 6. Security Review
- None are embedded in Salesforce, so no in-org supply-chain exposure from adoption. Document sidecars (Tika/Unstructured), **if** self-hosted, run **outside** the org and are reached via Named Credential — no secrets in code, callout-audited.
- Reject anything requiring stored portal passwords or headless browser credential handling (credential-insecure).
- API-key handling (SAM data.gov key) stays in External Credentials — never in any adopted OSS config.
- Scrapers are rejected partly on security (brittle DOM coupling, IP-block/ban risk, unauditable data provenance).

## 7. Architecture Fit
- **Salesforce-native:** none. So OSS is **reference + optional external sidecar**, never in-org code adoption. This preserves auditability and governance.
- **Best fit:** the official-API reference clients (sam-search/pysam) directly validate our Apex `OA_SAMOpportunities_*` field mappings; Singer's state pattern maps to our incremental-sync checkpoint on `OA_Acquisition_Source__c`; Tika/Unstructured map to the **document strategy** as an optional callout when AI-Gateway extraction needs deterministic text first.

## 8. Recommended Reuse Strategy
1. **Reference, don't adopt** the MIT SAM clients to lock down our Get-Opportunities field mapping + pagination + rate-limit handling.
2. **Reference** `awesome-procurement-data` as the maintained catalog of authoritative APIs (feeds `OA_Acquisition_Source__c`).
3. **Document extraction:** AI Gateway first; if deterministic pre-extraction is needed, stand up **Apache Tika or Unstructured (Apache-2.0)** as an external microservice reached via Named Credential — never PyMuPDF.
4. **Incremental sync:** adopt the **Singer state/checkpoint pattern** conceptually in the Apex connector lifecycle.
5. **Reject all scrapers**; where a portal has no API, use its **email alert + authoritative reconcile**, not a scraper.

## 9. Build-vs-Reuse Decision
| Component | Decision | Rationale |
|---|---|---|
| SAM.gov / Grants.gov / SBIR connectors | **BUILD (Apex)** — reference MIT OSS contracts | wrong runtime to adopt; code already built; OSS validates fields |
| State/local platform adapters | **BUILD (Apex)** — reference Singer/Airbyte lifecycle | no reusable Salesforce-native option; scrapers rejected |
| Document extraction | **REUSE** AI Gateway (built); **optional** Tika/Unstructured sidecar (Apache-2.0) | permissive, mature, external, auditable |
| Source catalog | **REUSE (reference)** awesome-procurement-data | maintained, authoritative |
| ETL orchestration | **REFERENCE** Singer/Meltano patterns; do not run external ETL | keeps data flow inside SF governance |
| Any bid scraper | **REJECT** | ToS/legal/brittle/unauditable |

## 10. Risks
- Adopting AGPL/unstated-license code would create legal exposure → mitigated by permissive-only + reference-only policy.
- Self-hosted document sidecars add an external service to secure/maintain → mitigated by making them optional (AI Gateway first) and callout-audited.
- OSS API clients can lag official API changes → we treat them as **reference**, not runtime dependencies.
- Airbyte ELv2 ambiguity → verify per-connector before any use.

## 11. Final Recommendation
**Build the connectors in Apex (authoritative-source-first), using permissively-licensed OSS strictly as reference for API contracts + patterns, and reject every scraper and every AGPL/unlicensed component.** For documents, use the AI Gateway with an optional Apache-2.0 sidecar (Tika/Unstructured/pdfplumber). This keeps the platform authoritative-source-first, auditable, ToS-clean, and free of copyleft/scraping risk. The deep dive **confirms** the Program 023A architecture and unblocks Program 024 (SAM.gov activation) — no OSS changes the plan; it validates it.

## Sources
- github.com/makegov/awesome-procurement-data · github.com/MindPetal/sam-search · github.com/jpleger/pysam · github.com/usdigitalresponse/entity-api · github.com/GSA/srt-fbo-scraper · github.com/akshayakula/OpenSAM · github.com/apache/tika · github.com/Unstructured-IO/unstructured · github.com/jsvine/pdfplumber · github.com/pymupdf/PyMuPDF (AGPL — rejected) · github.com/dobtco/openrfps-scrapers (rejected) · singer.io · airbyte.com / meltano.com
