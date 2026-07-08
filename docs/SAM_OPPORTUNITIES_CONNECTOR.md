# SAM.gov Opportunities Connector — Opportunity Intelligence Phase 2

**Program 2 · Phase 2 (second source) · 2026-07-08**
**Status:** built + check-only validated · **DORMANT** · not deployed · staging-only · human-gated
Branch: `feature/opportunity-intelligence-sam-opportunities` (off `main`).
Implements the prepared design in [SAM_OPPORTUNITIES_CONNECTOR_DESIGN.md](SAM_OPPORTUNITIES_CONNECTOR_DESIGN.md);
relates to ADR-015…019 and the P1 Grants.gov slice.

---

## 1. What this is
The second Opportunity Intelligence source: the **SAM.gov Get Opportunities** API
(`/opportunities/v2/search`) — federal **contract solicitations** — normalized into the shared
`OA_Opportunity_Signal__c` human-review queue. Distinct from the existing SAM **Entity** connector
(different API, endpoint, credential, and grain). Creates **no** CRM `Opportunity`, touches **no**
Lead/Account, enables **no** automation, and stores **no** secrets in git.

## 2. Reuse-first (what was reused vs. built)
| Reused as-is (no edits) | Role |
|---|---|
| `OA_ConnectorEngine`, `OA_ConnectorHttp` | build→send→parse→map lifecycle; no DML |
| `OA_ConnectorPersistence` | idempotent staging upsert on `Canonical_Key__c` |
| `OA_Connector_Registry__mdt` | new row `SAM_Opportunities` (`Category=Opportunity`, `Enabled__c=false`) |
| `OA_Connector_Run__c` | telemetry (`Category=Opportunity`) |
| `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | anomaly → human review |
| **`OA_Opportunity_Signal__c`** (P1) | shared staging + review queue (target object) |
| `OA_Opportunity_Intelligence_Runtime` permset (P1) | object/telemetry/exception FLS (extended with 2 fields) |
| `OA_IConnector*`, `OA_ConnectorRow`, `OA_ConnectorContext`, `OA_ConnectorMock` | SDK contracts + test scaffold |

| Built new (thin, additive) | Role |
|---|---|
| `OA_SAMOpportunities_Request` | GET `/opportunities/v2/search` with date-window + filters; **key via EC header, never in URL** |
| `OA_SAMOpportunities_ResponseParser` | `opportunitiesData[]` → rows (nested PoP, NAICS single/multi, carries `totalRecords`) |
| `OA_SAMOpportunities_Mapper` | row → `OA_Opportunity_Signal__c` (`Canonical_Key__c='SAM:'+noticeId`) |
| `OA_SAMOpportunities_Connector` | `OA_IConnector` identity |
| `OA_SAMOpportunitiesService` | engine + persistence + telemetry + exceptions; **pagination** (offset loop, callout-before-DML, capped); `commit`-gated |
| `OA_SAM_Opportunities` Named Credential | prod `https://api.sam.gov`, `SecuredEndpoint`, secret-free (references UI-provisioned EC) |
| `OA_Connector_Registry.SAM_Opportunities` CMDT | registry row (dormant) |
| 2 fields on `OA_Opportunity_Signal__c`: `PSC__c`, `Place_of_Performance__c` | SAM data the object lacked (Phase-3 scorer inputs) |

## 3. Field mapping (SAM `opportunitiesData[]` → `OA_Opportunity_Signal__c`)
`noticeId`→`Canonical_Key__c`(`SAM:`+)/`Raw_Payload_Ref__c` · `title`→`Title__c` ·
`solicitationNumber`→`Opportunity_Number__c` · `fullParentPathName`→`Agency__c` ·
`naicsCode`/`naicsCodes[]`→`NAICS__c` · `classificationCode`→`PSC__c` ·
`typeOfSetAsideDescription`/`typeOfSetAside`→`Set_Aside__c` · `placeOfPerformance`→`Place_of_Performance__c` ·
`postedDate`→`Posted_Date__c` · `responseDeadLine`→`Response_Deadline__c` · `award.amount`→`Estimated_Value__c` ·
`uiLink`→`URL__c` · `active`→`Source_Status__c`/`Status__c` · constants `Source__c='SAM.gov'`, `Type__c='Contract'`,
`Review_Status__c='Pending'`. Absent fields → null (never fabricated).

## 4. Safety guarantees (verified by tests)
- `preview()` = **0 DML**; `run(commit=true)` = **staging only** (signal upsert + telemetry + exceptions).
- **No CRM writes** — test asserts `COUNT(Lead) == 0` after a committed run.
- Every signal `Review_Status__c='Pending'` (human gate).
- **Pagination** loops offset/limit with **all callouts before any DML**, capped by `maxPages`.
- **No secrets** — the data.gov key is injected by the External Credential as `X-Api-Key`; never in URL/Apex/git.
- **Dormant** — registry `Enabled__c=false`, permset unassigned, no triggers/flows/schedules. Kill switch = registry `Enabled__c`.

## 5. Validation evidence
- **Check-only deploy validation** (validateOnly — nothing persisted): **Succeeded**, id
  **`0AfPn0000023YK9KAM`**, tests **9/9 passing, 0 failures**.
- **Live API:** not exercised — SAM Opportunities requires a data.gov key that is **not provisioned**
  (gated, RED). Connectivity is to be confirmed in a gated smoke test at go-live.
- **Not deployed:** `sf project deploy quick` intentionally NOT run. Production unchanged.

## 6. Credential (RED / gated — Louis)
The **Named Credential `OA_SAM_Opportunities`** ships secret-free (references External Credential
`OA_SAM_Opportunities`). Its **External Credential** (holding the data.gov key) is **UI-provisioned
in Setup, never in git** — and does not yet exist, so the NC is **excluded from the check-only
validation** (it would fail on the missing EC) and ships as the gated deploy artifact. Go-live
requires (RED): provision + confirm the data.gov key (2xx), create the EC, grant EC principal access,
assign the permset to the runtime user.

## 7. How to run (after an authorized deploy — gated)
```apex
Map<String,Object> cfg = new Map<String,Object>{
    'postedFrom' => '06/01/2026', 'postedTo' => '06/30/2026',   // <= 1-year window
    'ncode' => '541512', 'typeOfSetAside' => 'SBA', 'limit' => 100, 'maxPages' => 5 };
OA_SAMOpportunitiesService.Outcome p = OA_SAMOpportunitiesService.preview(cfg);        // 0 DML
OA_SAMOpportunitiesService.Outcome c = OA_SAMOpportunitiesService.run(cfg, true);      // staging only
```

## 8. Next (gated)
1. **G1** — dormant deploy (object+2 fields, classes, CMDT, permset; then NC after EC exists).
2. **B1/B2** — provision data.gov key + EC + principal access (RED, Louis).
3. **G2** — preview → inspect → approve a small committed run into the review queue.
4. Phase 3 — explainable scoring over the enriched signals (NAICS/set-aside/PSC now captured).
