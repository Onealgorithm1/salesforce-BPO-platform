# Opportunity Intelligence — Reuse Analysis

**Program 2 · Phase 0 (design only) · 2026-07-08**

Component-by-component verdict for every platform asset OI might touch. Verdicts:
**Reuse** (use as-is) · **Extend** (additive on top, no edits to the original) · **Leave Alone**
(don't use, don't touch) · **Replace/New** (supersede or create) · **Do Not Touch** (hard guardrail).

Headline: **~80% of OI is reuse/extend of certified assets; the only genuinely new thing for the
MVP is one object + one thin connector + one permset.**

---

## Connector SDK (certified "underscore" generation)
| Component | Verdict | Rationale |
|---|---|---|
| `OA_ConnectorRunner` | **Reuse** | source-agnostic dispatcher, `Type.forName`, **no DML by default** — OI adds registry rows, not runner edits |
| `OA_ConnectorHttp` | **Reuse** | standard callout wrapper |
| `OA_Connector_Registry__mdt` | **Extend (new rows)** | already has Connector/Parser/Mapper/NamedCredential/Endpoint/Enabled/Category/Dedupe/Staging/ReviewRequired — no new CMDT needed |
| `OA_Connector_Run__c` | **Reuse** | has `Category__c`; stamp `Opportunity` |
| `OA_IConnector` / `_Request` / `_Parser` / `_Mapper` | **Reuse (implement)** | new OI classes implement these |
| `OA_ConnectorMock`, `OA_ConnectorTestBase` | **Reuse** | test HTTP scaffolding |
| `OA_ConnectorEngine`, `OA_ConnectorContext`, `OA_ConnectorRow`, `OA_ConnectorRunResult`, `OA_ConnectorPersistence` | **Reuse (as invoked by runner)** | SDK internals; do not edit |

## Governance / audit / exception
| Component | Verdict | Rationale |
|---|---|---|
| `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | **Reuse** | generic human-review routing; target object = the new signal |
| `OA_ChangeLogService` + `OA_Enrichment_Change_Log__c` | **Reuse (Phase 5)** | before/after snapshot + rollback for CRM writeback; not needed for insert-only MVP |
| `OA_FieldWritePolicyEngine` + `OA_Field_Write_Policy__mdt` | **Leave Alone (model only)** | governs *field writes onto existing records*; OI creates new records. Imitate the Active+Trusted CMDT gate for Phase-3 scoring; don't call it |
| `OA_ConfidenceEvaluator`, `OA_NameNormalizer`, `OA_CanonicalOrg` | **Reuse (optional, later)** | only if OI links an opportunity to an Account (read-only, ADR-007) |

## Proposal / writeback (Lead Enrichment)
| Component | Verdict | Rationale |
|---|---|---|
| `OA_ProposalAdapter` (`toLeadProposals`) | **Leave Alone** | wired to Lead grain + enrichment mappers; OI writes an opportunity mapper to a new object |
| `OA_EnrichmentWriter` / `OA_EnrichmentOrchestrator` / `OA_EnrichmentQueueable` | **Do Not Touch** | Lead Enrichment (maintenance mode) |
| `OA_LeadWritebackService` (deployed dormant, unauthorized) | **Do Not Touch** | explicitly out of scope |

## Staging / data objects
| Component | Verdict | Rationale |
|---|---|---|
| `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c`, `OA_Discovered_Organization__c` | **Leave Alone** | entity/company grain; opportunity is a different grain — reusing them would pollute enrichment data |
| `OA_Opportunity_Signal__c` (+ deferred Score/Assessment/Pursuit) | **New** | the one new grain OI introduces |

## Sources
| Component | Verdict | Rationale |
|---|---|---|
| `OA_USASpending_*` (certified, keyless) | **Reuse (Phase 3)** | past-performance scoring factor |
| `OA_SAM_Connector` (Entity API, `api.sam.gov`) | **Leave Alone** | wrong API; OI needs SAM *Opportunities* — new NC, new thin classes |
| `OA_Census_*`, `OA_IRS_*`, `OA_SEC_*` | **Leave Alone** | entity sources, not opportunities |
| Legacy gen (`OA_USASpendingClient`, `OA_USASpendingConnector`, `OA_SAMConnector`, `OA_IConnector`) | **Leave Alone (dead-code candidate)** | orphaned/zero-callers; separate cleanup, not OI |
| **New** `OA_GrantsGov_*` (P1), `OA_SAMOpportunities_*` (P2) | **New (thin)** | implement existing interfaces; no framework edits |

## Explicit no-touch zones (guardrails)
| Zone | Verdict |
|---|---|
| ERE (`OA_Engagement_*`, `OA_Engagement_Resolution__c`, `OA_Engagement_Config__mdt`) | **Do Not Touch** |
| Analytics (`Campaign_Funnel_Snapshot__c`, exec-analytics reports/permsets) | **Do Not Touch** |
| Meta / LinkedIn / Auth branches & credentials | **Do Not Touch** |
| Lead Enrichment production behavior / connectors / policies | **Do Not Touch** |

## Net new footprint for the MVP (Phase 1)
- **1 object:** `OA_Opportunity_Signal__c`
- **1 registry row:** `GRANTS_GOV` (`Enabled__c=false`)
- **1 Named Credential:** `OA_GrantsGov` (public, endpoint only, no secret)
- **4 thin classes:** `OA_GrantsGov_Request/Parser/Mapper` + `OA_OpportunitySignalService`
- **Tests** for the above (mocked HTTP, ≥90%)
- **1 permset:** `OA_Opportunity_Intelligence_Runtime` (unassigned)
- **1 report + report type:** "Opportunity Review Queue"

Everything else = reuse of certified, dormant-safe assets.
