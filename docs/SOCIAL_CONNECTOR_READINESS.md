# Social Connector Readiness — LinkedIn & Meta

**Org:** `00Dbn00000plgUfEAI` (verified) · **Date:** 2026-07-07 · **Runtime user:** oauser@pboedition.com
**Setup steps:** `docs/SOCIAL_CREDENTIAL_SETUP.md`

## Verified baseline (org-side, evidence)
- Named Credentials in org: OpenAI, OA_Anthropic, OA_Census, OA_SAM, OA_USASpending, OA_SEC — **no OA_LinkedIn, no OA_Meta**.
- External Credentials in org: OpenAI, OA_Anthropic, OA_SAM — **no OA_LinkedIn, no OA_Meta**.
- **Auth Providers in org: NONE.**
- Permsets in org: OA_Connector_Staging, OA_SAM_Connector, OA_SAM_Temp_Principal — **no OA_LinkedIn_Connector / OA_Meta_Connector**.

## LinkedIn status
| Item | State |
|---|---|
| Developer app | Exists (per prior workstream); **redirect URI still to be added** |
| OAuth flow | 3-legged Authorization Code (Browser Flow) |
| Auth Provider | **NOT created** — needs Client ID + **Client Secret** (UI, Louis) → generates callback |
| Redirect URI | `https://onealgorithmllc.my.salesforce.com/services/authcallback/OA_LinkedIn` (exact value shown after Auth Provider save) |
| Scopes | start `openid profile email`; add approved-product scopes later |
| External Credential | metadata shell exists (gitignored, org-only); **cannot deploy until the Auth Provider exists** |
| Named Credential | `OA_LinkedIn` metadata ready (this branch), endpoint `https://api.linkedin.com` |
| Permission set | `OA_LinkedIn_Connector` ready; principal access + oauser assignment pending secrets |
| Credentials configured | **NO** — blocked on Auth Provider + Client Secret (UI) |
| Smoke test | **DEFERRED** (no secrets) |

## Meta / Facebook status
| Item | State |
|---|---|
| Developer app | `OA BPO Connector Hub` (unpublished) |
| Token type | **Non-expiring Business System User token** (Custom auth — no OAuth flow, no redirect URI) |
| Auth Provider | **Not required** (Custom EC) |
| Scopes/permissions | `ads_read` (own ad account; no App Review needed for own assets) |
| External Credential | `OA_Meta` (Custom) — validated previously; **not deployed**; token entry pending (UI, Louis) |
| Named Credential | `OA_Meta` metadata ready (branch `feature/meta-connector-int011`), endpoint `https://graph.facebook.com` |
| Permission set | `OA_Meta_Connector` ready; principal access + oauser assignment pending secret |
| Credentials configured | **NO** — blocked on System User token (UI) |
| Smoke test | **DEFERRED** (no secret) |

## Tests run
**None yet** — both smoke tests are gated on secret entry (hard rule). Endpoints ready:
LinkedIn `callout:OA_LinkedIn/v2/userinfo`; Meta `callout:OA_Meta/v21.0/me` — read-only, status + top-level shape only.

## Limitations & app-review blockers
- **LinkedIn:** live product scopes depend on which LinkedIn products are approved; `w_organization_social`/ads scopes may require app verification. Basic `openid profile email` works now.
- **Meta:** own-ad-account `ads_read` needs **no App Review**; higher rate-limit tier / other-user data would. App stays unpublished.
- Both are **dormant** — no callouts possible until secrets are entered + NC/EC deployed + permset assigned.

## Safe next steps
1. Louis completes the UI secret entry per `SOCIAL_CREDENTIAL_SETUP.md` (LinkedIn Auth Provider + Client Secret; Meta System User token).
2. Claude deploys the no-secret NC/EC/permset shells + assigns `oauser` (gated, on Louis's OK).
3. Claude runs one read-only smoke test per platform; reports status code + top-level shape only.
