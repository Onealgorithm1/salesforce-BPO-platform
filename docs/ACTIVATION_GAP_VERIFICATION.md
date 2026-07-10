# Activation Gap Verification & Operational Go-Live — Program 025A

**Org:** 00Dbn00000plgUfEAI (authoritative) · **Mode:** Independent, evidence-driven verification (read-only)
**Every conclusion below is backed by a live org query. Prior certifications were challenged — two were wrong.**
**Verdict: WARN** · **Can the platform go live today? NO.**

---

## 1. Executive Summary

Independent verification against the live org **corrected two prior claims and surfaced one new blocker**:
- ❌ **SAM.gov is not "credential-blocked" — it needs engineering.** The deployed acquisition class (`OA_FederalOpportunityAcquisition`) contains **only `grantsGov()`**; there is **no SAM-opportunities connector in production** (the `OA_SAMOpportunities_*` classes were removed from `main` by #85 and were never deployed).
- ✅ **Dashboards were understated.** Four BPO/OA dashboards exist and refresh daily (not "one"), though none covers the new procurement-intelligence funnel or connector/runtime health.
- 🚩 **New blocker: org-persisted test coverage is effectively empty** (1 of 108 aggregate rows > 0; every intelligence class shows 0 lines covered). A full **Run All Tests** is required before any production-deploy gate.

Confirmed as previously stated: **PR #85/#86/#87 all OPEN** (main ≠ production); **Microsoft Graph cloud execution does not exist** (no class — DESIGNED only); **runtime = `oauser` System Administrator / Modify All Data** (least-privilege FAIL); **no monitoring subscriptions/alerts**. The platform **cannot go live today**. Grants.gov procurement and Lead Enrichment are genuinely closest to ready.

---

## 2. Baseline Verification (Phase 0) — evidence

| Item | Evidence | State |
|---|---|---|
| PR #85 (reconciliation) | `gh`: OPEN, mergeState CLEAN, not merged | **PENDING MERGE** |
| PR #86 (024G) / #87 (025) | OPEN, not merged | docs, pending |
| `main` HEAD | `dbf8d12` (Merge PR #24) | **≠ production** |
| Production parity | Validation `0AfPn0000023x2PKAQ` (678/678, 354 tests, 0 fail) — but **check-only**, coverage not persisted | ready-to-merge |
| Runtime health | `AsyncApexJob` last 2 days: **Completed only, 0 failed** | healthy |
| Live scheduled jobs | 7 (Artifact/Booking×4/EDWOSB Follow-Up/Drip) — campaign+booking only | no procurement/enrichment job |

## 3. Activation Gap Matrix (Phase 1) — evidence-classified

| Subsystem | Classification | Evidence |
|---|---|---|
| AI Gateway | **READY** | `OA_AI_Gateway` deployed; `OA_AI_Request_Log__c` = 17 rows (live calls logged) |
| Compliance | **IMPLEMENTED, not org-validated** | `OA_ComplianceScreen` deployed; 18 signals screened; **0 persisted coverage** |
| Qualification | **IMPLEMENTED, not org-validated** | `OA_OpportunityQualification` deployed; 0 persisted coverage |
| Investment Intelligence | **IMPLEMENTED, not org-validated** | `OA_PursuitInvestment` deployed; 0 persisted coverage |
| Partner Intelligence | **IMPLEMENTED** | `OA_PartnerIntelligence` deployed; partner capability data incomplete |
| Evidence Intelligence | **PILOTED** | `OA_EvidenceCitation`/`OA_DocumentIntelligence` deployed; `OA_Knowledge_Document__c` = 2 evidence rows |
| Knowledge Foundation | **IMPLEMENTED** | `OA_KnowledgeIntelligence` + Company Profiles deployed |
| Review Queue | **READY** | `OA_Opportunity_Signal__c` = 18 staged (Pending) |
| Document Intelligence | **PILOTED (text only)** | binary → Manual Review (no OCR sidecar) |
| Opportunity Intelligence | **IMPLEMENTED** | `OA_OpportunityIntelligence` deployed |
| Opportunity Acquisition (Grants.gov) | **READY / PILOTED** | Remote Site `OA_GrantsGov` **active** → `api.grants.gov`; `OA_FederalOpportunityAcquisition.grantsGov()` deployed |
| Opportunity Acquisition (SAM.gov) | **BLOCKED — ENGINEERING** | **No SAM connector in prod**; class has only `grantsGov()` |
| Lead Enrichment | **IMPLEMENTED, runtime-blocked** | v1.2 deployed; `OA_Enrichment_Change_Log__c` = 478 rows |

**Note:** "not org-validated" = the code passes in check-only validation, but the org's **persisted** coverage is 0 (see §14) — a deploy-gate risk, not a code defect.

## 4. Microsoft Graph Runtime Audit (Phase 2) — challenged

| Question | Evidence | Answer |
|---|---|---|
| Queueable poller exists? | ApexClass search `%Graph%/%Outlook%/%MailPoll%/%EmailIntake%` → **0 results** | **NO** |
| Server-side cloud execution exists? | No Graph Apex, no Graph Named Credential | **NO** |
| Runs with Louis's PC OFF? | Current Graph = local PowerShell WAM as `lrubino` | **NO** |
| Requires PowerShell / WAM / delegated login? | Yes (local WAM SSO) | **YES** |
| App-only execution exists? | No app-only credential, no NC | **NO** |

**Status: DESIGNED (not implemented).** Cloud email intake is a design only; today it cannot run unattended.

## 5. Least-Privilege Audit (Phase 3) — **FAIL**

Evidence: `User oauser@pboedition.com` → Profile **System Administrator**, `PermissionsModifyAllData = true`. Permission Set Groups in org: only Salesforce-standard (`ScaleCenterUsers`, `SalesWorkspacePSG`) — **no OA runtime PSG**. All automation runs with Modify All Data. **Production cannot safely run unattended. FAIL.**

## 6. Dashboard Audit (Phase 4) — corrected

**Exist (evidence — actively refreshed):**
- `Executive Campaign Analytics` (OA Executive Analytics)
- `BPO Campaign Command Center` (refreshed 2026-07-09)
- `BPO Operations Daily` (refreshed 2026-07-09)
- `BPO Exception Monitor` (refreshed 2026-07-08)

**Absent (evidence — no such dashboard):** Procurement / Business-Development intelligence funnel (signal→qualified→GO→investment), **Connector Health**, **Runtime/AI Health**, dedicated **Compliance** dashboard. Existing dashboards are campaign/BPO-ops-oriented. **Status: PARTIAL** (campaign ops covered; procurement + runtime not).

## 7. Monitoring Audit (Phase 5) — evidence

- **Telemetry EXISTS and flows:** `OA_AI_Request_Log__c` (17), `OA_Enrichment_Change_Log__c` (478), `OA_Connector_Run__c` (18), `OA_Enrichment_Exception__c` (1).
- **Proactive monitoring does NOT exist:** no dashboard/report subscriptions, no failure-notification jobs, no runtime alerts (only the campaign/booking scheduled jobs run). Dashboards refresh **on view**, not on a schedule.
- **Status: PARTIAL** — data captured; **no alerting/subscription layer**.

## 8. Lead Enrichment Readiness (Phase 7)

| Dimension | Evidence | State |
|---|---|---|
| Engineering | v1.2 deployed, `OA_LeadWritebackService` (WITH USER_MODE) | **COMPLETE** |
| Runtime (least-priv) | runs as `oauser`/MAD | **FAIL** |
| Security | FLS bypassed except USER_MODE paths | **WARN** |
| Monitoring | change-log 478 rows; no alerts | **PARTIAL** |
| Org test coverage | 0 persisted on `OA_LeadWritebackService` (0/348) | **REFRESH NEEDED** |
| Pilot ready | yes, reviewer-gated, ≤10 leads | **READY (gated)** |
| Production ready | blocked by runtime user | **NO** |

## 9. Procurement Readiness (Phase 8) — evidence

| Component | State | Evidence |
|---|---|---|
| Grants.gov | **READY** | Remote Site active + `grantsGov()` deployed + piloted |
| USASpending | **READY** | `OA_USASpendingEnrichment` + `OA_USASpending` NC |
| Review Queue / Compliance / Qualification / Investment / Evidence / Opportunity Intelligence | **IMPLEMENTED** | classes deployed; 18 signals; coverage refresh needed |
| **SAM.gov** | **BLOCKED — ENGINEERING + CREDENTIAL** | no connector in prod; no `OA_SAM_Opportunities` NC; no data.gov key |
| Cloud execution | **DESIGNED** | no Graph/scheduled cloud intake |
| Scheduling | **NOT ENABLED** | `OA_FederalAcquisitionScheduler` deployed, not scheduled |
| Monitoring | **PARTIAL** | logs exist; no alerts/dashboards for procurement |

## 10. SAM.gov Readiness (Phase 6) — exact blocker list (corrected)

| Category | Blocker |
|---|---|
| **Engineering** | **No SAM-opportunities connector deployed.** Code exists on branch `feature/sam-opportunities-connector` (`OA_SAMOpportunities_*`), removed from `main` by #85, never in prod. Must be re-scoped/deployed. |
| Credential | data.gov API key (Louis); `OA_SAM_Opportunities` NC + EC absent (only entity `OA_SAM` exists) |
| Configuration | NC endpoint `api.sam.gov`, EC principal access to runtime user |
| Approval | deploy approval + scheduling approval |
| Operational | validation (alpha 2xx) + ≤10 pilot + rollback |

**SAM.gov is the one subsystem where engineering is NOT complete.**

## 11. Go-Live Decision (Phase 9) — **NO**

Blockers by category:
- **Governance:** PR #85 unmerged (`main` ≠ production).
- **Security:** runtime = System Admin / Modify All Data; no least-privilege user/PSG.
- **Engineering:** SAM.gov connector not deployed; **org test coverage ~0 → Run All Tests required before any prod deploy** (75% gate).
- **Credentials:** data.gov key; Graph app-only credential.
- **Operations:** no procurement/connector/runtime dashboards; no monitoring alerts; no scheduled acquisition/enrichment jobs; Graph cloud intake not implemented.
- **Business:** partner capability data incomplete (Partner Intelligence).

## 12. 30-Day Activation Roadmap (Phase 10)

| Week | Owner | Tasks | Dependencies | Rollback | Success |
|---|---|---|---|---|---|
| **1** | Louis + Claude | Merge #85; Claude runs post-merge validation + **Run All Tests** to persist coverage; build procurement + connector-health + runtime-health dashboards | #85 approval | revert merge | main==prod; coverage ≥75%; dashboards live |
| **2** | Louis + Claude | Provision least-priv **OA Runtime** user + PSG; canary FLS test; Grants.gov manual pilot (≤10 signals) | user license | keep admin runtime; delete pilot signals | FLS enforced under runtime user; signals→Pending, 0 Opps |
| **3** | Louis + Claude | Schedule Grants.gov + enrichment under runtime user; add monitoring subscriptions/alerts | week 2 | unschedule | job success ≥95%; alerts firing |
| **4** | Louis + Claude | **SAM.gov engineering** (deploy connector) + data.gov key + NC/EC + alpha validate + ≤10 pilot | data.gov key | dormant connector | SAM signals ingested, reviewed |

## 13. Operational Risks
1. **Least-privilege (highest):** unattended automation as Modify All Data.
2. **Coverage gate:** a production deploy could fail the 75% org coverage requirement until Run All Tests is executed.
3. **SAM.gov mis-scoped as config-only** when it needs engineering (this audit corrects it).
4. Graph cloud intake is PC-dependent until app-only is built.
5. No proactive monitoring — failures visible only on dashboard view.

## 14. Verdict — **WARN** (go-live: NO)
Every conclusion is evidence-backed. Engineering is complete **except SAM.gov opportunities**. The platform is close for **Grants.gov procurement** and **Lead Enrichment**, but is blocked by merge, least-privilege runtime, coverage refresh, credentials, and operational monitoring/dashboards. Not a FAIL (core paths genuinely work); not a PASS (multiple real blockers).

## 15. Exact Louis Decisions
1. **Merge PR #85.** 2. Provision least-privilege **OA Runtime** user (+ license). 3. Obtain **data.gov key** + **Azure Graph app-only** credential. 4. Approve **scheduling**. 5. Decide SAM.gov: **re-scope/deploy the connector** (engineering) or defer.

## 16. Exact Claude Actions (GREEN, post-merge)
- Post-merge validation + **Run All Tests** (persist coverage) — read-only/check.
- Build procurement / connector-health / runtime-health dashboards + monitoring subscriptions (config).
- Draft least-priv PSG + canary FLS test (proposal).
- Scaffold `OA_SAM_Opportunities` NC/EC + connector deployment plan (after key/decision).
- Execute gated Grants.gov / enrichment pilots.

## 17. Definition of Production Ready
`main` == production (#85 merged) · **org coverage ≥75% persisted** · least-privilege runtime user (no MAD) executes all automation · credentials configured per activated source · procurement + runtime dashboards and monitoring alerts live · a 30-day pilot completes with **0 governance violations** (no auto-Opportunity, no unreviewed Lead write, FLS enforced). SAM.gov additionally requires its connector deployed.
