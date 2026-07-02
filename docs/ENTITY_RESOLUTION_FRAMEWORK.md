# Entity Resolution Framework

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Governed by [ADR-007](decisions/ADR-007-entity-resolution-framework.md).

**Confidence labels:** `[Verified from source]` = confirmed in repo metadata; `[Proposed/Future]`
= not yet built.

Defines how an enriched external record is matched to the correct Salesforce `Lead` (and, later,
`Account`/`Contact`) before any human review or write-back.

---

## 1. Problem

Public sources identify organizations inconsistently — sometimes with a SAM UEI, often only by
name and location. Entity resolution decides: *does this external award/record belong to this
Lead, and how confident are we?*

The USASpending staging object already carries the **result fields** for this process
`[Verified from source]`: `Match_Confidence__c` (HIGH/MEDIUM/LOW), `Name_Match_Score__c`
(Number), and `Review_Status__c` (Pending/Approved/Rejected/Written Back). The **matching logic
that populates them does not exist yet** `[Proposed/Future]`.

---

## 2. Matching tiers

Resolution is deterministic-first, then probabilistic:

| Tier | Rule | Result `confidence` |
|------|------|---------------------|
| **T1 — Identifier** | External `uei` equals a known UEI on the Lead/Account. | **HIGH** |
| **T2 — Strong fuzzy** | Normalized name match ≥ high threshold **and** state match. | **HIGH / MEDIUM** |
| **T3 — Weak fuzzy** | Normalized name match above floor, no state corroboration. | **MEDIUM / LOW** |
| **T4 — No match** | Below floor. | Not staged as a match (or staged `LOW` for review). |

`Name_Match_Score__c` stores the numeric similarity; `Match_Confidence__c` stores the banded
outcome. Thresholds are configuration `[Proposed/Future]` (Custom Metadata), not hardcoded.

---

## 3. Normalization (name hygiene)

Before comparison, names are normalized: lowercase, trim, strip punctuation, and remove common
business suffixes/stopwords (LLC, INC, CORP, LP, CO, THE, etc.). `[Proposed/Future]` The
algorithm choice (token-set ratio vs. Jaro-Winkler vs. Levenshtein) is decided in ADR-007 /
implementation and documented here once built.

---

## 4. Review gate (mandatory)

Entity resolution **never** auto-links or auto-writes. Every assessment lands in staging with
`Review_Status__c = Pending`. A human advances it to `Approved` / `Rejected`. Only `Approved`
rows are eligible for a separate, governed write-back step. `Written Back` marks completion.

This enforces the platform rule that **connectors never mutate Lead/Contact/Campaign/CampaignMember
automatically** (see [`SECURITY_BASELINE.md`](SECURITY_BASELINE.md)).

---

## 5. Confidence → action policy `[Proposed]`

| `confidence` | Default routing |
|--------------|-----------------|
| HIGH | Queue for fast-track review (still human-approved). |
| MEDIUM | Standard review queue. |
| LOW | Held; surfaced only on demand to avoid reviewer noise. |

No confidence band bypasses human review.

---

## 6. Open questions (resolve before build)
- Which fuzzy algorithm and thresholds? (ADR-007)
- Is UEI stored on Lead/Account today? `[Unverified]` — the staging object holds
  `Recipient_UEI__c`, but a corresponding Lead/Account UEI field was **not** observed in the
  repo; confirm before relying on T1.
- Duplicate handling when multiple Leads match one external entity.

---

## Related documents
- [ADR-007 — Entity Resolution Framework](decisions/ADR-007-entity-resolution-framework.md)
- [Canonical Data Model](CANONICAL_DATA_MODEL.md)
- [Evergreen Data Dictionary](EVERGREEN_DATA_DICTIONARY.md)
- [Security Baseline](SECURITY_BASELINE.md)
