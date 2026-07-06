# Unified Dedupe Strategy (Deliverable 5)

_Status: **DESIGN ONLY — for review** · 2026-07-06. One dedupe model shared by every connector._

Dedupe has **three distinct jobs** that are often confused. This model separates them so every
connector behaves identically.

| Job | Question | Where it acts | Mechanism |
|---|---|---|---|
| **1. Run idempotency** | "Did *this run* already write this row?" | Layer 2 staging | `Dedupe_Key__c` (ExtId + Unique) upsert |
| **2. Canonical identity** | "Is this the *same real-world thing* we already track?" | Layer 3 canonical | `Canonical_Key__c` (stable natural key) |
| **3. Change detection** | "Did the source *change* since last time?" | both | `Source_Payload_Ref__c` (SHA-256) |

> **Boundary with ADR-007:** dedupe is about not duplicating *intelligence records*. **Entity
> resolution** (ADR-007) is about linking a resolved entity to a *CRM Lead/Account*. They meet at the
> `OA_Entity_Intelligence__c` hub but are different decisions — dedupe is deterministic and automatic;
> CRM linkage is human-reviewed.

---

## 1. Keys

### External IDs (job 1 — run idempotency, exists today)
`Dedupe_Key__c = Source_Run_ID__c + "|" + <source external id>`, marked **External Id + Unique**.
Re-running the same run **upserts** rather than duplicates. Already implemented on all three staging
objects. The `<source external id>` per category:

| Category | Source external id |
|---|---|
| Entity | UEI (SAM) / NPI (NPPES) / CIK (SEC) / EIN (IRS) |
| Contract | Award ID (USASpending/NIH/NSF) |
| Opportunity | Opportunity number (Grants/SBIR/DOE) |
| Compliance | Registration id / exclusion id / EIN |
| Market | dataset + geography + period |

### Composite / canonical key (job 2 — cross-run identity, new)
`Canonical_Key__c = <SourceKey?no> normalized natural key`, **source-independent** so two sources
describing the same org collapse to one hub. Preference order:

```
Entity canonical key:
   1. UEI                         (best — the federal identity spine)
   2. CAGE code
   3. EIN                         (nonprofits / IRS)
   4. SHA-256( normalize(legalName) + "|" + state )   (fuzzy fallback identity)
Opportunity canonical key:   normalize(opportunityNumber)
Contract canonical key:      normalize(awardId)
```
`normalize()` = uppercase, trim, strip punctuation/`INC|LLC|CORP` suffixes, collapse whitespace.

### Payload hash (job 3 — change detection, exists today)
`Source_Payload_Ref__c = SHA-256(identity fields + runId)`. On re-fetch, compare the new hash to the
stored one:
- **unchanged** → no-op (skip promotion; just stamp `Last_Confirmed__c`).
- **changed** → update the canonical record **and** re-flag for review **if a *material* field changed**
  (see review rules). Immaterial changes (e.g. a timestamp) update silently.

---

## 2. Update rules (staging → canonical promotion)

For an **Approved** staging row:
1. Compute `Canonical_Key__c`.
2. **No canonical match** → create a new canonical record (`First_Seen__c = now`).
3. **Match, hash unchanged** → touch `Last_Confirmed__c` only.
4. **Match, hash changed** → apply **survivorship** (below); bump `Last_Confirmed__c`; if material
   change, set `Review_Status__c = Pending` on the canonical record for re-approval.

## 3. Merge rules (two sources, one entity)

When two staging rows (different `Primary_Source__c`) resolve to the **same** `Canonical_Key__c`:
- They link to **one** `OA_Entity_Intelligence__c`; `Contributing_Sources__c` accumulates both.
- **Field survivorship = source-priority, then recency.** Priority order (most trusted first):
  `SAM > IRS > SEC > NPPES > USASpending > Census > commercial`. Within equal priority, most-recent
  `Last_Confirmed__c` wins.
- Conflicting high-priority values (e.g. two different UEIs for one name-match) → **do not auto-merge**;
  raise an `OA_Intelligence_Action__c` (Action_Type = Review-Merge) for a human.
- Merges **supersede** (`Superseded__c = true`), never hard-delete, preserving lineage.

## 4. Review rules (what forces a human back into the loop)

A change or match is **auto-safe** (no re-review) only when all are true; otherwise `Pending`:

| Force re-review when… | Why |
|---|---|
| Fuzzy-identity fallback used (name+state, not UEI/CAGE/EIN) | Weakest key; false-merge risk |
| A **material field** changed: registration status, cert/socioeconomic type, exclusion, tax-exempt revocation, award amount | Business/compliance impact |
| Two high-priority sources **conflict** on identity | Possible wrong merge |
| Confidence band drops below HIGH | ADR-007 threshold |
| First time an entity is linked to a CRM Lead/Account | ADR-007 gate — always human |

Immaterial deltas (descriptive text, refresh timestamps, new non-conflicting contributing source)
update without re-review but are logged on `OA_Connector_Run__c`.

---

## 5. Governor & safety notes
- All dedupe is **deterministic** and done in the promotion service — never in a trigger that fires on
  raw ingest (keeps ingest bulk-safe and side-effect-free).
- Upserts use `allOrNone = false` (partial success) as the SDK already does.
- `Canonical_Key__c` and `Dedupe_Key__c` are both External Id/Unique so identity collisions surface as
  upsert results, not silent duplicates.
- No dedupe step ever writes to a CRM object.
