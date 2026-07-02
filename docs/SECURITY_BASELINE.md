# Security Baseline — Evergreen & Platform

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Governed by [ADR-008](decisions/ADR-008-security-and-credential-standard.md).
Complements the existing [`SECURITY_MODEL.md`](SECURITY_MODEL.md).

**Confidence labels:** `[Verified from source]` = confirmed in repo metadata; `[Unverified]` =
org/runtime not checked; `[Proposed/Future]` = not yet built.

Baseline security standards every connector, credential, and guest-facing surface must meet.

---

## 1. Credential standard

**All external callouts authenticate via Named Credential / External Credential.** Secrets are
never stored in custom objects, custom settings, custom metadata, or Apex.

Current state `[Verified from source]`:

| Item | Status | Action |
|------|--------|--------|
| `OA_Anthropic` Named Credential | Present, but references an **External Credential that is not committed** | Commit the External Credential metadata; verify deploy. |
| `OA_Graph_Credential__c` (Client_Id/Client_Secret/Tenant_Id as Text) | **Non-compliant** — secret material in a custom object | Migrate Graph auth to Named/External Credential; retire secret fields. |
| Remote Sites `MicrosoftGraph`, `MicrosoftLogin`, `OA_USASpending` | Legacy callout pattern | Replace with Named Credentials. |

> **Finding `[Verified from source]`:** `OA_Graph_Credential__c.Client_Secret__c` is a Text(255)
> field — client secrets should not live in queryable object data. This is a security-debt item.

---

## 2. Connector security rules `[Proposed]`

1. **Public data only** at this stage — no source returning PII/CUI without a prior data-classification decision.
2. **Named Credential for every connector**, including public no-auth endpoints (declared with no External Credential) — one callout path, no hardcoded endpoints.
3. **Staging is Private** and contains only what the source returned; no secrets, no derived PII.
4. **No automatic write-back** to `Lead`/`Contact`/`Campaign`/`CampaignMember`. Write-back occurs only after `Review_Status__c = Approved` via a separate governed step.
5. **Least privilege** — connector runtime users get access to staging objects only, not to production campaign automation.

---

## 3. Guest / unsubscribe surface `[Verified from source + Proposed rules]`

The public unsubscribe endpoint is the platform's only guest-facing surface. Baseline rules:

- **GET must never mutate** preference state (render/validate only).
- **POST performs token-based unsubscribe** — mutation requires a valid token (`Token_Hash__c`, SHA-256 / Text(64)).
- **Guest access minimal** — only `OA_Unsubscribe_Guest_Access`; no broad object CRUD/FLS to the guest user.
- **No guest object CRUD/FLS** beyond the minimum the endpoint requires; audit the permission set before any change.
- Async processing via `OA_Unsubscribe_Request__e` + `OA_UnsubscribeRequestTrigger` keeps guest transactions minimal. `[Verified from source]`

---

## 4. Data classification `[Proposed]`

| Class | Examples | Handling |
|-------|----------|----------|
| Public | USASpending awards, Census geography | May be staged freely; no PII. |
| Confidential | Lead business data | Never sent to an unapproved external API. |
| Restricted | Credentials, tokens | Named/External Credential only; never in objects/logs. |

Any new connector must declare its data classification at the [Definition of Ready](DEFINITION_OF_READY.md) gate.

---

## 5. Secrets & logging hygiene `[Proposed]`
- No secrets in `System.debug`, `Notes__c`, or `Request_Metadata__c`.
- Correlation ids (`Correlation_Id__c`, `Enrichment_Run_ID__c`) are safe to log; tokens/secrets are not.
- Store only token **hashes**, never raw tokens (already the pattern for unsubscribe). `[Verified from source]`

---

## 6. Baseline checklist (per change)
- [ ] All new callouts use Named/External Credential (no Remote Site, no hardcoded endpoint).
- [ ] No secret stored in object/setting/metadata/Apex.
- [ ] Guest permission set unchanged or reviewed and minimized.
- [ ] Staging Private; no PII beyond declared classification.
- [ ] No automatic production write-back.

---

## Related documents
- [ADR-008 — Security & Credential Standard](decisions/ADR-008-security-and-credential-standard.md)
- [Security Model](SECURITY_MODEL.md) · [Integration Registry](INTEGRATION_REGISTRY.md)
- [Connector Framework](CONNECTOR_FRAMEWORK.md) · [Metadata Registry](METADATA_REGISTRY.md)
- [Technical Debt](TECHNICAL_DEBT.md)
