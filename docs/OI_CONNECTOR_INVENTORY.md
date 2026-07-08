# Opportunity Intelligence — Connector Inventory & Source Readiness

**Program 2 · Phase 0 (design only) · 2026-07-08**

Two parts: (A) what connector machinery already exists in the org/repo and how OI relates to it,
and (B) the readiness of each candidate opportunity source. **No live opportunity-API calls were
made in Phase 0** — source characteristics are from public API docs + prior connector experience
and must be re-verified during each build slice.

---

## Part A — Existing connector machinery (repo inventory)

### A1. Certified SDK ("underscore" generation) — reuse anchors
| Component | Kind | Role | OI verdict |
|---|---|---|---|
| `OA_ConnectorRunner` | Apex | registry-driven dispatcher; `Type.forName`; no source branches; **no DML by default** | **Reuse** |
| `OA_ConnectorHttp` | Apex | HTTP wrapper | **Reuse** |
| `OA_Connector_Registry__mdt` | CMDT | per-source config (see fields below) | **Extend via new rows** |
| `OA_Connector_Run__c` | Object | run telemetry/provenance | **Reuse** (`Category='Opportunity'`) |
| `OA_IConnector`, `OA_IConnectorRequest/Parser/Mapper` | Interfaces | per-source contract | **Reuse (implement)** |
| `OA_ConnectorMock`, `OA_ConnectorTestBase` | Apex | test HTTP scaffolding | **Reuse** |
| `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | Apex+Obj | human-review routing (4 cases) | **Reuse** |
| `OA_ChangeLogService` + `OA_Enrichment_Change_Log__c` | Apex+Obj | before/after audit + rollback | **Reuse (Phase 5)** |

`OA_Connector_Registry__mdt` fields (verified present): `Connector_Class__c`, `Parser_Class__c`,
`Mapper_Class__c`, `Named_Credential__c`, `Endpoint_Path__c`, `Enabled__c`, `Category__c`,
`Source_System__c`, `Dedupe_External_Id_Field__c`, `Staging_Object__c`, `Review_Required__c`,
`Owner_Steward__c`, `Version__c`, `Status__c`. **Conclusion:** it already carries every field OI
needs; no new source CMDT is required ([ADR-016](decisions/ADR-016-opportunity-registry-and-run-reuse.md)).

`OA_Connector_Run__c` fields (verified present): `Run_ID__c` (ExtId), `Source_System__c`,
`Category__c`, `Status__c`, `Requested__c`, `Parsed__c`, `Mapped__c`, `Persisted__c`,
`Records_Enriched__c`, `HTTP_Errors__c`, `Parse_Errors__c`, `Exceptions_Raised__c`,
`Endpoint__c`, `Started__c`, `Ended__c`, `Initiated_By__c`, `Messages__c`.

### A2. Enrichment-specific engines — model, don't reuse directly
| Component | Why not a direct OI reuse |
|---|---|
| `OA_FieldWritePolicyEngine` + `OA_Field_Write_Policy__mdt` | governs *field writes onto existing Lead/Account*; OI creates *new records* — no field-overwrite decision. **Imitate the "Active+Trusted CMDT gate" pattern** for the Phase-3 scoring ruleset; do not call it. |
| `OA_ProposalAdapter` (`toLeadProposals`) | hard-wired to **Lead** grain + enrichment mappers. **Leave alone**; OI writes an opportunity mapper that emits new-object rows. |
| `OA_EnrichmentWriter/Orchestrator/Queueable` | Lead Enrichment (maintenance mode). **Do not touch.** |
| `OA_ConfidenceEvaluator`, `OA_NameNormalizer`, `OA_CanonicalOrg` | useful only if/when OI links an opportunity to an Account (read-only, ADR-007). **Optional, later.** |

### A3. Existing source connectors — relationship to OI
| Connector | API | OI verdict | Note |
|---|---|---|---|
| `OA_USASpending_*` (underscore) | USASpending (keyless, certified, HTTP 200 proven) | **Reuse in Phase 3** | past-performance scoring factor, not an opportunity feed |
| `OA_SAM_Connector` (underscore) | SAM **Entity** API (`api.sam.gov`) | **Leave alone** | wrong API for OI (needs SAM *Opportunities*); do not repoint |
| `OA_Census_*`, `OA_IRS_*`, `OA_SEC_*` | entity data | **Leave alone** | not opportunity sources |
| Legacy gen (`OA_USASpendingClient`, `OA_USASpendingConnector`, `OA_SAMConnector`, `OA_IConnector`) | — | **Leave alone (dead-code candidate)** | orphaned/zero-callers; separate cleanup, not OI |

### A4. New OI connector classes (Phase 1–2, thin, design only)
| Class | Phase | Responsibility |
|---|---|---|
| `OA_GrantsGov_Request` | 1 | build Grants.gov Search2 REST call from registry config |
| `OA_GrantsGov_Parser` | 1 | response JSON → in-memory signal rows |
| `OA_GrantsGov_Mapper` | 1 | rows → `OA_Opportunity_Signal__c` (dedupe by `Canonical_Key__c`) |
| `OA_OpportunitySignalService` | 1 | orchestrate fetch→parse→map→optional persist; callout-before-DML; `commit=false` default |
| `OA_SAMOpportunities_Request/Parser/Mapper` | 2 | same shape, SAM get-opportunities v2 |

---

## Part B — Source readiness matrix

| Source | Auth | API key? | Data | SF target | Rate limits / risk | Sequence |
|---|---|---|---|---|---|---|
| **Grants.gov** (Search2 REST) | none (public) | ❌ | federal grants: opportunityNumber, CFDA/AssistanceListings, category, postDate, closeDate, awardCeiling/Floor, eligibility | `OA_Opportunity_Signal__c` (Type=Grant) | low; be polite w/ paging; grant≠contract workflow | **P1 — first live slice** |
| **SAM.gov Contract Opportunities** (get-opportunities v2) | data.gov `api_key` header | ✅ **not provisioned** | contracts: noticeId, title, solicitationNumber, fullParentPathName (agency), naicsCode, classificationCode (PSC), typeOfSetAside, placeOfPerformance, postedDate, responseDeadLine, value, uiLink | `OA_Opportunity_Signal__c` (Type=Contract) | key historically unresolved (alpha/prod, validity); pagination; large volumes → dedupe by noticeId | **P2** (highest value; gated on key) |
| **SBIR/STTR** (SBIR.gov solicitations) | none (public) | ❌ | R&D topics/solicitations | Signal (Type=SBIR) | historical 429s; topic taxonomy; varied cadence | P3 |
| **Federal Register** (federalregister.gov API v1) | none (public) | ❌ | notices/rules — agency **context/signal**, not solicitations proper | Signal (Type=Notice) or context-only | low; high volume/noise → tight agency+doc-type filters or it floods the queue | P3 (context, not primary feed) |
| **data.gov** (CKAN catalog) | none (catalog); datasets vary | mixed | meta-catalog that *points to* datasets (incl. SAM) — not a single opportunity feed | n/a (discovery/directory) | heterogeneous; each dataset its own contract | P4 (treat as directory, not a connector) |
| **USASpending** (reuse) | none (certified) | ❌ | *awarded* history (past performance) | feeds `OA_Opportunity_Score__c` past-perf factor | none observed | **reuse in Phase 3 scoring**, not a feed |

### Per-source notes
- **Grants.gov (P1):** identical pipeline exercise to SAM with **zero external-credential
  dependency** → de-risks the whole platform before betting on the blocked SAM key. A dormant
  Grants.gov staging prototype exists on `feature/grantsgov-lead-enrichment-staging` to consult
  (do not merge; reference for field shape).
- **SAM Opportunities (P2):** a **distinct** endpoint/key from the SAM **Entity** API used by
  Lead Enrichment. Requires a **new** Named/External Credential `OA_SAM_Opportunities`; do **not**
  reuse or repoint the entity `OA_SAM` credential.
- **Federal Register (P3):** best as *context enrichment* (which agencies are active on a topic),
  not as a primary pursuit feed — otherwise it overwhelms the review queue.
- **data.gov (P4):** a directory of datasets, not an opportunity stream; use to *discover* new
  feeds, not as a connector.

### Recommended build order
**Grants.gov (P1, keyless) → SAM Opportunities (P2, on key) → SBIR + Federal Register (P3).**
This inverts ADR-015's original SAM-first order specifically to remove the external-key dependency
from the first live proof.
