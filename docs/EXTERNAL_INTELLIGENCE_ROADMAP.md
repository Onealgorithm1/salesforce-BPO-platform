# External Intelligence Roadmap — Connector Inventory (Deliverable 1)

> 🔎 **Phase 6 refocus (2026-07-06):** the active phase is **Lead Enrichment only** — see the trimmed
> 7-connector list in [`LEAD_ENRICHMENT_CONNECTORS.md`](LEAD_ENRICHMENT_CONNECTORS.md) (SAM, USASpending,
> Census, IRS, SEC, NPPES, USPTO). Grants/SBIR/NIH/NSF/DOE **Opportunity** connectors below are
> **DEFERRED** to a later phase. This document is retained as the long-range source catalog.

_Status: **DESIGN ONLY — for review** · 2026-07-06. No connector below is authorized for live
callouts or deployment beyond the three already built dormant._

Legend — **Status:** ✅ built-dormant · 🟡 next candidates · ⚪ designed/backlog · 🔒 commercial (placeholder).
**Complexity:** S (≈1–2 days) · M (≈3–5 days) · L (≈1–2 weeks) · XL (multi-week / new pattern).
**Auth:** None = public keyless · Key = API key in External Credential · OAuth/S2S = authenticated.

---

## A. Government sources

| # | Source | Primary category | Business value | Auth | Refresh cadence | API limits | Canonical object | Human review | Complexity | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **SAM.gov Entity** | Entity | Identity spine: UEI/CAGE, registration, socioeconomic certs (WOSB/EDWOSB/HUBZone/8a/SDVOSB) | **Key** (X-Api-Key) | Monthly + on-demand | Tiered (~10k/day system acct) | `OA_Entity_Intelligence__c` | Full gate; cert changes high-stakes | M | ✅ dormant |
| 2 | **USASpending** | Contract | Award history, obligations, agencies, sub-awards (teaming signal) | None | Monthly (data lags) | Generous; be polite | `OA_Contract_Intelligence__c` | Full gate | M | ✅ dormant |
| 3 | **Grants.gov** | Opportunity | Open funding opportunities, deadlines, CFDA/ALN (timing signal) | None (Search2) | **Daily** | Unspecified public | `OA_Opportunity_Signal__c` | Full gate | S | ✅ dormant |
| 4 | **Census** | Market | Firmographic/geographic/demographic context; NAICS business patterns | Key (optional, recommended) | Annual (ACS) / decennial | 500/day no-key; more with key | `OA_Market_Intelligence__c` | Light (reference data) | M | 🟡 |
| 5 | **SBIR.gov** | Opportunity + Contract | SBIR/STTR solicitations (opportunity) and awards (contract); small-biz R&D | None | Weekly/monthly | Rate-limited (429 seen historically) | `OA_Opportunity_Signal__c` + `OA_Contract_Intelligence__c` | Full gate | M | 🟡 |
| 6 | **NIH RePORTER** | Contract | NIH research awards, PIs, funding — health/biotech capture | None (POST API) | Monthly | ~1 req/s; ~500 rec/page | `OA_Contract_Intelligence__c` | Full gate | M | ⚪ |
| 7 | **NSF Awards** | Contract | NSF award history — research/STEM capture | None | Monthly | ~25 rec/page; be polite | `OA_Contract_Intelligence__c` | Full gate | M | ⚪ |
| 8 | **DOE Opportunity feeds** | Opportunity | Energy funding opportunities (EERE/OE/ARPA-E), often via Grants.gov mirror | None / Key (varies) | Daily/weekly | Varies by feed | `OA_Opportunity_Signal__c` | Full gate | M–L | ⚪ |
| 9 | **IRS Tax-Exempt (BMF/Pub 78)** | Compliance + Entity | Nonprofit status, EIN, revocations — eligibility & partner vetting | None (**bulk files, not live API**) | Monthly | N/A (file download) | `OA_Compliance_Intelligence__c` | Full gate; revocation high-stakes | L (new ingest pattern) | ⚪ |
| 10 | **SEC EDGAR** | Entity + Market | Public-company identity, filings, financials — larger primes/partners | None (**User-Agent required**) | Daily (filings) | ≤10 req/s | `OA_Entity_Intelligence__c` + `OA_Market_Intelligence__c` | Full gate | L | ⚪ |
| 11 | **NPPES (NPI)** | Entity | Healthcare provider registry — health-sector entities/contacts | None | Weekly/monthly | ≤200 results/request | `OA_Entity_Intelligence__c` | Full gate | S–M | ⚪ |
| 12 | **USPTO** | Market + Relationship | Patents/trademarks — innovation & competitive signal | Key (PatentsView) / None (TSDR) | Monthly/quarterly | ~45 req/min (keyed) | `OA_Market_Intelligence__c` | Light–Full | M–L | ⚪ |

## B. Commercial sources — **placeholder only** (contract, cost, ToS, and licensing review required first)

| # | Source | Primary category | Business value | Auth | Notes / blockers |
|---|---|---|---|---|---|
| 13 | **Dun & Bradstreet** | Entity | DUNS/firmographics, corporate hierarchy, risk | OAuth + paid | License + cost; ToS on storage |
| 14 | **Crunchbase** | Market | Funding rounds, growth signal | Key + paid | Redistribution limits |
| 15 | **LinkedIn** | Relationship | People, roles, org connections | OAuth + strict ToS | **Scraping prohibited**; only sanctioned APIs |
| 16 | **ZoomInfo** | Relationship + Entity | Contacts, intent data | Key + paid | Cost; PII governance |
| 17 | **GovWin (Deltek)** | Opportunity | Pre-RFP pipeline, forecasts | Key + paid | Premium licensing |
| 18 | **GovTribe** | Opportunity + Contract | Awards/opportunities aggregation, agency intel | Key + paid | Premium licensing |

> Commercial sources are **not** designed in detail here. They enter the roadmap only after a
> licensing/ToS/cost/PII review, because most impose storage-and-redistribution constraints that the
> governance standard (Deliverable 6) must encode per-source.

---

## C. Prioritization — by business value, not ease

Ease of implementation is **not** the ranking criterion (per Louis). Ranking blends **capture value**
to the BPO's federal/EDWOSB pipeline with **dependency readiness**.

| Wave | Sources | Rationale |
|---|---|---|
| **W0 — Done (dormant)** | SAM (1), USASpending (2), Grants.gov (3) | Identity + contract + opportunity spine already built |
| **W1 — Highest value next** | SBIR (5), NIH (6), NSF (7) | Direct opportunity+award capture for R&D/small-biz; all public, no-auth |
| **W2 — Compliance & market** | IRS Tax-Exempt (9), Census (4), USPTO (12) | Eligibility vetting + market/innovation context |
| **W3 — Depth** | SEC EDGAR (10), NPPES (11), DOE (8) | Larger-partner and sector-specific depth |
| **W4 — Commercial** | D&B, GovWin, GovTribe, ZoomInfo, Crunchbase, LinkedIn | Only after licensing/ToS/cost approval |

Every wave item stays **dormant** until its own activation gate (credential provisioning where needed,
review-queue readiness, least-privilege runtime user, monitoring). See governance standards.

---

## D. Cross-source implementation notes

- **No-auth first.** W1 (SBIR/NIH/NSF) needs no credential — lowest security surface, fastest to a
  dormant build using the Grants.gov pattern.
- **Two sources break the "REST GET/POST" mold** and need a *new ingestion pattern* before build:
  IRS Tax-Exempt (**bulk file** ingest) and, partially, SEC EDGAR (**bulk submissions + User-Agent**).
  Flag these as XL-adjacent; do not assume the SDK covers them without extension.
- **Rate-limit-sensitive:** SBIR (429s), SEC EDGAR (10 req/s), NIH (~1 req/s) — require the
  per-connector rate policy (Deliverable 6) before any bulk run.
- **Reuse:** all W1–W3 gov sources reuse the SDK + registry + canonical objects + review gate with
  ~80–90% shared scaffolding; per-connector work is Request/Parser/Mapper + a staging object + tests +
  a runbook + one registry entry.
