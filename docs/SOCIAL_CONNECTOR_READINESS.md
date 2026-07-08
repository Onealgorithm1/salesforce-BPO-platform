# Social Connector Readiness — LinkedIn & Meta

**Org:** `00Dbn00000plgUfEAI` (verified) · **First captured:** 2026-07-07 · **Updated:** 2026-07-08 (PR #18) · **Runtime user:** oauser@pboedition.com
**Setup steps:** `docs/SOCIAL_CREDENTIAL_SETUP.md`

## Current verified state (2026-07-08, PR #18)
- **Meta Named Credential metadata is present** in this branch/PR (`force-app/main/default/namedCredentials/OA_Meta.namedCredential-meta.xml`), endpoint `https://graph.facebook.com`.
- **Meta path is validated** — check-only deploy of the 4 no-secret components (2 Named Credentials + 2 permission sets) succeeded: **4/4 components, 0 errors** (validation IDs `0AfPn0000023WbhKAE`, earlier `0AfPn0000023JOLKA2`).
- **Read-only `GET /me` returned HTTP 200** — `callout:OA_Meta/v21.0/me`, run as `oauser` via anonymous Apex; response shape `{id, name}`, no error. Status + top-level shape only; no secret printed.
- **No secrets are stored in Git** — secret scan of the PR diff is clean; secret-bearing metadata (External Credentials, Auth Providers) is gitignored and lives only in the org's encrypted store.
- **LinkedIn authentication remains pending** — metadata is present, but the OAuth "Authenticate" step has not been completed (see LinkedIn status below).
- **Components are dormant** — no automation, triggers, or schedules; nothing is activated. Activation (permset assignment, LinkedIn auth) happens only on explicit approval.

## Baseline snapshot (2026-07-07, org-side, evidence)
> Point-in-time snapshot from initial capture. Superseded for Meta: the OA_Meta Named/External Credential and principal now exist and function in the org (confirmed by the working read-only `GET /me` on 2026-07-08). Retained for history.
- Named Credentials in org: OpenAI, OA_Anthropic, OA_Census, OA_SAM, OA_USASpending, OA_SEC.
- External Credentials in org: OpenAI, OA_Anthropic, OA_SAM.
- Auth Providers in org: NONE.
- Permsets in org: OA_Connector_Staging, OA_SAM_Connector, OA_SAM_Temp_Principal.

## LinkedIn status
| Item | State |
|---|---|
| Developer app | Exists (per prior workstream); **redirect URI still to be added** |
| OAuth flow | 3-legged Authorization Code (Browser Flow) |
| Auth Provider | **NOT authenticated** — needs Client ID + **Client Secret** (UI) → generates callback |
| Redirect URI | `https://onealgorithmllc.my.salesforce.com/services/authcallback/OA_LinkedIn` (exact value shown after Auth Provider save) |
| Scopes | start `openid profile email`; add approved-product scopes later |
| External Credential | secret-bearing; gitignored, org/UI-only |
| Named Credential | `OA_LinkedIn` metadata present in this branch (PR #18), endpoint `https://api.linkedin.com` |
| Permission set | `OA_LinkedIn_Connector` present (PR #18); principal access + oauser assignment pending activation |
| Credentials configured | **NO** — blocked on Auth Provider authentication + Client Secret (UI) |
| Smoke test | **DEFERRED** (authentication pending) |

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
- **LinkedIn:** deferred — `callout:OA_LinkedIn/v2/userinfo` gated on completing the OAuth "Authenticate" step.

## Limitations & app-review blockers
- **LinkedIn:** live product scopes depend on which LinkedIn products are approved; `w_organization_social`/ads scopes may require app verification. Basic `openid profile email` works once authenticated.
- **Meta:** own-ad-account `ads_read` needs **no App Review**; higher rate-limit tier / other-user data would. App stays unpublished.
- Both remain **dormant** — no callouts occur until explicitly activated (permset assignment; LinkedIn authentication).

## Safe next steps
1. **Meta:** functional and validated; remains dormant until permset assignment is explicitly approved.
2. **LinkedIn:** complete the UI Auth Provider + Client Secret entry per `SOCIAL_CREDENTIAL_SETUP.md`, add the callback to the LinkedIn app, then run the "Authenticate" step on `OA_LinkedIn_Principal`.
3. On explicit approval, assign the permission set(s) to `oauser` and run one read-only smoke test per platform (status code + top-level shape only).
