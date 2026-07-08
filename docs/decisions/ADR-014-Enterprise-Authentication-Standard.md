# ADR-014 — Enterprise Authentication Standard

**Status:** Proposed
**Date:** July 7, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any new connector is added to the Connector SDK, and before any legacy
authentication migration begins

> **This ADR is the authentication standard for the Connector SDK.** It generalizes the
> connector-specific OAuth decision in [[ADR-013-LinkedIn-OAuth-Architecture]] into a single,
> mandatory standard every current and future connector must follow, operating *within* the security
> rules of [[ADR-008-security-and-credential-standard]] and the connector contract of
> [[ADR-005-connector-framework]]. It **extends** those ADRs; it does not replace them.

---

## Purpose

Establish one permanent, reusable authentication standard for every connector on the One Algorithm
platform, so that authentication is a *configuration fact* declared in the connector registry — not
bespoke code per source. This closes the last per-connector variation left after v1.0 (auth handled
ad hoc as public / API-key) and gives every future OAuth, JWT, webhook, and AI connector a single
pattern to inherit.

## Scope

**In scope:** authentication category selection, credential/secret storage, token lifecycle, the
shared authentication components, connector lifecycle gates, and the mandatory standards for retry,
logging, monitoring, security, and governance — for **all** connectors (government, AI, social,
financial, public data).

**Out of scope:** the canonical data model ([[ADR-006-canonical-data-model]]), entity resolution
([[ADR-007-entity-resolution-framework]]), and the enrichment write policy (ADR-012). This ADR
governs *how a connector authenticates and is operated*, not *what it does with the data*.

## Architectural Principles

1. **Named Credential for every callout.** Including public/no-auth endpoints. Remote Site Settings
   are deprecated for connector use (ADR-008 rule #1).
2. **Secrets only in External Credentials.** Never in objects, custom settings, metadata, Apex, git,
   or logs (ADR-008 rule #2).
3. **Auth is declared, not coded.** A connector's category is a row in `OA_Connector_Registry__mdt`,
   resolved by a shared provider — no per-source `if/switch` in business logic.
4. **Apex never handles a raw token.** Salesforce's credential store injects it at callout time.
5. **Dormant by default.** Every connector deploys disabled; a live callout requires an explicit,
   gated commissioning step.
6. **Reuse before rebuild.** Extend the frozen SDK and existing credentials; do not re-implement.
7. **Least privilege.** Minimal OAuth scopes; a non-MAD runtime user for writes ([[runtime-user-exception]]).

## Authentication Categories

Every connector maps to exactly one category (full per-connector classification in
[[AUTHENTICATION_COMPLIANCE_REPORT]]):

| Category | Salesforce mechanism | Examples |
|---|---|---|
| **OAuth (3-legged, Authorization Code)** | External Credential (OAuth 2.0, Named Principal) + Named Credential | LinkedIn, Meta, Google, YouTube, GitHub, QuickBooks |
| **Client Credentials (2-legged)** | External Credential (Client Credentials) + Named Credential | select AI/partner reporting APIs |
| **API Key** | External Credential (custom header) + Named Credential | SAM.gov |
| **JWT / Server-to-Server** | External Credential (JWT bearer) + Named Credential | future Google service accounts; deferred Grants.gov S2S |
| **Anonymous / Public** | Named Credential (`NoAuthentication`/`Anonymous`), **no** External Credential | USASpending, Census, SEC, Grants.gov, IRS bulk |

## Secret Management

- Client Secrets, refresh tokens, and access tokens live **only** in External Credentials (encrypted).
- **Gap to close (evidence-based):** no External Credential metadata is committed to the repo
  `[Verified from source — 0 files under externalCredentials/]`. `OA_SAM` and `OA_Anthropic`
  reference org-only ECs. Standard requires ECs be committed (or documented as intentionally
  org-only) so deploys are reproducible (ADR-008 rule #3).
- **Prohibited pattern (evidence-based):** `OA_Graph_Credential__c.Client_Secret__c` — a Text(255)
  field holding a live secret `[Verified from source]`. No new connector may store secrets this way;
  the existing instance is scheduled for migration (see [[AUTHENTICATION_COMPLIANCE_REPORT]] Task 4).

## Token Management

- **Access tokens** refresh automatically via the Named/External Credential on expiry/401.
- **Refresh tokens** are used silently by Salesforce; their **periodic expiry (per provider) is the
  one manual event** — tracked by `OA_HealthMonitor` with an advance reminder.
- **No token in Apex.** Hand-rolled `getAccessToken()` (as in `OA_BookingPoller` /
  `OA_ArtifactPoller` `[Verified from source]`) is the anti-pattern this standard retires.
- **Revocation:** rotate the Client Secret or delete/re-point the EC principal to invalidate tokens.

## Connector Lifecycle

Every connector passes these gates before live operation ([[ADR-010-definition-of-ready]]):

`Design (auth category chosen) → Build (Request/Parser/Mapper on the SDK interface) →
Register (OA_Connector_Registry__mdt, dormant) → Validate (check-only, tests ≥ coverage) →
Dormant Deploy → Gated Smoke Test (1 synthetic record) → Commissioned (enabled, monitored)`.

## Error Handling

- Typed exceptions; distinguish **retryable** (429, 5xx, timeout) from **terminal** (400, 401, 403).
- Missing data returns null — **never fabricated** (carried from the enrichment mappers).
- No silent swallow; every failure reaches the error log.

## Retry Standards

- Exponential backoff **with jitter**, capped attempts, honor `Retry-After`.
- Terminal failures land in a **dead-letter** state — nothing silently lost.
- No naked retry loops in connector code; retry is a shared-component responsibility.

## Monitoring Standards

- Every run emits telemetry to `OA_Connector_Run__c` (start/finish/duration/processed/qualified/
  rejected/exceptions) `[Verified from source — object exists]`.
- Health checks registered: token-expiry (OAuth), consecutive-failure, dead-letter growth,
  rate-limit proximity.
- Dashboards over existing log objects; alerts fire **before** a connector breaks.

## Security Standards

- Least-privilege runtime user; minimal OAuth scopes.
- No new guest/inbound surface without its own ADR; guest GET never mutates (ADR-008 rule #4).
- No automatic CRM write from a connector except where an explicit ADR authorizes it (ADR-007;
  ADR-012 enrichment exception) — and then only with logging + rollback + tripwires.
- **Financial systems (QuickBooks):** its OAuth scope is **not** read-only; read-only must be
  enforced by discipline ([[quickbooks-future-workstream-baseline]]).

## Governance Rules — mandatory standards by connector type (Task 5)

Every future connector follows **one** standard, specialized only by category:

| Connector type | Mandatory pattern |
|---|---|
| **OAuth connectors** | Ext+Named Cred, Named Principal, Authorization Code (ADR-013 template); minimal scopes; annual re-consent monitored. |
| **API-key connectors** | Ext+Named Cred with custom header; key only in EC; rotation schedule. |
| **Public API connectors** | Named Cred `NoAuthentication`/`Anonymous`; no EC; still full retry/log/monitor. |
| **JWT connectors** | Ext+Named Cred JWT bearer; signing key in EC; no interactive consent. |
| **Webhook connectors** | Inbound terminates in a **middleware service**, not Salesforce directly; validate signature/challenge; forward via Platform Event. |
| **Polling connectors** | Scheduled Apex + async bulk orchestrator; staggered schedules; governor-safe. |
| **AI providers** | Ext+Named Cred (API-key or Client-Credentials); key only in EC (never in a custom object). |
| **Financial systems** | OAuth Named Principal + explicit read-only discipline; scope minimization; highest audit bar. |
| **Social platforms** | OAuth Named Principal; polling-first; webhooks via middleware when justified. |
| **Government APIs** | Public Named Cred or API-key EC; respect published usage policies (e.g. SEC User-Agent `[Verified from source — OA_SEC NC exists]`). |

Additional governance: connectors are **dormant by default** (Enabled=false, Review=true); every
policy exception requires its own ADR; every connector is listed in `INTEGRATION_REGISTRY` and the
connector registry; CMDT records must carry `xmlns:xsd` on the root element (deploy learning).

## Governance Review (Task 6)

- **Is ADR-013 sufficient?** **No.** ADR-013 decides one connector's OAuth flow (LinkedIn). It is
  necessary as the *precedent* but is not a platform-wide standard. ADR-014 generalizes it.
- **Does ADR-014 overlap ADR-008?** **Partially, and intentionally.** ADR-008 is the *security &
  credential* standard (secrets in ECs, Named Credential for all callouts, no auto-write, guest
  rules). ADR-014 is the *authentication operating standard for the Connector SDK* (categories,
  token lifecycle, retry/monitor/lifecycle). ADR-014 **builds on** ADR-008 and must not restate or
  contradict it.
- **Should ADR-008 remain unchanged?** **Yes.** It remains the foundational Accepted decision.
  ADR-014 operationalizes it for connectors; no edit to ADR-008 is required.
- **Should ADR-014 reference ADR-005, ADR-008, and ADR-013?** **Yes — all three.**

**Recommended final ADR dependency chain:**

```
ADR-005  Connector Framework            (the contract connectors plug into)
   │
   ▼
ADR-008  Security & Credential Standard  (secrets in EC; Named Cred for all callouts)
   │
   ▼
ADR-013  LinkedIn OAuth Architecture     (first OAuth precedent; proves the pattern)
   │
   ▼
ADR-014  Enterprise Authentication Standard  (generalizes 013 under 008, within 005)
```

Supporting relations: ADR-006 (canonical model), ADR-007 (review/no-auto-write), ADR-010
(definition of ready). ADR-014 supersedes nothing; it is additive.

## Future Expansion Strategy

- **First exercise:** LinkedIn (ADR-013) validates the OAuth path end-to-end before Meta / Google /
  YouTube / GitHub / QuickBooks reuse it.
- **Additive gap:** the async bulk orchestrator (already identified) lands to cover scheduled polling
  at volume — additive, not a platform redesign.
- **Webhooks:** graduate from Defer to Build-Later when Lead Sync real-time is justified; always
  fronted by middleware.
- **Legacy convergence:** the one Major Refactor (`OA_Graph_Credential__c` + pollers) migrates onto
  this standard on a security-prioritized schedule (see [[AUTHENTICATION_COMPLIANCE_REPORT]]).

## Consequences

- **Positive:** one auth pattern for the whole platform; secrets rotatable/auditable; connector
  onboarding becomes config + Request/Parser/Mapper; reproducible deploys once ECs are committed.
- **Negative:** requires committing the currently org-only External Credentials (or documenting the
  exception); requires the Graph legacy migration (blocked historically by sandbox availability,
  TD-001); adds a monitoring obligation (annual OAuth re-consent).

## Related Decisions

- [[ADR-005-connector-framework]], [[ADR-008-security-and-credential-standard]],
  [[ADR-013-LinkedIn-OAuth-Architecture]] — the dependency chain above.
- [[ADR-006-canonical-data-model]], [[ADR-007-entity-resolution-framework]],
  [[ADR-010-definition-of-ready]] — supporting.
- `docs/AUTHENTICATION_FRAMEWORK.md`, `docs/CONNECTOR_AUTHENTICATION_MATRIX.md`,
  `docs/AUTHENTICATION_COMPLIANCE_REPORT.md`, `docs/AUTHENTICATION_ROADMAP.md`,
  `docs/SECURITY_BASELINE.md`.
