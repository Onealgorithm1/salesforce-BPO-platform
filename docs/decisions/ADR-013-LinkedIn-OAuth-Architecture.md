# ADR-013 — LinkedIn OAuth & Enterprise Authentication Architecture

**Status:** Proposed
**Date:** July 7, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any LinkedIn Named Credential / External Credential / Auth Provider is created, and before the first authenticated LinkedIn callout

> **Numbering note.** This ADR is numbered **013**, not 011. ADR-011 (External Intelligence
> Platform) and ADR-012 (Lead-Enrichment auto-write) are already reserved on the
> `design/lead-enrichment-platform` branch. Numbering this decision 013 avoids a duplicate
> ADR-011 in repo history. Decided with Louis on 2026-07-07.

---

## Executive Summary

One Algorithm is adding LinkedIn as a connector (Community Management, Advertising, Lead Sync,
Conversions, Ad Library, Verified). Unlike the v1.0 enrichment connectors (SAM.gov, USASpending,
Census, IRS, SEC), which are public or API-key sources, **LinkedIn requires 3-legged OAuth 2.0
acting on behalf of the One Algorithm company page / ad account.** This is the platform's first
member-context OAuth connector, so the decision here also sets the precedent for every future
OAuth connector (Meta, Google, YouTube, GitHub, QuickBooks).

**Decision in one line:** Terminate LinkedIn OAuth **inside Salesforce** using an
**External Credential + Named Credential** with a **Named Principal**, **Authorization Code**
flow, **polling first**; introduce a small middleware service **only later** for webhooks, and
**never** expose Salesforce directly to LinkedIn webhooks.

This keeps the Client Secret and tokens in Salesforce's encrypted store (never in code, metadata,
or git), requires **no server to run or patch today**, lets Salesforce auto-refresh access tokens,
and extends the credential standard already ratified in [[ADR-008-security-and-credential-standard]].

---

## Business Problem

The Lead Enrichment platform (v1.0, [[ADR-005-connector-framework]] … ADR-010) answers *"who is
this organization?"* from government open data. It does **not** cover:

- **Outbound marketing / social presence** — posting and reading LinkedIn company-page activity
  (Community Management).
- **Paid acquisition telemetry** — ad performance, audiences, conversions (Advertising,
  Conversions, Ad Library).
- **Inbound demand capture** — LinkedIn Lead Gen Form submissions (Lead Sync), which map directly
  onto the existing Lead / Campaign / CampaignMember funnel.

To integrate these, the platform must authenticate to LinkedIn **as One Algorithm** (not as an
anonymous data reader). That is a materially different authentication problem than any connector
built to date, and it must be solved once, correctly, in a way every future OAuth connector reuses.

---

## Requirements

1. **Act on behalf of the company** — post to / read the One Algorithm company page and ad account
   (requires member/organization consent, i.e. 3-legged OAuth).
2. **No secret material in code, metadata, git, or logs** — carry forward the ADR-008 rule.
3. **No server to run today** — a small team cannot own a 24/7 middleware host for an MVP.
4. **Automatic token renewal** — access tokens must refresh without human action on the routine path.
5. **Reproducible, auditable, rotatable credentials** — same bar as ADR-008.
6. **Reuse the frozen connector platform** — dispatch, staging, review, logging, and health
   patterns from the Lead Enrichment platform must apply unchanged.
7. **Future-proof for webhooks** — Lead Sync is webhook-native; the design must have a clear,
   deferred path to real-time without a rebuild.
8. **Least-privilege runtime** — consistent with the standing [[runtime-user-exception]] risk.

---

## Alternatives Considered

| Where OAuth terminates | Verdict | Reason |
|---|---|---|
| **A. Salesforce External Credential** | ✅ **Chosen (with B)** | Holds auth, secret, and tokens in Salesforce's encrypted store. Half of the modern SF pattern. |
| **B. Salesforce Named Credential** | ✅ **Chosen (with A)** | Holds the endpoint; is what Apex calls (`callout:OA_LinkedIn`). External + Named together = the current SF-recommended pattern and the platform standard (ADR-008). |
| C. Experience Cloud | ❌ Rejected for OAuth | Experience Cloud is an *inbound* public surface, not a token store. It has a possible *future* role as a webhook receiver — not where OAuth should live. |
| D. Dedicated integration platform | ⏸ Deferred | A full middleware tier is over-engineering at current volume; adds a server, cost, and attack surface. Revisit only at high webhook volume. |
| E. Small middleware service | ⏸ Later, webhooks only | The right home for *webhook validation* eventually — not needed for OAuth or polling. |
| F. Custom Apex OAuth (hand-rolled) | ❌ Rejected | Exactly the `OA_Graph_Credential__c` / `OA_BookingPoller.getAccessToken` anti-pattern ADR-008 is retiring (secrets in objects, hand-managed tokens). Do not repeat it. |

**OAuth flow alternatives:**

| Flow | Verdict | Reason |
|---|---|---|
| **Authorization Code (3-legged)** | ✅ **Chosen** | Community Management / Lead Sync / Conversions act on behalf of the company page & ad account — only 3-legged provides member/organization consent. |
| Authorization Code + PKCE | ❌ Not applicable | PKCE protects *public* clients that cannot hold a secret. LinkedIn's auth-code flow authenticates with the Client Secret; our client is *confidential* (secret in SF's encrypted vault), so PKCE adds nothing. LinkedIn does not require it. |
| Client Credentials (2-legged) | ❌ Rejected | LinkedIn permits it only for a narrow partner-API set and it carries **no** member/organization context — it cannot post to the page or read Lead Gen forms. |

---

## Final Decision

**Terminate LinkedIn OAuth in Salesforce: External Credential (Authorization Code, Named
Principal) + Named Credential (`OA_LinkedIn`, base URL `https://api.linkedin.com`). Poll on a
schedule to start. Defer webhooks; when built, front them with a small middleware service, never
Salesforce directly.**

**Why each part:**

- **External + Named Credential** — the platform credential standard (ADR-008); no secret ever
  reaches Apex; Salesforce refreshes tokens automatically; reproducible and rotatable.
- **Authorization Code (3-legged)** — the only flow that grants company-page / ad-account context.
- **Named Principal** (not Per-User) — this integration acts as *One Algorithm the company*, not as
  each Salesforce user. One admin authorizes once; all backend jobs share that identity. Per-User
  Principal is for letting individual users connect their own LinkedIn — not the use case here.
- **Polling first** — no inbound endpoint, no signature validation, entirely inside Salesforce;
  adequate until lead volume or latency justifies real-time.
- **Webhooks deferred, via middleware** — keeps Salesforce off the raw internet; the middleware
  validates LinkedIn's signature/challenge, buffers bursts, and forwards clean events.

---

## Security Considerations

- **Secrets** — Client Secret, refresh token, and access token live **only** in the External
  Credential's encrypted store. Apex references `callout:OA_LinkedIn`; it never reads, logs, or
  persists a token. No secret in objects, metadata, git, or logs (ADR-008 rule #2).
- **Scope minimization** — request only the OAuth scopes the enabled products need; do not grant
  the full catalogue "just in case."
- **Least-privilege runtime** — callouts run as the platform runtime user. Today that is the
  temporary MAD exception ([[runtime-user-exception]]); the standing plan to replace it with a
  non-MAD least-privilege user applies here too.
- **Emergency kill switch** — rotating the Client Secret in LinkedIn invalidates all tokens
  immediately; deleting/re-pointing the External Credential principal revokes access.
- **Guest surface** — none added by this decision. Polling is outbound-only. Any future webhook
  receiver is a *middleware* concern, not a Salesforce guest surface (preserves ADR-008 rule #4).

---

## Authentication Flow

**One-time consent (Authorization Code):**

```
 ADMIN (One Algorithm)        SALESFORCE                       LINKEDIN
      | 1. "Authenticate" on   |                                |
      |    External Credential  |                               |
      |------------------------>| 2. redirect to /authorization  |
      |                         |------------------------------->|
      | 3. login + consent (scopes shown)                        |
      |<---------------------------------------------------------|
      | 4. approve ---------------------------------------------->|
      |                         | 5. redirect to SF callback +   |
      |                         |    ?code=...                   |
      |                         |<-------------------------------|
      |                         | 6. exchange code + secret      |
      |                         |    for access + refresh token  |
      |                         |------------------------------->|
      |                         | 7. tokens returned             |
      |                         |<-------------------------------|
      |                         | 8. store ENCRYPTED in Ext Cred |
      |  "Authenticated"        |                                |
      |<------------------------|                                |
   (Happens ONCE. Everything after is automatic.)
```

**Every routine call thereafter:**

```
 SCHEDULED APEX     NAMED CREDENTIAL      EXTERNAL CRED (vault)     LINKEDIN
     | callout:OA_LinkedIn |                     |                    |
     |------------------->| valid token?         |                    |
     |                    |-------------------->|                     |
     |                    |   (expired) refresh -------------------->|
     |                    |<---------------------------- new token ---|
     |                    | attach Bearer + send -------------------->|
     |                    |<------------------------- JSON response ---|
     |<-------------------| data                 |                    |
     | write staging / log / enrich              |                    |
   (Apex never sees the token. Refresh is invisible + automatic.)
```

---

## Token Lifecycle

- **Access token** — LinkedIn 3-legged tokens last ~**60 days**. Salesforce refreshes automatically
  on expiry/401.
- **Refresh token** — LinkedIn refresh tokens last ~**365 days**. Salesforce uses it silently.
- **Renewal** — automatic for access tokens; the **annual refresh-token expiry is the one manual
  event**. Set a reminder at **~11 months** to re-consent before it lapses.
- **Failure handling** — on refresh failure (revoked / expired / secret rotated), callouts return
  401. Catch it, write to the error log, alert, and pause dependent jobs until re-authorized. Never
  tight-loop-retry a dead token.
- **Revocation** — three paths: (a) the authorizing member revokes app access, (b) rotate the Client
  Secret, (c) delete/re-point the External Credential principal. Any forces a fresh consent.

---

## Secret Management

| Secret | Where it lives | Never |
|---|---|---|
| **Client Secret** | External Credential (encrypted) | Apex, metadata XML, git, Named-Credential plaintext, logs |
| **Refresh Token** | Ext/Named Credential token store (encrypted) | Surfaced to Apex or logs |
| **Access Token** | Same encrypted store; injected at callout time | Read, printed, or stored by Apex |

Mirrors [[ADR-008-security-and-credential-standard]] and the [[salesforce-anthropic-key-leak]]
lesson: secrets belong only in the org's encrypted store.

---

## Polling vs Webhooks

- **Polling first (chosen for MVP).** Scheduled Apex pulls Lead Sync forms / ad stats on an interval.
  Simple, no inbound endpoint, no signature handling, fully inside Salesforce.
- **Webhooks become beneficial when** (a) near-real-time lead capture materially lifts conversion,
  (b) polling frequency strains API or governor limits, or (c) LinkedIn push volume makes polling
  wasteful. Lead Sync is the first place this pays off.
- **When built, webhooks terminate in a small middleware service, not Salesforce.** The service
  validates LinkedIn's signature/challenge, buffers spikes, transforms, and forwards a clean
  Platform Event or authenticated inbound call. Salesforce must **not** receive LinkedIn webhooks
  directly (attack surface + governor-limit burst absorption + challenge-handshake handling).

---

## Named Principal vs Per-User

**Named Principal (chosen).** The integration acts as *One Algorithm the company*. One admin
authorizes once; all scheduled jobs share that identity. Simple, matches the "company automation"
intent, and only one annual re-consent to manage.

**Per-User Principal (rejected here).** Appropriate only if each Salesforce user needed to connect
their *own* LinkedIn identity (e.g. a "post as me" feature). That is not the requirement and would
multiply consent/refresh management by user count.

---

## Risks

| Risk | Rating | Mitigation |
|---|---|---|
| Technical | **LOW** | Native SF OAuth pattern, no custom auth code; keep tokens out of Apex. |
| Security | **LOW–MEDIUM** | Secrets in encrypted vault; residual = MAD runtime user ([[runtime-user-exception]]) → least-privilege user when a license frees; minimize scopes. |
| Deployment | **LOW** | Config-driven; deploy dormant, gated smoke test with one synthetic record (SAM.gov precedent). |
| Maintenance | **LOW–MEDIUM** | Access tokens self-heal; the annual refresh re-consent is the one recurring task → reminder + token-expiry monitor. |

---

## Future Expansion

- **This ADR is the OAuth template for the platform.** Meta, Google, YouTube, GitHub, and QuickBooks
  are all 3-legged OAuth connectors that reuse this exact pattern (Ext Cred + Named Cred + Named
  Principal + Authorization Code). See [[AUTHENTICATION_FRAMEWORK]] and
  [[CONNECTOR_AUTHENTICATION_MATRIX]].
- **Webhook middleware** graduates from "defer" to "build later" when Lead Sync real-time is justified.
- **Async bulk orchestrator** (already identified as the platform's one additive gap) covers
  scheduled LinkedIn polling at volume.

---

## Related Decisions

- [[ADR-005-connector-framework]] — the connector contract LinkedIn plugs into.
- [[ADR-006-canonical-data-model]] — staging → canonical shape for LinkedIn objects.
- [[ADR-007-entity-resolution-framework]] — review-gate / no-silent-write discipline.
- [[ADR-008-security-and-credential-standard]] — Named/External Credential standard this extends.
- [[ADR-010-definition-of-ready]] — readiness gate before any LinkedIn build.
- [[ADR-014-Enterprise-Authentication-Standard]] — **generalizes this LinkedIn OAuth precedent into
  the platform-wide authentication standard.** ADR-013 is the precedent; ADR-014 is the standard.
- `docs/AUTHENTICATION_FRAMEWORK.md`, `docs/CONNECTOR_AUTHENTICATION_MATRIX.md`,
  `docs/AUTHENTICATION_ROADMAP.md`, `docs/AUTHENTICATION_COMPLIANCE_REPORT.md`.
