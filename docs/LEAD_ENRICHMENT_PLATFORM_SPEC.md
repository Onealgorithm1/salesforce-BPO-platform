# Lead Enrichment Platform — Specification & Connector Matrix

_Status: **feature-complete platform + Wave 1 connectors (dormant, source only, check-only validated)** ·
2026-07-06. Nothing deployed/pushed/activated/scheduled; no live API calls._

## Architecture (frozen)
One generic framework enriches organizations from many trusted sources:
- **`OA_IEnrichmentConnector`** — the source-agnostic contract (`sourceKey()`, `fetch(input, cfg)`).
- **`OA_ConnectorRunner`** — registry-driven dispatcher (dynamic `Type.forName`; identical lifecycle;
  telemetry). No source-specific dispatch anywhere.
- **`OA_CanonicalOrg`** — shared canonical organization (identity + `attributes` context bag).
- Platform engines (frozen): Field Write Policy, Qualification, Confidence, Source Precedence,
  Discovery, Change Log, Rollback, Exception Routing, Connector Registry.

A connector = **Request + Parser + Mapper + a Connector implementing the interface + metadata**.
No platform change is required to add one (proven by Wave 1: SAM, USASpending, Census, IRS).

## Ingestion patterns supported
- **REST/JSON object** — SAM.gov, USASpending (POST).
- **REST/JSON array-of-arrays** — Census (aggregate context).
- **Bulk file (CSV)** — IRS EO BMF: the connector implements the same interface but performs NO HTTP;
  `fetch(input)` parses provided bulk content. Retrieval/chunking of the monthly file is an operational
  step (not built; no scheduled jobs). This proves the framework is not REST-locked.

## Connector Matrix

| Connector | Status | Category / Authority | Auth | Refresh cadence | Identity key | Field coverage (canonical) |
|---|---|---|---|---|---|---|
| **SAM.gov** | Built (Wave 0/1) | Entity / identity + certifications (authoritative) | data.gov key (X-Api-Key header) | Monthly + on-demand | UEI, CAGE | UEI, CAGE, legal name, DBA, reg status/expiration, entity type, business types, socioeconomic certs, address, website. *Unavailable: NAICS, exclusion, phone.* |
| **USASpending** | Built (Wave 1) | Contract / federal awards (authoritative) | None (public) | Monthly | UEI (else name) | recipient, UEI, award total, award count, latest award date, awarding agencies, parent org, state, federal-recipient flag. *Location detail limited.* |
| **U.S. Census** | Built (Wave 1) | Market / geographic context (aggregate) | None (key optional) | Annual (CBP) | **none** (context) | establishments, employment, annual payroll, industry label, geography. *No organization identity — enriches an existing org by state/NAICS.* |
| **IRS Tax-Exempt** | Built (Wave 1, bulk) | Compliance / nonprofit status (authoritative) | None (bulk file) | Monthly (EO BMF) | EIN | EIN, name, address, exempt status, subsection, deductibility, foundation type, ruling date, NTEE. |
| SEC EDGAR | Future | Entity / public-company | None (User-Agent) | Daily | CIK | (design pending) |
| NPPES | Future | Entity / healthcare | None | Weekly | NPI | (design pending) |
| USPTO | Future | Market / innovation | Key (PatentsView) | Monthly | — | (design pending) |

**Source precedence (survivorship):** `SAM > IRS > USASpending > Census` (by `OA_Enrichment_Source__mdt.Precedence__c`).

## How aggregate Census data enriches an existing organization
Census returns metrics for a **geography (+ industry)**, not a firm. The Census connector produces a
canonical **context** record (no identity, `NONE` confidence). Downstream, an **existing** matched
organization (matched by the platform on its state / NAICS) receives the context as market fields
(`Market_Establishments__c`, `Market_Employment__c`, …). Census **never** creates or identifies an
organization — identity comes only from identity sources (SAM/USASpending/IRS).

## Entity resolution (existing platform — no new engine)
- Deterministic: `OA_CanonicalOrg.canonicalKey()` — `UEI:` / `EIN:` / `NPI:` / `CIK:` / `CAGE:`, else a
  normalized name+state hash. SAM + USASpending sharing a UEI collapse to one entity; IRS keys by EIN.
- Confidence: `OA_ConfidenceEvaluator` — exact identifier match → HIGH.
- Duplicate handling: `OA_SourcePrecedenceEngine.winner(a,b)` picks the higher-precedence source.
- Context sources (Census) never identity-match; they attach to an already-resolved entity.

## Operational prerequisites before live enrichment (not platform gaps)
Deploy (types first, then CMDT records); provision a least-privilege runtime user (0 spare licenses);
grant External Credential principal access for keyed sources (SAM) via a permission set; activate the
dormant registry/source/policy records under ADR-012 governance. IRS additionally needs a bulk-file
importer (download + chunk → feed via the runner) — future, gated, no scheduled job built.
