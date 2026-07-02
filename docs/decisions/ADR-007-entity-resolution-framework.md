# ADR-007 — Entity Resolution Framework

**Status:** Accepted
**Date:** July 2, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before entity-resolution implementation; re-review after first real match batch

---

## Context

Enriched external records must be attached to the correct Salesforce `Lead`. Sources identify
organizations inconsistently — sometimes by SAM UEI, often only by name + location. The
USASpending staging object already has the **result** fields `[Verified from source]`
(`Match_Confidence__c` HIGH/MEDIUM/LOW, `Name_Match_Score__c`, `Review_Status__c`
Pending/Approved/Rejected/Written Back), but no matching logic exists to populate them.

## Decision

**Adopt a deterministic-first, probabilistic-fallback matching framework with a mandatory human
review gate**, as specified in [`ENTITY_RESOLUTION_FRAMEWORK.md`](../ENTITY_RESOLUTION_FRAMEWORK.md):

- **T1 Identifier** (UEI equality) → HIGH.
- **T2/T3 Fuzzy** (normalized name ± state) → HIGH/MEDIUM/LOW via `Name_Match_Score__c`.
- **No auto-link, no auto-write:** every assessment lands `Review_Status__c = Pending`; only
  human-`Approved` rows are eligible for a separate governed write-back.
- Thresholds and the fuzzy algorithm are **configuration** (Custom Metadata), not hardcoded.

Open item `[Unverified]`: whether Lead/Account carries a UEI field today (needed for T1) — a
Lead/Account UEI field was **not** observed in the repo; confirm before relying on identifier
matching.

## Consequences

- **Positive:** confidence-banded, auditable matching; protects the production lead base via the
  review gate; tunable without code changes.
- **Negative:** fuzzy matching needs tuning and a labeled review sample; requires a UEI field on
  the CRM side for the strongest tier.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Auto-link on any name match | Unsafe for a compliance-sensitive lead base; false positives write bad data. |
| Manual matching only | Does not scale; wastes reviewer time on obvious HIGH-confidence matches. |
| Hardcoded thresholds | Not tunable; every adjustment becomes a deployment. |

## Related Decisions
- [[ADR-006-canonical-data-model]] — identifiers matched on.
- [[ADR-008-security-and-credential-standard]] — no automatic write-back rule.
- `docs/ENTITY_RESOLUTION_FRAMEWORK.md`.
