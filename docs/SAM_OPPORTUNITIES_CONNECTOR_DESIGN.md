# SAM.gov Opportunities Connector — Design & Build Preparation

_Status: **RESEARCH / DESIGN ONLY — no code, nothing deployed or enabled** · 2026-07-08_
_Program 2 (Opportunity Intelligence) · the **P2** connector slice. Relates to
[ADR-015](decisions/ADR-015-opportunity-intelligence-platform.md),
[ADR-016](decisions/ADR-016-opportunity-registry-and-run-reuse.md),
[ADR-017](decisions/ADR-017-opportunity-data-model-and-staging-grain.md),
and [OI_CONNECTOR_INVENTORY.md](OI_CONNECTOR_INVENTORY.md) /
[OI_DATA_MODEL.md](OI_DATA_MODEL.md) / [OI_STAGING_DESIGN.md](OI_STAGING_DESIGN.md)._

This document prepares the implementation of a **SAM.gov Get Opportunities** connector — the
federal **contract-solicitation** feed for Opportunity Intelligence (OI). It is deliberately
**distinct** from the existing SAM **Entity** connector used by Lead Enrichment: different API,
different endpoint, different credential, different data grain.

---

## 1. Audit of the existing SAM connector (what exists today)

There are **two** SAM code generations in the repo:

| Generation | Classes | Interface | Status |
|---|---|---|---|
| **Active (underscore)** | `OA_SAM_Connector`, `OA_SAM_Request`, `OA_SAM_ResponseParser`, `OA_SAM_Mapper` (+ tests) | `OA_IEnrichmentConnector`, dispatched by `OA_ConnectorRunner` via `OA_Connector_Registry.SAM` | **Live pattern**, dormant (`Enabled__c=false`) |
| **Legacy (no underscore)** | `OA_SAMConnector`, `OA_SAMMapper`, `OA_SAMParser`, `OA_SAMRequest` | old `OA_IConnector` | **Dead code — zero callers/registry refs** (cleanup candidate; not this task) |

**Active connector behavior (the reuse blueprint):**
- Endpoint: `callout:OA_SAM/entity-information/v3/entities` (Named Credential + registry `Endpoint_Path__c`).
- Method `GET`; `Accept: application/json`; 30s timeout.
- Query params: `ueiSAM=<val>` (12-char UEI) **or** `legalBusinessName=<val>`, plus fixed
  `includeSections=entityRegistration,coreData` and **`page=0&size=1`** (single-record fetch, **no pagination**).
- **API key:** injected as an **`X-Api-Key` header by the `OA_SAM` External Credential** — never in the URL.
- Named Credential `OA_SAM` currently points at **`https://api-alpha.sam.gov`** (ALPHA), `SecuredEndpoint`, `generateAuthorizationHeader=false`, secret-free in git; the EC (git-ignored) carries the key.
- Parser reads `entityData[]` → `OA_CanonicalOrg` (UEI, CAGE, legalBusinessName, registrationStatus, expiration, businessTypes/socioeconomic, address, website).
- Mapper emits `OA_EnrichmentWriter.FieldProposal` rows onto **Lead** fields.
- Permission set `OA_SAM_Connector`: Read/Create/Edit on `OA_SAM_Entity_Staging__c` + field FLS; **unassigned**; does **not** grant EC principal access (added separately at the "key gate").

**Findings:**
- The SAM Entity connector is the **wrong API** for opportunities (it returns companies, not solicitations) — **leave it alone; do not repoint** its credential.
- SAM is currently **⚠️ Blocked**: alpha endpoint (should be prod), **EC principal access = 0**, and an **unconfirmed data.gov key** (prior alpha smoke test returned non-2xx).
- Documentation gap: **SAM is absent from `INTEGRATION_REGISTRY.md`** and the two-implementation duplication is **not** in `TECHNICAL_DEBT.md`. (This PR registers SAM — see §9 — and recommends a TD entry.)

---

## 2. Reusable components (reuse as-is, no edits)

Per [OI_REUSE_ANALYSIS.md](OI_REUSE_ANALYSIS.md) and confirmed by the audit:

| Component | Kind | Reuse role for SAM Opportunities |
|---|---|---|
| `OA_ConnectorHttp` | Apex | HTTP wrapper (timeout/headers) |
| `OA_Connector_Registry__mdt` | CMDT | **add one new row** — already carries every needed field |
| `OA_Connector_Run__c` | Object | run telemetry/provenance (`Category__c='Opportunity'`) — delete-by-run reversibility |
| `OA_IEnrichmentConnector` / `OA_ConnectorResult` | Interface/DTO | connector contract (`sourceKey()`, `fetch(input,cfg)`) |
| `OA_ConnectorMock`, `OA_ConnectorTestBase` | Apex | mock-HTTP test scaffolding |
| `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | Apex+Obj | route fetch/parse/low-confidence anomalies to human review (run continues) |
| `OA_Opportunity_Signal__c` | Object | **shared OI MVP object** — the staging/review target (created by the Grants.gov **P1** slice) |
| `OA_OpportunitySignalService` | Apex | **shared OI orchestrator** — fetch→parse→map→optional persist, callout-before-DML, `commit=false` default (also from P1) |

**Do NOT reuse** (entity-grain / enrichment-specific): `OA_SAM_Connector`, `OA_SAM_Entity_Staging__c`,
`OA_EnrichmentWriter`/`OA_ProposalAdapter` (Lead field-proposal path), `OA_CanonicalOrg` as the carrier
(an opportunity is not an org). **No-touch:** Lead Enrichment writeback, ERE, Analytics, Meta/LinkedIn credentials.

---

## 3. Entity API vs Opportunities API — the differences that drive the design

| Aspect | SAM **Entity** Mgmt API (in use) | SAM **Get Opportunities** API (new) |
|---|---|---|
| Purpose | company registration record | **contract solicitations** |
| Path | `/entity-information/v3/entities` | `/opportunities/v2/search` |
| Host (prod) | `api.sam.gov` (repo NC on **alpha**) | `api.sam.gov` (**use prod**) |
| Method | `GET` (POST for sensitive) | `GET` |
| Required params | one search term (`ueiSAM`/`legalBusinessName`) | **`postedFrom`, `postedTo`** (`MM/dd/yyyy`, **≤ 1-year window**) + `api_key` |
| Key filters | `includeSections` | `ncode` (NAICS), `typeOfSetAside`, `ccode` (PSC), `state`, `organizationName`, `status`, `ptype`, `rdlfrom/rdlto` |
| API key transport | `X-Api-Key` header (data.gov) | GSA doc shows **`api_key` query param**; the api.data.gov umbrella **also honors `X-Api-Key` header** → reuse the EC-header pattern (see §5) |
| Grain / volume | one entity per call | **many notices**, paged |
| Pagination | `page/size` (hardcoded `0/1`) | **`offset`/`limit`**, `limit` max **1000**, response `totalRecords` → **must loop** |
| Result array | `entityData[]` | **`opportunitiesData[]`** |
| Dedupe id | UEI | **`noticeId`** → `Canonical_Key__c = 'SAM:' + noticeId` |
| Rate limit (non-fed) | 10/day (no role) · 1,000/day (role) | per-day by role (non-fed/general) |
| SF target | Lead fields (FieldProposal) | **`OA_Opportunity_Signal__c`** (new record, review-gated) |

**Net structural changes vs the Entity connector:** (1) **real pagination** (offset/limit loop to
`totalRecords`, capped); (2) **date-window** request driven by `postedFrom/postedTo` (incremental
pulls); (3) parse `opportunitiesData[]` into the **opportunity/signal grain**, not `OA_CanonicalOrg`;
(4) map to **`OA_Opportunity_Signal__c`** rows, not Lead FieldProposals; (5) a **new credential**.

---

## 4. Implementation plan

Ship **dormant** (`Enabled__c=false`, `commit=false`), behind the same EC-principal-access gate as the
Entity connector. No platform class is edited.

**Apex (4 thin classes + 4 tests) — mirror the underscore pattern:**
1. `OA_SAMOpportunities_Request` — builds `GET callout:OA_SAM_Opportunities/opportunities/v2/search`
   with `postedFrom/postedTo` (from cfg/params), `limit`, `offset`, and ICP filters (`ncode`,
   `typeOfSetAside`, `ptype`, `status=active`); **no key in the URL** (EC header). Endpoint/NC read from the registry row.
2. `OA_SAMOpportunities_ResponseParser` — deserialize; iterate **`opportunitiesData[]`**; per record emit a
   normalized opportunity DTO; read `totalRecords`/`limit`/`offset` for the pager; malformed → `ParseException`; missing array → empty.
3. `OA_SAMOpportunities_Mapper` — DTO → `OA_Opportunity_Signal__c` rows (field map in §5), `Canonical_Key__c='SAM:'+noticeId`, `Source__c='SAM.gov'`, `Type__c='Contract'`.
4. `OA_SAMOpportunities_Connector implements OA_IEnrichmentConnector` — `fetch(input,cfg)`: page-loop
   Request→send→Parser, accumulate signals, never throw (record `httpErrors`/`parseErrors` on the result); hand off to `OA_OpportunitySignalService` for optional persist.

**Orchestration:** reuse `OA_OpportunitySignalService` (P1): callout-before-DML, ≤50 rows/txn, preview
(`commit=false`) → bulk `upsert` on `Canonical_Key__c`, each row stamped with `Connector_Run__c`;
anomalies → `OA_ExceptionRoutingService`.

**Sequencing:** this is **P2**. It depends on the **P1 (Grants.gov, keyless)** slice having created the
shared OI MVP infra (`OA_Opportunity_Signal__c` + `OA_OpportunitySignalService`). Recommended order
(per OI_CONNECTOR_INVENTORY §Recommended build order): **P1 Grants.gov → P2 SAM Opportunities**.

**Tests (≥90%):** request (routes via NC, no key in URL, window+filters set); parser (opportunity
contract, pagination math, malformed→ParseException, unknown fields tolerated); mapper (present values
only, `Canonical_Key__c` shape); connector (mock 2xx multi-page / non-2xx / malformed / thrown). Reuse
`OA_ConnectorMock`/`OA_ConnectorTestBase`.

---

## 5. Field mapping — `opportunitiesData[]` → `OA_Opportunity_Signal__c`

| SAM field | Signal field | Notes |
|---|---|---|
| `noticeId` | `Canonical_Key__c` = `'SAM:'+noticeId`; `Raw_Payload_Ref__c` | unique ExtId / lineage |
| `title` | `Title__c` | Text(255) truncate |
| `solicitationNumber` | `Solicitation_Number__c` | |
| `fullParentPathName` | `Agency__c` | issuing agency hierarchy |
| `naicsCode` | `NAICS__c` | comma-join if multiple |
| `classificationCode` | `PSC__c` | product/service code |
| `typeOfSetAsideDescription` (`typeOfSetAside`) | `Set_Aside__c` | EDWOSB/WOSB/SB/none |
| `placeOfPerformance.{city,state}` | `Place_of_Performance__c` | |
| `postedDate` | `Posted_Date__c` | parse `YYYY-MM-DD` |
| `responseDeadLine` | `Response_Deadline__c` | queue sort key |
| `award.amount` (when present) | `Estimated_Value__c` | Currency |
| `uiLink` | `URL__c` | canonical link |
| `active` (`Yes`/`No`) / `status` | `Status__c` | → New/Active/Expired |
| — | `Source__c='SAM.gov'`, `Type__c='Contract'`, `Review_Status__c='Pending'`, `Confidence__c` | constants / banding |

`typeOfSetAside`, PSC (`classificationCode`), and NAICS are the fields the OI Phase-3 scorer will use;
capture them now even though scoring is deferred. Fields not present → leave **null** (never fabricate).

---

## 6. Metadata required (all new, all dormant)

| Metadata | Name | Key settings |
|---|---|---|
| **CMDT row** | `OA_Connector_Registry.SAM_Opportunities` | `Connector_Class__c=OA_SAMOpportunities_Connector`, `Parser_Class__c=OA_SAMOpportunities_ResponseParser`, `Mapper_Class__c=OA_SAMOpportunities_Mapper`, `Named_Credential__c=OA_SAM_Opportunities`, `Endpoint_Path__c=/opportunities/v2/search`, `Category__c=Opportunity`, `Source_System__c=SAM.gov`, `Staging_Object__c=OA_Opportunity_Signal__c`, `Dedupe_External_Id_Field__c=Canonical_Key__c`, `Enabled__c=false`, `Review_Required__c=true`, `Status__c=Draft`, `Version__c=1.0.0` |
| **Named Credential** | `OA_SAM_Opportunities` | `SecuredEndpoint`, URL `https://api.sam.gov` (**prod**), `generateAuthorizationHeader=false`, references EC `OA_SAM_Opportunities`. **Secret-free — committed.** |
| **External Credential** | `OA_SAM_Opportunities` | Custom; custom header `X-Api-Key` = data.gov key (via principal parameter). **Git-ignored, UI-only** (matches `OA_SAM`/secret-hygiene). **Distinct from `OA_SAM`.** |
| **Permission set** | `OA_SAM_Opportunities_Connector` | EC principal access to `OA_SAM_Opportunities-<principal>` + Read/Create on `OA_Opportunity_Signal__c`. Least-priv, **unassigned by default**. |

**Reused (no new build):** `OA_Opportunity_Signal__c`, `OA_Connector_Run__c`,
`OA_Enrichment_Exception__c`, `OA_Connector_Registry__mdt`/`OA_ConnectorRunner`/`OA_ConnectorHttp`.
No `OA_Field_Write_Policy__mdt` (no Lead writes in MVP); no scoring CMDT (Phase 3).

---

## 7. Configuration required (Setup/gated — RED tier, Louis)

1. **Provision a data.gov API key** with SAM Opportunities (non-federal/role) access, and **confirm it returns 2xx** (the prior alpha smoke test failed).
2. Enter the key in **EC `OA_SAM_Opportunities`** in Setup (UI only — never in git/chat).
3. Point NC `OA_SAM_Opportunities` at **prod** `https://api.sam.gov` (not alpha).
4. Grant **EC principal access** and assign `OA_SAM_Opportunities_Connector` to the runtime user **JIT at go-live** (Modify-All-Data does **not** substitute — Sprint-15 finding).
5. Configure the pull window (`postedFrom/postedTo`, ≤1yr) and ICP filters (NAICS/set-aside) for the run.
6. Leave `Enabled__c=false` until **G1**; run **preview (`commit=false`)** then a human approves **G2** before any commit.

---

## 8. Estimated engineering effort

| Work item | Effort | Note |
|---|---|---|
| 4 Apex classes + 4 tests (pagination + signal mapper are the net-new) | **2–3 dev-days** | pattern exists; ≥90% cov |
| NC + EC + permission set (secret-free NC committed; EC UI-only) | ~0.5 day | mirrors OA_SAM |
| CMDT registry row | ~0.25 day | one record |
| Check-only validation, docs, dormant ship | ~0.5 day | |
| **Connector-specific total (assuming P1 delivered the shared OI MVP infra)** | **≈ 3.5–4.5 dev-days** | |
| _If this slice must ALSO stand up shared OI infra_ (`OA_Opportunity_Signal__c` ~20 fields + `OA_OpportunitySignalService` + OI permset) | **+3–4 dev-days** | normally P1's cost |

Excludes external/owner tasks (key provisioning, App-account role) which are **calendar** blockers, not eng effort.

---

## 9. Blockers

| # | Blocker | Tier | Owner |
|---|---|---|---|
| B1 | **data.gov API key unconfirmed / not provisioned** (prior alpha smoke = non-2xx). Highest-value slice is gated on a valid key. | RED | Louis |
| B2 | **New credential + principal access** — create EC/NC `OA_SAM_Opportunities` and grant EC principal access + permset assignment (RED: credentials + permset assignment). | RED | Louis |
| B3 | **Shared OI MVP infra dependency** — `OA_Opportunity_Signal__c` + `OA_OpportunitySignalService` must exist first (P1 Grants.gov). Build P1 before P2. | Plan | OI program |
| B4 | **Endpoint host** — must target prod `api.sam.gov`; do not reuse/repoint the Entity `OA_SAM` (alpha) credential. | Design | — |
| B5 | **Runtime-user least-privilege** — the temporary `oauser`/MAD exception is the standing top operational risk; prefer a least-priv runtime user before 24/7 automation. | Risk | Louis |
| B6 | **Volume / rate limits** — opportunity search returns large sets; requires real pagination, date-window incrementals, dedupe by `noticeId`, and respect for the per-day key quota. | Design | — |
| B7 | **Activation gates** — enabling (`Enabled__c=true`), permset assignment, and any scheduling are RED actions requiring explicit approval. | RED | Louis |

---

## 10. Definition of Done (build phase — future, gated)

```
[ ] 4 classes (Request/ResponseParser/Mapper/Connector implements OA_IEnrichmentConnector)
[ ] Real pagination (offset/limit → totalRecords, capped) + date-window request
[ ] Map to OA_Opportunity_Signal__c (Canonical_Key__c='SAM:'+noticeId); unavailable fields null
[ ] CMDT registry row + NC (committed, secret-free) + EC (UI-only) + least-priv permset — all dormant
[ ] Tests >=90% (request/parser/mapper/connector, multi-page mock)
[ ] Check-only validated; committed; NOT deployed/enabled
[ ] No platform class touched; no Lead/ERE/Analytics/Enrichment/Meta/LinkedIn asset changed
[ ] Key confirmed 2xx in a gated alpha/prod smoke test before enablement
```

---

_This is preparation only. No Apex, metadata, credential, or deployment change is made by this
document. Build is gated on Louis (key + credentials) and on the P1 OI MVP infra landing first._
