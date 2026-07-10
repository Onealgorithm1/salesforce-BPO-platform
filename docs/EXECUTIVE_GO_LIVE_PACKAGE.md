# Executive Go-Live Authority & Operational Execution Plan — Program 025B

**Org:** 00Dbn00000plgUfEAI (authoritative) · **Mode:** Executive Readiness · **Read-only. No code, no deploy, no merge, no activation.**
**Verdict: WARN** — activatable after a short, defined sequence. **No new engineering recommended.**

---

## 1. Executive Summary

**The one question:** *What remains before One Algorithm runs this as its daily Business Development Operating System?*

**Answer:** Not engineering (it is essentially complete). What remains is **five operational steps, in order** — (1) merge PR #85 so `main` == production, (2) run all tests to persist coverage, (3) provision a **least-privilege runtime user** to retire the admin/Modify-All-Data dependency, (4) deploy the operational dashboards, (5) approve **scheduling** of Grants.gov + Lead Enrichment. After those, **One Algorithm can operate daily on Grants.gov procurement + Lead Enrichment.** SAM.gov and Microsoft Graph email intake are **deferred fast-follows** (SAM needs its connector deployed; Graph needs an app-only credential) — neither should be built before the platform is operating.

Baseline verified live (unchanged since 025A): PR #85/#86/#87/#88 **all OPEN**; `main` = `dbf8d12` (PR #24) ≠ production; no activation; runtime = `oauser` (System Admin / Modify All Data).

---

## 2. Operational Readiness Matrix (Phase 1) — live-evidence classification

| Subsystem | State | Evidence |
|---|---|---|
| Review Queue | **LIVE** | `OA_Opportunity_Signal__c` = 18 staged (Pending) |
| AI Gateway | **LIVE** | `OA_AI_Request_Log__c` = 17 real calls logged |
| Grants.gov | **PRODUCTION READY** (manual) | Remote Site `OA_GrantsGov` active → `api.grants.gov`; `grantsGov()` deployed + piloted |
| USASpending | **PRODUCTION READY** | `OA_USASpendingEnrichment` deployed; `OA_USASpending` NC live |
| Lead Enrichment | **PILOT READY** | v1.2 deployed; blocked from production by runtime user |
| Compliance | **PILOT READY** | `OA_ComplianceScreen` deployed; screened 18 signals |
| Qualification | **PILOT READY** | `OA_OpportunityQualification` deployed |
| Investment Intelligence | **PILOT READY** | `OA_PursuitInvestment` deployed |
| Evidence Intelligence | **PILOT READY** | `OA_EvidenceCitation`/`OA_DocumentIntelligence`; 2 evidence rows |
| Document Intelligence | **PILOT READY** (text only) | binary → Manual Review (no OCR) |
| Opportunity Intelligence | **VALIDATED (build)** | deployed; org coverage refresh needed |
| Knowledge Foundation | **BUILT** | `OA_KnowledgeIntelligence` + Company Profiles |
| Partner Intelligence | **BUILT** | deployed; partner capability data incomplete |
| Runtime Monitoring | **BUILT (data only)** | logs flow (enrichment change-log 478); **no alerts** |
| Dashboards | **BUILT (partial)** | 4 campaign/BPO-ops dashboards live; no procurement/runtime dashboards |
| Microsoft Graph | **NOT BUILT** (designed) | no Apex class, no app-only credential |
| SAM.gov | **NOT BUILT** (in prod) | acquisition class has only `grantsGov()`; no SAM connector deployed |

*Nothing is "LIVE" in the autonomous sense — everything is dormant/manual pending activation. "PILOT READY" = deployed + governed, awaiting the activation sequence.*

## 3. Responsibility Matrix (Phase 2)

| Task | Claude | Louis | Approval | Credential | Prod Change | Merge |
|---|---|---|---|---|---|---|
| Merge PR #85 | — | ✅ | ✅ | — | — | ✅ |
| Run All Tests (persist coverage) | ✅ | — | — | — | — (compute only) | — |
| Post-merge validation (read-only) | ✅ | — | — | — | — | — |
| Build dashboards (source) | ✅ | — | — | — | — | — |
| Deploy dashboards to prod | ✅ prep | ✅ | ✅ | — | ✅ | — |
| Provision least-priv runtime user + license | — | ✅ | ✅ | — | ✅ | — |
| Assign runtime permission-set group | ✅ prep | ✅ | ✅ | — | ✅ | — |
| Schedule Grants.gov + enrichment jobs | ✅ prep | ✅ | ✅ | — | ✅ | — |
| Enter data.gov / Graph credentials | — | ✅ | ✅ | ✅ | ✅ | — |
| Run Grants.gov / enrichment pilots | ✅ | ✅ | ✅ | — | (data only) | — |
| Close superseded PRs #25–83 | ✅ prep | ✅ | ✅ | — | — | — |

## 4. Activation Blockers (Phase 3)

| # | Blocker | Category | Owner | Effort | Dependency | ETA |
|---|---|---|---|---|---|---|
| 1 | PR #85 unmerged (`main` ≠ prod) | Governance | Louis | minutes | — | Day 0 |
| 2 | Org coverage ~0 (75% deploy gate) | Engineering | Claude | ~1 hr (Run All Tests) | #85 merged | Day 1 |
| 3 | Runtime = System Admin / MAD | **Security (highest)** | Louis | ~1 day (user+license) | — | Week 1–2 |
| 4 | No least-priv PSG assigned | Security | Louis (Claude preps) | hours | #3 | Week 2 |
| 5 | No procurement/runtime dashboards | Operations | Claude+Louis | ~1 day | #85 | Week 1 |
| 6 | No monitoring alerts/subscriptions | Operations | Claude+Louis | hours | dashboards | Week 1–2 |
| 7 | Scheduling not enabled | Operations | Louis | minutes | #3, #5 | Week 2–3 |
| 8 | data.gov key + `OA_SAM_Opportunities` NC | Credentials | Louis | days | — | fast-follow |
| 9 | **SAM connector not deployed** | Engineering | Louis decision | ~1 sprint | #8 | fast-follow (defer) |
| 10 | Graph app-only credential + class | Credentials/Eng | Louis | ~1 sprint | Azure | fast-follow (defer) |
| 11 | Partner capability data incomplete | Business | Louis/team | ongoing | — | continuous |

## 5. Go-Live Sequence (Phase 4)

| Step | Action | Expected result | Validation | Rollback | Gate |
|---|---|---|---|---|---|
| 1 | **Merge PR #85** | `main` == production | `git log` merge commit | revert merge | **Louis (RED)** |
| 2 | Close superseded PRs #25–83 (branches preserved) | PR queue clean | `gh pr list` | reopen | Louis |
| 3 | **Run All Tests** in prod | coverage persisted ≥75% | coverage report | n/a (read) | Claude |
| 4 | Build + deploy 3 dashboards (procurement/connector/runtime) | ops visibility | dashboards render | delete dashboards | Louis (deploy) |
| 5 | Provision least-priv **OA Runtime** user + assign PSG | no-MAD runtime | login + FLS canary on 1 record | keep admin runtime | Louis (RED) |
| 6 | Manual **Grants.gov pilot** (≤10 signals) | signals → screened → qualified → invested → Pending | 0 Opportunities | delete signals | Louis approves run |
| 7 | Manual **Lead Enrichment pilot** (≤10 leads) | enriched, reviewer-gated | 0 unreviewed writes | writeback rollback | Louis approves run |
| 8 | Schedule Grants.gov + enrichment under runtime user | autonomous ingest/enrich | job success ≥95% | unschedule | Louis (RED) |
| 9 | Add monitoring alerts/subscriptions | failure visibility | test alert | remove | Louis |
| — | *(fast-follow)* data.gov key → SAM connector deploy → SAM pilot | SAM opportunities | alpha 2xx + pilot | dormant | Louis (RED) |
| — | *(fast-follow)* Azure Graph app-only → cloud email intake | PC-off intake | poll 2xx | disable | Louis (RED) |

## 6. Business Readiness (Phase 5) — after Steps 1–8

| Can One Algorithm immediately… | Answer | Why |
|---|---|---|
| Discover opportunities | **YES (Grants.gov)** / SAM: no | SAM connector not deployed |
| Qualify opportunities | **YES** | `OA_OpportunityQualification` live |
| Determine go/no-go | **YES** | `OA_ComplianceScreen` live |
| Identify partners | **PARTIAL** | engine live; partner capability data incomplete |
| Enrich leads | **YES** (post least-priv) | v1.2 + reviewer-gated writeback |
| Support campaigns | **YES (already live)** | EDWOSB drip + follow-up running |
| Schedule meetings | **YES (already live)** | booking pollers active |
| Measure pipeline | **PARTIAL** | campaign dashboards live; procurement funnel dashboard = Step 4 |

## 7. 30-Day Operating Plan (Phase 6)

**Daily:** review the opportunity queue (screened/qualified/invested), promote GO items to Opportunity (human), review enrichment writeback proposals, check connector-health + runtime dashboards.
**Weekly:** pipeline review (pursued vs passed), AI cost review (`OA_AI_Request_Log__c`), exception review (`OA_Enrichment_Exception__c`), governance check (0 auto-Opps, 0 unreviewed writes).
**Monthly:** KPI review; decide SAM.gov/Graph fast-follow based on demand; partner data collection progress.
**KPIs:** opportunities ingested/week; % evidence-backed; qualification GO-rate; leads enriched; review-queue latency; job success ≥95%; AI cost within budget; **governance violations = 0**.
**Success criteria:** 30 days operating, queue flowing daily, decisions evidence-backed, 0 governance violations, least-privilege enforced.

## 8. Executive Scorecard (Phase 7)

| Dimension | Status | Note |
|---|---|---|
| Engineering | 🟡 Yellow | complete except SAM connector + coverage refresh |
| Repository | 🔴 Red | `main` ≠ production; #85 unmerged; ~61 PRs open |
| Security | 🔴 Red | runtime = Modify All Data; no least-priv user |
| Operations | 🟡 Yellow | dashboards partial; no scheduling |
| Monitoring | 🟡 Yellow | telemetry yes; alerts no |
| Business Readiness | 🟡 Yellow | Grants + enrichment ready; SAM/Graph not |
| Runtime | 🔴 Red | admin runtime; cloud Graph not built |

## 9. Verdict — **WARN**
Evidence-backed. The platform is **not live today** but is **activatable via a short, defined sequence** with **no new engineering** for the primary paths (Grants.gov + Lead Enrichment). Reds are operational/governance (merge, least-privilege, repository), not capability gaps.

## 10. Exact Louis Actions
1. **Merge PR #85.** 2. Approve closing PRs #25–83. 3. Provision the least-privilege **OA Runtime** user (+ license) and approve its PSG. 4. Approve dashboard deploy + **scheduling** of Grants.gov + enrichment. 5. Approve the two gated pilots. 6. *(Fast-follow, optional)* provide the data.gov key / Azure Graph credential and decide whether to build the SAM connector.

## 11. Exact Claude Actions (GREEN, after merge)
Run all tests (persist coverage) · post-merge validation · build the 3 missing dashboards + monitoring subscriptions (source) · prepare the least-priv PSG + FLS canary · prepare the PR-closure list · execute the gated Grants.gov + enrichment pilots on approval.

## 12. Definition of Business Operational
One Algorithm is **operating the platform** when: `main` == production; a **least-privilege runtime user** (no MAD) runs all automation; **Grants.gov opportunities flow into the review queue on a schedule**, each **auto-screened, qualified, investment-scored, and evidence-backed**; a human reviews the queue **daily** and promotes GO items to Opportunity; **leads are enriched under reviewer-gated writeback**; **pipeline is visible on a dashboard**; and the operation runs **30 days with 0 governance violations**. At that point the Salesforce BPO Platform is One Algorithm's live Business Development Operating System.

---

### Final Executive Decision (Phase 8)
1. **Can Louis operate the platform after the remaining steps?** **Yes** — for Grants.gov procurement and Lead Enrichment, via the Go-Live Sequence, with no new engineering.
2. **Single highest remaining risk:** the **least-privilege runtime user** — automation currently runs as System Admin / Modify All Data; nothing should run unattended until this is replaced.
3. **What should NOT be built next:** nothing. No new features, engines, connectors, or architecture. Specifically, **do not build SAM.gov or Graph until Grants.gov + enrichment are operating**.
4. **90-day focus:** **operate, don't build** — activate Grants.gov + enrichment, run the review queue daily, consolidate the repository (merge #85, close PRs), harden security (least-privilege) and monitoring; treat SAM.gov and Graph as demand-driven fast-follows only.
