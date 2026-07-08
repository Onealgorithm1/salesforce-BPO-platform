# OA Authentication Framework

**Status:** Proposed (design only)
**Date:** July 7, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Governs:** Authentication for every current and future One Algorithm connector
**Anchored by:** [[ADR-013-LinkedIn-OAuth-Architecture]] (OAuth precedent),
[[ADR-008-security-and-credential-standard]] (secret standard),
[[ADR-005-connector-framework]] (connector contract)

> **Scope.** This is a design/governance document. It defines a **single reusable authentication
> architecture** so that LinkedIn, Meta, Google, YouTube, GitHub, QuickBooks, SAM.gov, USASpending,
> Grants.gov, SEC, Census, and future AI providers all authenticate through **one** abstraction —
> not a bespoke pattern per source. No code. No configuration. No deployment.

---

## 1. Why a framework (not one design per connector)

The v1.0 Lead Enrichment platform proved a connector can plug into a frozen platform with zero
platform-class changes (SAM → USASpending → Census → IRS → SEC). Authentication was the one
dimension still handled ad hoc: public/no-auth or API-key. Adding LinkedIn introduces OAuth, and
five more OAuth connectors (Meta, Google, YouTube, GitHub, QuickBooks) follow. Without a shared
abstraction, each would re-invent token handling — reproducing the exact `OA_Graph_Credential__c`
anti-pattern (secrets in a custom object, hand-rolled refresh) that ADR-008 is retiring.

**One abstraction, five auth classes.** Every connector's auth need collapses into exactly one of
five provider types, all resolved behind a single interface.

---

## 2. The five authentication classes

| Class | What it is | Who uses it | Salesforce mechanism |
|---|---|---|---|
| **OAuth (3-legged)** | Authorization Code, acts on behalf of a company/user identity | LinkedIn, Meta, Google, YouTube, GitHub, QuickBooks | External Credential (OAuth 2.0, Named Principal) + Named Credential |
| **Client Credentials (2-legged)** | App-only token, no user context | Some future AI/partner APIs, select ad-platform reporting | External Credential (Client Credentials) + Named Credential |
| **API Key** | Static secret header/param | SAM.gov | External Credential (Custom header, e.g. `X-Api-Key`) + Named Credential |
| **JWT / Server-to-Server** | Signed assertion, no interactive consent | Future: Google service accounts, Grants.gov S2S (deferred) | External Credential (JWT bearer) + Named Credential |
| **Anonymous / Public** | No secret, keyless | USASpending, Census, SEC, Grants.gov (public Search2), IRS bulk | Named Credential, `NoAuthentication` / `Anonymous`, **no** External Credential |

**Design rule:** *Every* connector — including public ones — goes through a Named Credential
(ADR-008 rule #1). Remote Site Settings are deprecated for connector use. The only variable is
whether an External Credential (and which auth type) sits behind it.

---

## 3. Common abstraction

```
                         ┌─────────────────────────────────┐
                         │      OA_CredentialProvider        │  (interface)
                         │  resolve(sourceKey) -> auth ctx   │
                         └──────────────┬──────────────────┘
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼               ▼
   OAuth3Legged   ClientCreds       ApiKey            JWT           Anonymous
   (LinkedIn…)    (AI/partner)    (SAM.gov)      (future S2S)   (USASpending…)
        └───────────────┴───────────────┴───────────────┴───────────────┘
                                        │
                                        ▼  all resolve to a Named Credential ref
                              callout:OA_<Source>  (Apex never sees the secret)
```

Connectors do not know or care which auth class they use. They call
`callout:OA_<Source>/...` and the Named/External Credential attaches whatever the source needs. The
auth class is a **configuration fact** in the connector registry (`OA_Connector_Registry__mdt`),
not code branching inside the connector.

---

## 4. OA Authentication Framework — components (Task 3)

A layered set of Apex components, each with a single responsibility. **Design only — no code
written.** Names follow the platform's `OA_` convention.

### OA_AuthenticationManager
- **Responsibility:** The single entry point a connector asks "give me an authenticated callout for
  source X." Resolves the source's auth class from the registry, ensures a valid credential context
  exists, and hands back a Named-Credential-backed request. Delegates secret handling entirely to
  Salesforce's credential store — it never holds a raw token.
- **Does not:** store secrets, branch per-source in business logic, or perform the HTTP call itself.

### OA_TokenManager
- **Responsibility:** Owns token *state awareness* for OAuth/Client-Credentials/JWT sources — knows
  expiry windows, triggers Salesforce's refresh path on 401/expiry, and surfaces the **annual
  refresh-token deadline** to the health monitor. For sources where Salesforce auto-refreshes, this
  is a thin observer; it exists so token lifecycle is monitorable, not hidden.
- **Does not:** read or persist the token value (that stays in the External Credential vault).

### OA_CredentialProvider
- **Responsibility:** The abstraction in §3. Maps a `sourceKey` to its auth class and Named
  Credential name. One implementation per auth class (OAuth3Legged, ClientCredentials, ApiKey, JWT,
  Anonymous), selected by registry config. This is where "how does source X authenticate" is
  declared once.
- **Does not:** contain per-connector business logic.

### OA_CalloutService
- **Responsibility:** The single HTTP execution point for the whole platform. Issues
  `callout:OA_<Source>` requests, applies standard timeouts, headers, and (via OA_RetryManager)
  retry policy, and normalizes the response for the connector's parser. This is the "no more raw
  `new Http().send()`" enforcement point (the gap ADR-005 identified).
- **Does not:** know a source's auth details (asks OA_AuthenticationManager) or interpret payloads
  (hands them to the connector's parser).

### OA_RetryManager
- **Responsibility:** Applies the platform retry standard — exponential backoff with jitter, capped
  attempts, respect for `Retry-After`, and a terminal **dead-letter** state so nothing is silently
  lost. Distinguishes retryable (429, 5xx, timeout) from non-retryable (400, 401, 403) failures.
- **Does not:** log (delegates to OA_ErrorLogger) or decide business outcomes.

### OA_ErrorLogger
- **Responsibility:** The single structured error/audit sink. Writes endpoint, HTTP status,
  correlation/run id, source key, attempt count, and **redacted** context to the platform log
  object(s). Guarantees no secret or token is ever written. Feeds monitoring.
- **Does not:** ever log token/secret material; ever throw (logging must not break a callout path).

### OA_HealthMonitor
- **Responsibility:** Continuous connection health — token-expiry countdown (esp. the annual OAuth
  refresh deadline), consecutive-failure counters, dead-letter growth, and rate-limit proximity.
  Raises alerts before a connector breaks, not after. Backs the monitoring dashboards.
- **Does not:** mutate credentials or perform business callouts.

**Data flow:** `Connector → OA_AuthenticationManager (→ OA_CredentialProvider, OA_TokenManager) →
OA_CalloutService (→ OA_RetryManager → OA_ErrorLogger) → parser`; `OA_HealthMonitor` observes
tokens + logs out of band.

---

## 5. Connector Standards — every connector must comply (Task 4)

Non-negotiable standards. A connector is not "Definition-of-Ready" ([[ADR-010-definition-of-ready]])
until all are met.

| # | Standard | Requirement |
|---|---|---|
| 1 | **Authentication** | Exactly one of the five auth classes (§2), declared in `OA_Connector_Registry__mdt`, resolved via OA_CredentialProvider. Never hand-rolled. |
| 2 | **Retries** | Use OA_RetryManager. Exponential backoff + jitter, capped attempts, honor `Retry-After`, dead-letter on terminal failure. No naked retry loops. |
| 3 | **Logging** | All failures + key lifecycle events via OA_ErrorLogger to the platform log object. Redacted. No secrets, ever. |
| 4 | **Rate limiting** | Respect each source's documented limits; OA_HealthMonitor tracks proximity; reuse `OA_SendGovernor`-style throttling where needed. |
| 5 | **Monitoring** | Emit run telemetry to `OA_Connector_Run__c` (start/finish/duration/processed/qualified/rejected/exceptions). Surfaced on dashboards. |
| 6 | **Health checks** | Registered with OA_HealthMonitor: token-expiry (OAuth), consecutive-failure, dead-letter, rate proximity. |
| 7 | **Staging** | Land raw results in a per-source staging object ([[ADR-006-canonical-data-model]]) with dedupe key, source run id, endpoint, HTTP status, payload ref (SHA-256), review status. No direct-to-CRM writes from the connector. |
| 8 | **Review** | Human/policy review gate before CRM write, per [[ADR-007-entity-resolution-framework]] — except where an explicit ADR (e.g. ADR-012 enrichment auto-write) authorizes deterministic auto-write with logging + rollback + tripwires. |
| 9 | **Write-back** | Only via the platform writer (USER_MODE, per-field write policy, change log + rollback). Never a bespoke DML path. |
| 10 | **Secrets** | Only in External Credentials (ADR-008). Never in objects, settings, metadata, Apex, git, or logs. |
| 11 | **Security** | Least-privilege runtime user; minimal OAuth scopes; no new guest surface without its own ADR; guest GET never mutates. |
| 12 | **Governance** | Registered in the connector registry + INTEGRATION_REGISTRY; dormant-by-default (Enabled=false, Review=true); an ADR for any policy exception. |
| 13 | **Error handling** | Typed exceptions; retryable vs terminal distinction; graceful degradation (missing field = null, never fabricated); no silent swallow. |

---

## 6. Governance ratings (Task 8)

| Dimension | Rating | Rationale | Mitigation |
|---|---|---|---|
| **Technical Risk** | **LOW** | Reuses the frozen, validated connector platform + native SF credentials; auth collapses to 5 known classes. | Keep tokens out of Apex; one provider impl per auth class; contract tests. |
| **Security Risk** | **MEDIUM** | Introduces stored OAuth secrets/refresh tokens (higher value than public APIs); MAD runtime user still in force. | Ext Cred encryption; minimal scopes; replace MAD user with least-priv ([[runtime-user-exception]]); rotation + revocation runbook. |
| **Deployment Risk** | **LOW** | Config-driven (Ext/Named Cred, registry rows, dormant-by-default); dormant-deploy + canary precedent proven. | Deploy dormant; gated smoke test per connector; CMDT `xmlns:xsd` rule to avoid UNKNOWN_EXCEPTION. |
| **Maintenance Risk** | **MEDIUM** | Annual OAuth refresh re-consent per OAuth connector; more moving parts as connector count grows. | OA_HealthMonitor expiry countdown + ~11-month reminders; one shared framework to maintain, not N bespoke ones. |
| **Scalability Risk** | **LOW–MEDIUM** | Six+ OAuth connectors + polling volume + eventual webhooks. Governor limits on synchronous callouts. | Async bulk orchestrator (identified additive gap); staggered schedules; middleware for webhooks at volume; shared abstraction scales linearly, not combinatorially. |

---

## 7. Relationship to existing platform

- **Extends, does not replace, ADR-005/006/007/008.** The connector contract, canonical model,
  entity resolution, and credential standard are unchanged. This framework formalizes the *auth*
  slice they left source-specific.
- **The frozen platform stays frozen.** OA_IEnrichmentConnector, OA_ConnectorRunner, and the
  engines need no change; authentication is resolved *before* a connector's `fetch()` runs.
- **Dormant-by-default remains law.** Nothing here authorizes a live callout; each connector still
  passes its own gated commissioning.

See [[CONNECTOR_AUTHENTICATION_MATRIX]] for the per-connector classification and
[[AUTHENTICATION_ROADMAP]] for the phased evolution.
