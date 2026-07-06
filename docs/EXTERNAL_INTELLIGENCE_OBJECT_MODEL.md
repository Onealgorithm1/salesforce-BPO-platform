# External Intelligence Object Model (Deliverable 3)

> 🔎 **Phase 6 refocus (2026-07-06):** active phase is **Lead Enrichment only**. The
> **`OA_Opportunity_Signal__c`**, **`OA_Intelligence_Action__c`** (AI activation), and **grant** objects
> are **DEFERRED**. The enrichment phase adds `OA_Enrichment_Change_Log__c`, `OA_Field_Write_Policy__mdt`,
> `OA_Qualification_Rule__mdt`, and `OA_Enrichment_Exception__c` (see
> [`LEAD_ENRICHMENT_PLATFORM.md`](LEAD_ENRICHMENT_PLATFORM.md) §6). Entity/Contract/Compliance/Market
> intelligence objects + `OA_Connector_Run__c` carry into enrichment.

_Status: **DESIGN ONLY — for review** · 2026-07-06. No objects/fields are created here._

Extends ADR-006 (canonical data model). Preserves the existing per-source staging objects as the
immutable landing/provenance layer; adds a **source-neutral canonical layer**, durable **run
telemetry**, and an **activation** object.

---

## 1. Entity–relationship diagram

```
                                    ┌────────────────────────────┐
                                    │  OA_Connector_Registry__mdt │  (declarations; CMDT)
                                    └──────────────┬─────────────┘
                                                   │ declared by
                                                   ▼
   SOURCE (external) ──callout──► [ SDK ] ──► OA_Connector_Run__c  ◄─── provenance for every row
                                                   │ 1
                                                   │
                    ┌──────────────────────────────┼───────────────────────────────┐
                    │ N (each staging row → its run)                                │
                    ▼                                                               │
   LAYER 2  ┌───────────────────────────────────────────────┐                      │
   STAGING  │ OA_USASpending_Staging__c  OA_SAM_Entity_...   │  Review_Status=Pending│
   (per src)│ OA_Grants_Opportunity_Staging__c  (+future)    │                      │
            └───────────────────────┬───────────────────────┘                      │
                                    │ promote (only when Approved)                  │
                                    ▼                                               │
   LAYER 3  ┌─────────────────────────────────────────────────────────────────┐    │
   CANONICAL│                 OA_Entity_Intelligence__c  ◄── HUB (UEI-keyed)    │    │
            │                 ▲        ▲        ▲        ▲        ▲             │    │
            │   Entity__c ────┘        │        │        │        │             │    │
            │   ┌──────────────┐ ┌─────┴─────┐ ┌┴────────┐ ┌──────┴──────┐      │    │
            │   │Opportunity_  │ │Contract_  │ │Compliance│ │Relationship_│      │    │
            │   │Signal__c     │ │Intel__c   │ │_Intel__c │ │Intel__c     │      │    │
            │   └──────────────┘ └───────────┘ └──────────┘ └─────────────┘      │    │
            │              OA_Market_Intelligence__c (context, may be entity-free)│    │
            └───────────────────────┬─────────────────────────────────────────┘    │
                                    │ subject of                                    │
                                    ▼                                               │
   LAYER 4  ┌─────────────────────────────────────────────┐                        │
   ACTIVATE │        OA_Intelligence_Action__c            │── every Action cites ───┘
            │  (AI/rule recommendation; needs approval)   │   its source run + record
            └───────────────────────┬─────────────────────┘
                                    │ (on HUMAN APPROVAL only)
                                    ▼
   CRM      Lead  ·  Account  ·  Contact  ·  Opportunity  ·  Task
              ▲ entity resolution (ADR-007): OA_Entity_Intelligence__c.Lead__c / Account__c

   GRANTS MODULE (Deliverable 7):
      OA_Opportunity_Signal__c ──seeds──► OA_Grant_Workspace__c ──► Proposal / Submission / Checkpoint
```

---

## 2. Object catalog

### Cross-cutting

**`OA_Connector_Run__c`** — one row per connector execution (durable telemetry/provenance).
`Run_ID__c` (ExtId, Unique), `Connector__c` (registry key), `Category__c`, `Started__c`, `Ended__c`,
`Status__c` (Running/Succeeded/PartialErrors/Failed), `Requested__c`, `Parsed__c`, `Mapped__c`,
`Persisted__c`, `HTTP_Errors__c`, `Parse_Errors__c`, `Initiated_By__c` (User), `Endpoint__c`,
`Messages__c` (Long Text). Parent (lookup) of every staging row created in that run.

**`OA_Connector_Registry__mdt`** — connector declarations (see Registry doc). Metadata, not data.

### Layer 2 — Source staging (exists; standard field contract)
`OA_USASpending_Staging__c`, `OA_SAM_Entity_Staging__c`, `OA_Grants_Opportunity_Staging__c`, + future.
Shared framework fields already standardized: `Dedupe_Key__c` (ExtId/Unique), `Source_Run_ID__c`,
`Source_Endpoint__c`, `Source_Payload_Ref__c` (SHA-256), `HTTP_Status__c`, `Query_Date__c`,
`Last_Fetched__c`, `Review_Status__c` (Pending default), `Error_Message__c`, `Gate_Results__c`,
`Lead__c`. **Recommended addition:** `Connector_Run__c` lookup → `OA_Connector_Run__c` (replaces the
text `Source_Run_ID__c` as the durable link; keep the text for backward compatibility).

### Layer 3 — Canonical intelligence (new; source-neutral, deduped)

Every canonical object shares a **common header**: `Canonical_Key__c` (ExtId/Unique — the dedupe
identity, see dedupe doc), `Primary_Source__c`, `Contributing_Sources__c` (multi), `Confidence__c`,
`First_Seen__c`, `Last_Confirmed__c`, `Source_Run__c` (lookup), `Review_Status__c`, `Superseded__c`.

| Object | Grain | Key category-specific fields | Links |
|---|---|---|---|
| **`OA_Entity_Intelligence__c`** (hub) | one organization | `UEI__c`, `CAGE_Code__c`, `Legal_Name__c`, `State__c`, `NAICS__c`, `Business_Types__c`, `Registration_Status__c`, `Reg_Expiration__c`, `EIN__c`, `NPI__c`, `SEC_CIK__c` | `Lead__c`, `Account__c` (ADR-007 resolved, reviewed) |
| **`OA_Opportunity_Signal__c`** | one funding/solicitation opportunity | `Opportunity_Number__c`, `Title__c`, `Agency__c`, `CFDA_Numbers__c`, `Open_Date__c`, `Close_Date__c`, `Status__c`, `URL__c` | `Entity__c` (optional relevance), `Workspace__c` |
| **`OA_Contract_Intelligence__c`** | one award/obligation | `Award_ID__c`, `Amount__c`, `Awarding_Agency__c`, `Award_Date__c`, `Perf_State__c`, `Contract_Type__c`, `Program__c` | `Entity__c` (recipient) |
| **`OA_Relationship_Intelligence__c`** | one tie (org↔org / org↔person / org↔agency) | `From_Entity__c`, `To_Entity_Name__c`, `Relationship_Type__c` (Sub/Prime/Teaming/Agency/Person), `Strength__c`, `Evidence_Source__c` | `Entity__c` |
| **`OA_Compliance_Intelligence__c`** | one status/finding | `Check_Type__c` (Registration/Exclusion/TaxExempt/Cert), `Status__c`, `Effective_Date__c`, `Expiration_Date__c`, `Finding__c`, `Severity__c` | `Entity__c` |
| **`OA_Market_Intelligence__c`** | one market/context datum | `Geography__c`, `Metric_Type__c` (Demographic/Patent/Filing/Funding), `Metric_Value__c`, `Period__c`, `Source_Dataset__c` | `Entity__c` (optional — may be entity-free) |

### Layer 4 — Activation

**`OA_Intelligence_Action__c`** — a proposed action from AI **or** business rules, awaiting human
approval. `Action_Type__c` (Link-to-Lead / Create-Opportunity / Flag-Compliance / Recommend-Partner /
Create-Task / Cert-Gap), `Recommendation__c` (Long Text), `Rationale__c`, `Confidence__c`,
`Generated_By__c` (Rule/AI), `Source_Object__c` + `Source_Record_Id__c` (which canonical record),
`Citations__c` (source run/record refs), `Approval_Status__c` (Pending/Approved/Rejected),
`Approved_By__c`, `CRM_Target__c` (Lead/Account/Opportunity Id, set on approval), `Executed__c`.
**No trigger auto-executes it** — a governed service acts only on `Approved` Actions.

### Grants module (Deliverable 7)
`OA_Grant_Workspace__c` (+ `OA_Grant_Proposal__c`, `OA_Grant_Submission__c`,
`OA_Compliance_Checkpoint__c`) — detailed in the Grant Management Roadmap.

---

## 3. Relationship rules

- **Provenance is mandatory:** every Layer-2 and Layer-3 record links to an `OA_Connector_Run__c`.
- **Hub-and-spoke:** `OA_Entity_Intelligence__c` is the organization hub; Contract/Compliance/
  Relationship/Opportunity/Market records optionally reference it via `Entity__c`. Records may exist
  before an entity is resolved (blank `Entity__c`) and be linked later during review.
- **CRM linkage is reviewed, not automatic:** `Lead__c`/`Account__c` on the Entity hub is populated
  only by a human-approved entity-resolution decision (ADR-007). Canonical objects never write to CRM.
- **Polymorphic source pointer:** `OA_Intelligence_Action__c` uses `Source_Object__c` +
  `Source_Record_Id__c` (text pair) because Salesforce custom lookups aren't polymorphic; typed
  lookups can be added later if a single dominant type emerges.
- **Supersede, don't delete:** dedupe/versioning sets `Superseded__c = true` on the old canonical
  record rather than deleting — preserves the audit trail.

---

## 4. Naming & packaging
All objects `OA_` prefixed, no namespace (ADR-001), in `force-app/` core (ADR-003). Canonical objects
are Private sharing by default (internal intelligence); staging remains as-is. Each new object is
inventoried in `METADATA_REGISTRY.md` (ADR-009) when built.
