# BLO Phase 6 — Production Operations Enablement

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/blo-phase6-production-operations`
**Mode:** engineering · operations · production hardening · runtime validation. **No conversion; no new deploy; no permission assignment; no runtime-user provisioning; no automation; no scheduling; no bulk change; no merge.** All work reversible/read-only + documentation.
**Baseline:** 1 governed Lead (`00QPn000012SyPNMA0`); PR #52/#53/#54 open.

---

## 1. Executive Summary
The BLO Candidate→Lead capability is **operationally ready for repeatable supervised production** — the missing pieces are the two gated admin enablers, not engineering. This sprint delivers the **operations runbook** (daily/weekly/monthly + alert thresholds + failure/rollback procedures), a **reviewer-workflow production standard** (persisted-field UI for humans; service/map for future automation), **dashboard recommendations reusing existing reports**, and a **2→10 batch readiness matrix**. Governance is intact: human approval, auditability, rollback, monitoring, Lead quality, duplicate protection, least-privilege design. **No production changes.** **Verdict: 🟢 PASS** (gated only on permset assignment + runtime-user provisioning).

## 2. Operational Baseline (Phase 0 — live)
| Item | State |
|---|---|
| Org / PRs | `00Dbn00000plgUfEAI` ✅ · PR #52/#53/#54 OPEN |
| BLO deployment | 4 classes + field + permset live (Deploy `0AfPn0000023g4nKAA`) |
| Production Lead | `00QPn000012SyPNMA0` (ORG-00011 → Converted) |
| Monitoring (live) | funnel {Converted 1, Needs Review 5}; audit Create 1 / Rollback 0; **NO UNEXPECTED AUTOMATION**; 0 DML |
| Rollback | `rollbackCreated` available; audit `OA_Enrichment_Change_Log__c` |
| Runtime state | BLO async 0 · schedules 0 |
| Permissions | `OA_BLO_Contact_Access` assignments **0** · `OA_BLO_Runtime` permset **not created** · runtime user **not provisioned** |

## 3. Runtime User Status (Phase 1) — 🔴 GATED (nothing provisioned)
`OA_BLO_Runtime` validated design (CRUD/FLS/Apex/login below). **What remains before provisioning (all 🔴):**
1. Create user `OA_BLO_Runtime` (Salesforce Integration license — BLO has no callouts/UI need).
2. Create permset `OA_BLO_Runtime` — CRUD: candidate R/Edit, Lead C/R/Edit, change-log C/R; FLS: mapped Lead fields + `Reviewed_Contact_Email__c`.
3. Assign `OA_BLO_Runtime` + `OA_BLO_Contact_Access`.
4. Login: IP/hours restricted, MFA, non-human; **no MAD/ViewAll**; no NC/EC/flow access.
5. Audit: all writes → change log; monitor LoginHistory.
Everything design-side is **complete**; provisioning is the only remaining step and is **held for approval**.

## 4. Reviewer Workflow Recommendation (Phase 2)
| Dimension | Persisted-field (UI) | Programmatic service (map) |
|---|---|---|
| UX | standard record edit of `Reviewed_Contact_Email__c` + status | none (API only) |
| Security | FLS-gated (`OA_BLO_Contact_Access`); needs assignment | in-memory; no field FLS |
| Auditability | **field + change log** (who/when persisted on candidate) | Lead + change log only (not on candidate) |
| Failure modes | invalid-email caught by field type; FLS-blocked until assigned | email lost if caller omits; no persisted trace |
| Operational simplicity | simple for humans (click-edit-approve) | simple for code (one call) |
**Production standard: the persisted-field UI path for human reviewers** (auditable, simple, secure once `OA_BLO_Contact_Access` is assigned). **Reserve the service/map path for a future approved automated contact-resolution connector.** Both enforce the Lead validation rule at insert; neither bypasses governance.

## 5. Operations Monitoring Runbook (Phase 3)
**Tool:** `blo_supervised_monitoring.apex` (0-DML; embedded in [BLO_PHASE5_SUPERVISED_BATCH.md](BLO_PHASE5_SUPERVISED_BATCH.md) App. A).
- **Daily:** run the monitor. Verify M5 = NO UNEXPECTED AUTOMATION; M2 rollback count expected; failedAsync24h = 0; review-queue (Needs Review) not growing unbounded.
- **Weekly:** Lead quality (`Leads Missing Email` report; converted-Lead completeness); duplicate review (`Duplicate Leads` report); reviewer backlog (Approved/Lead Ready aging); audit reconciliation (Create count == new Leads).
- **Monthly:** permission-assignment review (least-privilege drift); runtime-user login history; rollback drill; dead-letter/failed-job sweep.
- **Alert thresholds:** any BLO `Failed` async → investigate; unexpected BLO schedule/async → **halt** (governance breach); Lead delta ≠ conversions → reconcile; conversion `FAILED/VALIDATION` spike → check email/dup rule.
- **Failure investigation:** read `RowOutcome.gate/reason` + `OA_Connector_Run__c` + change log; classify (validation/dedup/data/state); fix input, not governance.
- **Rollback procedure:** `OA_LeadCreationService.rollbackCreated(leadIds)` → deletes Leads, resets candidates to Lead Ready, logs `TYPE_ROLLBACK`; verify with the monitor.
- **Operator responsibilities:** reviewer (verify company + supply email + approve); operator (run monitor, reconcile, escalate); admin (permissions, runtime user, rollback authority).

## 6. Dashboard Recommendations (Phase 4 — reuse-first)
| Dashboard need | Reuse existing | New (defer until volume) |
|---|---|---|
| Candidate Funnel | — | candidate-by-status (on `OA_Discovered_Organization__c`); monitor script covers now |
| Lead Creation / Conversion Success | `Lead Inventory`, `Sample: Leads by Status` | BLO-created Leads (Matched_Lead not null) |
| Conversion Failures | — | change-log/`RowOutcome` failures |
| Audit Activity | — | change log Create/Rollback trend |
| Lead Quality | **`Leads Missing Email`**, `Marketable Leads` | converted-Lead completeness |
| Duplicate Review | **`Duplicate Leads`** | candidate MATCH outcomes |
| Reviewer Backlog / Approval Queue | — | Approved/Lead Ready aging |
| Connector Health | `Daily Funnel Trend`, `Funnel Snapshot Source` (OA Executive Analytics) | `OA_Connector_Run__c` errors |
**Recommendation:** reuse `Leads Missing Email`, `Duplicate Leads`, `Lead Inventory`, and the `OA Executive Analytics` funnel reports now; build the candidate-funnel + audit-trend reports (on existing report types, no new object) when batch volume ≥10 justifies a dashboard. Monitoring script covers the gap today.

## 7. Batch Readiness Matrix (Phase 5 — no execution)
| Size | Operational risk | Human workload | Rollback complexity | Monitoring | Go/No-Go |
|---|---|---|---|---|---|
| **2** | Very Low | 2 verified emails | trivial (2 IDs) | monitor script | **GO** (after enablers) |
| **3** | Low | 3 emails | simple (3 IDs) | monitor script | **GO** |
| **5** | Low–Med | 5 emails (2 runs of ≤3) | per-run (≤3 IDs each) | monitor + `Leads Missing Email` | **GO** with a dashboard |
| **10** | Med | 10 emails (throughput bottleneck) | track 10 IDs; batch rollback | **dashboard + review list view required** | **Conditional GO** — build dashboard + staff review first |
**Constant:** human approval + verified email per candidate; UEI/CAGE candidates only until CIK-aware dedup ships; no unattended automation.

## 8. Technical Debt Register
| Item | Priority | Business impact | Effort | Sprint | Owner |
|---|---|---|---|---|---|
| Assign `OA_BLO_Contact_Access` + provision `OA_BLO_Runtime` | **High** | enables reviewer/UI path + removes MAD | S | Phase 7 (gated) | Admin |
| CIK-aware dedup in `OA_LeadCreationService` (SEC candidates) | **Medium** | correct dedup for CIK-only orgs | S | next Eng | Eng |
| Candidate-funnel + audit dashboards | Medium | operator visibility at volume | M | Ops | Ops |
| Audit/rollback best-effort surfacing | Low | observability | S | minor Eng | Eng |
| Repo hygiene (122 branches, 30 open PRs) | Medium | maintainability | M | post-RC1 | Eng/Gov |
| Legacy connector dead-code cleanup | Low | tidiness | M | separate PR | Eng |

## 9. Repository Readiness (Phase 7 — recommend, do NOT merge)
- **Open PRs (30: #25–#54).** Recommended handling after independent review:
  - **Docs/script-only, base main, safe to merge independently:** #51, #53, #54 (certification/hardening/ops docs) + #55 (this).
  - **BLO code PRs:** #50 (BLO engine), #52 (deploy + first conversion) — merge after review; note the metadata is already in prod (source-catch-up).
  - **LA/enrichment stack (#25–#48/#49):** the 2-squash RC1 consolidation (enrichment tip #32 → main; acquisition tip → main).
- **Branches (122):** prune fully-merged after RC1 (owner decision).
- **Docs:** add `docs/README.md` index; banner superseded readiness docs.
- **Do not merge this sprint.**

## 10–14. Components / Validation / Production / Risks / Rollback
- **Components changed:** this doc only. **No Salesforce metadata; no deploy.**
- **Validation:** monitoring script executed live (0 DML); baseline queries read-only.
- **Production changes:** **none** (Leads 13,302, Converted 1, 0 async/schedules, 0 permset assignments — unchanged).
- **Risks:** MAD runtime user [High, gated]; reviewer field/UI path pending FLS [Med, gated]; SEC/CIK dedup [Med]; no dashboards yet [Low, monitor mitigates].
- **Rollback plan (pilot Lead):** `OA_LeadCreationService.rollbackCreated(new List<Id>{'00QPn000012SyPNMA0'})`.

## 15. PASS / WARN / FAIL — 🟢 PASS
Operational readiness for repeatable supervised acquisition demonstrated with human approval, auditability, rollback, monitoring, Lead quality, duplicate protection, operational governance, and least-privilege design preserved. **No unattended automation, no scheduled acquisition, no production changes, no merge.**

## 16–17. Commit / PR
See closeout. **PR #52/#53/#54 remain OPEN; none merged.**

## 18. Exact Next Engineering Sprint
**BLO Phase 7 — Supervised Batch Go-Live (gated):** on approval, 🔴 provision/assign `OA_BLO_Runtime` + `OA_BLO_Contact_Access`; reviewers set verified `Reviewed_Contact_Email__c` on **ORG-00012 + ORG-00013** via the UI (persisted-field standard); run one **2-candidate supervised batch** as the runtime user with the monitor before/after and rollback ready. Ship **CIK-aware dedup** before including SEC candidates. No automation, no scheduling, no bulk.
