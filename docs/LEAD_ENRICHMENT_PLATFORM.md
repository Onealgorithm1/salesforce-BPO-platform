# Lead Enrichment Platform — Master Architecture (Phase 6, refocused)

_Status: **DESIGN ONLY — for review** · Date: 2026-07-06 · Owner: Louis Rubino_
_Nothing here is built, deployed, activated, or scheduled. Design of a fully-automated enrichment
platform; **activation is separately gated** (see §9)._

**Scope correction (2026-07-06):** this phase is **Lead Enrichment only**. Grants, Opportunity
Intelligence, AI recommendations, proposal/capture management, and external workflows are **deferred**
to later phases (their earlier design docs carry a DEFERRED banner). The shared spine — Connector SDK,
canonical intelligence hub, connector registry, unified dedupe, governance — is **reused** here.

---

## 1. Mission

A **world-class, fully-automated Lead Enrichment Platform** that runs 24/7 with minimal human
intervention: continuously **discover** new organizations and **enrich** existing Leads, Accounts, and
Contacts from **trusted external sources**, keeping Salesforce synchronized with authoritative data.

**Automation is the default. Human review is the exception**, required *only* for:
1. Low-confidence entity matches
2. Conflicting authoritative sources
3. Duplicate merge decisions that are not deterministic
4. Policy exceptions

There is **no routine approval queue** for enrichment.

## 2. Connector scope (7, in build order)

| Tier | Connector | Enrichment role | Status |
|---|---|---|---|
| 1 | **SAM.gov** | Identity spine (UEI/CAGE), registration status, socioeconomic certs | ✅ built dormant |
| 1 | **USASpending** | Federal contractor / award-recipient status (qualification signal) | ✅ built dormant |
| 1 | **U.S. Census** | Firmographic / geographic / industry context | 🟡 next |
| 2 | **IRS Tax-Exempt** | Organization type, nonprofit status, EIN | ⚪ |
| 2 | **SEC EDGAR** | Public-company identity, CIK, financials (public firms) | ⚪ |
| 3 | **NPPES** | Healthcare provider identity (NPI) | ⚪ |
| 3 | **USPTO** | Innovation signal (patents/trademarks) | ⚪ |

Full per-connector detail (auth, cadence, limits, fields, complexity) in
[`LEAD_ENRICHMENT_CONNECTORS.md`](LEAD_ENRICHMENT_CONNECTORS.md). **No Opportunity/Grants connectors are
designed or prioritized until this pipeline is complete.**

> **Data-availability note:** per-organization **employee count / revenue** are *not* reliably
> available from these public sources (Census is aggregate; SEC covers public filers only). Those ICP
> criteria will be partial until a commercial source (e.g. D&B) is later approved — flagged honestly so
> qualification rules don't silently under-match.

## 3. Governance change — this platform AUTO-WRITES to production

This platform deliberately **reverses** the previous "no automatic write-back" rule for the enrichment
surface, under strict guardrails. That reversal is ratified in
[`decisions/ADR-012-automated-lead-enrichment.md`](decisions/ADR-012-automated-lead-enrichment.md),
which **supersedes ADR-007's no-auto-link/no-auto-write and ADR-008 rule #5 *for enrichment only***.
All other surfaces (Campaign/CampaignMember, unsubscribe, etc.) keep the no-auto-write rule.

Auto-write is permitted **only** when every guardrail holds:
- **Deterministic HIGH-confidence** identity match (exact UEI/CAGE/EIN/NPI/CIK).
- Target field is on the **trusted-field write policy** (per-field, metadata-driven).
- **FLS enforced** via a **least-privilege runtime user** (no Modify All Data — MAD bypasses FLS).
- **Before-snapshot + rollback** on every write; **every change logged**.
- **Auto-shutoff tripwires** halt the platform on any anomaly.
- The 4 exception types route to human review.

## 4. Architecture (one page)

```
   7 TRUSTED SOURCES ──Named Credential──► [ Connector SDK (ADR-005) ]
                                                    │  discovered via OA_Connector_Registry__mdt
                                                    ▼
                                        per-source Staging (ADR-006)
                                                    │  entity resolution + unified dedupe
                                                    ▼
                                   OA_Entity_Intelligence__c  ◄── canonical hub = DISCOVERY layer
                                                    │
                            ┌───────────────────────┴────────────────────────┐
             existing CRM match?  YES                                    NO
                            │                                                 │
                            ▼                                                 ▼
             AUTOMATED ENRICHMENT WRITER                       DISCOVERY QUALIFICATION ENGINE
             (per-field policy, HIGH-conf only)                (metadata ICP rules)
                            │                                     │            │
             ┌──────────────┴───────────┐                   qualified?    not qualified
             ▼                          ▼                        │            │
   Lead / Account / Contact    OA_Enrichment_Exception__c   auto-create    retain in
   + OA_Enrichment_Change_Log  (4 exception types → review)  Lead + enrich  Discovery layer
                                                                            (continuous re-eval)
   CROSS-CUTTING: OA_Connector_Run__c (telemetry) · confidence scoring ·
                  rollback engine · auto-shutoff tripwires · full audit log.
```

## 5. The automated pipeline (stage by stage)

| # | Stage | Automated? | Component (design) | Control |
|---|---|---|---|---|
| 1 | Ingest from source | ✅ | Connector SDK (exists) | Named Credential; registry `Enabled` |
| 2 | Land in staging | ✅ | `OA_ConnectorPersistence` | Idempotent upsert; provenance run |
| 3 | Entity resolution | ✅ | `OA_EntityResolver` (design) | Deterministic→fuzzy; confidence band (ADR-007) |
| 4 | Dedupe / auto-merge | ✅ deterministic only | promotion service (design) | Non-deterministic merge → review |
| 5 | Confidence scoring | ✅ | scorer (design) | Thresholds in metadata |
| 6 | **CRM match** | ✅ | matcher (design) | Match existing Lead/Account/Contact |
| 7a | **Enrich existing** (matched) | ✅ HIGH-conf | Enrichment Writer (design) | Per-field policy; FLS; snapshot; log |
| 7b | **Qualify + maybe create** (unmatched) | ✅ gated | Qualification Engine (design) | 6 gates; else retain + re-evaluate |
| 8 | Log every change | ✅ | `OA_Enrichment_Change_Log__c` | One row per field change; reversible |
| 9 | Exceptions → review | human | `OA_Enrichment_Exception__c` | Only the 4 exception types |
| 10 | Monitor + tripwires | ✅ | monitor (design) | Auto-halt on breach; alert |

Detail: [`AUTOMATED_MATCH_AND_WRITE_POLICY.md`](AUTOMATED_MATCH_AND_WRITE_POLICY.md) (stages 3–8, 10)
and [`DISCOVERY_QUALIFICATION_ENGINE.md`](DISCOVERY_QUALIFICATION_ENGINE.md) (stage 7b).

## 6. Object model (refocused)

**Reused:** per-source Staging objects, `OA_Entity_Intelligence__c` (hub + discovery layer),
`OA_Contract_Intelligence__c`, `OA_Compliance_Intelligence__c`, `OA_Market_Intelligence__c`,
`OA_Connector_Run__c`, `OA_Connector_Registry__mdt`.
**New for enrichment:** `OA_Enrichment_Change_Log__c` (audit), `OA_Field_Write_Policy__mdt` (per-field
rules), `OA_Qualification_Rule__mdt` (ICP), `OA_Enrichment_Exception__c` (review queue for the 4 cases).
**Deferred (not in this phase):** `OA_Opportunity_Signal__c`, `OA_Intelligence_Action__c` (AI), grant
objects.

## 7. Scale target
Continuously process **thousands of organizations/day**. Achieved via async (Queueable/Batch) ingest +
resolution + write, chunked and rate-limited per connector, idempotent throughout, with the tripwire
kill-switch as the safety backstop. (Async workers and any scheduler are **design-only** here and
activated separately — nothing is scheduled by this document.)

## 8. What stays human
Only the 4 exceptions (low-confidence match, source conflict, non-deterministic merge, policy
exception) land in `OA_Enrichment_Exception__c`. Everything deterministic and high-confidence flows
automatically. This is *exception-based* governance, not a routine queue.

## 9. Activation prerequisites (design ≠ on)
Designing this is safe and reversible. **Turning it on** requires, each separately gated:
1. **Least-privilege runtime user** (Minimum Access profile + enrichment permission set; **no MAD**) so
   FLS is genuinely enforced — currently **blocked: 0 spare Salesforce licenses**.
2. Approved `OA_Field_Write_Policy__mdt` (which fields, which mode, which source of truth).
3. Approved `OA_Qualification_Rule__mdt` ICP ruleset (business sign-off).
4. Rollback engine + tripwire kill-switch **built and tested** (canary on synthetic → small batch).
5. Monitoring + alerting live.
Until all pass, the platform stays dormant.

## 10. Companion documents
| Doc | Deliverable |
|---|---|
| [`decisions/ADR-012-automated-lead-enrichment.md`](decisions/ADR-012-automated-lead-enrichment.md) | Governance decision (supersedes ADR-007/008 for enrichment) |
| [`LEAD_ENRICHMENT_CONNECTORS.md`](LEAD_ENRICHMENT_CONNECTORS.md) | 7-connector inventory |
| [`AUTOMATED_MATCH_AND_WRITE_POLICY.md`](AUTOMATED_MATCH_AND_WRITE_POLICY.md) | Resolution, per-field write, confidence, logging, rollback, tripwires, auto-merge |
| [`DISCOVERY_QUALIFICATION_ENGINE.md`](DISCOVERY_QUALIFICATION_ENGINE.md) | Metadata-driven ICP qualification + continuous re-evaluation |
| [`CONNECTOR_REGISTRY_ARCHITECTURE.md`](CONNECTOR_REGISTRY_ARCHITECTURE.md) | Reused — connector discovery |
| [`UNIFIED_DEDUPE_STRATEGY.md`](UNIFIED_DEDUPE_STRATEGY.md) | Reused — dedupe/identity |
| [`CONNECTOR_GOVERNANCE_STANDARDS.md`](CONNECTOR_GOVERNANCE_STANDARDS.md) | Reused — per-connector standards |

Preserves and depends on: ADR-005 (SDK), ADR-006 (canonical model), ADR-009 (metadata registry).
Supersedes (enrichment surface only): ADR-007 no-auto-write, ADR-008 #5 — via ADR-012.
