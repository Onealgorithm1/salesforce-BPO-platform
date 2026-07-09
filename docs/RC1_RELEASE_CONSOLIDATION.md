# RC1 Release Consolidation Program — Lead Enrichment RC1 + Lead Acquisition RC1

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-live-pilot` (PR #49)
**Mode:** consolidation + certification + documentation. **No new functionality · no new epics · no automation · no scheduling · no merge.**
**Source of truth:** live production org + read-only runtime + repository dry-merge checks.

---

## Executive Summary
Both releases are **clean-mergeable to `main` with zero conflicts**, and the two epics **share no files** — so the **minimum path to RC1 is two independent squash merges**. The Lead Acquisition core (6 services + connectors + object) is **already deployed dormant in production**; `main` is *behind* prod for 6 classes, so merging is **source catching up to prod (near-zero runtime risk)**. **Lead Acquisition RC1 and Lead Enrichment RC1 can both be certified for supervised operation now**, gated only on a bounded set of **pre-volume** conditions (least-privilege runtime user, SAM permission-set consolidation, credential hygiene, matching rules). Nothing blocks the merge itself. **Overall: 🟢 PASS with 🟡 WARN volume conditions.**

---

## Phase 1 — PR Consolidation

### Live merge facts
- `main` HEAD = *"Merge PR #24: Opportunity Intelligence Phase 2 — SAM.gov Opportunities connector"*.
- **Already on `main`:** `OA_Discovered_Organization__c` (object + fields), `OA_SAM_Connector`, `OA_ConnectorRunner`, `OA_USASpending_Connector`, `OA_SEC_Connector`.
- **RC1 acquisition delta (tip vs main) = only 6 core classes (+6 tests) + SAM NC endpoint line + 1 report type + docs** (51 files, +3,374): `OA_CandidateDiscovery`, `OA_CandidateDiscoveryService`, `OA_CandidateDiscoveryQueueable`, `OA_IdentityResolution`, `OA_SourceFusion`, `OA_LeadCompleteness`.
- **Dry-merge (read-only `git merge-tree`):** acquisition tip → main = **0 conflicts**; enrichment tip (#32) → main = **0 conflicts** (54 files, +2,880).
- **Cross-epic file overlap = NONE** (`comm -12` empty).
- **gh mergeable:** #32, #33, #41, #45, #48, #49 all `MERGEABLE / CLEAN`.

### Dependency graph (both linear stacks)
```
main
 ├── Lead Enrichment RC1 train (independent):
 │     #25 → #26 → #27 → #28 → #29 → #30 → #31(analytics) → #32(RC1 pkg = TIP)
 └── Lead Acquisition RC1 train (base=main):
       #33 → #34 → #35 → #36 → #37 → #38 → #39 → #40 → #41 → #42 →
       #43 → #44 → #45 → #46 → #47 → #48 → #49(SAM pilot+expansion+readiness = TIP)
```
Each arrow = "based on"; each TIP contains the cumulative diff of its whole train.

### Superseded / duplicate / overlap
| Item | Status |
|---|---|
| #43 (Phase 10), #44 (Phase 11) | **Superseded** by Phase 18/19 release docs |
| #46 (SAM readiness), #48 (SAM Phase 16 STOPPED) | **Superseded** by the successful SAM resolution (Phase 17b, in #49) |
| #36 (framework design) | Partly **superseded** by shipped code (#37–#42) |
| #25–#31 | **Rolled up** into #32 (RC1 package) |
| Documentation overlap | SAM readiness §1–§9 historical; §10–§11 current — one file, no duplication |
| Metadata overlap | **None across epics**; within acquisition the object/connectors are already on main (stack only adds services) |
| Conflict risk | **LOW/none** — both tips dry-merge clean; additive-only; no shared files |

### Minimum merges to reach RC1 → **2**
1. **Squash-merge Enrichment RC1 tip (#32)** → `main` (retarget base #32→main; captures #25–#32).
2. **Squash-merge Acquisition RC1 tip (#49)** → `main` (retarget base #49→main; captures #33–#49).
Then close the 22 intermediate PRs (#25–#31, #33–#48) as **rolled-up** (not merged individually). Order is free (independent); recommend **enrichment first** by convention. No history rewrite; branches preserved.

---

## Phase 2 — RC1 Release Package

### Production metadata (RC1 = source catch-up; prod already has the runtime)
- **Acquisition (net-new to main):** 6 Apex classes + 6 tests; `OA_SAM` NamedCredential endpoint (`api.sam.gov`); `OA_Discovered_Organizations` report type. (Object/connectors/permsets already on main & prod.)
- **Enrichment:** RC1 analytics package (report types/reports/dashboards, dormant) + certification docs.

### Deployment order
1. **Enrichment RC1** merge → (already largely deployed; analytics dormant) → validate.
2. **Acquisition RC1** merge → (6 classes already in prod; NC endpoint already deployed) → validate.
> No new deploy is strictly required to production — the merge reconciles `main` to the already-deployed prod state. Any re-deploy is idempotent (dormant code, connectors `Enabled__c=false`).

### Rollback plan
- **Source:** `git revert` the squash-merge commit on `main` (no force-push); branches remain intact.
- **Runtime:** connectors stay `Enabled__c=false` (nothing to disable); no schedules to cancel. Pilot candidate fusions are reversible (fill-empty only touched previously-null fields; delete/clear by captured Ids). No Lead/Account writes exist to unwind.
- **Permission:** unassign `OA_SAM_Temp_Principal` to instantly re-gate SAM callouts.

### Validation plan (post-merge, read-only)
- `main == origin/main`; both squash commits present.
- Org ID `00Dbn00000plgUfEAI`; candidates 6; Leads 13,301; Accounts 1 (unchanged).
- Acquisition async jobs = 0; acquisition schedules = 0; all connectors `Enabled__c=false`.
- Apex: 16 acquisition classes present; tests green in the validating deploy.

### Smoke tests (read-only, 0 DML)
- **SAM:** `GET /entity-information/v3/entities?ueiSAM=YA8LJBJCND19` → **HTTP 200** + parse (UEI/CAGE/address/website).
- **USASpending:** `run('USASpending','Aerospace',false,3)` → HTTP 200, parsed>0, DML=0.
- **SEC:** `run('SEC','0000101829',false,3)` → HTTP 200, `wouldInsert≥0`, DML=0.

### Regression plan
- Confirm protected automations untouched (EDWOSB drip/follow-up, Reply Detection, EmailSender, enrichment writeback) — 12 pre-existing CronTriggers all `WAITING`, none acquisition.
- Confirm no auto-Lead creation path exists; candidates remain `Needs Review`.
- Run the deployed Apex test suite (acquisition classes ~90–100% cov) in the validating deploy.

---

## Phase 3 — Pre-Volume Hardening (implementation plans; not executed)
| Item | Plan (all 🔴; execute only on approval) |
|---|---|
| **Least-privilege runtime user** | Provision a dedicated integration user (a spare license) with only the acquisition permsets; move pilots off `oauser`/MAD; re-test SAM smoke as that user. Removes the top standing risk. |
| **`OA_SAM_Temp_Principal` consolidation** | Move the EC principal access (`ExternalCredentialParameter`) onto `OA_SAM_Connector` (metadata `externalCredentialPrincipalAccesses`); assign `OA_SAM_Connector` to the runtime user; verify SAM 200; then unassign + retire `OA_SAM_Temp_Principal`. |
| **`OA_SAM_Connector` finalization** | Ensure it carries staging CRUD **+** EC principal access; document as the permanent SAM permset. |
| **Matching Rules** | Define org Matching Rules on `OA_Discovered_Organization__c` (UEI, CAGE, name+state) to complement the Apex resolver; activate in a sandbox first. |
| **Duplicate Rules** | Add Duplicate Rules mapping candidates↔Leads/Accounts (alert, not block) to reinforce review-before-Lead. |
| **Review dashboards** | Deploy candidate KPIs (by source, by status, completeness bands, fusion count) — extends RC1 analytics (two-phase report-type→reports→dashboard). Operational, not engine. |
| **Monitoring** | Alerts on `OA_Connector_Run__c` httpErrors/parseErrors + review-queue aging; no scheduler required for supervised mode. |

---

## Phase 4 — Technical Debt Register
| Item | Class | Note |
|---|---|---|
| NAICS mapping (E2) | **Engineering (optional)** | externally blocked; SAM sections omit NAICS |
| Candidate dashboards (E4) | **Operations** | metadata deploy; not engine code |
| `OA_SAM_Connector` permset consolidation | **Configuration** | move EC grant + staging CRUD |
| Least-privilege runtime user | **Administration** | replace `oauser`/MAD |
| Retire `OA_SAM_Temp_Principal` | **Administration** | after consolidation |
| Migrate raw `X-Api-Key` header → `ApiKey` param | **Configuration** | secret hygiene |
| Matching/Duplicate rules | **Configuration** | org rules currently empty |
| PR merges + branch retirement | **Administration** | consolidation |
| Connector enablement / cadence | **Activation (🔴)** | gated |
| Additional sources, UEI↔CIK crosswalk, field-precedence fusion | **Future** | enhancements |
| Legacy dead code (`OA_IConnector`, `OA_USASpendingClient`, unused `OA_SAM_Opportunities`, incomplete IRS, StateRegistry template) | **Engineering (cleanup, separate PR)** | out of scope this sprint |

**Engineering backlog after pruning:** only (a) optional NAICS/E2 and (b) a separate legacy dead-code cleanup PR. Everything else is configuration/administration/operations/activation.

---

## Phase 5 — RC1 Certification (definitive)
- **Can Lead Acquisition RC1 be certified?** **YES — for supervised operation.** Core engine complete, deployed dormant, tested; tip dry-merges clean (0 conflicts); governance intact (review-before-Lead, no automation, audit/provenance). Conditions apply before *volume/automation* (Phase 3).
- **Can Lead Enrichment RC1 be certified?** **YES.** Tip dry-merges clean (0 conflicts); already prod-certified v1.2; #25–#32 is the RC1 doc/analytics packaging (dormant analytics).
- **Can they be merged independently?** **YES.** Zero shared files; both clean vs `main`; no cross-dependency.
- **Should they be merged together?** **Merge in one release window but as two distinct squash commits** (never mix epics in one merge, per governance). Order is free; enrichment-first by convention.
- **What risks remain?** Pre-volume only: least-privilege runtime user (top risk), SAM temp permset + raw header, empty matching/duplicate rules. Source↔prod drift is *resolved* by the merge. Deep-stack hygiene = close 22 rolled-up PRs.

---

## Phase 6 — Executive Release Report

**Architecture summary:** connector (`OA_IEnrichmentConnector`) → `OA_ConnectorRunner`/`OA_CandidateDiscovery` driver → `OA_IdentityResolution` (bulk-safe cross-identifier match) → `OA_SourceFusion` (fill-empty + provenance) → `OA_LeadCompleteness` (0–100) → `OA_Discovered_Organization__c` candidate (Needs Review) → human approval → Lead. Async via `OA_CandidateDiscoveryQueueable` (callout spacing, no scheduler). Registry-driven (`OA_Connector_Registry__mdt`); all connectors dormant.

**Merge plan:** 2 squash merges (enrichment #32 → main; acquisition #49 → main); close #25–#31 & #33–#48 as rolled-up; tag `lead-enrichment-rc1` and `lead-acquisition-rc1`.

**Risk register:**
| Risk | Likelihood | Impact | Class | Mitigation |
|---|---|---|---|---|
| Runtime user = admin/MAD | High (standing) | High | Before volume/automation | Least-priv user |
| SAM temp permset + raw header | Medium | Medium | Before volume | Consolidate + migrate |
| Empty Matching/Duplicate rules | Medium | Medium | Before volume | Add org rules |
| Merge conflict | **None observed** | Low | — | Dry-merge clean; re-check at merge time |
| Unintended activation | Low | High | Governance | Connectors stay `Enabled__c=false`; no schedules |

**Technical debt register:** see Phase 4.

**Production readiness:** engine deployed dormant; runtime clean (0 acq jobs/schedules); no secrets in repo; audit/provenance intact; review-before-Lead preserved.

**Release score (from Phase 19):** Business 75 · Engineering 90 · Security 70 · Operational 60 · Governance 90 · Scalability 75 · Deployment 65 (→ **80+ once merged**, drift resolved) · Support 55 → **overall ≈72–75/100** = **RC1 for supervised operation**.

**PASS / WARN / FAIL → 🟢 PASS** (with 🟡 WARN volume conditions). No production safety violation; no Leads/Accounts modified; no automation/schedules; no merge performed.

**Definition of Done:** Engineering ✅ (optional NAICS + separate dead-code PR) · Configuration (permset/rules/hygiene) · Administration (runtime user/merges/retire temp) · Operations (dashboards/monitoring/staffing) · Activation 🔴 (enablement/cadence) · Future (sources/crosswalk/fusion precedence).

**Next program recommendation:** execute **pre-volume hardening** → the **2-merge RC1 consolidation** (tag both RC1s) → resume **supervised USASpending expansion** (Phase 18 runbook). Only after volume is proven and hardening lands should Opportunity Intelligence (ADR-015) begin as a separate, gated program. **Do not** enable automation/scheduling or merge until approved.
