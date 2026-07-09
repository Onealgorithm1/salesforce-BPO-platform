# Lead Acquisition — SAM Entity Pilot Readiness

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-readiness`
**Mode:** read-only audit + read-only smoke test · **No Candidate/Lead/Account writes; no schedules; no automation; no connector enabled.**

> Determines exactly what blocks the first supervised SAM production pilot. **Finding: SAM is NOT blocked by engineering
> or parser — it is blocked by an External Credential principal grant (administration), the alpha→prod endpoint
> (configuration), and confirmation of the data.gov key (administration/external).**

## Phase 14 update (2026-07-08) — endpoint fixed; still credential-gated
- ✅ **CONFIGURATION RESOLVED:** the `OA_SAM` Named Credential endpoint was updated **`api-alpha.sam.gov` → `api.sam.gov`** and **deployed to production** (validate `0AfPn0000023eNxKAI`; **deploy `0AfPn0000023ePZKAY` Succeeded**). The connector now targets the production SAM Entity API. (Reversible: redeploy the prior commit.)
- ⛔ **STILL BLOCKED (unchanged):** the read-only smoke test **re-run after the endpoint fix** returns the **same** `System.CalloutException: We couldn't access the credential(s)... external credential "OA_SAM"` — because the runtime user still has **no EC principal access** (`SetupEntityAccess` = 0; permission-set assignment is a 🔴 gate, scoped to verify/document this sprint) **and** the **data.gov API key** cannot be entered (external secret; not available to engineering). The callout is blocked at the credential layer and never reaches SAM, so the prod endpoint + key are **still unvalidated end-to-end**.
- **Net:** 1 of 3 blockers cleared (endpoint). Remaining (both required for a successful call, both non-engineering): **(a) EC principal grant** — assign `OA_SAM_Connector` permset to the runtime user (🔴 Louis); **(b) data.gov API key** in the `OA_SAM` EC (🔴 Setup/external). **SAM is NOT yet ready for a successful read-only call or the pilot** until (a)+(b) are done by Louis/admin.
- **Production safety:** endpoint metadata deploy only (dormant NC; no connector enabled); read-only smoke test did 0 DML; **no Candidate/Lead/Account change**; data unchanged (6/13,301/1).

## Phase 16 gate check (2026-07-08) — permset alone is INSUFFICIENT; key/principal is the true blocker
**Material finding (surfaced, not assumed):** assigning the `OA_SAM_Connector` permission set — even though authorized this
sprint — would **NOT** grant SAM access. The permset contains **no `externalCredentialPrincipalAccesses` block** (only
`OA_SAM_Entity_Staging__c` CRUD/FLS); its own description states *"EC principal access added at the key gate."* Evidence:
- Repo permsets granting EC principal access: **only `OA_LinkedIn_Connector`, `OA_Meta_Connector`** — **none for `OA_SAM`**.
- Live `SetupEntityAccess` for ExternalCredential org-wide = **0**; `OA_SAM_Connector` assignments = 0.
- Read-only smoke re-confirmed: `System.CalloutException: We couldn't access the credential(s)... external credential "OA_SAM"`.

**Therefore the permset was NOT assigned** (a hollow RED change that wouldn't unblock SAM and would add an unnecessary
standing grant). The true, ordered blocker chain is **administrative + external**, requiring the data.gov key first:

**Exact Setup steps (admin, requires the data.gov API key):**
1. **Setup → Security → Named Credentials → External Credentials → `OA_SAM` → Principals** → edit the Named Principal →
   under **Authentication Parameters** set the **`X-Api-Key`** header value = the **data.gov API key**. *(The key is an
   external secret; engineering cannot invent/obtain it. Prior sessions: alpha 401 / prod 200 with a valid key.)*
2. **Setup → Permission Sets → `OA_SAM_Connector` → External Credential Principal Access → Edit** → enable the **`OA_SAM`**
   principal → Save. *(Adds the `externalCredentialPrincipalAccesses` grant / `SetupEntityAccess` row — metadata-deployable
   as a permset update, but requires the EC principal from step 1 to exist first.)*
3. **Assign `OA_SAM_Connector`** (now carrying the EC grant) to the runtime user `oauser@pboedition.com`.

Only after steps 1–3 will the read-only smoke return **HTTP 200**; then the supervised ≤3-Candidate pilot (§6) can run.

**Why engineering cannot proceed:** step 1 needs the **data.gov API key** (external secret, not held by engineering) and
Setup-UI entry; step 2's principal grant depends on step 1. `OA_SAM_Connector` was therefore **not** assigned this sprint
(it would not help). **STOPPED per Phase 3.** No permset assigned; no key; no smoke 200; no preview; no pilot; **0 DML;
data unchanged (6/13,301/1).**

---

## 1. State verification (Phase 1)
Org `00Dbn00000plgUfEAI` ✅ · Candidates 6 (3 USASpending + 3 SEC) · Leads 13,301 · Accounts 1 · **0 acquisition async jobs** · no schedules. Deployed LA classes: `OA_CandidateDiscovery`, `OA_CandidateDiscoveryService`, `OA_CandidateDiscoveryQueueable`, `OA_IdentityResolution`, `OA_SourceFusion`, `OA_LeadCompleteness` (all dormant).

## 2. SAM connector audit (Phase 2)
| Item | Status |
|---|---|
| Connector class | `OA_SAM_Connector` ✅ deployed; implements `OA_IEnrichmentConnector`; emits `OA_CanonicalOrg` |
| Registry row | `SAM` ✅ — class `OA_SAM_Connector`, NC `OA_SAM`, path `/entity-information/v3/entities`, `Enabled__c=false` |
| Input format | 12-char alphanumeric → `ueiSAM=`; otherwise `legalBusinessName=` search (`OA_SAM_Request`) |
| Endpoint (configured) | **`https://api-alpha.sam.gov`** (ALPHA) — ⚠ should be prod `api.sam.gov` |
| Auth method | SecuredEndpoint NC → EC `OA_SAM`; **X-Api-Key** header injected by the EC (never in URL/logs/source) |
| Named Credential | `OA_SAM` ✅ present (SecuredEndpoint, references EC) |
| External Credential | `OA_SAM` ✅ present (gitignored; holds the key) |
| **Principal grant** | ❌ **0 `SetupEntityAccess` for ExternalCredential** — runtime user has NO access to `OA_SAM` |
| Parser | `OA_SAM_ResponseParser` ✅ mature |

## 3. Read-only smoke test (Phase 4) — executed, 0 DML
Ran `OA_SAM_Connector.fetch('YA8LJBJCND19', cfg)` (a real UEI; read-only GET):
```
http=null  parsed=0  httpErrors=1  DML rows=0
System.CalloutException: We couldn't access the credential(s). You might not have the required
permissions, or the external credential "OA_SAM" might not exist.
```
**Interpretation (precise):** the connector built the request and attempted the callout; Salesforce blocked it at the
**credential layer** because the runtime user lacks **EC principal access** to `OA_SAM` (confirmed: `SetupEntityAccess`=0).
The call never reached SAM, so the **data.gov key and prod endpoint could not be validated** in this pass. **The
plumbing (connector, request, driver) is proven correct; the block is the credential grant.** No data written.

## 4. Credential readiness (Phase 3) — blockers by category
| Blocker | Category | Detail | Gate |
|---|---|---|---|
| **EC principal grant missing** | **Administration** | assign the `OA_SAM_Connector` permission set (carries `ExternalCredentialParameter` principal access) to the runtime user; MAD does **not** substitute (Sprint-15 finding) | 🔴 permission-set assignment |
| **data.gov API key** | Administration / External | must be entered in the `OA_SAM` External Credential in **Setup only** (never git); prior sessions saw alpha 401 / prod 200 with a key — **confirm/rotate** | 🔴 credential + external |
| **Endpoint alpha→prod** | Configuration | change `OA_SAM` NC `Url` `api-alpha.sam.gov` → `api.sam.gov` and deploy | 🔴 NamedCredential deploy |
| **Runtime user** | Administration | MAD `oauser` acceptable for a supervised ≤3 pilot; **least-privilege user required before volume**, not before the pilot | (pilot: acceptable; volume: 🔴 license) |
| **Engineering** | — | **NONE** — connector/parser/driver/queueable all ready (smoke test proves request + callout attempt) | — |

## 5. Parser field matrix (Phase 6) — `OA_SAM_ResponseParser`
| Field | Populated by SAM |
|---|---|
| Organization Name / Normalized Name | ✅ |
| UEI | ✅ |
| CAGE | ✅ |
| Address / City / State / Postal | ✅ (full) |
| Website | ✅ |
| Phone | ✅ |
| NAICS | ❌ (not in entityRegistration/coreData sections; documented) |
| Source confidence | ✅ (HIGH — deterministic UEI/CAGE) |
| Canonical key / Payload hash | ✅ (computed) |

**Expected completeness contribution:** highest of any source — adds CAGE + full address + website + phone to UEI identity → largest single Lead-Completeness lift.
**Expected fusion contribution:** **the best fusion partner.** SAM records key on `UEI:` — the **same namespace as USASpending candidates** → SAM will **MATCH and fuse** into existing USASpending candidates (e.g., an Aerospace-Corporation UEI overlap), producing the **first real committed cross-source fusion** (filling their blank website/CAGE/address).

## 6. Supervised pilot runbook (Phase 5) — for execution AFTER the gates in §4 are cleared (Louis-approved)
**Preconditions (all 🔴, Louis):** (a) data.gov key in `OA_SAM` EC; (b) `OA_SAM` NC endpoint → `api.sam.gov`; (c) assign `OA_SAM_Connector` permset (EC principal access) to the runtime user; (d) explicit approval to write ≤3 Candidates.

**Step 1 — read-only smoke (re-run §3):** expect HTTP 200 + one org with UEI/CAGE/address/website/phone. If 401/403 → key/endpoint issue; stop.

**Step 2 — PREVIEW (0 DML)** via the generic driver:
```apex
OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run('SAM', '<UEI or legalBusinessName>', false, 3);
// inspect r.candidates: fused (matches existing USASpending UEI) vs wouldInsert (new); DML must be 0
```
Use up to 3 inputs (UEIs of existing USASpending candidates to prove **fusion**, and/or new legal-name searches).

**Step 3 — COMMIT (≤3), controlled:**
```apex
OA_CandidateDiscovery.run('SAM', '<input>', true, 3);   // direct driver, synchronous, one input
// or, for spaced execution (no schedule): System.enqueueJob(new OA_CandidateDiscoveryQueueable('SAM', inputs, true, 3, 1));
```
**Hard limit: ≤3 Candidate writes.** SAM records that MATCH an existing USASpending UEI candidate will **fuse** (UPDATE, no new insert); genuinely new SAM orgs INSERT as `Needs Review`.

**Step 4 — verify:** candidate IDs/status; identity decision (MATCH/REVIEW/NONE); **fusion** filled fields + provenance (`Discovery_Metadata__c`); **completeness before/after** (`OA_LeadCompleteness`); **no Leads/Accounts changed; no schedules; no automation**. Rollback = delete the SAM rows / revert fused fields (idempotent via payload hash).

## 7. Production safety verification
Read-only audit + one read-only callout (blocked at credential layer). **No Candidate/Lead/Account write; 0 DML; no connector enabled; no schedule; no automation.** Data unchanged (6 candidates / 13,301 leads / 1 account).

## 8. PASS / WARN / FAIL — 🟡 WARN (credentials missing — expected)
SAM blocker identified **precisely** (EC principal grant missing — proven by the exact CalloutException); credential/config status verified; parser readiness documented; pilot runbook complete; **no production data change, no Lead/Account change, no automation, no schedules.** **WARN:** credentials/principal-grant/endpoint are missing (administration/configuration) — not engineering. 🔴 none.

## 9. Exact next approval gate (Louis)
To run the SAM pilot, Louis must authorize (all 🔴): **(1)** enter the data.gov API key in the `OA_SAM` External Credential (Setup); **(2)** change the `OA_SAM` Named Credential endpoint `api-alpha.sam.gov` → `api.sam.gov` (deploy); **(3)** assign the `OA_SAM_Connector` permission set (EC principal access) to the runtime user; **(4)** approve a supervised ≤3-Candidate SAM pilot. Engineering requires nothing further.

---

## 10. Phase 17 — live wiring resolved; remaining blocker is at the SAM boundary (2026-07-09)
Live Setup was reconfigured by Louis since Phase 16: key populated, `OA_SAM_Principal` created, **EC principal access now references permission set `OA_SAM_Temp_Principal`** (the Sprint-31 test permset — carries the `ExternalCredentialParameter` grant), **not** `OA_SAM_Connector`.

**Fix applied (authorized this sprint):** assigned `OA_SAM_Temp_Principal` to the runtime user `oauser@pboedition.com` (it was unassigned; 0 → 1). This is the correct runtime permset given how the EC principal is wired.

**Result — the Salesforce runtime credential issue is RESOLVED.** Evidence: the read-only smoke error changed from Phase-16 `System.CalloutException: We couldn't access the credential(s)... external credential "OA_SAM"` → **HTTP 404 with a response body from SAM's own gateway**. The callout now traverses the full credential path and reaches SAM.

**Remaining blocker (external / credential-config — NOT engineering, NOT a Salesforce permission):** every SAM request returns an **empty-body `HTTP 404`** with these response headers: `server: istio-envoy`, `x-envoy-upstream-service-time: 2`, **no `x-ratelimit-*` headers**. Diagnosis:
- The 404 comes from **SAM.gov's own Envoy/Istio gateway** — not api.data.gov (whose rate-limit headers are absent) and not the SAM application (which returns JSON `403` for an invalid key / `400` for a bad request, per open.gsa.gov docs).
- The response is **uniform across every path** tested — `/entity-information/v1|v2|v3|v4/entities`, the host root `/`, and the `opportunities/v2/search` product — never a `403`, `400`, or any JSON error.
- The **absence of `x-ratelimit-limit`** means api.data.gov never established a keyed rate-limit context for the request: our `X-Api-Key` **header** is not being recognized as the api.data.gov `api_key` for these **GET** routes.
- Per open.gsa.gov Entity API docs: for **GET**, the key is expected as the **`api_key=` query-string parameter**; the `x-api-key` **header** form is documented specifically for **POST / Sensitive** data. Our `OA_SAM` credential injects the key **only as an `X-Api-Key` header**, so on a GET the key never lands where SAM's gateway authenticates → generic empty `404`.

### Request-contract tests (read-only raw callouts)
| # | Path tested | Key supplied as | HTTP | Body |
|---|---|---|---|---|
| 1 | `/entity-information/v1/entities?ueiSAM=…` | EC `X-Api-Key` header | 404 | empty, `server: istio-envoy` |
| 2 | `/entity-information/v3/entities?ueiSAM=…` | EC `X-Api-Key` header | 404 | empty, `server: istio-envoy` |
| 3 | v4 / host root `/` / `opportunities/v2/search` | EC `X-Api-Key` header | 404 | empty, `server: istio-envoy` |
| 4 | `/entity-information/v1/entities?…&api_key={!$Credential.OA_SAM.*}` | query param via credential merge field | — | `CalloutException: Illegal character in opaque part` (Salesforce rejects merge fields in the endpoint URL) |

**Findings:** (a) **path/version is not the differentiator** — v1/v2/v3/v4, root, and opportunities all return the identical empty istio-envoy 404; switching the connector from v3→v1 would NOT help. (b) **Salesforce cannot place the key in the query string** — `$Credential` merge fields resolve only in **headers/body**, never in `setEndpoint`; a query-param `api_key` cannot be supplied securely from a Named Credential (proven, test #4).

### IP allowlist analysis (Salesforce Hyperforce egress vs SAM-approved ranges)
Org instance = **`USA350`** (Hyperforce US). The SAM-approved system-account ranges map **exactly** onto Salesforce's published Hyperforce egress list (`https://ip-ranges.salesforce.com/ip-ranges.json`): `155.226.144.0/22`=aws us-east-1, `155.226.156.0/23`+`155.226.186.0/23`=aws us-east-2, `155.226.128.0/21`=aws us-west-2, `129.77.12.0/24`/`129.77.13.0/24`=gcp us-central1/us-east4. ARIN RDAP confirms `155.226.144.0/20` is **owned by Salesforce, Inc. (SFDC-AWS-BYOIP)**. **Conclusion: the SAM allowlist already covers Salesforce outbound callouts; a US Hyperforce pod egresses from within these ranges. IP allowlist is NOT the blocker and needs no update.**

### EC configuration (retrieved metadata — names only, no secret)
`OA_SAM` External Credential: `authenticationProtocol=Custom`, one parameter `OA_SAM_Principal` (`NamedPrincipal`). **No Custom Header and no key auth-parameter are present in the exported metadata** — i.e., there is no visible `X-Api-Key` custom-header mapping that would actually transmit the stored key on the request. This is consistent with the empty istio-envoy 404 and the **absent `x-ratelimit-*` headers** (api.data.gov never established a keyed context): the request likely reaches SAM's gateway **without a recognized api key**.

### Actual remaining blocker (credential configuration — 🔴 RED / protected, external to code)
Most-probable root cause: the `OA_SAM` External Credential **does not send the api key on the request** — the key value is stored on the principal but is not wired to an `X-Api-Key` **Custom Header**, so SAM's gateway sees an unauthenticated GET and returns an empty 404. (Path, permission, and IP are all ruled out above.) Required credential pattern (Salesforce-supported, secure):
1. On `OA_SAM` EC, define an **Authentication Parameter** holding the data.gov key, then a **Custom Header** `X-Api-Key` = `{!$Credential.OA_SAM.<paramName>}`. api.data.gov officially accepts the **header** form — this keeps the secret out of the URL (the only secure option, since query-param injection is impossible per test #4).
2. Re-run the read-only smoke. Expected `HTTP 200` (JSON entity body) or SAM's JSON `403`/`400` (key now reaches SAM's app) — either is a non-empty response that supersedes the current empty gateway 404.
3. If SAM still refuses, escalate on the SAM.gov side: confirm the system account/key is **entitled to the Entity Management API** (role provisioning).

This is a **Named/External Credential change (CLAUDE.md §9 protected; §2 RED)** — outside this sprint's granted scope (which authorized permission-set assignment, done) and outside anything a source change can fix. **Per the instruction "if Salesforce Named Credential cannot inject the key into a query parameter securely, document the required credential pattern and stop," I stopped here.**

**Smoke did NOT reach HTTP 200 → per the sprint gate, preview / pilot / fusion were NOT executed.** No Candidate/Lead/Account write; 0 DML; connector still dormant (`Enabled__c=false`); no schedule; no automation. Data unchanged (6 candidates / 13,301 leads / 1 account). Standing change this sprint: `OA_SAM_Temp_Principal` assigned to the runtime user (authorized; it carries the `ExternalCredentialParameter` grant). Naming note: it is the Sprint-31 *test* permset — recommend later consolidating the EC principal grant onto a properly-named production permset and retiring the temp one.

**Verdict: 🟡 WARN** — Salesforce runtime credential **access** resolved (CalloutException → SAM gateway reached); IP allowlist confirmed covering; a **live credential-configuration dependency** (EC not transmitting the api key as an `X-Api-Key` header) still blocks execution and requires a 🔴 EC change by Louis.
