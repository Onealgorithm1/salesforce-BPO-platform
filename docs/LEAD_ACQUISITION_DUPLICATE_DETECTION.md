# Lead Acquisition — Duplicate Detection Design (Phase 3)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** design (reuses existing fields; no new schema, no execution)
**Reuses:** `OA_Discovered_Organization__c` dedup fields · existing `Lead` enrichment fields · org Matching/Duplicate Rules

> Phase 3. Every Candidate is matched against existing Salesforce Leads (and Accounts) **before** any Lead is created.
> **A Candidate never creates a duplicate Lead** — a match routes it to `Duplicate` (linked via `Matched_Lead__c`).

---

## 1. Match signals + confidence (weighted, deterministic)
Evaluated in priority order against existing `Lead` data; the highest-confidence hit wins.

| # | Signal | Candidate field | Lead field | Weight | Match type |
|---|---|---|---|---|---|
| 1 | **UEI** | `UEI__c` | `UEI__c` | 1.00 | exact → definitive duplicate |
| 2 | **CAGE** | `CAGE_Code__c` | `CAGE_Code__c` | 0.95 | exact |
| 3 | **Website domain** | host of `Website__c` | host of `Website`/`Website__c` | 0.85 | normalized host equality |
| 4 | **Email domain** | (from source payload) | domain of `Email` | 0.55 | domain equality (weak alone) |
| 5 | **Company name** | `Normalized_Name__c` | normalized `Company` | 0.70 | normalized exact / fuzzy |
| 6 | **Address** | `Address__c`+`Postal_Code__c` | Street+PostalCode | 0.50 | normalized equality |

**Composite confidence** = highest single deterministic signal (UEI/CAGE/domain) OR a combination rule
(name 0.70 + address 0.50 + email-domain 0.55 → treat as duplicate when two independent ≥0.5 signals agree).

## 2. Decision bands
| Composite | Decision | `Qualification_Status__c` | Action |
|---|---|---|---|
| ≥ 0.90 (UEI/CAGE) | **Definitive duplicate** | `Duplicate` | set `Matched_Lead__c`; never create a Lead |
| 0.65–0.89 | **Probable duplicate** | `Needs Review` | route to review queue; human confirms |
| 0.50–0.64 | **Possible duplicate** | `Needs Review` | human adjudication |
| < 0.50 | **Unique** | `Approved`/`Needs Review` | eligible for human Lead-creation |

## 3. Reused infrastructure (no new schema)
- **`Canonical_Key__c`** — stable canonical identity (e.g. UEI or normalized-name+state) for set-based grouping.
- **`Normalized_Name__c`** — case/punctuation-normalized name for name matching.
- **`Source_Payload_Hash__c`** — idempotency: identical re-discovery from the same source is deduped at ingestion (no churn).
- **`Matched_Lead__c` / `Matched_Account__c`** — the resolved link when a duplicate is found.
- **Org Matching/Duplicate Rules** — the `duplicateRules`/`matchingRules` folders are **empty scaffolds today**;
  configure Lead matching rules (UEI/CAGE/domain) to reinforce the Apex-side scoring. Config task, gated.

## 4. Governance
- Matching is **read-only against production Leads** — it reads Lead fields, never writes them.
- The dedup step runs **before** the human approval gate; a duplicate is never promoted to a Lead.
- All match decisions are auditable (recorded on the candidate + optionally an `OA_Enrichment_Change_Log__c` entry).
- **Not executed this sprint** — design only; no discovery run, no matching run, no data change.

## 5. Remaining work (gated, future)
Implement the matching as a reusable Apex service invoked by the candidate pipeline (reuse `OA_ConnectorRunner`
post-processing; no new framework), + configure org Matching/Duplicate Rules. Validate against the 13,301 existing
Leads (78 have UEI, 13,279 have CAGE — strong deterministic coverage) in a supervised, gated pilot.
