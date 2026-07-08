# LinkedIn Integration Foundation (Dormant)

**Status:** Prepared — dormant metadata + design (YELLOW: reversible, no secrets, no data writes)
**Date:** July 7, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Org verified:** `00Dbn00000plgUfEAI` (oauser@pboedition.com, Connected) — matched before any action
**Standards:** [[ADR-013-LinkedIn-OAuth-Architecture]], [[ADR-014-Enterprise-Authentication-Standard]]
**Authoritative source:** Microsoft Learn — LinkedIn API docs (`https://learn.microsoft.com/en-us/linkedin/`), cited inline. Blog posts were **not** used.

> **Goal:** a scalable LinkedIn integration foundation that supports *every* approved and
> future-approved LinkedIn product through **one** product-agnostic credential set, with **no
> hardcoded scopes**. Adding a product later = enable its scopes at OAuth consent + (optionally) add
> a staging object — **no credential redesign.** This document is design + dormant metadata only.

---

## 1. What this foundation is (and is not)

- **Is:** one External Credential + one Named Credential + one permission set that serve *all*
  LinkedIn REST APIs (they share host `https://api.linkedin.com` and one company OAuth identity),
  plus a product/scope catalog kept in documentation so products are declared, not coded.
- **Is not:** a per-product connector, an authentication, a token, a webhook, a scheduled job, or any
  production data write. None of those exist or are created here.

Extensibility mechanism: **scopes are granted at consent time per approved product** (LinkedIn:
*"The scopes available to your app depend on which Products or Partner Programs your app has access
to … Your app's Auth tab will show current scopes available"* — MS Learn, Authorization Code Flow).
Because scopes live in the OAuth grant and the product catalog — never in Salesforce metadata —
enabling Advertising, Lead Sync, Events, etc. later requires **no change to the credential design**.

---

## 2. OAuth facts — verified against Microsoft Learn

Source: *LinkedIn 3-Legged OAuth Flow* (MS Learn, `shared/authentication/authorization-code-flow`, updated 2026-05-15).

| Item | Value | Evidence |
|---|---|---|
| Flow | 3-legged **Authorization Code** | `[Verified — MS Learn]` |
| Authorization endpoint | `GET https://www.linkedin.com/oauth/v2/authorization` | `[Verified — MS Learn]` |
| Token endpoint | `POST https://www.linkedin.com/oauth/v2/accessToken` | `[Verified — MS Learn]` |
| `grant_type` | `authorization_code` | `[Verified — MS Learn]` |
| API base host | `https://api.linkedin.com` (e.g. `/v2/me`, `/rest/...`) | `[Verified — MS Learn]` |
| **Access token lifetime** | **60 days** (`expires_in: 5184000`) | `[Verified — MS Learn]` |
| **Refresh tokens** | Supported, **but "Programmatic refresh tokens are available for a limited set of partners"** — not automatic for every app | `[Verified — MS Learn]` |
| PKCE | Not part of the documented flow; auth uses `client_secret` (confidential client) | `[Verified — MS Learn]` |
| Redirect URI rules | Absolute HTTPS, **exact match**, no `#`, query params ignored | `[Verified — MS Learn]` |
| Scope change behavior | Changing requested scopes **invalidates existing tokens** and forces re-consent | `[Verified — MS Learn]` |

### ⚠️ Correction to ADR-013 token-lifecycle assumption

ADR-013 stated refresh tokens are ~365 days and auto-refreshed. **Microsoft Learn shows programmatic
refresh is gated to a "limited set of partners."** Therefore, until One Algorithm's app is confirmed
in LinkedIn's programmatic-refresh program, the operating assumption must be: **plan for a 60-day
access-token cycle with an admin re-consent** (Salesforce cannot silently refresh without the
partner-enabled refresh token). This is flagged for the eventual live phase; it does not change the
dormant foundation. `[Needs Verification — is OA's app enrolled in Programmatic Refresh Tokens?]`

---

## 3. Proposed metadata (dormant) + validation result

Check-only dry-run against `00Dbn00000plgUfEAI` (Deploy ID `0AfPn00000238W9KAI`, then re-run; API v67):

| Component | File | Dry-run | Notes |
|---|---|---|---|
| **NamedCredential** `OA_LinkedIn` | `force-app/main/default/namedCredentials/OA_LinkedIn.namedCredential-meta.xml` | ✅ **PASS** | SecuredEndpoint → `OA_LinkedIn` EC; URL `https://api.linkedin.com`; product-agnostic. |
| **PermissionSet** `OA_LinkedIn_Connector` | `force-app/main/default/permissionsets/OA_LinkedIn_Connector.permissionset-meta.xml` | ✅ **PASS** | Dormant, unassigned, container for future EC principal access + staging perms. |
| **ExternalCredential** `OA_LinkedIn` | `force-app/main/default/externalCredentials/OA_LinkedIn.externalCredential-meta.xml` | ❌ **BLOCKED** | *"must have either an AuthProvider parameter or an ExternalAuthIdentityProvider parameter"* — requires the Auth Provider, which needs the **Client Secret** and generates the **redirect URI** in the UI. |

> **Repo note `[Verified from source]`:** `.gitignore` line 50 (`**/externalCredentials/`) deliberately
> excludes *all* External Credential metadata from version control. The `OA_LinkedIn` EC file exists on
> disk and was used for the dry-run, but it will **not** be committed — consistent with the platform's
> existing pattern (`OA_SAM` / `OA_Anthropic` ECs are org-only). This is why ADR-014's "commit the
> org-only ECs" item is a deliberate open question, not an oversight.

**The ExternalCredential cannot be deployed via metadata without an Auth Provider**, and the Auth
Provider requires the Client Secret + produces the callback URL — a **manual UI/secret step** that
the hard rules and Step 9 forbid me to perform. So the credential chain stops here, by design.

---

## 4. LinkedIn Product & Scope Catalog (extensible — no scopes hardcoded)

All eight target products are served by the same `OA_LinkedIn` credential (same host, same company
identity). Exact scope strings are **granted per product only after that product is approved in the
Developer Portal** ("do not assume access is approved") — so they are catalogued here as
`[Confirm in Portal Auth tab on approval]` rather than hardcoded anywhere.

| Product | Documented on MS Learn | API area / host | Webhook? | Scope source |
|---|---|---|---|---|
| **Community Management** | ✅ (`marketing/community-management/...`) | `api.linkedin.com/rest` — organizations, posts, social actions | Mentions notifications | Portal Auth tab on approval |
| **Advertising** | ✅ (`marketing/integrations/ads/...`) | `api.linkedin.com/rest` — campaign mgmt + reporting | No (polling) | Portal Auth tab on approval |
| **Lead Sync** | ✅ (`marketing/lead-sync/...`) | `api.linkedin.com/rest` — Lead Gen Forms → CRM | **Yes (native)** | Portal Auth tab on approval |
| **Conversions API** | ✅ (`marketing/conversions/...`) | `api.linkedin.com/rest` — conversion events | No (push events out) | Portal Auth tab on approval |
| **Ad Library** | Separate (research API) | `api.linkedin.com` | No | Portal Auth tab on approval `[Needs Verification — scope set]` |
| **Events Management** | ✅ (`marketing/event-management/...`) | `api.linkedin.com/rest` — events | No | Portal Auth tab on approval |
| **Pages Data Portability** | Separate (DMA portability program) | `api.linkedin.com` | No | Portal Auth tab on approval `[Needs Verification — scope set]` |
| **Verified on LinkedIn** | Separate (identity verification) | `api.linkedin.com` | No | Portal Auth tab on approval `[Needs Verification — scope set]` |

**Versioning:** LinkedIn REST APIs are versioned via a `LinkedIn-Version` header (MS Learn: Marketing
*API Versioning*). The Named Credential is version-agnostic; the version header is set per-call by the
future connector code, so version bumps need **no** credential change. `[Verified — MS Learn lists API Versioning]`

**How a new product is enabled later (no redesign):**
1. Apply for / receive the product in the Developer Portal.
2. Add its scopes to the OAuth consent (re-consent — note: scope change invalidates old tokens).
3. (If it produces data) add a staging object + grant it on `OA_LinkedIn_Connector`.
4. Build the product's connector (Request/Parser/Mapper) on the SDK. The credential set is untouched.

---

## 5. Manual UI / secret steps required (documented; STOPPED here per Step 9)

These cannot be done as reversible metadata and are **out of scope for YELLOW / this sprint**:

1. **Create the LinkedIn Auth Provider** in Setup (holds Consumer Key + **Client Secret**; do **not**
   paste the secret in chat). Salesforce **generates the Callback URL** on creation.
2. **Read the generated Callback URL** from the Auth Provider page — that is the production
   **Redirect URI** (do not guess it; MS Learn requires exact match).
3. **Add that Redirect URI** to the LinkedIn app's Authorized redirect URLs (Auth tab).
4. **Finalize the External Credential**: add the `AuthProvider` parameter referencing the new Auth
   Provider (the one line that unblocks the dry-run), then create the **Named Principal**.
5. **Run the OAuth authorization** once (admin consent) to mint tokens — Named Principal.
6. **Add EC principal access** to `OA_LinkedIn_Connector` (snippet below) and assign the permset to
   the runtime identity when going live.

EC-principal-access snippet to add to the permission set after step 4:
```xml
<externalCredentialPrincipalAccesses>
    <enabled>true</enabled>
    <externalCredentialPrincipal>OA_LinkedIn-OA_LinkedIn_Principal</externalCredentialPrincipal>
</externalCredentialPrincipalAccesses>
```

---

## 6. Security risks

| Risk | Rating | Mitigation |
|---|---|---|
| Client Secret handling | **MED** | Secret entered only in the Auth Provider UI; never in metadata/git/chat. MS Learn explicitly warns against sharing/URL-passing the secret. |
| Refresh-token gap (60-day forced re-auth) | **MED** | Confirm programmatic-refresh partner status; else schedule admin re-consent + `OA_HealthMonitor` expiry alert (ADR-014). |
| Over-broad scopes | **LOW–MED** | MS Learn: request least scopes; scopes granted per approved product only; none hardcoded. |
| Dormant metadata mistaken as live | **LOW** | EC blocked (no Auth Provider), permset unassigned, no tokens, no jobs — cannot call out. |
| Runtime user (MAD) | **MED** | Standing [[runtime-user-exception]]; use least-privilege user before live automation. |

---

## 7. Result

- **PermissionSet + Named Credential:** validated (dry-run PASS), dormant, reversible.
- **External Credential:** authored and prepared, but **correctly blocked** at the Auth-Provider /
  secret / redirect-URI boundary — a manual UI step, documented, stopped as required.
- **Design:** extensible foundation for all 8 products confirmed against Microsoft Learn; no scopes
  hardcoded; one correction logged (refresh-token partner gating).

**PASS / WARN / FAIL → WARN** (foundation prepared + 2/3 components validate; the credential chain
intentionally stops at the documented UI/secret boundary — expected and safe, not a failure).

**Next smallest reversible step:** confirm whether One Algorithm's LinkedIn app is enrolled in
LinkedIn's **Programmatic Refresh Tokens** program (a read-only check in the Developer Portal / MS
Learn `programmatic-refresh-tokens`). That single fact decides the renewal strategy (auto-refresh vs.
60-day admin re-consent) before any Auth Provider or OAuth work begins. It changes nothing.

*YELLOW compliance: no deploy, no Salesforce/LinkedIn configuration, no Auth Provider, no Named/
External Credential created in the org, no authentication, no token, no webhook, no job, no data
write, no commit, no push. Only dormant source files + this document + read-only check-only validation.*
