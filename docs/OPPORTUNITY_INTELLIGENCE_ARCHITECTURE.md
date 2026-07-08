# Opportunity Intelligence — Architecture

**Program 2 · Phase 0 (design only) · 2026-07-08**
Relates to: ADR-005 (connector framework), ADR-006 (canonical model), ADR-007 (entity resolution),
ADR-008 (security/credential), ADR-009 (metadata registry), ADR-010 (definition of ready),
ADR-011 (External Intelligence vision, design branch), ADR-015 (OI charter).

---

## 1. Purpose & boundaries

OI turns the firehose of public procurement/grant postings into a **ranked, explainable,
human-reviewed pursuit pipeline**. It is the first concrete program under the External
Intelligence Platform vision (ADR-011).

**In scope (over the full program):** fetch postings from public sources → normalize into a
source-neutral Opportunity Signal → dedupe → (Phase 3) score fit → (Phase 4) route to a human
pursuit workflow → (Phase 5, gated) create CRM Opportunities on human approval.

**Out of scope (hard):** automatic `Opportunity` creation, any outreach/CampaignMember change,
proposal *submission* or any external write, grant *submission* automation, AI decisioning (v1),
and any modification of Lead Enrichment / ERE / Analytics / Meta / LinkedIn / Auth work.

## 2. System context (C4 level 1)

```
        ┌─────────────────── Public sources (read-only, GET) ───────────────────┐
        │  Grants.gov (P1)   SAM.gov Opportunities (P2)   SBIR/STTR   Fed Register │
        └───────────────┬───────────────────────────────────────────────────────┘
                        │  Named/External Credential (ADR-008)
                        ▼
        ┌───────────────────────────  Salesforce (org 00Dbn00000plgUfEAI)  ───────────────┐
        │                                                                                  │
        │   REUSED, CERTIFIED SDK                    NEW OI LAYER                           │
        │   ┌───────────────────────┐    emits       ┌──────────────────────────────┐      │
        │   │ OA_ConnectorRunner    │──────────────► │ OA_Opportunity_Signal__c      │      │
        │   │ OA_ConnectorHttp      │  (canonical    │  (review queue, Pending)      │      │
        │   │ OA_Connector_Registry │   signals)     └──────────────┬───────────────┘      │
        │   │ OA_Connector_Run__c   │  telemetry                    │ Phase 3+             │
        │   │ OA_ExceptionRouting…  │  anomalies      ┌─────────────▼───────────────┐      │
        │   └───────────────────────┘                │ Score / Assessment /         │      │
        │        (unchanged)                          │ Pursuit Candidate (later)    │      │
        │                                             └─────────────┬───────────────┘      │
        │   NEVER TOUCHED BY OI:                                     │ Phase 5 (human gate) │
        │   Lead, Account, Campaign, ERE, Analytics,   ┌────────────▼───────────────┐      │
        │   Lead-writeback engines                     │ CRM Opportunity (approved) │      │
        │                                              └────────────────────────────┘      │
        └──────────────────────────────────────────────────────────────────────────────────┘
                        ▲
                        │ works the queue
                 Human reviewer (Go / No-Go)
```

## 3. Pipeline (per run)

`Initialize → Execute Request → Receive Response → Parse → Map → Dedupe → (optional) Persist Signals → Collect telemetry → Complete`

- Driven by the **existing** `OA_ConnectorRunner` lifecycle (registry-driven, `Type.forName`,
  no source-specific branches, **no DML by default**).
- **Callout-before-DML**, ≤50 records/txn (Lead-Enrichment learning — see `SPRINT23_FIRST_SUCCESSFUL_WRITE.md`).
- **Dedupe** by `Canonical_Key__c` (source-scoped unique external id) via registry
  `Dedupe_External_Id_Field__c`.
- **Persist is opt-in** (`commit=false` default). A preview run produces proposed signals with zero DML.
- **Anomalies** (fetch/parse errors, low confidence) route to `OA_Enrichment_Exception__c` via the
  reused `OA_ExceptionRoutingService` — no new exception object needed.

## 4. Component responsibilities

| Layer | Component | Owner | Change in OI |
|---|---|---|---|
| Dispatch | `OA_ConnectorRunner` | SDK (frozen) | **Reuse, no edit** |
| Transport | `OA_ConnectorHttp` | SDK (frozen) | **Reuse, no edit** |
| Config | `OA_Connector_Registry__mdt` | SDK | **Extend via new rows** (`Category='Opportunity'`) |
| Telemetry | `OA_Connector_Run__c` | SDK | **Reuse** (stamp `Category='Opportunity'`) |
| Per-source | `OA_GrantsGov_Request/Parser/Mapper` (+ `OA_SAMOpportunities_*` P2) | **New (thin)** | implement existing interfaces |
| Orchestration | `OA_OpportunitySignalService` | **New (thin)** | fetch→parse→map→optional persist |
| Review store | `OA_Opportunity_Signal__c` | **New object** | the queue |
| Exceptions | `OA_ExceptionRoutingService` + `OA_Enrichment_Exception__c` | SDK | **Reuse** |
| Scoring (P3) | `OA_Opportunity_Score__c` + CMDT-weighted engine | **New (later)** | explainable, versioned |
| Audit/rollback (P5) | `OA_ChangeLogService` + `OA_Enrichment_Change_Log__c` | SDK | **Reuse (later)** |

Detailed component-by-component verdicts: [OI_REUSE_ANALYSIS.md](OI_REUSE_ANALYSIS.md).

## 5. Why a new object instead of reusing staging

Every existing staging object (`OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c`,
`OA_Discovered_Organization__c`) is **entity/company grain** (UEI, CAGE, legal name). An
opportunity/solicitation is a **different grain** (notice id, NAICS, set-aside, deadline).
Reusing entity staging would pollute Lead-Enrichment data and violate the no-touch rule. OI
introduces exactly one new grain — `OA_Opportunity_Signal__c` — and reuses everything around it.
Rationale in [ADR-017](decisions/ADR-017-opportunity-data-model-and-staging-grain.md).

## 6. Deployment topology (all phases start dormant)

- New object ships **empty**; connector rows `Enabled__c=false`; permset
  `OA_Opportunity_Intelligence_Runtime` **unassigned**; no scheduled jobs.
- Nothing runs until (a) G1 dormant deploy, then (b) explicit manual preview, then (c) G2 commit.
- Kill switch = registry `Enabled__c=false` (mirrors Lead Enrichment's connector-disable switch).

## 7. Non-functional targets

| Concern | Target | Basis |
|---|---|---|
| Callouts/txn | ≤ platform binding limit (100), design ≤50 | Lead-Enrichment PERFORMANCE_VALIDATION |
| DML pattern | callout-before-DML, bulkified insert | SPRINT23 root-cause fix |
| Idempotency | dedupe by `Canonical_Key__c` unique ExtId | prevents duplicate signals across re-runs |
| Test coverage | ≥90% on new classes, mocked HTTP (no live callout in tests) | platform norm |
| Reversibility (MVP) | delete-by-run (signals stamped with `Connector_Run__c`) | insert-only |
| Least privilege | dedicated runtime user (target); MAD-`oauser` carryover documented | inherits Program-1 exception |

## 8. Roadmap (phased, each entered by a human gate)

1. **Phase 0** — architecture approval (this package).
2. **Phase 1** — `OA_Opportunity_Signal__c` + registry row + permset + **Grants.gov** thin connector,
   dormant; preview then tiny commit into the review queue. *Exit:* signals in queue, 0 CRM writes,
   audited, reversible, tests ≥90%.
3. **Phase 2** — **SAM.gov Opportunities** connector (on data.gov key + new EC) + review list views/report type.
   *Exit:* SAM signals dedupe by noticeId; unified queue; still no scoring.
4. **Phase 3** — explainable CMDT-weighted scoring (`OA_Opportunity_Score__c`) + draft
   `OA_Go_NoGo_Assessment__c`; reuse USASpending for past-performance factor. *Exit:* ranked queue with reasons.
5. **Phase 4** — `OA_Pursuit_Candidate__c` lifecycle + dashboard. *Exit:* humans work a pipeline.
6. **Phase 5** — on human approval only: create CRM `Opportunity`, owner, proposal `Task`s; read-only
   Account link (ADR-007); reuse `OA_ChangeLogService` for reversibility. *Exit:* gated CRM creation.

## 9. Risks (architecture-level)

| Risk | Mitigation |
|---|---|
| SAM data.gov key historically unresolved | Lead with keyless Grants.gov; SAM is non-blocking fast-follow |
| Scope creep into CRM/outreach | No code path in MVP writes outside the new object; Phase 5 is a separate approval |
| Touching Lead Enrichment/ERE/Analytics | New objects only; writeback/proposal adapter left alone; explicit no-touch list |
| MAD `oauser` over-privilege | Inherited standing risk; MVP is manual (bounded); gate 24×7 on least-priv user |
| Review-queue noise (Fed Register/data.gov) | Tight agency/doc-type filters; keep as P3 context, not primary feed |
| Dedupe collisions across sources | `Canonical_Key__c` source-scoped unique ExtId; reuse enrichment dedupe pattern |
| Parallel-session branch collision | Build in isolated worktree/branch; quiet-org check before any deploy |

Full risk table with likelihood/impact: see the readiness audit and
[OI_SECURITY_MODEL.md](OI_SECURITY_MODEL.md) §Threats.
