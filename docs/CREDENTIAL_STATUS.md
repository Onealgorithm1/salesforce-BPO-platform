# Connector Credential Status (Track A) — Sprint 17 (re-verified Sprint 19)

_Re-verified live 2026-07-07 (Sprint 19, Tooling API) · Org 00Dbn00000plgUfEAI · read-only audit · NO secrets shown_

> **Sprint 19 live re-verification & correction.** The SAM "endpoint blank" finding below was a **misread**: `OA_SAM`
> is a new-style `SecuredEndpoint` Named Credential, so the legacy `NamedCredential.Endpoint` field is null by design.
> The **real** endpoint lives in a `namedCredentialParameter` (live value **`https://api-alpha.sam.gov`** — the ALPHA host,
> not production `api.sam.gov`). SAM's genuine gaps are: **principal access = 0** (confirmed live — permset `OA_SAM_Connector`
> carries no `externalCredentialPrincipalAccesses` grant and has 0 assignments), **alpha endpoint** (should move to prod),
> and **unconfirmed key** (prior non-2xx). USASpending re-confirmed live-ready: **connectivity test HTTP 200** (read-only,
> Sprint 19). Census + SEC NCs **prepared + check-only validated** (`0AfPn00000236CbKAI`, Succeeded) but **not deployed**.
> Full detail: `SPRINT19_LIVE_PILOT_REPORT.md`.

Production credential readiness for every v1.0 connector. Values below are **presence/endpoint only** —
no keys, tokens, or secrets are recorded here (secrets live only in External Credentials in Setup).

| Connector | Callout? | Named Credential | External Credential | Endpoint | Auth | Ready? |
|---|---|---|---|---|---|---|
| **USASpending** | Yes (REST POST) | `OA_USASpending` ✓ | none (public) | `https://api.usaspending.gov` ✓ | none | ✅ **Ready** |
| **IRS Tax-Exempt** | **No** (bulk CSV) | n/a | n/a | n/a | n/a | ✅ **Ready** (no credential needed) |
| **SAM.gov** | Yes (REST GET) | `OA_SAM` (present, **endpoint blank**) | `OA_SAM` ✓ (Custom) | ⚠️ blank on NC | data.gov `X-Api-Key` header | ⚠️ **Blocked** |
| **U.S. Census** | Yes (REST GET) | ❌ **missing** | none (public) | needs `https://api.census.gov` | none | ❌ **Missing NC** |
| **SEC EDGAR** | Yes (REST GET) | ❌ **missing** | none (public) | needs `https://data.sec.gov` | `User-Agent` header (SEC policy) | ❌ **Missing NC** |

Other Named/External Credentials in the org (`OA_Anthropic`, `OpenAI`) belong to unrelated workstreams
and are out of scope for enrichment.

## Gaps to close before live callouts
1. **SAM.gov** — two items:
   - Set the **endpoint** on the `OA_SAM` Named Credential (currently blank).
   - Grant the runtime user **External Credential principal access** to `OA_SAM` — verified **not granted**
     (`OA_SAM_Connector` permission set = **0 assignments**; no `ExternalCredentialParameter` grant found).
     Modify-All-Data does **not** substitute for EC principal access (Sprint-15 finding). Grant JIT at go-live,
     revoke after. The data.gov key must be confirmed valid (the alpha smoke test previously returned non-2xx).
2. **U.S. Census** — create a secret-free Named Credential `OA_Census` → `https://api.census.gov` (no auth).
3. **SEC EDGAR** — create a secret-free Named Credential `OA_SEC` → `https://data.sec.gov`; the connector
   sends the required descriptive `User-Agent` header per SEC's access policy.

## Error handling (already built into the platform)
Every connector returns non-2xx / parse failures on `OA_ConnectorResult` (never throws for expected
failures); the runner records `httpErrors` / `parseErrors` and marks the run `PartialErrors` or `Failed`.
The Sprint-17 orchestrator retries transient (`PartialErrors` + httpErrors) once and **stops the run** on a
`Failed` status. No credential material is ever logged.

## Bottom line
- **Ready now (no credential work):** USASpending, IRS.
- **Needs provisioning:** SAM (endpoint + EC principal access + key confirmation), Census (NC), SEC (NC).
- These are **Setup/config tasks for Louis** — no code change. Until closed, live callouts stay disabled and
  the platform remains dormant.
