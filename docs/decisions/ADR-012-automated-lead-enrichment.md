# ADR-012 — Automated Lead Enrichment (Auto-Write)

**Status:** Proposed (design-only; awaiting Louis's approval)
**Date:** July 6, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any enrichment auto-write is activated in production
**Supersedes (enrichment surface only):** ADR-007 (no auto-link/no auto-write) and ADR-008 rule #5
(no automatic write-back to Lead/Contact/Account) — **for the Lead Enrichment surface only.**

---

## Context

Prior decisions established a strict **no automatic write-back** posture: ADR-008 #5 forbids connectors
writing to Lead/Contact/Account/Campaign, and ADR-007 requires every match to land `Pending` for human
approval. The Lead Write-Back engine was built and validated but left **dormant**; real-data write-back
was **not authorized**.

Louis has now directed (2026-07-06) that Lead Enrichment become a **fully-automated, 24/7 platform**
with **no routine approval queue** — automatically discovering organizations and enriching Leads,
Accounts, and Contacts from trusted external sources, with human review reserved for four exception
types only. This is a deliberate reversal of the no-auto-write rule for the enrichment surface and
requires an explicit decision so the audit trail is honest.

## Decision

**Authorize automatic write-back for Lead Enrichment**, under mandatory guardrails, as specified in
`LEAD_ENRICHMENT_PLATFORM.md`, `AUTOMATED_MATCH_AND_WRITE_POLICY.md`, and
`DISCOVERY_QUALIFICATION_ENGINE.md`. Automatic writing is permitted **only** when **all** hold:

1. **Deterministic HIGH-confidence identity** (exact UEI/CAGE/EIN/NPI/CIK). Fuzzy/low matches → review.
2. **Per-field trusted-write policy** (`OA_Field_Write_Policy__mdt`): only fields marked Active +
   Trusted are written; each has an explicit Write Mode (FillEmptyOnly / Overwrite / Never), source of
   truth, confidence floor, and conflict behavior. Non-blank overwrites happen only where the field
   policy says Overwrite; otherwise the difference is a conflict → review.
3. **Least-privilege runtime user** (Minimum Access + enrichment permission set, **no Modify All
   Data**), so FLS is genuinely enforced (MAD bypasses `stripInaccessible`).
4. **Before-snapshot + rollback** on every write; **every field change logged**
   (`OA_Enrichment_Change_Log__c`).
5. **Auto-shutoff tripwires** halt all automated writing on any anomaly (writes without snapshot, below
   floor, to non-trusted fields, FillEmptyOnly overwrite, rollback failure, FLS-bypass, volume/error
   spikes).
6. **Human review** for the four exceptions only: low-confidence match, conflicting authoritative
   sources, non-deterministic duplicate merge, policy exception. No routine approval queue.
7. **Auto-create of new Leads** (from discovery) only through the Discovery Qualification Engine's six
   gates, including a metadata-driven ICP ruleset.

**Unchanged / still no-auto-write:** Campaign, CampaignMember, unsubscribe, and every non-enrichment
surface keep the ADR-008 #5 rule. Automatic **merge** is limited to deterministic-identifier duplicates.

## Activation is separately gated (design ≠ on)

This ADR authorizes the **design and build (dormant)**. **Activation** additionally requires: the
least-privilege runtime user provisioned (**currently blocked: 0 spare Salesforce licenses**); approved
field-write-policy and ICP metadata; rollback + tripwire kill-switch built and canary-tested (synthetic
→ small batch → scale); and live monitoring/alerting. Until then the platform stays dormant.

## Consequences

**Positive**
- Salesforce stays continuously synchronized with authoritative sources at scale (thousands/day) with
  minimal human effort; humans focus only on genuine exceptions.
- Every automated change is FLS-safe, logged, reversible, and bounded by tripwires.

**Negative / risks**
- Auto-writing to ~13k compliance-sensitive (EDWOSB) production records is inherently higher-risk than a
  review queue; the guardrails (deterministic-only, per-field policy, rollback, tripwires, least-priv
  user) are what make it acceptable — **removing any one materially raises risk**.
- Reverses two Accepted ADRs; future readers must see this supersession to understand current behavior.
- Some ICP criteria (employees/revenue) lack public-source data until a commercial source is approved.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Keep the no-auto-write rule (queue everything) | Contradicts the stated 24/7, minimal-intervention mission |
| Auto-write on any match (incl. fuzzy) | Unsafe on a compliance-sensitive base; false matches corrupt data |
| Overwrite all fields by default | Would clobber human-entered CRM data; per-field policy chosen instead |
| Auto-create a Lead for every discovered org | Floods the CRM; Discovery Qualification Engine gates creation instead |
| Rely on a Modify-All-Data admin as runtime user | MAD bypasses FLS — the field-level guardrail becomes fiction |

## Related Decisions
- [[ADR-005-connector-framework]] · [[ADR-006-canonical-data-model]] · [[ADR-009-metadata-registry]] — reused, unchanged.
- [[ADR-007-entity-resolution-framework]] — **superseded (enrichment only):** HIGH-band deterministic
  matches now auto-write; fuzzy still reviewed.
- [[ADR-008-security-and-credential-standard]] — **rule #5 superseded (enrichment only)**; all other
  rules (Named/External Credential, secrets, guest surface) remain in force.
- Designs: `LEAD_ENRICHMENT_PLATFORM.md`, `AUTOMATED_MATCH_AND_WRITE_POLICY.md`,
  `DISCOVERY_QUALIFICATION_ENGINE.md`, `LEAD_ENRICHMENT_CONNECTORS.md`.
