# ADR-008 — Security & Credential Standard

**Status:** Accepted
**Date:** July 2, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any new callout or guest-surface change

---

## Context

The platform makes external callouts (Microsoft Graph, Anthropic, USASpending) and exposes one
guest surface (public unsubscribe). Verification on 2026-07-02 found inconsistent credential
handling `[Verified from source]`:

- `OA_Anthropic` Named Credential exists but references an **External Credential not committed** to the repo.
- `OA_Graph_Credential__c` stores `Client_Secret__c` / `Client_Id__c` / `Tenant_Id__c` as **Text fields** in a custom object.
- Three **Remote Site Settings** (`MicrosoftGraph`, `MicrosoftLogin`, `OA_USASpending`) remain, i.e. hardcoded-endpoint callouts.

## Decision

**Standardize on Named Credential / External Credential for all callouts, and forbid secret
material in objects, settings, metadata, Apex, or logs.** Full baseline in
[`SECURITY_BASELINE.md`](../SECURITY_BASELINE.md).

Key rules:
1. Every connector (incl. public no-auth endpoints) uses a Named Credential; Remote Sites are deprecated for connector use.
2. Secrets live only in External Credentials. `OA_Graph_Credential__c` secret fields are migrated out and retired.
3. Commit the missing `OA_Anthropic` External Credential (or document why it is org-only) so deploys are reproducible.
4. Guest surface: **GET never mutates; POST is token-based; guest access minimal** (`OA_Unsubscribe_Guest_Access` only; no broad CRUD/FLS).
5. No automatic write-back to Lead/Contact/Campaign/CampaignMember from connectors.

## Consequences

- **Positive:** rotatable, auditable credentials; smaller guest attack surface; reproducible deploys.
- **Negative:** migration work (Graph auth) requiring sandbox validation (blocked by `TD-001` — no Full Sandbox yet); coordination with the live Graph pipeline (do not disrupt production).

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Keep credentials in custom objects | Secrets become queryable data; violates least-privilege and rotation. |
| Remote Sites for public APIs | Two callout patterns; hardcoded endpoints; harder to test/rotate. |
| Broaden guest permissions for convenience | Expands the only anonymous attack surface; unacceptable. |

## Related Decisions
- [[ADR-005-connector-framework]] — Named Credential is a framework standard.
- [[ADR-007-entity-resolution-framework]] — review-gate / no-auto-write rule.
- `docs/SECURITY_BASELINE.md`, `docs/SECURITY_MODEL.md`, `docs/INTEGRATION_REGISTRY.md`, `docs/TECHNICAL_DEBT.md`.
