# Lead Enrichment Platform — RELEASE 1.0 (permanent baseline)

_Version 1.0 · Commissioned in production 2026-07-07 · Org 00Dbn00000plgUfEAI · GO_

> **Historical baseline (tag `lead-enrichment-v1.0` = `485f7dc`).** This document describes the v1.0 release *before*
> Sprint 17. Statements below that the async orchestrator is "not built" and that the epic is "closed" are superseded:
> Sprint 17 built the async orchestrator (`OA_EnrichmentOrchestrator`/`OA_EnrichmentQueueable`, merged to `main`, **not
> yet deployed to the org**), and as of Sprint 20 the epic is **not yet closed** — one controlled 25-Lead write pilot
> remains (preview validated live, 0 writes). Current status: `SPRINT20_OPERATIONAL_READINESS.md` + `PROGRAM_ROADMAP.md`.

Version 1.0 of the Lead Enrichment Platform is **built, deployed, commissioned, and proven on
production Leads** with durable audit and verified rollback. The Lead Enrichment epic is **closed**.
The next development program is the **Opportunity Intelligence Platform**.

## 1. Architecture
Metadata-driven, connector-agnostic enrichment inside Salesforce (Apex). One generic framework; add a
source with Request + Parser + Mapper + a Connector implementing the interface + metadata — no platform
code changes.
- **Generic framework:** `OA_IEnrichmentConnector` (interface), `OA_ConnectorRunner` (registry-driven
  dispatcher, dynamic `Type.forName`, identical lifecycle + telemetry), `OA_ConnectorResult`.
- **Canonical model:** `OA_CanonicalOrg` (identity + attribute bag), `OA_NameNormalizer`.
- **Engines:** Field Write Policy, Qualification, Confidence, Source Precedence, Discovery Qualification.
- **Governed write:** `OA_EnrichmentWriter` (per-field policy, USER_MODE FLS, before-snapshot), Change
  Log + Rollback (`OA_ChangeLogService`), Exception Routing (`OA_ExceptionRoutingService`).
- **Objects:** `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Change_Log__c` (audit + rollback),
  `OA_Enrichment_Exception__c` (review queue), `OA_Discovered_Organization__c` (net-new + qualification).
- **Config (CMDT):** `OA_Connector_Registry__mdt`, `OA_Enrichment_Source__mdt`, `OA_Field_Write_Policy__mdt`,
  `OA_Qualification_Rule__mdt`, `OA_Enrichment_Pipeline__mdt`.
- **Lead schema:** 29 enrichment fields. **Runtime FLS:** `OA_Lead_Enrichment_Runtime` permission set.

## 2. Connector inventory (6)
| Connector | Category | Ingestion | Auth | Status |
|---|---|---|---|---|
| SAM.gov | Entity/identity+certs | REST GET | data.gov key (X-Api-Key) | built; live callout needs EC principal access |
| USASpending | Contract/awards | REST POST | none (public) | built; live-ready |
| U.S. Census | Market context | REST GET (array) | none | built; needs Census NC |
| IRS Tax-Exempt | Compliance/nonprofit | **bulk CSV** (no callout) | none | built; validated live (bulk parse) |
| SEC EDGAR | Entity/public co | REST GET | none (User-Agent) | built; needs SEC NC |
| State Registry (template) | Entity/state formation | REST GET (extensible) | per-state | template; no live state connector |

## 3. Deployment history (IDs)
| Deploy | ID | Result |
|---|---|---|
| Lead enrichment fields (29) | `0AfPn0000022znpKAA` | 29/29 |
| Platform types (objects/fields/35 classes/22 tests/5 CMDT types/permset) | `0AfPn0000022zz7KAA` | 184/184, 86 tests |
| CMDT records (44) | `0AfPn000002308nKAA` | 44/44 |
| Runtime permset (expanded: 4 obj + 99 field perms) | `0AfPn00000230aDKAQ` | 1/1 |

**Key deployment learning:** CMDT record files require `xmlns:xsd="http://www.w3.org/2001/XMLSchema"` on
the root element, or the org rejects them with an opaque `UNKNOWN_EXCEPTION`.

## 4. Validation / commissioning IDs & results
- Latest check-only validation (full platform + 6 connectors): `0AfPn0000022zW5KAI` — 183 components,
  86 tests, 0 failures, 97.21% coverage.
- **Canary** (Lead `00QPn000012Ktl3MAC`): connector runner, canonical, qualification (Qualified),
  policy (fill-empty write + conflict), writer, **change log + exception + connector run persisted**,
  rollback restored — all PASS.
- **5-Lead production pilot:** 5/5 enriched (fill-empty `UEI__c`), audited, **rolled back 5/5** (0
  residual), audit retained. Real IRS bulk parse validated a 2nd source.
- **Root-cause resolution:** the earlier "No such column" commissioning blocker was **Field-Level
  Security** (runtime user lacked FLS; the granting permset had been revoked) — not a platform defect.
  Fixed by the expanded, assigned `OA_Lead_Enrichment_Runtime` permset.

## 5. Operational prerequisites (before scaling / scheduling)
1. **Runtime FLS permset must stay assigned** to the runtime user (revoking it hides the fields → "No such column").
2. **Live-callout credentials:** create secret-free Named Credentials for Census + SEC; grant SAM
   External Credential principal access (JIT). USASpending + IRS need none.
3. **Async bulk orchestrator** (Queueable/Batch) for volume/scheduled runs — additive, not built.
4. **Monitoring dashboards** built from the (present) data (`MONITORING_DASHBOARDS.md`).

## 6. Known limitations
- **Runtime user is temporary `oauser` (Modify All Data)** — weakens the FLS guardrail; see
  `RUNTIME_USER_EXCEPTION.md`. Replace with a dedicated least-privilege user when a license is available.
- Enrichment fields are **Text-typed** to match the frozen mappers' string output (typed Currency/Date
  need a future mapper coercion layer).
- Per-input synchronous processing today (fine ≤ ~100/txn); scale needs the async orchestrator.
- No cross-source auto-merge/promotion layer (dedup is deterministic-key; entity resolution is reviewed).
- State registry + certification connectors are templates/designs pending stable public interfaces.

## 7. Runtime-user exception
Documented business decision (`RUNTIME_USER_EXCEPTION.md`): `oauser` (admin/MAD) is the temporary
runtime user because 0 spare Salesforce licenses. Conservative controls apply; replace with a
least-privilege user when budget allows. This is the single highest standing operational risk.

## 8. Future roadmap
- **Immediate:** 25-Lead pilot (real prospects + live USASpending) → 100-Lead pilot.
- **Then:** provision Census/SEC NCs + SAM EC access; build async bulk orchestrator; build dashboards;
  provision the least-privilege runtime user → enable scheduled enrichment → 24/7 operation.
- **Wave 3 connectors (future):** NPPES, USPTO, live state registries, diversity-certification sources.
- **Next program:** **Opportunity Intelligence Platform** (separate epic).

---
_This document is the permanent Version 1.0 baseline. The Lead Enrichment Platform epic is CLOSED._
