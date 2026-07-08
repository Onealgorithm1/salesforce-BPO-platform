# Grants.gov Connector — Opportunity Intelligence Phase 1

**Program 2 · Phase 1 (first live source) · 2026-07-08**
**Status:** built + check-only validated · **DORMANT** · not deployed · staging-only · human-gated
Branch: `feature/opportunity-intelligence-grants-slice` (off `main`). Relates to ADR-015…019.

---

## 1. What this is

The first Opportunity Intelligence source connector. It fetches federal grant opportunities from
the **public, keyless Grants.gov Search2 API**, normalizes them into `OA_Opportunity_Signal__c`
(the human-review queue), and stops. It creates **no** CRM `Opportunity`, touches **no** Lead/
Account/Campaign, enables **no** automation, and stores **no** secrets.

Grants.gov was chosen as the first slice (ahead of SAM.gov Opportunities) precisely because it needs
**no API key** — proving the whole pipeline end-to-end with zero external-credential dependency.

## 2. Reuse-first (what was reused vs. built)

| Reused as-is (certified SDK, no edits) | Role |
|---|---|
| `OA_ConnectorEngine` | build → send → parse → map lifecycle; **no DML** |
| `OA_ConnectorHttp` | mockable transport |
| `OA_ConnectorPersistence` | idempotent staging upsert on External Id; "does not read or write Lead records" |
| `OA_Connector_Registry__mdt` | source config (new row `GrantsGov`, `Category=Opportunity`, `Enabled__c=false`) |
| `OA_Connector_Run__c` | run telemetry (stamped `Category=Opportunity`) |
| `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | anomaly → human-review routing |
| `OA_IConnector/Request/Parser/Mapper`, `OA_ConnectorRow`, `OA_ConnectorContext`, `OA_ConnectorMock` | SDK contracts + test scaffold |

| Built new (thin) | Role |
|---|---|
| `OA_Opportunity_Signal__c` (+24 fields) | opportunity-grain staging + review queue (ADR-017) |
| `OA_GrantsGovRequest` | builds the Search2 POST from registry config |
| `OA_GrantsGovParser` | Search2 JSON → normalized rows |
| `OA_GrantsGovMapper` | row → `OA_Opportunity_Signal__c` (dedupe key, Review_Status=Pending) |
| `OA_GrantsGovConnector` | `OA_IConnector` identity (source, NC, staging type) |
| `OA_GrantsGovService` | orchestrator: engine + persistence + telemetry + exceptions; `commit` gated |
| `OA_GrantsGov` Named Credential | public endpoint `https://api.grants.gov` (NoAuth, no secret) |
| `OA_Connector_Registry.GrantsGov` CMDT | registry row (dormant) |
| `OA_Opportunity_Intelligence_Runtime` permset | CRUD/FLS on the OI objects; **unassigned** |

## 3. Data flow

```
Grants.gov Search2 (POST /v1/api/search2, public)
   └─ OA_GrantsGovRequest ─► OA_ConnectorEngine ─► OA_GrantsGovParser ─► OA_GrantsGovMapper
                                    │ (in memory, 0 DML)                        │
                                    ▼                                          ▼
                       OA_ConnectorRunResult ───────────────► OA_Opportunity_Signal__c (Review_Status=Pending)
                                    │ commit=true only              (idempotent upsert on Canonical_Key__c)
                                    ├─► OA_Connector_Run__c (telemetry)
                                    └─► OA_Enrichment_Exception__c (anomalies → human review)
```

Dedupe/idempotency key: `Canonical_Key__c = 'GRANTS:' + opportunityNumber` (External Id, Unique) —
re-running a fetch **upserts**, never duplicates.

## 4. Safety guarantees (verified by tests)

- **preview()** performs **0 DML** — proposed signals returned in memory only.
- **run(commit=true)** writes **staging only**: `OA_Opportunity_Signal__c` (upsert) +
  `OA_Connector_Run__c` (telemetry) + `OA_Enrichment_Exception__c` (anomalies).
- **No CRM writes** — test asserts `COUNT(Lead) == 0` after a committed run.
- Every signal lands `Review_Status__c = 'Pending'` (the human gate).
- **Dormant** — registry `Enabled__c=false`, permset unassigned, object ships empty, no triggers/
  flows/schedules. Kill switch = the registry row's `Enabled__c`.
- **No secrets** — Grants.gov is public; the Named Credential holds an endpoint only.

## 5. Validation evidence

- **Live API connectivity (read-only):** `POST https://api.grants.gov/v1/api/search2` →
  **HTTP 200**, `errorcode=0`, `hitCount=736`; fields `id, number, title, agencyCode, agency,
  openDate, closeDate, oppStatus, docType, cfdaList` (parser matches this exact shape).
- **Check-only deploy validation** (validateOnly — nothing persisted): **Succeeded**,
  deploy id `0AfPn0000023XUXKA2`, **34 components**, tests **9/9 passing, 0 failures**.
- **Not deployed:** `sf project deploy quick` was intentionally NOT run. Metadata exists on the
  branch only. Production is unchanged.

## 6. How to run (after an authorized deploy — gated)

Deployment and enablement are **not** performed here (awaiting approval). Once deployed dormant and
approved:

```apex
// PREVIEW (0 DML) — inspect proposed signals, writes nothing
OA_GrantsGovService.Outcome p = OA_GrantsGovService.preview(
    new List<String>{ 'small business' },
    new Map<String,Object>{ 'rows' => 25, 'oppStatuses' => 'posted' });
System.debug(p.mapped + ' signals previewed; committed=' + p.committed);

// COMMITTED run (staging only) — human reviews the queue afterward
OA_GrantsGovService.Outcome c = OA_GrantsGovService.run(
    new List<String>{ 'small business' }, null, true);
```

Review queue: `SELECT Title__c, Agency__c, Response_Deadline__c, URL__c FROM OA_Opportunity_Signal__c
WHERE Review_Status__c = 'Pending' ORDER BY Response_Deadline__c`.

## 7. Scope notes / limitations

- The Search2 **list** endpoint returns lightweight records; **NAICS, set-aside, and value are not
  in the list response** (they require a per-record detail fetch). Those fields exist on the object
  (Phase-2 ready) but stay null for the Grants.gov MVP.
- One broad keyword query per run by default; multiple keywords supported via the `keywords` list.

## 8. Next (gated)

1. **G1** — approve dormant deploy of this package.
2. **G2** — preview run → inspect → approve a small committed run into the review queue.
3. **Phase 2** — `OA_SAMOpportunities_*` (same shape) once Louis provisions a data.gov key in a new
   External Credential `OA_SAM_Opportunities`.
4. Optional enhancement — Grants.gov detail fetch to populate NAICS/value.
