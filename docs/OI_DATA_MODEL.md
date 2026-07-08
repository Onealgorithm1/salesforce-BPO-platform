# Opportunity Intelligence — Data Model

**Program 2 · Phase 0 (design only) · 2026-07-08**
Design-only field lists — **nothing built or deployed.** Field API names/types are indicative and
frozen at G0. Relates to [ADR-017](decisions/ADR-017-opportunity-data-model-and-staging-grain.md).

---

## 1. Model overview

OI introduces **exactly one new object for the MVP** (`OA_Opportunity_Signal__c`) and **reuses**
telemetry, exception, and audit objects. Scoring/assessment/pursuit objects are **designed here
but deferred** to later phases.

```
OA_Connector_Run__c (REUSE, Category='Opportunity')
        │ 1
        │ *          ┌──────────────────────────────┐
        └──────────► │ OA_Opportunity_Signal__c      │  ← MVP (Phase 1)
                     │  (one opportunity posting)    │
                     └───────┬───────────────┬───────┘
              Phase 3 │ 1..* │        Phase 4 │ 1..1
                      ▼                       ▼
         OA_Opportunity_Score__c    OA_Go_NoGo_Assessment__c   OA_Pursuit_Candidate__c
              (deferred)                  (deferred)                 (deferred)

REUSE for anomalies:  OA_Enrichment_Exception__c
REUSE for writeback audit (Phase 5): OA_Enrichment_Change_Log__c
```

## 2. `OA_Opportunity_Signal__c` — MVP object (Phase 1)

Grain: **one opportunity posting**, normalized (source-neutral). Ships empty/dormant.

| Field API | Type | Purpose / notes |
|---|---|---|
| `Canonical_Key__c` | Text(120), **External Id, Unique** | dedupe identity, source-scoped (e.g. `GRANTS:<oppNumber>`, `SAM:<noticeId>`). Idempotent re-runs. |
| `Source__c` | Picklist (Grants.gov / SAM.gov / SBIR / FederalRegister) | origin feed |
| `Type__c` | Picklist (Contract / Grant / SBIR / Notice) | opportunity class |
| `Title__c` | Text(255) | posting title |
| `Solicitation_Number__c` | Text(80) | solicitation/opportunity number |
| `Agency__c` | Text(255) | issuing agency (SAM `fullParentPathName`, Grants `agencyCode`) |
| `NAICS__c` | Text(255) | NAICS code(s), comma-joined (multi) |
| `PSC__c` | Text(40) | product/service code (SAM `classificationCode`) |
| `Set_Aside__c` | Text(80) | set-aside type (EDWOSB/WOSB/SB/none) |
| `Assistance_Listing__c` | Text(40) | CFDA / Assistance Listing (grants) |
| `Place_of_Performance__c` | Text(255) | geography |
| `Posted_Date__c` | Date | posting date |
| `Response_Deadline__c` | Date | close/response deadline (queue sort key) |
| `Estimated_Value__c` | Currency(16,2) | value/award ceiling when present |
| `URL__c` | URL(255) | canonical link (SAM `uiLink`, Grants detail) |
| `Status__c` | Picklist (New / Active / Expired) | posting lifecycle from source |
| `Confidence__c` | Picklist (High / Medium / Low) | parse/normalization confidence |
| `Review_Status__c` | Picklist (Pending / Reviewed / Dismissed / Promoted), default **Pending** | human-review state |
| `Reviewed_By__c` | Lookup(User) | who actioned it (blank until reviewed) |
| `Reviewed_At__c` | DateTime | when actioned |
| `Review_Notes__c` | Long Text(4000) | reviewer notes |
| `Connector_Run__c` | Lookup(`OA_Connector_Run__c`) | provenance / delete-by-run reversibility |
| `Raw_Payload_Ref__c` | Text(255) | pointer/hash to source payload (no PII), lineage |

**Indexes:** `Canonical_Key__c` (unique ExtId), plus report/list-view filters on
`Review_Status__c`, `Response_Deadline__c`, `Source__c`.

## 3. Reused objects (no new build)

| Object | Reuse in OI | Fields used |
|---|---|---|
| `OA_Connector_Run__c` | run telemetry, `Category__c='Opportunity'` | Run_ID, Source_System, Status, Requested/Parsed/Mapped/Persisted, HTTP_Errors, Started/Ended, Initiated_By |
| `OA_Enrichment_Exception__c` | fetch/parse/low-confidence anomalies routed to a human | Exception_Type, Target_Object=`OA_Opportunity_Signal__c`, Details, Recommended_Resolution, Connector_Run, Status |
| `OA_Enrichment_Change_Log__c` | **Phase 5 only** — audit + rollback of CRM writeback | Target_Object, Field_API_Name, Old/New_Value, Before_Snapshot, Change_Type, Connector_Run |

> Naming note: the exception/change-log objects say "Enrichment" but their services are generic
> (they build rows for any target object). Reusing them avoids two near-duplicate objects. If a
> clean OI-only audit trail is later preferred, that is a deliberate Phase-5 decision, not a Phase-1 need.

## 4. Deferred objects (designed, NOT built until their phase)

### `OA_Opportunity_Score__c` — Phase 3 (explainable scorecard)
Grain: one scoring pass on a signal. Master-detail → Signal.
Fields: `Total_Score__c` (0–100), `Band__c` (High/Med/Low), per-factor sub-scores **and reason
strings** (`NAICS_Score__c`, `SetAside_Score__c`, `Agency_Score__c`, `Capability_Score__c`,
`Value_Score__c`, `Deadline_Score__c`, `Geo_Score__c`, `PastPerf_Score__c`, `Risk__c`),
`Partner_Needed__c` (checkbox), `Ruleset_Version__c`, `Explanation__c` (Long Text).
Weights live in a new `OA_Opportunity_Score_Weight__mdt` (CMDT) so tuning needs no code —
mirroring the `OA_Field_Write_Policy__mdt` "config-not-code" pattern.

### `OA_Go_NoGo_Assessment__c` — Phase 4 (human decision record)
Fields: `Signal__c`, `Score__c`, `Recommendation__c` (system draft: Go/No-Go/Watch),
`Decision__c` (**blank until a human sets it**), `Decided_By__c`, `Decided_At__c`, `Rationale__c`.
**The system never sets `Decision__c`.**

### `OA_Pursuit_Candidate__c` — Phase 4 (internal pipeline)
Fields: `Signal__c`, `Assessment__c`, `Stage__c` (Draft/UnderReview/Approved/Rejected), `OwnerId`,
`Partner_Needed__c`, `Notes__c`. May link an Account **read-only** (ADR-007). Approval here is the
gate that can (Phase 5) create a CRM `Opportunity`.

## 5. Custom metadata

| CMDT | Phase | Purpose |
|---|---|---|
| `OA_Connector_Registry__mdt` (**reuse**) | 1 | add rows `GRANTS_GOV`, later `SAM_OPPORTUNITIES` (`Category='Opportunity'`, `Enabled__c=false`) |
| `OA_Opportunity_Score_Weight__mdt` (**new, deferred**) | 3 | per-factor scoring weights + bands (config-not-code) |

## 6. What OI never writes

Lead, Account, Contact (except read-only Phase-5 association), Campaign, CampaignMember, any ERE
object, any Analytics object, any Lead-Enrichment object. The MVP's only DML is
`insert OA_Opportunity_Signal__c` (+ optional reused exception/run rows).
