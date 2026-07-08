# Repository Integrity Review — One Algorithm BPO Platform

**Date:** 2026-07-08 · **Branch:** `main` (`dbf8d12`) · **Org:** `00Dbn00000plgUfEAI`
**Scope:** whole tracked repository (read-only audit) · **Change made:** documentation only
**Sprint:** Lead Enrichment Platform Hardening · **Companion:** [CONNECTOR_REGISTRY_REVIEW.md](CONNECTOR_REGISTRY_REVIEW.md) · [CLEANUP_ROADMAP.md](CLEANUP_ROADMAP.md) · [TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)

> Architectural inventory + duplicate/integrity findings. **Nothing was deleted or modified in code/metadata.**
> Every duplicate is ranked **DEAD** (superseded, safe to retire), **NEEDS-REVIEW** (has a live dependency), or
> **SHARED** (intentionally reused — keep). Retirement of any DEAD item is a separate 🔴 destructive-deploy gate
> (see the Cleanup Roadmap); this document only records the map.

---

## 1. Package layout (architectural inventory)

Three source packages (`sfdx-project.json`, API 67.0):

| Package | Path | Contents (high level) |
|---|---|---|
| **OA-Core-Platform** (default) | `force-app/` | ~127 Apex classes · 22 custom/staging objects + 6 CMDT types · 9 Named Credentials · 13 permission sets · 3 flows · 5 dashboards · email templates · ~63 CMDT records |
| **OA-Marketing-Automation** | `modules/marketing-automation/` | 12 Apex classes (Booking/Artifact pollers, AI summary, replay) · 1 CMDT type (`OA_Graph_Config__mdt`) · 7 Lead fields · 1 permset (`OA_Marketing_Automation`); depends on OA-Core-Platform |
| **PBO Edition** | `clients/pbo/` | **Empty scaffold** — `.gitkeep` only (8 empty folders); no real metadata |

Non-source: `docs/` (~139 files), `manifest/` (4 retrieval manifests), `scripts/` (gitignored; `scripts/shell/` force-added), `config/`.

### Lead Enrichment logical architecture (the live path)
```
OA_EnrichmentQueueable ─► OA_EnrichmentOrchestrator ─► OA_ConnectorRunner ─► OA_IEnrichmentConnector impls
   (async entry)            (2-phase: callouts then      (Type.forName +        (USASpending/SAM/Census/
                             writes; owns persistence)     cast to interface)     SEC/IRS/StateRegistry)
                                   │                                                      │
                                   ├─► OA_EnrichmentWriter (commitWrites default FALSE) ──┤
                                   ├─► OA_ChangeLogService (before-snapshot + rollback)   │
                                   ├─► OA_ExceptionRoutingService                         │
                                   └─► OA_Connector_Run__c (telemetry)  ◄─ config: OA_Connector_Registry__mdt
```
SDK contract for the live path = `OA_IEnrichmentConnector` (`sourceKey()`, `fetch(input, cfg)`); dispatcher = `OA_ConnectorRunner`; config = `OA_Connector_Registry__mdt`; canonical staging = `OA_Discovered_Organization__c`.

---

## 2. Three coexisting connector generations (the core duplication story)

| Gen | Contract | Dispatcher | Config source | Members | State |
|---|---|---|---|---|---|
| **B — LIVE** | `OA_IEnrichmentConnector` | `OA_ConnectorRunner` | `OA_Connector_Registry__mdt` | `OA_USASpending_Connector`, `OA_SAM_Connector`, `OA_Census_Connector`, `OA_IRS_Connector`, `OA_SEC_Connector`, `OA_StateRegistry_Template` (+ `_Mapper`/`_ResponseParser`/`_Request`) | **Live (dormant)** — the certified path |
| **A — service-driven** | `OA_IConnector` | `OA_ConnectorEngine` | programmatic | `OA_SAMConnector/Mapper/Parser/Request`, `OA_USASpendingConnector/Mapper/Parser/Request`, `OA_GrantsGov*`, `OA_SAMOpportunities_*` | **Split:** GrantsGov/SAMOpportunities are LIVE for **Opportunity Intelligence**; camelCase SAM/USASpending are **DEAD (LE)** |
| **0 — direct service** | none | none | hardcoded | `OA_USASpendingClient`, `OA_USASpendingEnrichmentService` | Client still read by live write-back; service DEAD |

The two interfaces (`OA_IConnector` vs `OA_IEnrichmentConnector`) are the root of the duplication: Framework A remains necessary **only** because Opportunity Intelligence's GrantsGov/SAM-Opportunities connectors run on it. Lead Enrichment fully migrated to Framework B.

---

## 3. Duplicate Apex classes

| Class | Locations | Identical? | Rank |
|---|---|---|---|
| `OA_BookingPoller` | `force-app/.../classes/` **and** `modules/marketing-automation/.../classes/` | Byte-identical but trailing newline | **DEAD copy in `force-app`** (references `OA_Graph_Config__mdt` which exists only in `modules/` → cannot compile core-only; canonical home = `modules`) |
| `OA_BookingPoller_Test` | same two dirs | Byte-identical but trailing newline | **DEAD copy in `force-app`** |

| Concern | Live (keep) | Superseded duplicate(s) | Rank |
|---|---|---|---|
| SAM entity connector | `OA_SAM_Connector` (+`_Mapper`/`_ResponseParser`/`_Request`) | `OA_SAMConnector`+`OA_SAMMapper`+`OA_SAMParser`+`OA_SAMRequest` (0 external refs) | **DEAD** |
| USASpending connector | `OA_USASpending_Connector` (+`_Mapper`/`_ResponseParser`/`_Request`) | `OA_USASpendingConnector`+`Mapper`/`Parser`/`Request`; `OA_USASpendingEnrichmentService` (0 external refs) | **DEAD** for the camelCase connector + service |
| USASpending client/staging | (write-back path) | `OA_USASpendingClient` + `OA_USASpending_Staging__c` | **NEEDS-REVIEW** — still **read by the LIVE `OA_LeadWritebackService`** |
| HTTP wrapper | `OA_ConnectorHttp` (9+ refs) | `OA_USASpendingClient` bespoke HTTP (2 refs) | NEEDS-REVIEW |
| Connector contract | `OA_IEnrichmentConnector` | `OA_IConnector` | **SHARED** — still required by Opportunity Intelligence; consolidate later |

---

## 4. Duplicate / overlapping metadata

**CMDT types + record counts:** `OA_Field_Write_Policy__mdt` (22), `OA_Enrichment_Pipeline__mdt` (11), `OA_Connector_Registry__mdt` (8), `OA_Enrichment_Source__mdt` (6), `OA_Qualification_Rule__mdt` (2), `OA_Engagement_Config__mdt` (1, ERE), `OA_Graph_Config__mdt` (1, modules). No duplicate CMDT type. `OA_Connector_Registry__mdt` vs `OA_Enrichment_Source__mdt`/`_Pipeline__mdt` enumerate the same 6–8 sources with partially overlapping purpose → **NEEDS-REVIEW** (registry = class wiring; source/pipeline = precedence/stage config; not strictly duplicative).

**Staging / custom objects:**
- `OA_Discovered_Organization__c` — LIVE canonical staging (all Framework-B connectors). **KEEP.**
- `OA_SAM_Entity_Staging__c` — written only by DEAD `OA_SAMConnector`/`OA_SAMMapper`. **DEAD (orphaned).**
- `OA_USASpending_Staging__c` — written by Framework-A USASpending + service, **but still read by LIVE `OA_LeadWritebackService`**. **NEEDS-REVIEW (not safe to remove).**
- `OA_Opportunity_Signal__c` — distinct grain (Opportunity Intelligence). **SHARED.**

**Permission sets (overlapping grants):**
- `OA_USASpending_Staging__c` granted by three permsets (`OA_Connector_Staging`, `OA_Lead_Writeback_Automation`, `OA_Lead_Writeback_Reviewer`). NEEDS-REVIEW.
- `OA_Connector_Run__c` + `OA_Enrichment_Exception__c` granted by both `OA_Lead_Enrichment_Runtime` and `OA_Opportunity_Intelligence_Runtime` (intentional domain split). NEEDS-REVIEW.
- `OA_SAM_Connector` permset grants only the DEAD `OA_SAM_Entity_Staging__c`. **DEAD permset.**
- `OA_LinkedIn_Connector`, `OA_Meta_Connector`, `OA_Campaign_Fields` grant no object perms (field/app-only or placeholder). NEEDS-REVIEW.

**Named Credentials:** 9 total; `OA_SAM` (entity) vs `OA_SAM_Opportunities` (opportunities) hit different SAM.gov APIs → **SHARED, not duplicate**. No true NC duplication.

---

## 5. Empty / placeholder metadata

`.gitkeep`-only (empty): entire `clients/pbo/` (8 dirs); `force-app/main/default/{components,duplicateRules,lwc,matchingRules,pages,staticresources}`; `modules/marketing-automation/main/default/{email,flows}`; `scripts/apex`. The empty `duplicateRules`/`matchingRules` dirs are expected — those rules exist in the org and are listed in `manifest/package-core.xml` for retrieval only.

---

## 6. Broken / phantom references

1. **Registry → interface mismatch (most significant):** `OA_Connector_Registry__mdt` rows **`GrantsGov`** and **`SAM_Opportunities`** point at `OA_IConnector` (Framework A) classes, but `OA_ConnectorRunner` casts to `OA_IEnrichmentConnector` and would reject them. Dormant (`Enabled__c=false`) → **no live failure**, but the wiring is broken/vestigial. **NEEDS-REVIEW** — remove these rows from the enrichment registry or give them a distinct runner. Detail in [CONNECTOR_REGISTRY_REVIEW.md](CONNECTOR_REGISTRY_REVIEW.md).
2. **Phantom manifest members:** `manifest/package-core.xml` → PermissionSet `OpenAI_Access` (no such file); `manifest/package-marketing.xml` → Flow `lead_by_ramesh` (untracked stray only). Retrieval manifests reference org-only/absent members.
3. **Flow package-boundary mismatch:** `OA_EDWOSB_Outreach_Sequence`, `OA_Reply_Detection` live in `force-app/` but are listed as marketing members; `OA_PostMeeting_Nurture` in no manifest. Not a hard break.
4. **`OA_Anthropic` NC → uncommitted External Credential** — expected (EC files gitignored).

---

## 7. Integrity verdict

| Area | Verdict |
|---|---|
| Duplicate connectors | **Known & mapped** — one live generation (B) for LE; DEAD Framework-A LE classes identified; Framework A retained for OI only |
| Duplicate objects | 1 DEAD (`OA_SAM_Entity_Staging__c`), 1 NEEDS-REVIEW (`OA_USASpending_Staging__c` — live dependency) |
| Duplicate permsets | 1 DEAD (`OA_SAM_Connector`), overlaps documented |
| Duplicate NCs / CMDT types | **None** |
| Cross-package dup | 1 (`OA_BookingPoller` ×2 — DEAD copy in force-app) |
| Broken references | 1 significant (registry↔interface, dormant), 2 phantom manifest members |
| Live path integrity | **PASS** — the certified Framework-B enrichment path is internally consistent and fully dormant |

**Net:** the platform's *live* architecture is clean and consistent. All duplication is **legacy sediment** from three connector generations plus one cross-package copy — none of it is active, and every item is now ranked with its dependencies. Retirement is planned (not executed) in the [Cleanup Roadmap](CLEANUP_ROADMAP.md).
