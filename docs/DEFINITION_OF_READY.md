# Definition of Ready

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Governed by [ADR-010](decisions/ADR-010-definition-of-ready.md).

The gate a unit of work must pass **before** implementation begins. Enforces the platform's
evidence-first, no-surprise-production discipline.

---

## 1. Universal Definition of Ready (all work)

A task is Ready only when:

- [ ] **Objective is written** and maps to a repository artifact (roadmap/ADR/doc), not just a chat instruction.
- [ ] **Repository evidence gathered** — relevant code/metadata read; claims carry confidence labels.
- [ ] **Production/runtime assumptions are labeled** `[Unverified]` unless confirmed by command output.
- [ ] **Scope boundaries stated** — what will and will not change; workstreams (campaign / unsubscribe / Evergreen) kept isolated.
- [ ] **Reversibility plan** — branch, `git status` baseline, and rollback path identified.
- [ ] **Approval recorded** for anything hard-to-reverse (deploy, commit, production change).

---

## 2. Additional DoR — Apex / metadata change

- [ ] Target org and **sandbox availability** confirmed (note: `TD-001` — no Full Sandbox yet `[Verified from source]`).
- [ ] Check-only validation plan (`sf project deploy validate`).
- [ ] Test plan with **≥75% coverage** identified (Salesforce gate).
- [ ] No change to Campaign/Lead/Contact/CampaignMember/schedulers/Flows/templates without explicit approval.

---

## 3. Additional DoR — new connector (Evergreen)

Before building any connector (USASpending refactor, Census, SAM, NSF/NIH/SBIR):

- [ ] **API behavior verified** against the live endpoint (status codes, pagination, auth) and recorded.
- [ ] **Data classification** declared (public/confidential/restricted) per [Security Baseline](SECURITY_BASELINE.md).
- [ ] **Named Credential** planned (no Remote Site, no hardcoded endpoint).
- [ ] **Staging object** designed with the framework-managed fields + an idempotency key ([Canonical Data Model](CANONICAL_DATA_MODEL.md)).
- [ ] **Entity resolution** approach chosen (tiers/thresholds) per [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md).
- [ ] **Review gate** confirmed — no automatic write-back; `Review_Status__c` workflow defined.
- [ ] **Test strategy** via `OA_ConnectorMock` (success / non-2xx / empty / parse-error).

---

## 4. Definition of Done (for reference)

A unit is Done when: code + tests committed on a feature branch; ≥75% coverage; check-only
validation passed; docs/registry updated; reversibility confirmed; and — for production — a
serialized, approved deployment with a rollback plan. No parallel production deployments from
multiple sessions.

---

## 5. Sprint 1A worked example `[Verified from source]`

Sprint 1A (documentation alignment) satisfies the Universal DoR: objective mapped to
[ADR-005](decisions/ADR-005-connector-framework.md) and the connector roadmap; repository
evidence gathered with confidence labels; production untouched (docs-only); reversible
(uncommitted new files); commit gated on approval. It is **not** subject to §2/§3 (no Apex,
no connector build).

---

## Related documents
- [ADR-010 — Definition of Ready](decisions/ADR-010-definition-of-ready.md)
- [Connector Framework Roadmap](CONNECTOR_FRAMEWORK_ROADMAP.md)
- [Security Baseline](SECURITY_BASELINE.md) · [Canonical Data Model](CANONICAL_DATA_MODEL.md)
- [Entity Resolution Framework](ENTITY_RESOLUTION_FRAMEWORK.md)
