# Social Connector Readiness — LinkedIn & Meta

**Org:** `00Dbn00000plgUfEAI` (verified) · **First captured:** 2026-07-07 · **Updated:** 2026-07-08 (LinkedIn now LIVE) · **Runtime user:** oauser@pboedition.com
**Setup steps:** `docs/SOCIAL_CREDENTIAL_SETUP.md`

## Current verified state (2026-07-08, PR #18)
- **Meta Named Credential metadata is present** in this branch/PR (`force-app/main/default/namedCredentials/OA_Meta.namedCredential-meta.xml`), endpoint `https://graph.facebook.com`.
- **Meta path is validated** — check-only deploy of the 4 no-secret components (2 Named Credentials + 2 permission sets) succeeded: **4/4 components, 0 errors** (validation IDs `0AfPn0000023WbhKAE`, earlier `0AfPn0000023JOLKA2`).
- **Read-only `GET /me` returned HTTP 200** — `callout:OA_Meta/v21.0/me`, run as `oauser` via anonymous Apex; response shape `{id, name}`, no error. Status + top-level shape only; no secret printed.
- **No secrets are stored in Git** — secret scan of the PR diff is clean; secret-bearing metadata (External Credentials, Auth Providers) is gitignored and lives only in the org's encrypted store.
- **LinkedIn is now AUTHENTICATED and LIVE** — the OAuth "Authenticate" step was completed in Setup (by Louis) since the prior capture. Read-only `GET /v2/userinfo` returned **HTTP 200** with a valid OIDC identity payload (`sub`, `name`, `given_name`, `family_name`, `email`) on 2026-07-08. Both platforms now pass their read-only smoke tests.
- **Components remain dormant at the automation layer** — no triggers, flows, or schedules; no writes to Leads. The credentials work for read-only callouts; nothing is wired to automation.

## Baseline snapshot (2026-07-07, org-side, evidence)
> Point-in-time snapshot from initial capture. Superseded for Meta: the OA_Meta Named/External Credential and principal now exist and function in the org (confirmed by the working read-only `GET /me` on 2026-07-08). Retained for history.
- Named Credentials in org: OpenAI, OA_Anthropic, OA_Census, OA_SAM, OA_USASpending, OA_SEC.
- External Credentials in org: OpenAI, OA_Anthropic, OA_SAM.
- Auth Providers in org: NONE.
- Permsets in org: OA_Connector_Staging, OA_SAM_Connector, OA_SAM_Temp_Principal.

## LinkedIn status — ✅ LIVE (2026-07-08)
| Item | State |
|---|---|
| Developer app | Exists; redirect URI added (callback registered) |
| OAuth flow | 3-legged Authorization Code (Browser Flow) — **completed** |
| Auth Provider | `OA_LinkedIn` (LinkedIn type) — Client ID + Secret entered |
| Redirect URI | `https://onealgorithmllc.my.salesforce.com/services/authcallback/OA_LinkedIn` (registered in the LinkedIn app) |
| Scopes | `openid profile email` — **working** (userinfo returns identity); higher product scopes require LinkedIn App Review |
| External Credential | `OA_LinkedIn` + `OA_LinkedIn_Principal` — **authenticated** (token in org's encrypted store; gitignored) |
| Named Credential | `OA_LinkedIn` present, endpoint `https://api.linkedin.com` |
| Permission set | `OA_LinkedIn_Connector` present; **assigned to `oauser`** |
| Credentials configured | **YES** — verified working by read-only `GET /v2/userinfo` = HTTP 200 |
| Smoke test | **PASS** — `callout:OA_LinkedIn/v2/userinfo` → HTTP 200, OIDC identity payload (2026-07-08) |

## Meta / Facebook status
| Item | State |
|---|---|
| Developer app | `OA BPO Connector Hub` (unpublished) |
| Token type | **Non-expiring Business System User token** (Custom auth — no OAuth flow, no redirect URI) |
| Auth Provider | **Not required** (Custom EC) |
| Scopes/permissions | `ads_read` (own ad account; no App Review needed for own assets) |
| External Credential | `OA_Meta` (Custom) — secret-bearing; gitignored, org/UI-only; functional |
| Named Credential | `OA_Meta` metadata present in this branch (PR #18), endpoint `https://graph.facebook.com`; validated check-only (0 errors) |
| Permission set | `OA_Meta_Connector` present (PR #18); assignment gated on explicit approval |
| Credentials configured | **YES (org-side, UI-only)** — verified working by read-only `GET /me` = HTTP 200; secret stored only in the org's encrypted store, none in Git |
| Smoke test | **PASS** — `callout:OA_Meta/v21.0/me` → HTTP 200 (2026-07-08); status + top-level shape only |

## Tests run
- **Meta:** `callout:OA_Meta/v21.0/me` (read-only) → **HTTP 200**, shape `{id, name}`, no error (2026-07-08). No secret exposed.
- **LinkedIn:** `callout:OA_LinkedIn/v2/userinfo` (read-only) → **HTTP 200**, OIDC identity payload (`sub`, `name`, `given_name`, `family_name`, `email`, `locale`) (2026-07-08). Endpoint reached (`api.linkedin.com`); authentication confirmed working. No secret exposed.

## Limitations & app-review blockers
- **LinkedIn:** basic identity (`openid profile email`) is **live and working now**. Any richer API — organization posts (`w_organization_social`), Marketing Developer Platform, Advertising, or lead-gen — requires the corresponding **LinkedIn product to be added and App-Review-approved**, plus the additional scopes re-consented via a fresh "Authenticate". Those are external LinkedIn gates, not Salesforce config.
- **Meta:** own-ad-account `ads_read` needs **no App Review**; higher rate-limit tier / other-user data would. App stays unpublished.
- Both remain **dormant** — no callouts occur until explicitly activated (permset assignment; LinkedIn authentication).

## Safe next steps
1. **Meta:** functional and validated (GET /me = 200); permset assigned; remains dormant at the automation layer.
2. **LinkedIn:** authentication complete; identity API (userinfo) verified 200; permset assigned; remains dormant at the automation layer.
3. **Production readiness:** both connectors are **credential/auth operational for read-only calls**. Before any write/automation use: (a) confirm the specific LinkedIn product + scopes are App-Review-approved for the intended API, (b) build/enable the connector automation on its own gated feature branch, (c) provision least-privilege runtime access. No writes to Leads and no automation are enabled by this readiness work.
