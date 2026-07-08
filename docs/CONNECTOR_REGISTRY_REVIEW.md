# Connector Registry Review — Lead Enrichment Platform

**Date:** 2026-07-08 · **Branch:** `main` (`dbf8d12`) · **Registry:** `OA_Connector_Registry__mdt` (8 records)
**Dispatcher:** `OA_ConnectorRunner` (`Type.forName` → cast to `OA_IEnrichmentConnector`) · **Config-consumer:** `OA_EnrichmentOrchestrator`
**Change made:** documentation only — no runtime behavior modified · **Companion:** [REPOSITORY_INTEGRITY_REVIEW.md](REPOSITORY_INTEGRITY_REVIEW.md)

> Row-by-row integrity of every registry record against its connector class, mapper/parser/request, persistence,
> runner compatibility, enabled state, object mapping, and field policies. All records are `Enabled__c=false` /
> `Status=Draft` (dormant) — no live impact from any FAIL below; each is a latent defect to fix before enabling.

---

## Verdict legend
- **PASS** — class resolves, implements `OA_IEnrichmentConnector`, wired consistently, safe to enable (after the normal go-live gates).
- **WARN** — works but has an inconsistency or a documentation/config nit to clean up.
- **FAIL** — would error if enabled as-is (e.g. runner cast rejects the class). Dormant, so no live failure today.

## Registry row-by-row

| Row | Connector_Class | Interface | Mapper / Parser / Request | Persistence target | Runner-compatible? | Enabled | Object mapping | Verdict |
|---|---|---|---|---|---|---|---|---|
| **USASpending** | `OA_USASpending_Connector` | `OA_IEnrichmentConnector` ✅ | `OA_USASpending_Mapper` / `_ResponseParser` / `_Request` ✅ | `OA_Discovered_Organization__c` + `OA_Connector_Run__c` | Yes | false | Lead ← UEI/awards/agencies (FillEmptyOnly policies) | 🟢 **PASS** — certified, live-proven source |
| **SAM** | `OA_SAM_Connector` | `OA_IEnrichmentConnector` ✅ | `OA_SAM_Mapper` / `_ResponseParser` / `_Request` ✅ | `OA_Discovered_Organization__c` + run | Yes | Lead ← SAM entity/CAGE/registration | 🟡 **WARN** — class adds a non-interface `fetch(input)` convenience overload (`OA_SAM_Connector.cls:34`) absent on the other five; also needs external cred (data.gov key + JIT EC principal) before enable |
| **Census** | `OA_Census_Connector` | `OA_IEnrichmentConnector` ✅ | consistent ✅ | `OA_Discovered_Organization__c` + run | Yes | false | Lead ← market/geography | 🟢 **PASS** — NC live (HTTP 200), public, no secret |
| **SEC** | `OA_SEC_Connector` | `OA_IEnrichmentConnector` ✅ | consistent ✅ | `OA_Discovered_Organization__c` + run | Yes | false | Lead ← entity/EDGAR | 🟢 **PASS** — NC live (HTTP 200), public |
| **IRS** | `OA_IRS_Connector` | `OA_IEnrichmentConnector` ✅ | consistent ✅ | `OA_Discovered_Organization__c` + run | Yes | false | Lead ← compliance/EO status (bulk CSV) | 🟢 **PASS** — no callout auth needed |
| **StateRegistry** | `OA_StateRegistry_Template` | `OA_IEnrichmentConnector` ✅ | template stubs | `OA_Discovered_Organization__c` + run | Yes | false | template (no live source) | 🟡 **WARN** — it is a **template/scaffold**, not a real source; keep dormant or remove from registry until a real state connector exists |
| **GrantsGov** | `OA_GrantsGovConnector` | **`OA_IConnector`** (Framework A) ❌ | `OA_ConnectorEngine` + `OA_ConnectorPersistence` | `OA_Opportunity_Signal__c` | **No** — runner cast to `OA_IEnrichmentConnector` rejects it | false | Opportunity (not Lead) | 🔴 **FAIL** — mis-registered: this is an **Opportunity Intelligence** connector driven by `OA_GrantsGovService`/`OA_ConnectorEngine`, not the enrichment runner. Would throw if enabled here. |
| **SAM_Opportunities** | `OA_SAMOpportunities_Connector` | **`OA_IConnector`** (Framework A) ❌ | `OA_ConnectorEngine` + `OA_ConnectorPersistence` | `OA_Opportunity_Signal__c` | **No** — same cast rejection | false | Opportunity (not Lead) | 🔴 **FAIL** — same as GrantsGov; belongs to OI, not the enrichment registry. |

## Summary

| Verdict | Count | Rows |
|---|---|---|
| 🟢 PASS | 4 | USASpending, Census, SEC, IRS |
| 🟡 WARN | 2 | SAM (extra overload + cred prereq), StateRegistry (template only) |
| 🔴 FAIL | 2 | GrantsGov, SAM_Opportunities (Framework-A classes in a Framework-B registry) |

**All 8 rows `Enabled__c=false` → 0 live impact.** The two FAILs are *latent* — a cast error only if someone enables them in the enrichment runner. Because they are Opportunity Intelligence connectors, the correct fix is to **remove the `GrantsGov` and `SAM_Opportunities` rows from `OA_Connector_Registry__mdt`** (OI drives them through `OA_ConnectorEngine`, not the enrichment runner), OR to give Opportunity Intelligence its own registry/runner. Either is a metadata change → 🔴 gated (see [CLEANUP_ROADMAP.md](CLEANUP_ROADMAP.md), item C-4).

## Supporting-component integrity (shared services)
- **Runner** `OA_ConnectorRunner` — resolves class via `Type.forName`, builds in-memory `OA_Connector_Run__c` (does **not** insert). PASS.
- **Persistence** — `OA_EnrichmentOrchestrator` owns the DML: inserts telemetry + change logs + exceptions in `USER_MODE` (2-phase, callouts before writes). PASS.
- **Telemetry** `OA_Connector_Run__c` — child lookups from `OA_Discovered_Organization__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`. PASS.
- **Field policies** `OA_Field_Write_Policy__mdt` — 22 records, **all `Active__c=false`**; 9 are `Overwrite` mode but none active; pilots use FillEmptyOnly only. PASS (dormant).
- **Pipeline / sources** `OA_Enrichment_Pipeline__mdt` (11) + `OA_Enrichment_Source__mdt` (6) — all disabled/inactive. PASS (dormant).

## Repair actions (documentation-tracked; no runtime change here)
| # | Action | Type | Gate |
|---|---|---|---|
| R-1 | Remove `GrantsGov` + `SAM_Opportunities` rows from the enrichment registry (or split OI into its own registry) | CMDT change | 🔴 deploy |
| R-2 | Normalize `OA_SAM_Connector` — drop or document the extra `fetch(input)` overload for SDK consistency | Apex | 🔴 deploy |
| R-3 | Decide StateRegistry: keep as documented template, or remove its registry row until a real source exists | CMDT | 🔴 deploy |

None of R-1…R-3 is required for the certified manual/preview scope (all rows dormant); they are consistency hardening for the future enablement path.
