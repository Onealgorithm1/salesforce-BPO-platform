# Post-Reconciliation Certification, PR Closure Plan & Activation Readiness — Program 024G

**Org:** 00Dbn00000plgUfEAI (source of truth) · **Reconciliation PR:** #85 · **Mode:** Governance
**No changes made. No merge, no deploy, no activation, no PR closures.** · **Verdict: PASS**

---

## 1. Executive Summary

PR #85 (production reconciliation) is verified **MERGE READY**: it is MERGEABLE with a CLEAN merge state, was built from production, and **production has not drifted since the retrieve** (no deploy occurred after validation `0AfPn0000023x2PKAQ`). Merging it makes `main` == production and unblocks the transition from engineering to runtime activation. This package certifies #85, plans closure of the 59 superseded program PRs (branches preserved), gives an executable post-merge validation script, scopes the connector-duplicate cleanup, and assesses activation readiness for Procurement and Lead Enrichment. **Nothing here changes metadata or production.** The single gating action is Louis's approval to merge #85.

---

## 2. PR #85 Verification (Phase 0)

| Field | Value |
|---|---|
| URL | https://github.com/Onealgorithm1/salesforce-BPO-platform/pull/85 |
| Branch → base | `chore/production-reconciliation` → `main` |
| Commit | `0685d54` |
| State | OPEN · **MERGEABLE · mergeState CLEAN** |
| Diff | **551 files** · +11,788 / −1,911 |
| Files added / modified / deleted | 239 / 286 / 25 (12 `.cls` + 12 `.cls-meta` + 1 permset; metas rename-detected) |
| Validation ID | **`0AfPn0000023x2PKAQ`** |
| Validation result | **Succeeded — 678/678 components, 0 component errors** |
| Tests / failures | **354 / 0** |
| Warnings | None material (CRLF line-ending notices only) |
| Unresolved conflicts | **None** (mergeState CLEAN) |
| Risky metadata changes | None: no NamedCredential/ExternalCredential/secret changes; no trigger/flow/schedule changes; removals are reverse-drift **absent from production** |

**Does #85 still match production?** **Yes.** The most recent `DeployRequest` in the org is our own validation (`0AfPn0000023x2PKAQ`, 23:47Z); no code deploy followed it. No drift.

## 3. Merge Readiness (Phase 1) — **MERGE READY**

| Criterion | Status | Evidence |
|---|---|---|
| Metadata parity | ✅ | Retrieved from prod; validation 678/678, 0 errors |
| Test coverage | ✅ | 354 local tests pass, 0 failures |
| Deleted files | ✅ | 25 reverse-drift files, documented, confirmed absent from prod |
| Protected metadata | ✅ untouched | No NC/EC/secret/trigger/flow/schedule changes |
| Named/External Credentials | ✅ untouched | Retrieve scope excluded them |
| Scheduled jobs | ✅ untouched | Source-only; 7 live jobs unaffected |
| Permission sets | ✅ | 25 reconciled to prod versions; 1 orphaned removed |
| Production-only changes | ✅ captured | 41 new classes + field/FLS drift now on branch |
| main-only (reverse drift) | ✅ removed | 12 classes + 1 permset (documented) |
| Rollback path | ✅ | Abandon branch; `main` (`dbf8d12`) + prod unchanged |

**Verdict: MERGE READY.** No blockers. Merge is a source-control operation (no deploy); production already contains this exact source.

## 4. Open PR Closure Plan (Phase 2) — **61 open PRs (#25–#85). Do not close — plan only.**

**Principle:** #85 was retrieved from production, so **all code from #25–#83 is already in #85**. Their **docs** are on their branches (not in #85). **All branches are preserved** (governance). Recommend closing superseded PRs *after* #85 merges, and preserving each program's `docs/` via one docs-consolidation commit (optional, since branches retain them).

| PR range | Chain / Program | Code in #85? | Recommendation |
|---|---|---|---|
| **#25–#32** | Lead Enrichment readiness/ops/analytics | ✅ (in prod) | **CLOSE AS SUPERSEDED** · preserve branch + docs |
| **#33–#49** | Lead Acquisition (candidate→SAM) | ✅ | **CLOSE AS SUPERSEDED** · preserve branch + docs |
| **#50–#57** | Business Lifecycle Orchestration | ✅ | **CLOSE AS SUPERSEDED** · preserve branch + docs |
| **#58–#61** | Campaign→Meeting→Opportunity / Meeting Resolution | ✅ | **REVIEW BEFORE CLOSING** (verify no meeting-attribution activation intent) then close superseded |
| **#62–#64** | Lead Conversion / Opportunity Ops / BD Operations | ✅ | **REVIEW BEFORE CLOSING** (first-Opportunity logic) then close superseded |
| **#65–#69** | Enterprise AI Platform / Gateway (018/019) | ✅ | **CLOSE AS SUPERSEDED** · preserve branch + docs |
| **#70** | 020 Opportunity Intelligence | ✅ | **CLOSE AS SUPERSEDED** |
| **#71** | 021 Knowledge Foundation | ✅ | **CLOSE AS SUPERSEDED** |
| **#72–#73** | 022/023 Acquisition & Compliance | ✅ | **CLOSE AS SUPERSEDED** |
| **#74–#78** | 023A–E certification (docs only) | docs only | **CLOSE AS SUPERSEDED** · preserve docs (research value) |
| **#79–#83** | 024–024D BD-OS arc | ✅ | **CLOSE AS SUPERSEDED** · preserve docs |
| **#84** | 024E Consolidation Certification (docs) | ❌ (doc not in #85) | **MERGE SEPARATELY** (docs-only) or fold doc into main |
| **#85** | 024F Production Reconciliation | — | **MERGE (this is the target)** |

**No PR recommended for ABANDON** — all represent real, deployed work. Zero branch deletions.

## 5. Post-Merge Validation Plan (Phase 3) — exact commands (run *after* Louis merges #85)

```bash
O=oauser@pboedition.com
# 1. Sync + confirm branch
git checkout main && git pull origin main
git log --oneline -1                      # expect the #85 merge commit
# 2. Source vs org parity (should report "No differences" for retrieved types)
sf project retrieve preview -o $O -x manifest/recon_package.xml   # or:
sf project deploy start --dry-run -o $O -l RunLocalTests \
  -d force-app/main/default/classes -d force-app/main/default/objects \
  -d force-app/main/default/permissionsets     # expect 0 component errors, tests pass
# 3. Metadata inventory parity
sf data query --use-tooling-api -o $O -r csv -q "SELECT Name FROM ApexClass WHERE Name LIKE 'OA%'" | wc -l   # expect 164
git ls-tree -r --name-only main -- force-app/main/default/classes | grep -c '\.cls$'                          # expect == org (minus tests delta)
# 4. Live automation unchanged (regression guard)
sf data query -o $O -q "SELECT CronJobDetail.Name,State FROM CronTrigger WHERE State='WAITING' AND CronJobDetail.Name LIKE 'OA%'"   # expect the same 7 jobs
sf data query --use-tooling-api -o $O -q "SELECT Name,Status FROM ApexTrigger WHERE Name LIKE 'OA%'"          # expect OA_UnsubscribeRequestTrigger Active
# 5. Credentials unchanged
sf data query --use-tooling-api -o $O -q "SELECT DeveloperName FROM NamedCredential"    # expect same 13
sf data query --use-tooling-api -o $O -q "SELECT DeveloperName FROM ExternalCredential" # expect same 8
# 6. Permission sets present
sf data query -o $O -q "SELECT Name FROM PermissionSet WHERE Name LIKE 'OA%' AND IsOwnedByProfile=false"     # expect 25
# 7. Regression: no new Opportunities / no CRM writes from consolidation
sf data query -o $O -q "SELECT COUNT() FROM Opportunity"     # expect unchanged (1)
```
All read-only / check-only — **safe for Claude to run without further approval** after merge.

## 6. Connector Cleanup Plan (Phase 4) — scope only, delete nothing

| Item | Assessment | Action (later) |
|---|---|---|
| **Grants.gov** — `OA_FederalOpportunityAcquisition.grantsGov()` | **ACTIVE / production-used** (024) | KEEP |
| **Grants.gov** — `OA_GrantsGov*` (6 classes) | **SUPERSEDED** (already removed from source in #85) | already handled |
| **SAM ×3 families** — `OA_SAM_*` (snake), `OA_SAMConnector/Mapper/Parser/Request` (camel), `OA_SAMOpportunities_*` | `OA_SAMOpportunities_*` removed; **2 remaining generations both in prod** | **REQUIRES FURTHER REVIEW** — identify the one true SAM path before retiring the other |
| **USASpending ×2–3** — `OA_USASpending_*`, `OA_USASpending*`, `OA_USASpendingClient/Connector/Enrichment(Service)` | Multiple in prod; `OA_USASpendingEnrichment` is the 024 path | **REQUIRES FURTHER REVIEW** — keep the enrichment path, retire legacy client/connector after dependency check |
| **Connector framework ×2** — legacy `OA_IConnector`/`OA_ConnectorEngine` vs active `OA_IEnrichmentConnector`/`OA_ConnectorRunner` | Both in prod | **SAFE TO RETIRE LEGACY LATER** after confirming no active references |
| **Staging objects** — `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c` | Early-generation staging | **REQUIRES REVIEW** — verify 0 rows / 0 references, then retire |
| **NamedCredential `OA_GrantsGov`** | On `main`, **not in prod** (orphaned) | **SAFE TO REMOVE LATER** (protected type — explicit approval) |
| **Permsets** `OA_SAM_Temp_Principal`, `OA_SAM_Connector` | Possibly obsolete if SAM consolidated | **REQUIRES REVIEW** before removal |

Cleanup is a **separate sprint** requiring destructive-change approval; nothing deleted here.

## 7. Procurement / Opportunity Acquisition Activation Readiness (Phase 5A)

| Item | Status | Owner | Blocker |
|---|---|---|---|
| Grants.gov connector | **READY** (dormant, live-piloted) | Claude | Scheduling approval only |
| USASpending enrichment | **READY** (NC live) | Claude | — |
| SAM.gov connector | **BLOCKED** | Louis | data.gov key + `OA_SAM_Opportunities` NC/EC (NC absent — verified) |
| MS Graph app-only email intake | **BLOCKED** | Louis | App-only Graph credential (current Graph = local PowerShell WAM only) |
| Scheduled Apex (`OA_FederalAcquisitionScheduler`) | **PARTIAL** | Louis | Exists but not scheduled; enabling = RED approval |
| Monitoring (`OA_AI_Request_Log__c`) | **PARTIAL** | Claude | Logs exist; dashboards not built |
| Dashboards | **PARTIAL** | Claude | Not built (design only) |
| Evidence layer (024C/D) | **READY** | Claude | — |
| Compliance (`OA_ComplianceScreen`) | **READY** | Claude | — |
| Qualification (`OA_OpportunityQualification`) | **READY** | Claude | — |
| Investment intelligence (`OA_PursuitInvestment`) | **READY** | Claude | — |
| Review queue (`OA_Opportunity_Signal__c`) | **READY** | Claude | — |

**Net:** the *intelligence* stack is READY; *ingestion breadth* is blocked on the data.gov key and the Graph app-only credential. Grants.gov can pilot today.

## 8. Lead Enrichment Activation Readiness (Phase 5B)

| Item | Status | Owner | Blocker |
|---|---|---|---|
| Enrichment connectors | **READY** (v1.2 certified, maintenance mode) | Claude | — |
| Review queue | **READY** | Claude | — |
| Write-back approval (`OA_LeadWritebackService`) | **READY** (reviewer permset) | Claude | — |
| Monitoring | **PARTIAL** | Claude | Audit logs exist; dashboards partial |
| **Least-privilege runtime user** | **BLOCKED** | Louis | Runs as `oauser` (MAD/admin) — verified; top operational risk |
| Scheduled jobs | **PARTIAL** | Louis | Campaign drip/follow-up live; enrichment batch not scheduled (RED) |
| Audit logging (`OA_Enrichment_Change_Log__c`) | **READY** | Claude | — |

**Net:** functionally READY; **the one real risk before 24/7 automation is the runtime-user privilege** (currently admin/MAD).

## 9. Credentials Checklist (Phase 6) — do not create/expose secrets

| Credential | Needed for | Status | Owner |
|---|---|---|---|
| data.gov API key | SAM.gov ingestion | **MISSING** | Louis |
| `OA_SAM_Opportunities` Named Credential | SAM.gov | **MISSING** (verified absent) | Claude (after key) |
| SAM External Credential (api-key) | SAM.gov | **MISSING** | Claude (after key) |
| MS Graph app-only credential (Azure app reg) | Cloud email intake | **MISSING** | Louis |
| Graph Named Credential (app-only) | Cloud email intake | **MISSING/partial** | Claude (after app reg) |
| Least-privilege runtime user + license | Enrichment/automation | **MISSING** | Louis |
| Permission-set assignments | Runtime access | pending | Louis (RED) |

## 10. Approval Checklist (Phase 6)

| Approval | Gates |
|---|---|
| **Merge PR #85** | `main` == production (THE next action) |
| PR closures #25–#83 | Repository cleanup |
| Scheduled-job enablement | Any autonomous ingestion/enrichment |
| Lead Enrichment activation | 24/7 enrichment |
| Write-back activation | Auto Lead updates |
| Monitoring activation | Dashboards/alerts |
| Credential entry (data.gov, Graph, runtime user) | Ingestion breadth + least-priv |

## 11. Controlled Pilot Plan (Phase 7)

**Procurement pilot (post-merge):**
- Source: **Grants.gov** (public, no credential). Filter: 1–2 capability keywords (e.g., "data analytics", "business process"). Cap: **≤10 signals**. Schedule: **manual run** (no scheduled job). Candidate limit: 10. Review owner: Louis. Rollback: delete pilot signals. Success: signals ingested → screened (Compliance) → qualified → investment-scored → **all Pending, 0 Opportunities**.

**Lead Enrichment pilot (post-merge):**
- Lead population: a **≤10-lead** hand-picked cohort. Cap: 10. Enrichment fields: existing v1.2 set. Review owner: Louis. Write-back rules: **staged/reviewer-gated, no auto-write**. Rollback: `OA_LeadWritebackService` rollback path. Success: enrichment computed + staged for review, **0 unreviewed writes**.

Both: **no automatic Opportunity creation; no automatic Lead write-back without approval.**

## 12. Risks
- Merging #85 is low-risk (parity proven) but is a large diff — review the *deletions* list specifically.
- Closing 59 PRs without first preserving their docs onto `main` would leave docs only on branches (mitigated: branches preserved).
- Activation risks concentrate in two credentials (data.gov, Graph) and the runtime-user privilege.

## 13. Technical Debt
Duplicate connector generations (SAM/USASpending/framework), orphaned `OA_GrantsGov` NC, staging objects, missing dashboards, admin-privilege runtime user, program docs not yet on `main`.

## 14. Verdict — **PASS**
PR #85 verified and MERGE READY; open PRs inventoried with a complete closure plan; post-merge validation plan is executable; connector cleanup scoped; procurement + enrichment readiness assessed; credentials and approvals listed; controlled pilot defined. **No changes made.**

## 15. Exact Commands for Next Step
```bash
# (Louis) approve + merge PR #85 in GitHub UI, or after approval Claude runs:
#   gh pr merge 85 --squash --delete-branch=false      # RED — requires Louis approval
# Then the Post-Merge Validation Plan (§5) — all read-only/check-only, Claude-executable.
```

## 16. Exact Louis Decision Required
**Approve merge of PR #85 to `main`** (source-only; production already contains this exact source; rollback = revert). Optionally pre-authorize: (a) closing #25–#83 as superseded with branches preserved, (b) a docs-consolidation commit preserving program docs onto `main`.

## 17. Exact Next Engineering Program
**024H — Post-Merge Validation & PR Closure Execution:** after Louis merges #85, run the §5 validation, execute the approved PR closures (branches preserved), and preserve program docs onto `main`. Immediately after: **Connector Cleanup** (§6, destructive-approval sprint), then **SAM.gov Activation** (data.gov key) as the first feature unlock.
