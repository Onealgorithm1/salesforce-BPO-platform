# Production Activation & Operational Readiness — Program 025

**Org:** 00Dbn00000plgUfEAI (operational baseline) · **Baseline PR:** #85 · **Mode:** Operations / Runtime Certification
**No software built. No metadata, deploy, activation, or scheduling changes.**
**Certification Verdict: PASS** · **Production Ready: NOT YET** (gated on the Go-Live Checklist §11)

---

## 1. Executive Summary

Engineering is complete — the intelligence platform (Compliance → Qualification → Investment → Partner → Evidence) is deployed and dormant, and telemetry is already being written (AI request log, enrichment change-log 478 rows, connector-run log). What remains before the platform operates as a Business Development Operating System is **not code — it is five operational gates**: (1) merge PR #85 so `main` == production; (2) provision a **least-privilege runtime user** (today everything runs as `oauser`/admin); (3) obtain **two credentials** (data.gov key, Microsoft Graph app-only); (4) **schedule** the dormant jobs; (5) build **operational dashboards + monitoring** on the log objects that already exist. Each is identified with an owner below. No engineering remains.

---

## 2. Baseline Verification (Phase 0)

| Check | State | Evidence |
|---|---|---|
| **PR #85 merged** | ❌ **OPEN** (MERGEABLE/CLEAN) | `main` still at `dbf8d12` (PR #24) — `main` ≠ production |
| Production parity | ✅ ready via #85 | Validation `0AfPn0000023x2PKAQ` (678/678, 354 tests, 0 fail) |
| Repository health | ⚠️ | 61 open PRs; closure plan ready (024G) |
| Scheduled jobs | ✅ 7 live | Artifact/Booking×4/EDWOSB Follow-Up/Drip — campaign+booking only; **no procurement/enrichment job scheduled** |
| Runtime users | ⚠️ | Runtime = `oauser@pboedition.com` (**System Admin / MAD**) |
| Credentials | ⚠️ | 13 NC / 8 EC present; **data.gov + Graph app-only missing** |
| Dashboards | ⚠️ 1 | "Executive Campaign Analytics" only |
| Reports | ✅ present | Executive Analytics report set (campaign) |
| Monitoring (data) | ✅ flowing | AI log 17, Enrichment Change-Log 478, Connector-Run 18, Enrichment-Exception 1, Signals 18, Evidence 2 |

## 3. Lead Enrichment Readiness (Phase 1)

| Prerequisite | Status | Blocker / owner |
|---|---|---|
| Enrichment connectors (v1.2) | **READY** | Maintenance mode, certified |
| Review queue | **READY** | — |
| Write-back approval (`OA_LeadWritebackService`, WITH USER_MODE) | **READY** | Reviewer permset exists |
| Audit logging (`OA_Enrichment_Change_Log__c` = 478 rows) | **READY** | Proven writing |
| Exception routing (`OA_Enrichment_Exception__c`) | **READY** | Live |
| **Least-privilege runtime user** | **BLOCKED** | Runs as `oauser`/MAD — Louis provisions user + license |
| Scheduled enrichment batch | **PARTIAL** | Not scheduled; enabling = RED approval |
| Monitoring dashboard | **PARTIAL** | Data exists; dashboard not built |

**Verdict: PARTIAL** — functionally ready; gated on runtime user + scheduling approval.

## 4. Procurement Readiness (Phase 2)

| Component | Status | Blocker / owner |
|---|---|---|
| Grants.gov (`OA_FederalOpportunityAcquisition`) | **READY** | Public API; live-piloted; scheduling approval only |
| USASpending enrichment (`OA_USASpendingEnrichment`) | **READY** | NC live |
| SAM.gov | **BLOCKED** | data.gov key + `OA_SAM_Opportunities` NC/EC (absent) — Louis |
| Evidence Layer (024C/D) | **READY** | Deployed |
| Qualification (`OA_OpportunityQualification`) | **READY** | — |
| Investment (`OA_PursuitInvestment`) | **READY** | — |
| Partner Intelligence (`OA_PartnerIntelligence`) | **READY** | Partner capability data collection ongoing |
| Review Queue (`OA_Opportunity_Signal__c` = 18 staged) | **READY** | — |
| Scheduled acquisition (`OA_FederalAcquisitionScheduler`) | **PARTIAL** | Exists, not scheduled (RED) |

**Verdict: PARTIAL** — intelligence + Grants.gov ready to pilot today; SAM breadth blocked on the data.gov key.

## 5. Microsoft Graph Cloud Execution (Phase 3)

**Goal:** move email intake from local PowerShell (WAM as `lrubino`, PC-dependent) to cloud Apex (runs PC-off).

| Requirement | State | Design |
|---|---|---|
| App-only authentication | **MISSING** | Azure app registration + `Mail.Read` **application** permission + admin consent |
| Named Credential | **MISSING** | `OA_Graph` NC → `https://graph.microsoft.com` |
| External Credential | **MISSING** | OAuth 2.0 **client-credentials** flow (client id/secret in EC) |
| Mailbox permissions | **PARTIAL** | Restrict app to the target mailbox (Application Access Policy) — least privilege |
| Email polling | design | Scheduled Apex → `GET /users/{mailbox}/messages?$filter=receivedDateTime ge …` → classify → `OA_Opportunity_Signal__c` (read-only; no delete/modify) |
| Failure handling | design | Non-2xx → `OA_Connector_Run__c` Failed + `OA_Enrichment_Exception__c`; skip-and-continue |
| Retry strategy | design | Exponential backoff via Queueable re-enqueue (bounded); token refresh on 401 |
| Monitoring | design | Poll success/latency to `OA_Connector_Run__c`; alert on N consecutive failures |

**Verdict: BLOCKED** on the app-only credential (Louis / Azure admin). All Apex-side design reuses existing patterns — no new engine.

## 6. SAM.gov Activation Checklist (Phase 4)

1. **data.gov API key** — Louis obtains (role-based; ~10 req/day non-federal → mitigate with `limit=1000`).
2. **External Credential** `OA_SAM_Opportunities` — api-key custom auth (secret entered by Louis; never in code).
3. **Named Credential** `OA_SAM_Opportunities` → `https://api.sam.gov` (+ Remote Site if needed).
4. **Permission set** — grant the runtime user EC principal access (Named-Principal callout needs it).
5. **Validation** — alpha call `opportunities/v2/search?postedFrom=…&postedTo=…&limit=1` with debug trace; confirm 2xx.
6. **Pilot** — ≤10 solicitations → normalize (OCDS) → screen → qualify → **Pending**, 0 Opportunities.
7. **Rollback** — delete pilot signals; connector returns to dormant.

**Verdict: BLOCKED** on data.gov key. Connector code path exists; this is credential + config, not engineering.

## 7. Least-Privilege Plan (Phase 5)

| | Detail |
|---|---|
| **Current runtime** | `oauser@pboedition.com` — **System Administrator (Modify All Data)**; scheduled jobs, callouts, enrichment writeback all run as admin (FLS effectively bypassed except where WITH USER_MODE enforces it) |
| **Recommended runtime** | Dedicated **"OA Runtime"** integration user, **no MAD**, permissions via a **Permission Set Group** |
| **Required permissions** | Bundle existing least-priv permsets: `OA_Lead_Enrichment_Runtime`, `OA_Lead_Writeback_Automation`, `OA_Connector_Staging`, `OA_Opportunity_Acquisition_Platform`, `OA_Document_Intelligence_Access`, `OA_Evidence_Decisioning_Access`, `OA_AI_Provider_Access` + Apex class access + EC principal access; object CRUD scoped to OA objects + Lead (create/edit within FLS) |
| **Migration plan** | (1) Louis provisions the user + license; (2) assign the permission set group; (3) **reschedule** the dormant jobs to run in the runtime user's context; (4) verify `WITH USER_MODE` writeback enforces FLS under the new user (canary on 1 record); (5) decommission the admin dependency. All steps gated (RED) — Louis. |

**Top operational risk** across the platform. Nothing activates safely 24/7 until this is done.

## 8. Operational Dashboards (Phase 6) — design on existing objects (no new metadata)

| Dashboard | Source objects | Key components |
|---|---|---|
| **Executive** | Campaign_Funnel_Snapshot__c (exists) + Opportunity_Signal | Pipeline value, signals→qualified→GO funnel, win-probability trend |
| **Operations** | `OA_Connector_Run__c`, `AsyncApexJob` | Runs today, success rate, queue depth, failures |
| **Business Development** | `OA_Opportunity_Signal__c` | By Review_Status (Pending/Screened/Qualified), by Investment_Level, by Agency |
| **Compliance** | `OA_Opportunity_Signal__c` (Compliance_Decision) | GO vs No-Go, set-aside distribution, evidence-backed % |
| **Connector Health** | `OA_Connector_Run__c` | Per-source success/fail, last-run age, records ingested |
| **Runtime Health** | `OA_AI_Request_Log__c`, `AsyncApexJob` | AI cost/tokens/latency, provider mix, failed jobs |

All buildable as reports+dashboards (config, not code) once #85 merges. The Executive Campaign dashboard already exists as the template.

## 9. Production Monitoring (Phase 7) — on existing telemetry

| Failure class | Signal (existing object/query) | Alert trigger |
|---|---|---|
| API failures | `OA_Connector_Run__c` Status='Failed' | any in last run window |
| Connector failures | `OA_Connector_Run__c` per source | N consecutive fails |
| Queue failures | `AsyncApexJob` Status='Failed'/'Aborted' | any |
| AI failures | `OA_AI_Request_Log__c` Status_Code≥400 / success=false | rate > threshold or cost spike |
| Email failures | Graph poll → `OA_Connector_Run__c` | consecutive poll failures / token 401 |
| Document failures | `OA_Knowledge_Document__c` Extraction_Status IN ('Failed','Manual Review') | backlog > threshold |
| Opportunity failures | `OA_Opportunity_Signal__c` stuck in 'Pending' aging | age > SLA |
| Lead failures | `OA_Enrichment_Exception__c` | any new row |

**Delivery:** scheduled report subscriptions + dashboard refresh + (optional) a light monitor query emailed daily. No new software — reuses logs already populated.

## 10. 30-Day Pilot (Phase 8)

| Week | Focus | KPI | Failure threshold → rollback |
|---|---|---|---|
| **1** | Grants.gov procurement, manual runs, ≤10 signals/run | signals ingested, % evidence-backed, 0 auto-Opps | any auto-Opportunity, any bad write → halt |
| **2** | Lead Enrichment on ≤10-lead cohort, reviewer-gated | enrichment accuracy, 0 unreviewed writes | any unreviewed write → halt |
| **3** | Add scheduled Apex (if runtime user ready), monitor connector health | job success ≥95%, AI cost within budget | success <90% or cost 2× budget → pause schedule |
| **4** | SAM.gov pilot **if key available**; review dashboards | end-to-end signal→qualify→invest→review | callout failure rate >10% → dormant |

**Weekly checkpoints** with Louis. **Rollback criteria:** any auto-Opportunity, any unreviewed Lead write, FLS bypass under runtime user, or cost/error thresholds breached → revert to dormant. **Success:** 30 days, 0 governance violations, review queue flowing, decisions evidence-backed.

## 11. Executive Go-Live Checklist (Phase 9)

**Before ANY activation**
- [ ] **Merge PR #85** → `main` == production *(Louis — RED)*
- [ ] Close superseded PRs #25–83 (branches preserved) *(Louis)*
- [ ] Build 6 operational dashboards + monitoring subscriptions *(Claude — config)*

**Before Lead Enrichment activation**
- [ ] Provision least-privilege **OA Runtime** user + license *(Louis)*
- [ ] Assign permission-set group; canary-verify FLS *(Claude proposes / Louis approves)*
- [ ] Schedule enrichment batch under runtime user *(Louis — RED)*
- [ ] Enable write-back reviewer flow *(Louis)*

**Before Procurement activation**
- [ ] Schedule `OA_FederalAcquisitionScheduler` (Grants.gov) *(Louis — RED)*
- [ ] Run Grants.gov pilot (≤10 signals) *(Claude, gated)*

**Before Cloud runtime (Graph/SAM)**
- [ ] data.gov API key → `OA_SAM_Opportunities` NC/EC *(Louis + Claude config)*
- [ ] Azure app-only Graph credential → `OA_Graph` NC/EC + mailbox policy *(Louis)*
- [ ] Validate + pilot SAM.gov and Graph email intake *(Claude, gated)*

## 12. Verdict — **PASS (certification)** · **Production Ready: NOT YET**
No engineering remains; every activation and runtime blocker is identified with an owner; monitoring and dashboards are designed on existing telemetry; the go-live checklist is complete. Production readiness is clearly determined: **gated on 5 operational items** (merge, runtime user, 2 credentials, scheduling) — none of which is code.

## 13. Exact Louis Decisions Required
1. **Merge PR #85** (the master gate).
2. Provision least-privilege **OA Runtime** user (+ license).
3. Obtain **data.gov API key** and **Azure Graph app-only credential**.
4. Approve **scheduling** of dormant jobs (procurement + enrichment).
5. Approve closing PRs #25–83.

## 14. Exact Claude Actions Remaining (GREEN, post-merge)
- Run post-merge validation (024G §5, read-only).
- Build the 6 dashboards + monitoring report subscriptions (config).
- Configure `OA_SAM_Opportunities` NC/EC scaffolding (once key provided) + validate.
- Draft the runtime permission-set group + canary FLS test.
- Execute the gated Grants.gov / SAM / enrichment pilots on approval.

## 15. Definition of Production Ready
The platform is **Production Ready** when: `main` == production (#85 merged); a **least-privilege runtime user** executes all automation (no admin/MAD); **credentials** for every activated source are configured (Grants live; SAM/Graph as needed); **dashboards + monitoring** are live on the existing log objects; and a **30-day pilot** completes with **0 governance violations** (no auto-Opportunity, no unreviewed Lead write, FLS enforced). At that point the Salesforce BPO Platform is a fully operational Business Development Operating System.
