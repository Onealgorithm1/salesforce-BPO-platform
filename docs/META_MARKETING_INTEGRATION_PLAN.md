# Meta Marketing API Integration — Implementation Plan (Design Only)

**Project:** Meta Marketing API Integration · App: **OA BPO Connector Hub** (UNPUBLISHED)
**Status:** GREEN — research/design/plan only. **STOP GATE: nothing implemented, published, or reviewed.**
**Date:** July 7, 2026 · **Org (context only):** `00Dbn00000plgUfEAI` · **Repo:** `salesforce-BPO-platform`
**Standards reused:** [[ADR-005-connector-framework]], [[ADR-008-security-and-credential-standard]], [[ADR-013-LinkedIn-OAuth-Architecture]], [[ADR-014-Enterprise-Authentication-Standard]]
**Authoritative sources:** Meta Graph API / Marketing API developer docs. Items not confirmable this session are marked `[Verify — Meta docs]` and are **not** assumed.

---

## REVISION 1 (2026-07-07) — Unknowns Resolved with Evidence

> The pre-approval unknowns are resolved below from **current Meta + Salesforce documentation** (not
> memory). Sources are linked at the end of this section. Net effect: Meta's recommended auth is
> **simpler and safer than LinkedIn's**, and the read-only MVP can proceed **without App Review,
> Business Verification, or app publication**, subject to one rate-limit caveat.

### Q1 — Does `ads_read` on assets owned by the *same verified Business Portfolio*, via a Business **System User**, require App Review / Business Verification / a specific Marketing API tier / app publication?

| Requirement | Answer | Evidence (current Meta docs) |
|---|---|---|
| **App Review** | **NO** — for reading your **own** ad account | Marketing API *Authorization/Overview*: *"If your app is only managing your ad account, standard access to the `ads_read` and `ads_management` permissions are sufficient."* Standard access ≠ App Review. |
| **Business Verification** | **NO** for own-account read; required only for sensitive-data / higher access | Same doc: Business Verification applies when an app *"will access sensitive data"*; not stated for managing your own account. `[Verify — confirm OA Business's verification status only affects Advanced tier]` |
| **Marketing API Access Tier** | **Caveat.** Default = **Limited/Development Access** ("*heavily rate-limited per ad account… for development only, not for production apps running for live advertisers*"). **Full Access** ("*lightly rate limited*") is **post-App Review**. | Marketing API *Authorization* page. |
| **App Publication** | **NO** — an unpublished/development app can access assets owned by users with a role on the app or in the same Business | Access-levels model: Standard access covers app-role/Business-owned assets without publishing. |

**Bottom line:** reading One Algorithm's **own** ad accounts with `ads_read` via a System User needs
**no App Review, no Business Verification, no publication** — the app stays UNPUBLISHED. The **only**
gating factor is **rate limits**: the default Limited tier is fine for a low-volume/dormant MVP, but
production-scale insights pulling would need **Full Access (App Review)** purely to lift rate limits,
**not** to gain permission. This is the single remaining, well-scoped trigger for a future App Review.

### Q2 — Authentication architecture decision matrix

| Criterion | **A. OAuth user token** (short-lived) | **B. Long-lived user token** | **C. Business System User token** ✅ |
|---|---|---|---|
| **Expiration** | ~1–2 hours | ~60 days | **Non-expiring by default** (optional 60-day variant) |
| **Refresh** | Constant re-auth / exchange | Re-exchange ≤60 days | **None** (default). Optional Refresh API if 60-day chosen |
| **Security** | Tied to a **person's** login (breaks if they leave / change pw) | Still person-tied | **Server identity** (System User), scoped to assigned assets; treat token as a password |
| **SF Named Credential compat** | OAuth 2.0 → needs **Auth Provider** (like LinkedIn) | OAuth or static-with-manual-refresh | **Custom header** `Authorization: Bearer` — **no Auth Provider** |
| **SF External Credential compat** | OAuth protocol (Auth Provider dependency) | Mixed | **Custom protocol, Named Principal, static token** — clean |
| **Operational overhead** | **HIGH** | MEDIUM (60-day + person dependency) | **LOW** (set once; rotate on policy) |
| **Production suitability** | **Poor** | Fair | **Best** |

**Recommendation: C — Business System User token** (non-expiring, generated in Business Manager,
asset-scoped, `ads_read`). It removes both the token-refresh problem *and* the person-dependency, and
maps to the simplest Salesforce credential type.

Evidence: Meta *Business Management APIs → System Users → Install Apps & Generate Tokens*: system-user
tokens **"never expire"** by default; a 60-day expiring variant is opt-in via
`set_token_expires_in_60_days=true` with a Refresh API. Meta best-practice: *"use a System User to
generate access tokens… as such tokens never expire… treat these tokens as your password."*

### Q3 — Can Salesforce External Credentials support Meta's model **without custom Apex token management?**

**YES — with the Custom authentication protocol, no Apex is required.** A System User token is a
**static, non-expiring bearer token**. Salesforce External Credentials support a **Custom**
authentication protocol using a **Named Principal** where the token is stored as an authentication
parameter and injected via a **custom header** (e.g. `Authorization: Bearer {token}`; Salesforce
docs explicitly list `bearer`, `ACCESS_TOKEN`, `X-API-Key` as common custom-header names, secret
value "functioning as a password"). **No OAuth flow, no Auth Provider, no refresh code, no custom
Apex.**

- **Contrast with LinkedIn (ADR-013):** LinkedIn uses live OAuth authorization-code, so its EC
  *required* an Auth Provider (the dry-run blocker). **Meta's System User static token uses the
  Custom protocol instead → the `OA_Meta` External Credential has no Auth-Provider dependency and is
  expected to validate as a metadata shell**, with only the token value entered in the UI.
- **When custom Apex *would* be required (and why we avoid it):** only if we chose the **60-day
  expiring** System User token and wanted programmatic renewal — that would need a scheduled Apex job
  calling Meta's Refresh API. **We avoid this entirely by using the non-expiring default token**, so
  the platform needs zero token-management code. Rotation becomes a periodic manual/ops action, not
  code.

### Q4 — Final architecture recommendation (no remaining assumptions)

**Authenticate with a non-expiring Business System User token (scoped to the owned ad account,
`ads_read`), stored in an `OA_Meta` External Credential using the Custom authentication protocol with
a `Authorization: Bearer` custom header and a Named Principal, fronted by an `OA_Meta` Named
Credential (host `https://graph.facebook.com`). No Auth Provider, no OAuth flow, no custom Apex, no
token refresh. The app stays UNPUBLISHED; no App Review or Business Verification for the read-only
MVP; App Review is deferred and triggered *only* if production rate limits require the Full Access
tier.** This supersedes the earlier ADR-013-style OAuth assumption for Meta.

**Sources:**
- [Meta Marketing API — Authorization/Overview](https://developers.facebook.com/docs/marketing-api/overview/authorization)
- [Meta Business Management APIs — System Users: Install Apps & Generate Tokens](https://developers.facebook.com/docs/business-management-apis/system-users/install-apps-and-generate-tokens/)
- [Meta Business Management APIs — System Users: Overview](https://developers.facebook.com/docs/business-management-apis/system-users/overview/)
- [Meta — Access Token Guide](https://developers.facebook.com/docs/facebook-login/guides/access-tokens/)
- [Salesforce — Use API Keys in Custom Headers with Named Credentials](https://help.salesforce.com/s/articleView?id=sf.nc_custom_headers_and_api_keys.htm&type=5)
- [Salesforce — Create or Edit a Custom Authentication External Credential](https://help.salesforce.com/s/articleView?id=sf.nc_create_edit_custom_auth_ext_cred.htm&type=5)
- [Salesforce — Authentication Protocols for Named Credentials](https://help.salesforce.com/s/articleView?id=xcloud.nc_auth_protocols.htm&type=5)

---

## Phase 1 — Repository Verification & Assumptions

**Verified (read-only):**
- Branch `main`, HEAD advanced during this sprint (`345e129 → ebc03d0`) — the **working tree is shared with an active parallel session** (committing Sprint 21–25 lead-write-pilot + USASpending field-write-policy work).
- No merge/rebase in progress. No existing Meta/Facebook connector in source `[Verified — git grep]`.
- INT registry uses INT-001…INT-009; INT-010 reserved (Read AI) → **Meta = INT-011** `[Verify INT-010 status]`.

**Assumptions documented (before any change):**
1. **No git branch created.** Creating/switching a branch in a *shared* working tree would move HEAD for the parallel session and interfere with its staged work (explicitly forbidden). The STOP GATE means no code is produced, so no branch is required. **When implementation is approved, isolate it in a dedicated `git worktree`** (per the platform's own "isolate parallel sessions in worktrees" lesson) rather than switching this tree.
2. This deliverable is an untracked design doc; **no commit, no push** (also honoring "do not commit directly to main").
3. Meta is a **marketing-data sync** (read ad performance), **not** Lead enrichment. It reuses the generic connector SDK but **not** the enrichment/CanonicalOrg/write-back layer.
4. "Verified by human" Meta app admin setup is taken as given; not re-checked (no Meta app changes permitted).

---

## Phase 2 — Architecture Review (Reuse-Before-Build)

**Where the Meta connector belongs:** on the **generic `OA_Connector*` SDK** (HTTP/context/engine/persistence/mock), registered in `OA_Connector_Registry__mdt`, authenticated via the ADR-013/014 OAuth pattern. It does **not** implement `OA_IEnrichmentConnector` (that returns `OA_CanonicalOrg` — an identity concept Meta ad metrics don't have) and does **not** touch `OA_EnrichmentWriter` / Lead write-back.

| Capability | Existing asset to REUSE | Evidence | Build new? |
|---|---|---|---|
| INT-xxx entry | `docs/INTEGRATION_REGISTRY.md` | INT-001…009 present | Add **INT-011** doc entry |
| OAuth framework | ADR-013 pattern (LinkedIn) + ADR-014 standard | ADRs present | Reuse pattern; Meta principal |
| Named Credential pattern | `OA_SAM` / `OA_Census` (SecuredEndpoint → EC) | `namedCredentials/` verified | New `OA_Meta` NC (same shape) |
| External Credential pattern | Org-only, **gitignored** (`**/externalCredentials/` line 50) | `.gitignore` verified | New `OA_Meta` EC (org/UI) |
| Secret management | External Credentials only (ADR-008) | ADR-008 | Reuse — no new mechanism |
| **HTTP client abstraction** | **`OA_ConnectorHttp`** (`send(HttpRequest)`, 30s timeout, `virtual` → mockable) | class verified | **Reuse as-is** |
| Connector SDK plumbing | `OA_ConnectorContext`, `OA_ConnectorEngine`, `OA_ConnectorPersistence`, `OA_ConnectorRow`, `OA_ConnectorRunResult`, `OA_ConnectorMock` | classes verified | Reuse |
| Logging / telemetry | `OA_ChangeLogService` + `OA_Connector_Run__c` persistence | verified | Reuse; add Meta run rows |
| Staging / write-back safeguards | `OA_EnrichmentWriter` (USER_MODE, per-field policy, change log, rollback), review gates | verified | **Reuse only the *staging* discipline; NO write-back** (Phase 4 rule) |
| Registry-driven dispatch | `OA_ConnectorRunner` (Type.forName) | verified | Reuse *if* Meta adopts a compatible interface; otherwise a thin Meta service on `OA_ConnectorHttp` |

**Conclusion:** ~80% of the Meta connector is existing platform. New code = Meta request/parse/map classes + Meta staging objects + `OA_Meta` credential + registry/doc entry. **No new HTTP, logging, secret, or SDK mechanism.**

---

## Phase 3 — Meta Integration Design

### Authentication (finalized in Revision 1 — see above)
- **Chosen: non-expiring Business System User token** (option C). In Business Manager, create a
  System User, assign the owned ad account(s) as assets, grant `ads_read`, and generate a
  **non-expiring** access token (System User tokens never expire by default). Server-to-server, no
  person-dependency, no refresh.
- **NOT 3-legged OAuth for Meta.** The earlier ADR-013-style OAuth assumption is superseded: Meta's
  static System User token uses the Salesforce **Custom** auth protocol, not OAuth — so **no Auth
  Provider and no OAuth browser flow** (unlike LinkedIn).
- **Business Manager integration:** assets assigned to the System User **in the BM UI once** — no
  `business_management` write scope for a read sync.
- **Salesforce termination:** `OA_Meta` External Credential (**Custom protocol**, Named Principal,
  `Authorization: Bearer` custom header) + `OA_Meta` Named Credential (host
  `https://graph.facebook.com`). Token entered once in the UI — never in source. **No custom Apex.**

### Marketing API (minimum scope)
Read-only sync of: **Ad Accounts → Campaigns → Ad Sets → Ads → Insights** via Graph API (`/act_<id>/campaigns`, `/adsets`, `/ads`, `/insights`). Requires **`ads_read`** only. Versioned host `graph.facebook.com/v<XX.0>` — version set per-call, so the Named Credential is version-agnostic. `[Verify — current Graph API version]`

### Pages permissions — which are actually required
| Permission | Needed for MVP (ads sync)? | Rationale |
|---|---|---|
| `pages_read_engagement` | **No** (defer) | Only if syncing organic Page engagement; MVP is ads. |
| `pages_show_list` | **No** (defer) | Only if enumerating managed Pages in-app; System User already has assigned assets. |
| `pages_manage_metadata` | **No** | Write/settings/webhook scope; not needed for read sync. |

**MVP needs zero Pages scopes.** Add `pages_read_engagement` + `pages_show_list` later only if Page-level reporting is added.

### Business Management necessity
**`business_management` is NOT required** for our use case. It manages BM assets/System Users programmatically; we assign assets once in the BM UI. Request it only if we later automate System-User/asset provisioning. `[Verify — Meta docs]`

---

## Phase 4 — Salesforce Design (objects/services only; no automation)

**Custom objects (staging/reporting — no Lead write-back):**
| Object | Purpose | Key fields (design) |
|---|---|---|
| `Meta_Ad_Account__c` | One row per ad account | Account_Id (ExtId, unique), Name, Currency, Status, Business_Id, Last_Synced |
| `Meta_Campaign__c` | Campaign | Campaign_Id (ExtId), Ad_Account (lookup), Name, Objective, Status, Daily_Budget |
| `Meta_Ad_Set__c` | Ad set | AdSet_Id (ExtId), Campaign (lookup), Name, Optimization_Goal, Status, Targeting_Summary |
| `Meta_Ad__c` | Ad | Ad_Id (ExtId), Ad_Set (lookup), Name, Status, Creative_Ref |
| `Meta_Insights__c` | Metrics snapshot | Insight_Key (ExtId: level+id+date), Level, Parent lookups, Date, Impressions, Clicks, Spend, CTR, CPC, Conversions, Source_Run_Id |

**Services (reuse SDK):** `OA_Meta_Request` (builds Graph requests, Named Credential) → `OA_ConnectorHttp.send()` → `OA_Meta_Parser` (Graph JSON, paging cursors) → `OA_Meta_Mapper` (→ staging upserts by ExtId) → `OA_Connector_Run__c` telemetry. All **dormant**; no scheduled jobs, no Flows, no automation.

**Explicit exclusions (per brief):** No Lead write-back. No production automation. No Flow activation. No scheduled sync in this design.

---

## Phase 5 — Security Review

| Area | Design | Improvement recommended |
|---|---|---|
| Token storage | Non-expiring System User token in `OA_Meta` EC (**Custom protocol**, encrypted) | Never in Apex/metadata/git/chat; no Apex token mgmt |
| Named Credentials | `OA_Meta` SecuredEndpoint → EC, host `graph.facebook.com` | Mirror `OA_SAM` shape |
| External Credentials | `OA_Meta` EC (Custom auth, `Authorization: Bearer` header), org-only (gitignored) | No Auth Provider needed (unlike LinkedIn); document as intentional org-only |
| Secret isolation | Client Secret + token entered in UI only | No secret leaves the org |
| Least privilege | `ads_read` only; MVP no Pages/BM scopes; System User scoped to assigned assets | Add scopes only per proven need |
| Rotation strategy | Rotate System User token on schedule; App Secret rotatable in Meta | Add token-expiry monitor (ADR-014 `OA_HealthMonitor`) |
| Audit logging | `OA_Connector_Run__c` per sync; no secret logged | Reuse enrichment logging discipline |

---

## Phase 6 — App Review Readiness (permission-by-permission)

Key principle: **App Review + Business Verification are required to access *other* users' data or Advanced Access. Reading your *own* Business's assets via a System User under Standard Access generally does not require App Review.** `[Verify — Meta App Review policy]`

| Permission | Purpose | Required? | Needs App Review? | Prod-only? | Recommended Action |
|---|---|---|---|---|---|
| **ads_read** | Read campaigns/ad sets/ads/insights | **YES** | **NO** for own account (Standard access sufficient — confirmed Q1) | No | **Request/enable** — core scope |
| **ads_management** | Create/edit ads | **NO** | YES (write) | — | **Do not request** (read-only sync) |
| **business_management** | Manage BM assets/System Users | **NO** | YES | — | **Do not request** (assign assets in UI) |
| **pages_read_engagement** | Read Page organic engagement | **NO** (MVP) | YES | — | Defer until Page reporting added |
| **pages_show_list** | List managed Pages | **NO** (MVP) | Sometimes NO | — | Defer |
| **pages_manage_ads** | Manage ads on a Page | **NO** | YES | — | **Do not request** |
| **Business Asset User Profile Access** | Access asset user profiles | **NO** | YES | — | Not needed for ad metrics |
| **Marketing API Access Tier** | Rate-limit tier (Limited/default vs Full), not a scope | Limited **YES** (MVP) / Full **NO** | **Full** needs App Review (for rate limits, not permission) | Full = prod scale | **Start on Limited (default)**; pursue Full/App Review only if rate limits bind |
| **threads_business_basic** | Threads API basic | **NO** | YES | — | **Do not request** (unrelated to ads) |

**Readiness verdict:** the MVP (read own ad data via System User, Standard Access) is likely achievable **without publishing, App Review, or Business Verification** — consistent with the STOP GATE. `[Verify — Meta docs for owned-asset Standard Access]`

---

## Phase 7 — Deliverables

### 7.1 Architecture diagram
```
  Meta Graph API (graph.facebook.com/vXX)
        ▲  HTTPS (System User long-lived token)
        │
  ┌─────┴───────────────── SALESFORCE ─────────────────────┐
  │  OA_Meta External Credential (token, encrypted, UI)     │
  │  OA_Meta Named Credential (SecuredEndpoint → EC)        │
  │        │ callout:OA_Meta                                │
  │  OA_Meta_Request → OA_ConnectorHttp.send() [REUSE]      │
  │        → OA_Meta_Parser → OA_Meta_Mapper                │
  │  Staging: Meta_Ad_Account/Campaign/Ad_Set/Ad/Insights   │
  │  Telemetry: OA_Connector_Run__c [REUSE]                 │
  │  Perm set: OA_Meta_Connector (dormant, unassigned)      │
  │  NO Lead write-back · NO Flow · NO scheduled job        │
  └────────────────────────────────────────────────────────┘
```

### 7.2 Connector design
Registry-declared (`OA_Connector_Registry__mdt` row **Meta**, Enabled=false), generic-SDK based, read-only, dormant. Lifecycle: Registry → Request → `OA_ConnectorHttp` → Parse → Map → Staging upsert (by ExtId) → Run telemetry.

### 7.3 Authentication sequence
```
Admin(BM) ── create System User, assign ad account(s) ──▶ Meta Business Manager
Admin ── issue long-lived System User token ───────────▶ (UI/secret)
Admin ── paste token into OA_Meta External Credential ─▶ Salesforce (encrypted)
Sync  ── callout:OA_Meta + Bearer(token) ─────────────▶ Graph API ─▶ JSON ─▶ staging
        (Apex never sees the raw token; NC injects it)
```

### 7.4 Metadata required
`OA_Meta` External Credential (**Custom protocol** — static System-User bearer token, **no AuthProvider dependency**, so the EC shell is expected to validate as metadata with only the token entered in UI — simpler than LinkedIn), `OA_Meta` Named Credential (host `graph.facebook.com`), `OA_Meta_Connector` permission set, `OA_Connector_Registry.Meta` CMDT record (dormant; **root `xmlns:xsd` required** — deploy learning), 5 staging objects + fields.

### 7.5 Salesforce components required
5 custom objects; `OA_Meta_Request/Parser/Mapper` (+ tests); NC/EC/permset; registry record; INT-011 doc entry. Reuse: `OA_ConnectorHttp`, `OA_Connector*` SDK, `OA_Connector_Run__c`, logging.

### 7.6 Estimated implementation effort
| Work | Effort |
|---|---|
| Objects + fields (5) | ~0.5 day |
| Meta Request/Parser/Mapper + tests | ~1.5 days |
| NC/EC/permset + registry + docs | ~0.5 day |
| BM System User + token setup (UI) | ~0.5 day (human) |
| Dormant deploy + check-only + canary read | ~0.5 day |
| **Total (dormant, read-only MVP)** | **~3.5 dev-days** (excludes any App Review) |

### 7.7 Risks
| Risk | Rating | Mitigation |
|---|---|---|
| **Technical** | **LOW** | ~80% reuse of a validated SDK; read-only; Graph paging is well-documented. |
| **Security** | **MEDIUM** | Long-lived token is high-value → EC encryption, least scope (`ads_read`), rotation + expiry monitor, MAD runtime-user exception ([[runtime-user-exception]]). |
| **Deployment** | **LOW** | Config-driven, dormant-by-default, check-only + canary precedent; CMDT `xmlns:xsd` known. |
| **Governance** | **MEDIUM** | App Review / Business Verification / access-tier rules → keep to owned assets + Standard Access; request scopes only per proven need; no publish. |
| **Scalability** | **MEDIUM** | Graph API rate limits + insights volume → async/batched sync (reuse async orchestrator gap), incremental date windows, backoff. |

### 7.8 Unknowns — status after Revision 1
1. `ads_read` on owned accounts without App Review — **RESOLVED (Q1): yes, no App Review/Verification/publication; only the higher rate-limit tier needs App Review.**
2. Exact current Graph API version + insights fields/limits. `[Verify — Meta docs]` (still open; minor, per-call versioning).
3. Salesforce EC holding a static System-User bearer token, no OAuth, no Apex — **RESOLVED (Q3): yes, Custom protocol + `Authorization: Bearer` custom header.**
4. INT-010 (Read AI) final status before assigning Meta = INT-011. `[Verify — registry]` (still open; doc-only).
5. OA Business Portfolio verification status — **RESOLVED (Q1): not required for the read-only MVP; affects only the Full Access/Advanced tier.**

**Remaining open items are minor and non-blocking:** (2) current Graph API version string, and (4)
the INT-010 registry confirmation. Neither gates the architecture.

---

## STOP GATE

Nothing implemented, deployed, published, reviewed, or committed. No Meta app change, no Salesforce change, no branch switch in the shared tree. This is a plan awaiting approval.

**Recommended next smallest reversible step:** confirm Unknown #1 + #3 (read-only, docs + a Salesforce EC capability check) — they decide whether the MVP avoids App Review entirely and whether the Meta EC is simpler than LinkedIn's. Neither changes anything. On approval to build, isolate the work in a dedicated `git worktree` off `main`.
