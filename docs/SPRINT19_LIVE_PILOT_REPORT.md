# Sprint 19 — Operational Merge, Credential Completion & First Live Pilot (Report)

_Executed 2026-07-07 · Org **00Dbn00000plgUfEAI** · all evidence via terminal/Salesforce CLI · no secrets exposed_

## Executive summary (plain English)
- **Sprint 17 is now MERGED into `main` and pushed** (clean fast-forward, validated).
- **USASpending is proven live-ready** — a real read-only call to the government API succeeded (HTTP 200) through the production credential.
- **The 25-Lead pilot did NOT run.** It is blocked by a safe, fixable gap: the enrichment "engine" code (Sprint 17 orchestrator) was never deployed to production, and the USASpending connector is switched off. Turning those on = production changes that need your explicit go-ahead. We stopped before them, by design.
- **A valuable correction:** the earlier "SAM endpoint is blank" finding was wrong — SAM's endpoint IS set (to the alpha test host). SAM's real remaining gap is principal access + key validity.
- Nothing was written to any real Lead. The platform remains dormant and safe.

---

## 1. Org verification — ✅ PASS
`sf org display`: Id **00Dbn00000plgUfEAI**, `oauser@pboedition.com`, instance `onealgorithmllc.my.salesforce.com`, **Connected**.

## 2. Git branch / merge status — ✅ PASS
Pre-merge: local main = origin/main = `485f7dc` (no divergence); Sprint 17 branch local = origin = `59f9df0`; merge-base = main HEAD → **fast-forward-able**; nothing staged; tag `lead-enrichment-v1.0` = `485f7dc`.

## 3. Sprint 17 merge result — ✅ MERGED (fast-forward)
`git checkout main` → `git merge --ff-only feature/sprint17-operational-enablement` → `Updating 485f7dc..59f9df0  Fast-forward` (16 files, +854/−95). **main = `59f9df0`.** Tag `lead-enrichment-v1.0` unchanged at `485f7dc` (not retagged). No conflicts, no manual resolution.

**Validation gate (check-only, no deploy):** `sf project deploy validate` of the 4 Sprint 17 classes + `OA_EnrichmentOrchestrator_Test` → **Succeeded** (ID `0AfPn00000235zhKAA`, 4 components / 0 errors, 6 tests / 0 failures).

## 4. Push result — ✅ PUSHED
`git push origin main` → `485f7dc..59f9df0  main -> main`. origin/main = local main = `59f9df0` (in sync). No force, no history rewrite.

## 5. Credential status by connector (live-verified via Tooling API)
| Connector | Named Credential | Endpoint (live) | Ext. Cred / Auth | Principal access | Status |
|---|---|---|---|---|---|
| **USASpending** | `OA_USASpending` ✓ | `https://api.usaspending.gov` (PrincipalType=Anonymous) | none (public) | n/a | 🟢 **Live-ready** |
| **IRS** | n/a | n/a (bulk CSV, no callout) | n/a | n/a | 🟢 **Ready** (no credential) |
| **SAM** | `OA_SAM` ✓ | **`https://api-alpha.sam.gov`** (set, in `namedCredentialParameter Url`) | Ext.Cred `OA_SAM` ✓ + NamedPrincipal `OA_SAM_Principal` ✓ + `X-Api-Key` header ✓ | **NONE** (permset `OA_SAM_Connector` carries no grant, 0 assignments) | 🟡 **Blocked** |
| **Census** | ❌ missing (prepared, not deployed) | needs `https://api.census.gov` | none (public) | n/a | 🟡 **Needs NC** |
| **SEC** | ❌ missing (prepared, not deployed) | needs `https://data.sec.gov` | none (public, User-Agent in code) | n/a | 🟡 **Needs NC** |

**SAM "verify-live" correction (Track C requirement):** the Sprint 18 "endpoint blank / principal access 0" finding was **half stale**. The endpoint is **NOT blank** — the legacy `NamedCredential.Endpoint` field is null only because `OA_SAM` is a new-style `SecuredEndpoint` NC whose URL lives in a `namedCredentialParameter` (live value `https://api-alpha.sam.gov`). The **principal-access = 0 finding is TRUE** (live-confirmed). SAM also points at the **alpha** host (not production `api.sam.gov`) and its key previously returned non-2xx — so SAM is not pilot-ready regardless.

## 6. Credential fixes made
- **Census + SEC Named Credentials prepared** (no-secret, public, NoAuth/Anonymous) and **check-only validated: Succeeded** (ID `0AfPn00000236CbKAI`, 2 components / 0 errors). Files: `force-app/main/default/namedCredentials/OA_Census.namedCredential-meta.xml`, `OA_SEC.namedCredential-meta.xml`.
- **NOT deployed** — per Track D's gate (deploy only if required for the live pilot; the pilot uses USASpending, which is already credentialed). Ready to deploy in one command at their go-live.
- **SAM: no change** (no key touched, no principal granted) — out of pilot scope.

## 7. Live connectivity results (Track E)
| Order | Connector | Test | Result |
|---|---|---|---|
| 1 | **USASpending** | GET `callout:OA_USASpending/api/v2/references/toptier_agencies/` (read-only) | ✅ **HTTP 200**, shape=object, top-level key `results`, body 52,665 chars. Production NC path works. |
| 2 | **IRS** | n/a | No callout (bulk CSV); no endpoint/credential — connectivity test not applicable. |
| 3 | **Census** | — | Skipped: NC not deployed. |
| 4 | **SEC** | — | Skipped: NC not deployed. |
| 5 | **SAM** | — | **Skipped by rule** (test SAM only if principal access AND endpoint verified — principal access is absent). |

No response bodies or secrets printed; only status + schema shape captured.

## 8. 25-Lead pilot preview results (Track F)
**Preview did not execute** — see blocker (§17). Read-only pre-checks all PASS:
- Connectors disabled by default: all 6 `OA_Connector_Registry__mdt.Enabled__c = false` ✓
- `commitWrites` default = false (constructor forces `false`; preview-safe) ✓
- Rollback service present: `OA_ChangeLogService` deployed ✓ (Sprint-16 proven, 5/5)
- Monitoring objects queryable: `OA_Connector_Run__c` (2), `OA_Enrichment_Change_Log__c` (6), `OA_Enrichment_Exception__c` (1), `OA_Discovered_Organization__c` (0) ✓
- Active write policies: **0** (`OA_Field_Write_Policy__mdt Active__c=true` count = 0) ✓

## 9. 25-Lead live pilot results (Track G)
**Not executed.** Blocked (§17). No writes to any Lead. No CampaignMember change. No records created.

## 10. Lead IDs selected (25, conservative)
Selected from the safe pool of 13,071 (not converted, has Company, **not** a campaign member, excluding Pisano/Marty/MediaNow). Mix of populated & blank enrichment fields.

**Populated-Website subset (12):**
`00QPn000011DshRMAS, 00QPn000011DshTMAS, 00QPn000011DshUMAS, 00QPn000011DshbMAC, 00QPn000011DsheMAC, 00QPn000011DshlMAC, 00QPn000011DshmMAC, 00QPn000011DshoMAC, 00QPn000011DshrMAC, 00QPn000011DshvMAC, 00QPn000011DshwMAC, 00QPn000011DshyMAC`

**Blank-Website subset (13):**
`00QPn000010M0DlMAK, 00QPn000010M0NRMA0, 00QPn000010Mz9BMAS, 00QPn000010TRifMAG, 00QPn000010bHXdMAM, 00QPn000010bIFBMA2, 00QPn000011B1yzMAC, 00QPn000011DshdMAC, 00QPn000011DshkMAC, 00QPn000011DshzMAC, 00QPn000011Dsi0MAC, 00QPn000011Dsi9MAC, 00QPn000011DsiKMAS`

(7 of the blank-subset are internal "One Algorithm LLC" test Leads — ideal lowest-risk canary candidates.)

## 11. Fields updated
**None.** No enrichment executed.

## 12. Exceptions
**None generated this sprint.** (1 pre-existing `OA_Enrichment_Exception__c` from earlier work; untouched.)

## 13. Change logs
**None created this sprint.** (6 pre-existing `OA_Enrichment_Change_Log__c` rows from the Sprint-16 pilot; untouched.)

## 14. Rollback status
**N/A** — no writes, nothing to roll back. Rollback service verified present and remains proven from Sprint 16.

## 15. Monitoring status (Track H)
All four telemetry objects are live and queryable (counts in §8). **Dashboards are NOT deployed** — they are a build-package (`MONITORING_DASHBOARDS.md`), deliberately deferred to the go-live window. **Next deployment step:** create report folder "OA Enrichment Ops" + custom report types, then reports R1–R10, then the 2 dashboards (Executive + Platform Health), then wire report subscriptions per `OPERATIONAL_ALERTS.md`. No code required.

## 16. Commit hash
- Merge (fast-forward): **`59f9df0`** on `main` (= Sprint 17 tip), pushed to origin.
- Sprint 19 documentation + prepared credentials commit: **see git log** (committed with explicit paths; recorded in memory).

## 17. Remaining blockers
**To run the 25-Lead preview/live pilot, three production changes are required (all RED — need explicit approval):**
1. **Deploy the Sprint 17 execution layer to production** — `OA_EnrichmentOrchestrator`, `OA_EnrichmentQueueable`, `OA_ProposalAdapter` are on `main` but **count = 0 in the org** (only ever check-only validated). Deploy them dormant.
2. **Enable the USASpending connector** — set `OA_Connector_Registry__mdt.USASpending.Enabled__c = true` (CMDT deploy). Without this the runner returns "Skipped".
3. **Activate a fill-empty write policy** for USASpending (CMDT deploy) — required for the *commit* pass only; the preview (commitWrites=false) needs just #1 + #2.

**Other standing blockers (not required for this pilot):** least-privilege runtime user (still `oauser`/MAD — top risk); Census/SEC NC deploy; SAM endpoint→prod + principal access + key confirmation.

## 18. Next recommended step
Authorize the **minimal preview path**: deploy the 3 orchestrator classes dormant → enable USASpending only → run `OA_EnrichmentQueueable(the 25 Ids, 'USASPENDING', ruleset, false)` in **preview (no writes)** → review proposals/telemetry → then decide on the commit pass. All reversible; connectors return to disabled afterward.

---

## Direct answers
1. **Is Sprint 17 now merged into main?** — **Yes**, fast-forward, validated, pushed (`main = 59f9df0`).
2. **Which connectors are live-ready?** — **USASpending** (proven, HTTP 200) and **IRS** (no callout needed). Census/SEC need their NC deployed; SAM needs principal access + prod endpoint + key.
3. **Did the 25-Lead pilot run?** — **No.** Blocked by the un-deployed execution layer + disabled connector (§17). 25 Leads are selected and ready.
4. **Did it write safely?** — **N/A** — nothing was written; platform stayed dormant.
5. **Ready for a 100-Lead pilot?** — **No.** The 25-Lead preview must run clean first.
6. **Ready for scheduled enrichment?** — **No.** Requires the least-privilege runtime user + a passing 25→100 pilot + monitoring wired.
7. **Can Opportunity Intelligence begin after this?** — **No — one more operational sprint first.** Run the 25-Lead preview + live pilot (Sprint 20) to prove real-data enrichment end-to-end; only then consider Program 2.

## Definition of Done — met
Sprint 17 merged ✓ · connector credential readiness verified live ✓ · one live-ready connector tested through the production path (USASpending 200 OK) ✓ · 25-Lead pilot has a documented, precise blocker with Leads pre-selected ✓ · repo clean and changes backed up ✓.
