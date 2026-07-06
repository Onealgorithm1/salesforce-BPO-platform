# Discovery Qualification Engine

_Status: **DESIGN ONLY — for review** · 2026-07-06. Metadata-driven qualification (ICP) governing
automatic Lead creation from newly discovered organizations._

Goal (Louis, 2026-07-06): **continuous *intelligent* discovery, not indiscriminate Lead creation.**
Newly discovered organizations are auto-created as Leads **only** when they pass configurable business
qualification; everything else is retained and re-evaluated over time.

---

## 1. Workflow

```
External Source → Entity Resolution → Duplicate Check → Qualification Rules
      │
      ├─ QUALIFIED ──────► Auto-create Lead (+ enrich via write policy)
      │
      └─ NOT QUALIFIED ──► Retain in Discovery/Intelligence layer
                            (OA_Entity_Intelligence__c, Qualification_Status = Not Qualified)
                            → eligible for automatic RE-EVALUATION
```

## 2. Auto-create gates — ALL must be true

A Lead is created automatically **only** when every gate passes:

| # | Gate | Source of check |
|---|---|---|
| 1 | **Deterministic identity** (HIGH-confidence) | Match/confidence tiers (T1) |
| 2 | **Not already in Salesforce** | Duplicate check (UEI/EIN/NPI + name+state) |
| 3 | **Source is trusted** | Connector registry `Status=Active`, trusted flag |
| 4 | **Required fields present** | Field-completeness check (configurable required set) |
| 5 | **Confidence > configured threshold** | `OA_Match_Config__mdt` |
| 6 | **Satisfies qualification ruleset (ICP)** | `OA_Qualification_Rule__mdt` (below) |

Fail any gate → **not** created; retained in the Discovery layer (never discarded).

## 3. Metadata-driven qualification — `OA_Qualification_Rule__mdt`

Business users change qualification **without touching Apex**. Each rule is one criterion; a **ruleset**
(a named group) is evaluated with AND/OR logic and an optional weighted score.

### Fields
| Field | Purpose |
|---|---|
| `Ruleset__c` | Named ICP profile (e.g. "Federal EDWOSB Prime") |
| `Criterion_Type__c` | Which attribute is tested (see catalog) |
| `Operator__c` | equals / in / gte / lte / between / contains / exists |
| `Value__c` | Comparison value(s), e.g. NAICS list, state list, min count |
| `Weight__c` | Contribution to a qualification score (for weighted mode) |
| `Required__c` | If true, a fail hard-disqualifies regardless of score |
| `Active__c` | On/off |
| `Logic_Mode__c` (ruleset-level) | ALL-required / weighted-threshold |

### Criterion catalog (configurable, extensible)
- **Active SAM registration** (SAM)
- **Federal contractor / award recipient** (USASpending)
- **Socioeconomic certification**: WOSB / EDWOSB / SDVOSB / HUBZone / 8(a) (SAM)
- **Target NAICS codes** (SAM)
- **Target agencies served** (USASpending)
- **Target geography** (state/region)
- **Minimum employee count** *(data-availability caveat — see below)*
- **Revenue range** *(data-availability caveat)*
- **Organization type** (IRS / SEC / SAM)
- **Custom business criteria** (any enriched field)

> **Honesty on data availability:** *minimum employee count* and *revenue range* are **not reliably
> available** from the 7 public sources (Census is aggregate; SEC covers public filers only). Rules
> using them will under-match until a commercial firmographic source (e.g. D&B) is approved later.
> Design supports the criteria now; they simply evaluate "unknown → not-satisfied" (or a configurable
> "unknown → pass/hold") until the data exists.

## 4. Retain + continuous re-evaluation (the "intelligent" part)

Non-qualified organizations remain in `OA_Entity_Intelligence__c` with `Qualification_Status__c`
(Qualified / Not Qualified / Needs Data) and `Qualification_Reasons__c` (which gates failed). They are
**automatically re-evaluated** when any of these change:

| Trigger | Why re-evaluate |
|---|---|
| **Enrichment data changes** | New SAM cert / award may now qualify them |
| **Qualification rules change** | Business widened/narrowed the ICP |
| **A new connector is added** | New attributes (e.g. NPI, patents) may satisfy a rule |
| **The organization's profile improves** | e.g. registration went Active, award recorded |

Re-evaluation is an **idempotent async job** (design; Batch/Queueable) that re-runs the ruleset over
retained entities and promotes newly-qualifying ones to Lead creation — with the **same six gates** and
the same tripwire safety. It never re-creates a Lead that already exists (gate 2), and it is bounded by
the daily volume cap.

## 5. Objects touched
- Reads: `OA_Entity_Intelligence__c` (+ contributing intelligence: Contract/Compliance/Market).
- Writes on qualify: a new **Lead** (via the enrichment writer + change log), sets
  `Qualification_Status__c = Qualified`, links the entity to the created Lead.
- Writes on not-qualify: `Qualification_Status__c`, `Qualification_Reasons__c`, `Last_Evaluated__c`.
- Config: `OA_Qualification_Rule__mdt`, `OA_Match_Config__mdt` — metadata, business-editable.

## 6. Guardrails
- Auto-create obeys the same **least-privilege runtime user + FLS + snapshot + log + tripwire**
  discipline as enrichment (ADR-012). A newly created Lead is a logged, reversible action.
- **Volume cap + tripwire**: a spike in auto-created Leads (misconfigured ruleset) trips the kill-switch
  before the CRM floods.
- Retained (non-qualified) entities live in the intelligence layer, **not** as production Leads — so a
  loose ICP never pollutes the CRM; it only enlarges the re-evaluation pool.
- Duplicate check runs **before** creation and again at the moment of insert (race-safe).
