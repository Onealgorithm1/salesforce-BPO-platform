# Automated Match & Write Policy

_Status: **DESIGN ONLY — for review** · 2026-07-06. Covers entity resolution, confidence, the per-field
trusted-write policy, change logging, rollback, auto-shutoff tripwires, and automatic deduplication._

Governs stages 3–8 and 10 of the enrichment pipeline. Auto-write is permitted **only** under the
guardrails ratified in ADR-012.

---

## 1. Confidence tiers (what may auto-write)

| Tier | Basis | Band | Behavior |
|---|---|---|---|
| **T1 Deterministic** | Exact match on a strong identifier: **UEI, CAGE, EIN, NPI, CIK** | **HIGH** | **Auto** — eligible for auto-write & auto-merge |
| **T2 Strong composite** | Normalized name + state **plus** a corroborating identifier | MEDIUM | Auto **only if** score ≥ configured threshold; else → review |
| **T3 Fuzzy** | Name-only / weak similarity | LOW | **Never auto** → review (exception #1) |

Thresholds and the fuzzy algorithm are **metadata** (`OA_Match_Config__mdt`, per ADR-007), never
hardcoded. Extends ADR-007's deterministic-first, fuzzy-fallback model; the change is that **HIGH-band
deterministic matches now auto-write** instead of waiting in a queue.

**Requires a CRM identity field.** T1 needs UEI/EIN/NPI on Lead/Account to match on. ADR-007 flagged
that a Lead/Account UEI field was not observed — **confirm/add identity fields before activation**
(design assumes `Lead.UEI__c` etc. exist or are added as part of the enrichment field set).

## 2. CRM matching (stage 6)

For a resolved canonical entity, find the existing CRM record:
1. **Identifier match** (UEI/EIN/NPI on Lead → Account → Contact) → HIGH.
2. **No identifier, strong composite** → MEDIUM → review unless above threshold.
3. **No match** → hand to the Discovery Qualification Engine (separate doc).
Matching is read-only; it never writes. A single entity may match a Lead *and* an Account (enrich both).

## 3. Per-field trusted-write policy (stage 7a)

The core of "update trusted fields automatically." A metadata registry declares, **per target field**,
exactly how automation may write it. **Fields not listed are never auto-written.**

### `OA_Field_Write_Policy__mdt` — fields
| Field | Purpose |
|---|---|
| `Target_Object__c` | Lead / Account / Contact |
| `Target_Field__c` | API name of the CRM field |
| `Source_Of_Truth__c` | Authoritative connector for this field (e.g. `SAM`) |
| `Write_Mode__c` | **FillEmptyOnly** / **Overwrite** / **Never** |
| `Confidence_Floor__c` | Minimum band to write (default HIGH) |
| `Conflict_Behavior__c` | OnConflict → **Review** (default) / KeepCRM / TakeSource |
| `Trusted__c` | Must be true to auto-write (belt-and-suspenders) |
| `Active__c` | Master on/off (default false) |

### Worked examples (illustrative — business confirms the real set)
| Object.Field | Source | Mode | Why |
|---|---|---|---|
| `Lead.UEI__c` | SAM | **FillEmptyOnly** | Identity — set once, never overwrite |
| `Lead.SAM_Registration_Status__c` | SAM | **Overwrite** | Changes over time; source is authoritative |
| `Lead.Registration_Expiration__c` | SAM | **Overwrite** | Time-sensitive; must stay current |
| `Lead.Socioeconomic_Certifications__c` | SAM | **Overwrite** | Cert set changes; SAM is truth |
| `Lead.NAICS__c` | SAM | Overwrite | Authoritative firmographic |
| `Lead.Company` / name | SAM | **FillEmptyOnly** | Never clobber human-entered names |
| `Account.Federal_Contractor__c` | USASpending | Overwrite | Derived status |
| `Contact.*` | (varies) | **FillEmptyOnly** | People data — conservative default |

**Every automated write:**
1. Checks the field policy (object+field must be Active, Trusted, band ≥ floor).
2. For a **non-blank** existing value: FillEmptyOnly → **skip → conflict → review**; Overwrite → proceed.
3. Enforces **FLS** (`WITH USER_MODE` / `stripInaccessible`) as the runtime (least-priv) user.
4. Writes a **before-snapshot** and an `OA_Enrichment_Change_Log__c` row.
5. Records the source, run, confidence, and write mode.

## 4. Change logging (stage 8) — "log every change"

`OA_Enrichment_Change_Log__c` — **one row per field changed**:
`Target_Object__c`, `Target_Record_Id__c`, `Field__c`, `Old_Value__c`, `New_Value__c`,
`Source_Connector__c`, `Connector_Run__c` (lookup), `Confidence__c`, `Write_Mode__c`, `Changed_By__c`
(system/runtime user), `Changed_At__c`, `Reversible__c`, `Before_Snapshot_Ref__c`. This is the audit
spine and the rollback source. No secrets/PII beyond the field values written.

## 5. Rollback

Reuse the **validated write-back rollback pattern** (already built dormant: snapshot → restore). Any
change (or a whole run) can be reverted from `Before_Snapshot_Ref__c` / the change log. Rollback is
itself logged. Field restores are typed and null-safe.

## 6. Auto-shutoff tripwires (stage 10) — the safety backstop

A monitor evaluates every run; **any breach flips a kill-switch** (`OA_Enrichment_Control__c` custom
setting / registry `Enabled=false`) that halts all automated writing, and alerts the owner.

**Must-be-zero tripwires:**
| Tripwire | Meaning |
|---|---|
| Writes without a before-snapshot | Rollback would be impossible |
| Writes below the confidence floor | Guardrail bypassed |
| Writes to a non-Trusted / inactive field | Policy bypassed |
| Overwrite of a FillEmptyOnly field | Policy violation |
| Rollback failures | Safety net broken |
| FLS-denied writes that still succeeded | MAD bypass detected — wrong runtime user |

**Rate/volume tripwires (configurable):** error-rate spike, write-volume spike beyond a daily cap,
per-record change-churn (same field flapping), source-disagreement rate. Breach → halt + alert, never
silent continuation.

## 7. Automatic deduplication / merge (stage 4)

- **Deterministic duplicates** (two CRM records or canonical entities sharing an exact UEI/EIN/NPI) →
  **auto-merge** using survivorship from [`UNIFIED_DEDUPE_STRATEGY.md`](UNIFIED_DEDUPE_STRATEGY.md)
  (source priority then recency; supersede, never delete).
- **Non-deterministic** (name/fuzzy) merge candidates → **review** (exception #3). Never auto-merge CRM
  records on a fuzzy match — irreversible-ish and high-risk on the production base.
- Salesforce Lead/Account merges are governed operations; the design routes them through the same
  snapshot + log + rollback discipline.

## 8. The four human exceptions (the only routine human work)
1. **Low-confidence match** (T3, or T2 below threshold).
2. **Conflicting authoritative sources** (two trusted sources disagree on a trusted field).
3. **Non-deterministic duplicate merge** decision.
4. **Policy exception** (e.g. a field flagged for mandatory review, or a tripwire near-miss).

All land in `OA_Enrichment_Exception__c` with context + a recommended resolution; resolving one can
feed the config back (e.g. confirm a match → strengthen the rule). Everything else is automatic.
