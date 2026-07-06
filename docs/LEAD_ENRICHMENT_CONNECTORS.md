# Lead Enrichment Connectors — Inventory (7)

_Status: **DESIGN ONLY — for review** · 2026-07-06. The only connectors in scope for the Lead
Enrichment Platform. No Opportunity/Grants connectors are designed until this pipeline is complete._

**Complexity:** S ≈1–2d · M ≈3–5d · L ≈1–2w · XL multi-week/new pattern. **Auth:** None = public
keyless · Key = API key in External Credential.

---

## Build order

| Tier | # | Connector | Enrichment role (what it fills) | Auth | Refresh | API limits | Complexity | Status |
|---|---|---|---|---|---|---|---|---|
| **1** | 1 | **SAM.gov Entity** | Identity spine: UEI, CAGE, legal name, registration status + expiration, socioeconomic certs (WOSB/EDWOSB/SDVOSB/HUBZone/8a), NAICS, state | Key (X-Api-Key) | Monthly + on-demand | Tiered (~10k/day) | M | ✅ built dormant |
| **1** | 2 | **USASpending** | Federal contractor / award-recipient status, agencies, award history, amounts | None | Monthly | Generous | M | ✅ built dormant |
| **1** | 3 | **U.S. Census** | Firmographic/geographic/industry context (NAICS business patterns, geography) | Key (optional) | Annual (ACS) | 500/day no-key | M | 🟡 next |
| **2** | 4 | **IRS Tax-Exempt (BMF/Pub 78)** | Organization type, nonprofit status, EIN, revocations | None (**bulk files**) | Monthly | N/A (download) | L (new ingest pattern) | ⚪ |
| **2** | 5 | **SEC EDGAR** | Public-company identity (CIK), filings, financials (public filers only) | None (**User-Agent required**) | Daily | ≤10 req/s | L | ⚪ |
| **3** | 6 | **NPPES (NPI)** | Healthcare provider identity (NPI), taxonomy, practice location | None | Weekly/monthly | ≤200 results/req | S–M | ⚪ |
| **3** | 7 | **USPTO** | Innovation signal: patents/trademarks (competitive/tech-maturity context) | Key (PatentsView) / None (TSDR) | Monthly | ~45 req/min keyed | M–L | ⚪ |

## Per-connector enrichment notes

- **SAM.gov (1)** — the authoritative identity + certification source; source-of-truth for most
  trusted fields (registration, certs, NAICS). Highest priority in survivorship. Already built dormant.
- **USASpending (2)** — primary signal for the ICP "federal contractor / award recipient" criterion and
  agency targeting. Already built dormant.
- **Census (3)** — **aggregate**, not per-firm: supplies market/geography context, *not* a specific
  company's employees/revenue. Use for context and geography rules, not per-org firmographics.
- **IRS Tax-Exempt (4)** — **bulk file** ingestion, not a live REST API → needs an SDK ingestion-pattern
  extension (download + parse + stage) before build. Feeds org-type / nonprofit qualification + EIN.
- **SEC EDGAR (5)** — public-company depth (CIK, revenue for filers); **requires a descriptive
  User-Agent header**; rate-limited ≤10 req/s. Covers only public companies.
- **NPPES (6)** — healthcare-sector identity (NPI); straightforward public API.
- **USPTO (7)** — innovation/competitive signal; PatentsView now key-gated. Enrichment-optional.

## Reuse & shared work
All seven reuse the Connector SDK + registry + per-source staging + unified dedupe + governance
standards. Per-connector work = Request/Parser/Mapper + a staging object + tests + a runbook + one
registry row. **Two need a pattern extension first:** IRS (bulk file) and, partially, SEC (bulk +
User-Agent) — flag as L/XL, do not assume the current REST pattern covers them.

## Source-of-truth precedence (for the write policy & dedupe)
`SAM > IRS > SEC > NPPES > USASpending > Census > (commercial, later)`. Encoded in
`OA_Field_Write_Policy__mdt.Source_Of_Truth__c` and the dedupe survivorship order.
