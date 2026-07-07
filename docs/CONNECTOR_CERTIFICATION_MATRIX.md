# Connector Certification Matrix

_Sprint 31 · 2026-07-07 · Org 00Dbn00000plgUfEAI · live-verified · no secrets · connectors DORMANT_

| Connector | Named Cred | Ext Cred | Endpoint | Auth | Principal access | Live test | Status |
|---|---|---|---|---|---|---|---|
| **USASpending** | `OA_USASpending` ✓ | none (public) | `api.usaspending.gov` | none | n/a | **HTTP 200** (in use) | 🟢 **CERTIFIED** |
| **IRS** | n/a | n/a | n/a (bulk CSV) | none | n/a | n/a (no callout) | 🟢 **READY** |
| **Census** | `OA_Census` ✓ | none (public) | `api.census.gov` | none | n/a | **HTTP 200** (Sprint 30) | 🟢 **READY** (dormant) |
| **SEC** | `OA_SEC` ✓ | none (public) | `data.sec.gov` | User-Agent (in code) | n/a | **HTTP 200** (Sprint 30) | 🟢 **READY** (dormant) |
| **SAM** | `OA_SAM` ✓ | `OA_SAM` ✓ (X-Api-Key) | **`api.sam.gov` (prod, fixed Sprint 32)** | data.gov key | JIT (temp permset) | **HTTP 200** (Sprint 32) | 🟡 **READY WITH CONDITIONS** |

> **SAM update (Sprint 32):** the Sprint-31 HTTP 401 was an **endpoint mismatch**, not a bad key. Re-tested the same key against **`api.sam.gov` (production)** → **HTTP 200, 1 org mapped**. The NC endpoint was corrected alpha→prod (deployed + repo updated). **SAM is no longer blocked.** To *use* SAM enrichment: (1) grant EC principal access to the runtime user JIT (a 1-permset assign — the temp `OA_SAM_Temp_Principal` works, or add the grant to `OA_SAM_Connector`), (2) enable the SAM registry row + activate SAM fill-empty policies. Connector remains dormant.

## SAM — definitive evidence (Track B, Sprint 31)
Temporarily granted oauser EC principal access (temp permset, deployed + assigned + **revoked** after test) and ran the real `OA_SAM_Connector` against `api-alpha.sam.gov`:
```
SAM cfg NC=OA_SAM path=/entity-information/v3/entities
SAM_TEST lastStatus=401 httpErrors=1 orgs=0
messages=(HTTP 401 from SAM (endpoint retained; no data mapped).)
```
**Interpretation:** **no CalloutException** → the Salesforce plumbing is fully correct and functional (NC + EC + `OA_SAM_Principal` + `X-Api-Key` header all work; the request reached SAM). The **HTTP 401** = the API key is **invalid/unauthorized for the alpha endpoint**. This is an **external vendor dependency**, not a config or code fault.

**To certify SAM (external actions, not CLI-fixable):**
1. Obtain/confirm a valid SAM (data.gov) API key authorized for the entities API.
2. Point the `OA_SAM` NC at the **production** endpoint `https://api.sam.gov` (currently alpha).
3. Add the key to the `OA_SAM` External Credential's `X-Api-Key` header (Setup — secret; never in git).
4. Grant EC principal access JIT (1-permset deploy) to the runtime user; re-test; expect 200.

**Everything on the Salesforce side is ready.** SAM is blocked solely by the external key/endpoint.

## Notes
- USASpending/Census/SEC are public/keyless; IRS is bulk-CSV (no callout).
- All connectors remain **dormant** (`Enabled__c=false`); readiness = credential/plumbing readiness, not activation.
- Runtime user is the temporary MAD `oauser`; the least-privilege user (licensing) is the intended model for all connectors.
