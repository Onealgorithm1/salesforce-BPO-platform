# External Intelligence Framework — Master Architecture

_Status: **DESIGN ONLY — for review** · Date: 2026-07-06 · Owner: Louis Rubino_
_Nothing in this document is built, deployed, activated, or scheduled. It describes the target architecture only._

---

## 1. Vision

Evolve the Salesforce BPO Platform from a **Lead Enrichment** tool into an **Enterprise External
Intelligence Platform**: one governed architecture that can ingest, normalize, review, and activate
external intelligence from **dozens** of government and (later) commercial data sources.

The platform already has the correct spine — the **Connector SDK** (ADR-005), the **canonical data
model** (ADR-006), the **entity-resolution + human-review gate** (ADR-007), the **security/credential
standard** (ADR-008), and the **metadata registry** (ADR-009). This framework does **not replace any
of them**. It *extends* the spine into a repeatable, metadata-driven platform and adds the missing
layers: a connector **registry**, a source-neutral **canonical intelligence layer**, a **unified
dedupe** model, **governance standards**, a **grants-management** module, and a **human-approved AI**
layer.

### Design invariants (never violated)
1. **Human review is mandatory** before any external data reaches a production CRM record.
2. **No automatic write-back** to Lead/Contact/Account/Campaign (ADR-008 #5).
3. **Secrets live only in External Credentials** (ADR-008); never in source, objects, or logs.
4. **Everything additive and dormant** until a separately-approved activation gate.
5. **Every record is auditable** back to its source, run, and reviewer.
6. **AI recommends; humans approve.** AI never writes to the CRM directly.

---

## 2. The Six Intelligence Categories

Every connector produces one primary **intelligence category**. Categories are the vocabulary the
whole platform (objects, review queues, AI, reporting) is organized around.

| Category | What it answers | Canonical object | Example sources |
|---|---|---|---|
| **Entity Intelligence** | *Who is this organization?* Identity, registration, firmographics, certifications | `OA_Entity_Intelligence__c` | SAM.gov, NPPES, IRS Tax-Exempt, SEC EDGAR, D&B |
| **Opportunity Intelligence** | *What can they pursue?* Funding/solicitation opportunities & timing | `OA_Opportunity_Signal__c` | Grants.gov, SBIR.gov, DOE feeds, GovWin |
| **Contract Intelligence** | *What have they won / performed?* Awards, obligations, performance | `OA_Contract_Intelligence__c` | USASpending, NIH RePORTER, NSF, SBIR awards |
| **Relationship Intelligence** | *Who do they work with?* Teaming, subs, agency ties, people | `OA_Relationship_Intelligence__c` | USASpending sub-awards, LinkedIn, ZoomInfo |
| **Compliance Intelligence** | *Are they eligible / in good standing?* Status, expirations, exclusions | `OA_Compliance_Intelligence__c` | SAM exclusions/registration, IRS revocations |
| **Market Intelligence** | *What is the landscape?* Demographics, geography, innovation, competition | `OA_Market_Intelligence__c` | Census, USPTO, SEC EDGAR, Crunchbase |

A single source can *contribute* to more than one category (USASpending is primarily Contract but also
feeds Relationship via sub-awards). Each connector declares exactly one **primary** category in the
registry; secondary contributions are modeled as records in the relevant secondary object.

---

## 3. Layered Architecture (one page)

```
                         ┌───────────────────────────────────────────────┐
   EXTERNAL SOURCES      │  SAM · USASpending · Census · Grants.gov ·     │
   (gov + commercial)    │  SBIR · NIH · NSF · DOE · IRS · SEC · NPPES ·  │
                         │  USPTO · (D&B · Crunchbase · … future)         │
                         └───────────────────────┬───────────────────────┘
                                                 │ Named Credential (ADR-008)
   ┌─────────────────────────────────────────────▼─────────────────────────────────────────┐
   │  LAYER 1 — CONNECTOR SDK  (ADR-005, EXISTS, unchanged)                                  │
   │  OA_ConnectorEngine · OA_IConnector/Request/Parser/Mapper · OA_ConnectorHttp · Row ·    │
   │  RunResult · Persistence · Mock.   Discovered via OA_Connector_Registry__mdt (new).     │
   └─────────────────────────────────────────────┬──────────────────────────────────────────┘
                                                 │  in-memory rows → idempotent upsert
   ┌─────────────────────────────────────────────▼─────────────────────────────────────────┐
   │  LAYER 2 — SOURCE STAGING  (ADR-006, per-source, EXISTS/dormant)                        │
   │  OA_USASpending_Staging__c · OA_SAM_Entity_Staging__c · OA_Grants_Opportunity_Staging__c│
   │  Immutable landing zone + provenance. Review_Status__c = Pending. NO CRM writes.        │
   └─────────────────────────────────────────────┬──────────────────────────────────────────┘
                                                 │  HUMAN REVIEW → Approved
   ┌─────────────────────────────────────────────▼─────────────────────────────────────────┐
   │  LAYER 3 — CANONICAL INTELLIGENCE  (NEW, source-neutral, deduped)                       │
   │  OA_Entity_Intelligence__c (hub) · Opportunity_Signal · Contract · Relationship ·       │
   │  Compliance · Market Intelligence.   Deduped (unified strategy). Entity-resolved (ADR-7)│
   └─────────────────────────────────────────────┬──────────────────────────────────────────┘
                                                 │  business rules + AI (reads Approved only)
   ┌─────────────────────────────────────────────▼─────────────────────────────────────────┐
   │  LAYER 4 — ACTIVATION  (NEW)                                                            │
   │  OA_Intelligence_Action__c — AI/rule recommendations, each requiring HUMAN APPROVAL     │
   │  before any CRM automation (Lead/Account/Opportunity/Task).                             │
   └─────────────────────────────────────────────┬──────────────────────────────────────────┘
                                                 │  HUMAN APPROVAL
                         ┌───────────────────────▼───────────────────────┐
   CRM (production)      │   Lead · Account · Contact · Opportunity ·     │
                         │   Campaign · Task   (governed write-back only) │
                         └────────────────────────────────────────────────┘

   CROSS-CUTTING:  OA_Connector_Run__c (telemetry/provenance) · Governance standards ·
                   Unified dedupe · Human-approved AI · Full audit trail.
```

**Why two data tiers (Staging *and* Canonical)?**
- **Layer 2 (Staging)** preserves ADR-006's per-source fidelity and provenance — the immutable "what
  the source said, when." It is the audit floor.
- **Layer 3 (Canonical)** is the source-neutral, **deduped**, entity-resolved view that AI and
  downstream consumers read. Promotion Staging→Canonical happens **only after human approval**.

Simple sources may map directly into a canonical object; high-fidelity or high-volume sources use the
full Staging→promote→Canonical path. Both are supported by the same SDK.

---

## 4. Canonical Intelligence Pipeline (Deliverable 4)

End-to-end flow. **Every arrow that crosses into production is a human gate. Nothing is automatic.**

| # | Stage | Component (existing / new) | Object touched | Gate / control |
|---|---|---|---|---|
| 1 | **External API** | Named Credential (ADR-008) | — | Callout enabled per-connector; secret in External Credential only |
| 2 | **Connector** | `OA_IConnector` impl (SDK) | — | Declared in `OA_Connector_Registry__mdt`; `Enabled` flag |
| 3 | **Parser** | `OA_IConnectorParser` | — | Malformed body → recorded parse error, never thrown to caller |
| 4 | **Mapper** | `OA_IConnectorMapper` | in-memory row | Field length/type discipline; SHA-256 payload ref (no raw PII) |
| 5 | **Staging Object** | `OA_ConnectorPersistence` | `OA_*_Staging__c` | Idempotent upsert on `Dedupe_Key__c`; lands `Review_Status__c = Pending` |
| 6 | **Review Queue** | List view / (future) LWC | Staging | Reviewer assesses; entity-resolution confidence shown (ADR-007) |
| 7 | **Approval** | Human sets `Review_Status__c = Approved` | Staging | **Mandatory human gate #1** |
| 8 | **Business Rules** | `OA_IntelligencePromotion` (new, design) | Staging→Canonical | Only Approved rows; dedupe + survivorship applied |
| 9 | **Salesforce (canonical) Objects** | promotion service | `OA_*_Intelligence__c` | Source-neutral, deduped, entity-resolved record created/updated |
| 10 | **AI Recommendations** | `OA_IntelligenceAI` (new, design) via `OA_Anthropic` | `OA_Intelligence_Action__c` | AI reads **Approved canonical only**; emits recommendation + citations |
| 11 | **Human Approval** | Human approves/rejects the Action | `OA_Intelligence_Action__c` | **Mandatory human gate #2** |
| 12 | **CRM Automation** | governed write-back service | Lead/Account/Opp/Task | Runs only on approved Actions; FLS-enforced; snapshot + rollback |

Provenance (`OA_Connector_Run__c`) is written at stage 5 and referenced by every record downstream, so
any CRM change is traceable: **CRM record → Action → Canonical record → Staging row → Run → Source**.

---

## 5. What exists vs. what this framework adds

| Concern | Today | This framework adds |
|---|---|---|
| Callout lifecycle | ✅ Connector SDK (ADR-005) | Metadata-driven **discovery** (registry) |
| Per-source staging | ✅ 3 objects (USASpending, SAM, Grants) | Standard field contract + 9 more sources |
| Credentials | ✅ Named/External Credential (ADR-008) | Registry-declared credential per connector |
| Entity → Lead match | ✅ Designed (ADR-007) | Unified into the canonical layer |
| Canonical model | ✅ Conceptual (ADR-006) | **Physical** `OA_*_Intelligence__c` objects |
| Dedupe | ⚠️ Per-object `Dedupe_Key__c` | **Unified** cross-connector strategy |
| Telemetry | ⚠️ In `OA_ConnectorRunResult` (transient) | Durable `OA_Connector_Run__c` |
| Activation | ❌ None | `OA_Intelligence_Action__c` + human approval |
| Grants management | ❌ None | `OA_Grant_Workspace__c` module (design) |
| AI | ✅ `OA_Anthropic` cred exists | Human-approved recommendation layer |

---

## 6. Companion documents

| Deliverable | Document |
|---|---|
| Decision record | [`decisions/ADR-011-external-intelligence-platform.md`](decisions/ADR-011-external-intelligence-platform.md) |
| 1 — Connector roadmap/inventory | [`EXTERNAL_INTELLIGENCE_ROADMAP.md`](EXTERNAL_INTELLIGENCE_ROADMAP.md) |
| 2 — Connector registry | [`CONNECTOR_REGISTRY_ARCHITECTURE.md`](CONNECTOR_REGISTRY_ARCHITECTURE.md) |
| 3 — Object model | [`EXTERNAL_INTELLIGENCE_OBJECT_MODEL.md`](EXTERNAL_INTELLIGENCE_OBJECT_MODEL.md) |
| 5 — Unified dedupe | [`UNIFIED_DEDUPE_STRATEGY.md`](UNIFIED_DEDUPE_STRATEGY.md) |
| 6 — Governance | [`CONNECTOR_GOVERNANCE_STANDARDS.md`](CONNECTOR_GOVERNANCE_STANDARDS.md) |
| 7 — Grant management | [`GRANT_MANAGEMENT_ROADMAP.md`](GRANT_MANAGEMENT_ROADMAP.md) |
| 8 — AI layer | [`EXTERNAL_INTELLIGENCE_AI_LAYER.md`](EXTERNAL_INTELLIGENCE_AI_LAYER.md) |

Preserves and depends on: ADR-005 (SDK), ADR-006 (canonical model), ADR-007 (entity resolution),
ADR-008 (security), ADR-009 (metadata registry).
