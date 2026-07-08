# Lead Acquisition — SAM Entity Pilot Readiness

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-readiness`
**Mode:** read-only audit + read-only smoke test · **No Candidate/Lead/Account writes; no schedules; no automation; no connector enabled.**

> Determines exactly what blocks the first supervised SAM production pilot. **Finding: SAM is NOT blocked by engineering
> or parser — it is blocked by an External Credential principal grant (administration), the alpha→prod endpoint
> (configuration), and confirmation of the data.gov key (administration/external).**

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
