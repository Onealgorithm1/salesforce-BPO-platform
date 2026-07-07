# Connector Readiness Matrix — Sprint 18

_Live-verified 2026-07-07 · Org **00Dbn00000plgUfEAI** (onealgorithmllc.my.salesforce.com) · read-only audit · **no secrets shown** · platform DORMANT_

This matrix classifies every v1.0 connector for a controlled live pilot and states **exactly** what remains
before each can make a real production callout. It supersedes the point-in-time table in `CREDENTIAL_STATUS.md`
with a fresh live check (connector registry, Named Credentials, permission-set assignments, scheduled jobs).

## Live verification snapshot (2026-07-07)
- **Connector registry** `OA_Connector_Registry__mdt.Enabled__c` = **false for all 6** (Census, IRS, SAM, SEC, StateRegistry, USASpending) → platform fully dormant.
- **Enrichment scheduled jobs** = **0** (the 12 CronTriggers in the org are campaign automation + platform system jobs, none enrichment).
- **Permission sets:** `OA_Lead_Enrichment_Runtime` = **1** assignment (runtime FLS, kept assigned) · `OA_SAM_Connector` = **0** · `OA_Connector_Staging` = **0**.
- **Named Credentials present:** `OA_USASpending` (endpoint `https://api.usaspending.gov`) · `OA_SAM` (endpoint **blank**) · `OA_Anthropic` (unrelated). **`OA_Census` and `OA_SEC` do not exist.**

## Readiness matrix

| Connector | Callout | Named Cred | External Cred / Auth | Endpoint | Principal Access | Permission Set | **Classification** | Exact remaining work before a real prod call |
|---|---|---|---|---|---|---|---|---|
| **USASpending** | REST POST | `OA_USASpending` ✓ | none (public API) | `https://api.usaspending.gov` ✓ | n/a (no EC) | runtime permset assigned ✓ | 🟢 **READY** | Enable registry row (`Enabled__c=true`) + activate write policy. No credential work. |
| **IRS Tax-Exempt** | **None** (bulk CSV load) | n/a | n/a | n/a | n/a | runtime permset assigned ✓ | 🟢 **READY** | Enable registry row + activate write policy + supply the CSV. No callout, no credential. |
| **SAM.gov** | REST GET | `OA_SAM` present | External Cred `OA_SAM` (data.gov `X-Api-Key`) | **BLANK on NC** ⚠️ | **NOT granted** (`OA_SAM_Connector` = 0 assigns) | not assigned | 🟡 **NEEDS SETUP** | (1) Set NC endpoint; (2) grant EC principal access JIT (MAD does **not** substitute — Sprint-15 finding); (3) **confirm data.gov key valid** — the prior alpha smoke test returned non-2xx, so the key is *unconfirmed*. |
| **U.S. Census** | REST GET | ❌ **missing** | none (public API) | needs `https://api.census.gov` | n/a | runtime permset covers FLS ✓ | 🟡 **NEEDS SETUP** | Create secret-free Named Credential `OA_Census` → `https://api.census.gov` (no auth). Then enable + activate policy. |
| **SEC EDGAR** | REST GET | ❌ **missing** | none (public, but `User-Agent` required) | needs `https://data.sec.gov` | n/a | runtime permset covers FLS ✓ | 🟡 **NEEDS SETUP** | Create secret-free Named Credential `OA_SEC` → `https://data.sec.gov`; connector already sends the required descriptive `User-Agent`. Then enable + activate policy. |
| **State Registry** | (template) | n/a | n/a | n/a | n/a | n/a | 🔴 **BLOCKED / not built** | Template only (`OA_StateRegistry_Template`). No production connector; out of scope for v1.0 pilots. |

Legend: 🟢 READY = usable now with config-only enable · 🟡 NEEDS SETUP = one or more Setup/config tasks (no code) · 🔴 BLOCKED = not viable for pilot.

## What each classification means operationally
- **READY (USASpending, IRS):** everything required for a real call is in place. The only remaining acts are the
  deliberate go-live toggles — enable the registry row and activate a (fill-empty) write policy — which are **RED**
  actions requiring Louis's approval. No developer work, no credential provisioning.
- **NEEDS SETUP (SAM, Census, SEC):** blocked **only** by Setup/config tasks that are Louis's to perform in the org
  UI (create/point a Named Credential; for SAM also grant EC principal access and confirm the key). **No code change.**
- **BLOCKED (State Registry):** intentionally a template; excluded from the pilot.

## Recommended pilot sequence (safest first)
1. **USASpending** — public API, no key, no External Credential, endpoint already set. Lowest blast radius; ideal
   first live connector. Start preview (`commitWrites=false`), then a tiny commit canary.
2. **IRS** — no callout at all (bulk CSV); zero credential/endpoint risk. Good second, fully offline path.
3. **Census** — after creating the `OA_Census` Named Credential (public, no secret).
4. **SEC** — after creating the `OA_SEC` Named Credential (public, `User-Agent` only).
5. **SAM** — **last.** It carries the only secret (data.gov key), needs JIT EC principal access, and its key is
   currently **unconfirmed** (prior non-2xx). Do not pilot SAM until the key is validated in a low-risk smoke test.

## Bottom line
- **Immediately usable (config-only enable):** USASpending, IRS.
- **Blocked only by Setup/config (no code):** SAM (endpoint + EC principal access + key confirmation), Census (NC), SEC (NC).
- **Not for pilot:** State Registry (template).
- The platform stays **dormant** until Louis authorizes the go-live toggles per `GO_LIVE_CHECKLIST.md`.
