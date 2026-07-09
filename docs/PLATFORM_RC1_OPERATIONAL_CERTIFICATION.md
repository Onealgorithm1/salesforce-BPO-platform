# Salesforce BPO Platform — RC1 Operational Certification (Phase 2: Validation & Readiness)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/platform-rc1-certification` (PR #51)
**Mode:** validation · governance · operational planning · documentation. **No features/objects/fields/automation/deploys/merges/activation/production changes.** Live production org = authoritative source of runtime behavior; repo docs never override it.
**Baseline:** [PLATFORM_RC1_CERTIFICATION.md](PLATFORM_RC1_CERTIFICATION.md) (not recreated — validated here).

---

## 1. Certification Validation (Phase 15)
| RC1 conclusion | Evidence (live) | Confidence | Would be invalidated by | Verdict |
|---|---|---|---|---|
| Discovery→campaign proven end-to-end | USASpending 200/28, SEC 200 (RTX), SAM 200 + fusion (23→47); 306 CampaignMembers | **High** | live re-test 4xx/5xx | PASS |
| Subsystems operational | 474 change logs, 18 connector runs, 44 ERE rows, 132 Events | **High** | empty/stale telemetry | PASS |
| Review-before-Lead; no auto-Lead | no candidate→Lead path deployed; BLO manual + check-only; 0 candidates Converted | **High** | any trigger/flow creating Leads from candidates | PASS |
| Connectors dormant | `Enabled__c=true`=**0**; acquisition async=**0**; acquisition schedules=**0** (re-validated) | **High** | any `Enabled__c=true` / running acq job | PASS |
| AI advisory/dormant | AISummary async=0; **not scheduled** (the `%AI%` match was "D**ai**ly") | **High** | AISummary in a trigger/schedule | PASS |
| No secrets in repo | `git grep` clean; EC files gitignored; NCs URL-only | **High** | a committed key/token | PASS |
| Baseline integrity | Candidates **6** / Leads **13,301** / Accounts **1** / Opps **0** unchanged | **High** | count drift w/o approval | PASS |
| MAD runtime user = top risk | `oauser` holds admin/MAD | **High** | least-priv user provisioned | WARN |
| Overall ≈74 | composite of scored dimensions | **Medium** | evidence shifts per dimension | WARN |
| `OA_Partner_Duplicate_Rule` behavior on BLO insert | rule **ACTIVE** (queryable); **action (Alert vs Block) NOT programmatically confirmed** (3 retrieve attempts failed) | **Low** | Setup shows "Block" → BLO inserts could be rejected | **WARN — verify in Setup before pilot** |
**Re-score:** RC1 **PASS (supervised) with WARN**. New explicit residual: the duplicate-rule action must be read in Setup → Duplicate Rules before the Candidate→Lead pilot (applies "validate target state before design").

## 2. Platform Dependency Matrix (Phase 16 — representative; full list in RC1 §0)
| Component | Purpose | Depends on | Referenced by | Prod risk | Safe to modify | Business owner | Tech owner |
|---|---|---|---|---|---|---|---|
| `OA_Discovered_Organization__c` | candidate/company intel | connector registry | discovery/identity/fusion/BLO | Low (dormant) | Additive only | Acquisition | Platform Eng |
| `OA_CandidateDiscovery(+Service,+Queueable)` | discovery pipeline | connectors, identity, fusion, completeness | driver, queueable | Low (dormant) | Yes (feature branch) | Acquisition | Platform Eng |
| `OA_IdentityResolution` | dedup/match | candidate, Lead/Account | service, BLO | Med (matching logic) | Careful | Acquisition | Platform Eng |
| `OA_SourceFusion` / `OA_LeadCompleteness` | enrich/score | canonical org | service | Low | Yes | Acquisition | Platform Eng |
| `OA_ChangeLogService` + `OA_Enrichment_Change_Log__c` | audit/rollback | — | enrichment, BLO | **High (shared audit)** | Careful | Compliance | Platform Eng |
| `OA_FieldWritePolicyEngine` + `OA_Field_Write_Policy__mdt` | write policy | — | enrichment writeback | Med | Careful | Governance | Platform Eng |
| BLO (`OA_LifecycleStates`/Approval/LeadCreation/Business…`) | Candidate→Lead bridge | candidate, audit, identity, Lead | (manual) | Low (check-only) | Yes | BD | Platform Eng |
| `Reviewed_Contact_Email__c` + `OA_BLO_Contact_Access` | contact input + FLS | Lead rule | BLO creation | Low (not deployed) | Yes | BD/Review | Platform Eng |
| Connectors (USASpending/SAM/SEC…) | external data | NC/EC, registry | runner/driver | Med (callouts) | Careful | Acquisition | Platform Eng |
| NC/EC (7/4) | credentials | secrets (in org) | connectors | **High (secrets/auth)** | Admin only | Security | Admin |
| Permsets (14) | access | fields/objects | users | Med | Admin only | Security | Admin |
| Enrichment (`Orchestrator/Queueable/Writer`) | Lead enrich | policy, audit, USASpending | (gated) | Med | Careful | BD | Platform Eng |
| Active flows (4) + scheduled Apex (7) | campaign/meeting/reply | Leads/CM/Email | — | **High (protected/live)** | **Do not modify** | Marketing/BD | Platform Eng |
| Reports (85)/Dashboards (9) | analytics | objects | execs/ops | Low | Yes (additive) | Execs | Ops |

## 3. Deployment Readiness Assessment (Phase 17)
| Item | Current | Target | Deps | Validation | Rollback | Risk | Impact | Duration | Owner | Go/No-Go |
|---|---|---|---|---|---|---|---|---|---|---|
| BLO bridge (4 classes) | check-only (`0AfPn0000023fThKAI`) | deployed dormant | — | check-only 9/9 (done) | revert deploy | Low | enables conversion | ~15 min | Eng | Go once authorized |
| `Reviewed_Contact_Email__c` + `OA_BLO_Contact_Access` | check-only | deployed | BLO | validate + FLS bundle | delete field/permset | Low | contact input | ~10 min | Eng/Admin | Go with BLO |
| Least-privilege runtime user | not provisioned | dedicated integration user | license | smoke as new user | reassign | Med | removes top risk | ~1 hr | Admin | **No-Go until provisioned** |
| SAM permset consolidation | temp permset | `OA_SAM_Connector` + retire temp | EC grant | SAM 200 as user | reassign temp | Med | hygiene | ~30 min | Admin | Go pre-volume |
| RC1 doc/code merges | 27 open PRs | main synced | dry-merge clean | 2 squash (0 conflict) | git revert | Low | source↔prod parity | ~30 min | Eng | Go |
| PR #51 (this cert) | open, docs-only | on main | base main | none (docs) | git revert | **Very Low** | knowledge on main | ~5 min | Eng | **Go — recommend merge** |

## 4. Production Activation Checklist (Phase 18 — checklist only, no activation)
- [ ] **Runtime user:** provision dedicated least-privilege integration user (replace `oauser`/MAD).
- [ ] **Permission sets:** assign only `OA_Lead_Enrichment_Runtime` + `OA_SAM_Connector` (consolidated) + `OA_BLO_Contact_Access` to the runtime user; reviewers get `OA_Engagement_Reviewer` + `OA_BLO_Contact_Access`.
- [ ] **Named/External Credentials:** confirm `OA_SAM` EC header (migrate raw key → `ApiKey` param); verify NC endpoints.
- [ ] **Duplicate rules:** **read `OA_Partner_Duplicate_Rule` action (Alert vs Block) in Setup** — if Block, decide BLO handling.
- [ ] **Matching rules:** define candidate-side UEI/CAGE/name+state rules (currently empty).
- [ ] **Validation rules:** confirm `Require_Email_Or_Contact_Person_Email` satisfied by reviewed email (done).
- [ ] **After-save flows:** confirm `OA New Website Lead Notification` entry criteria won't misfire on acquired Leads.
- [ ] **Scheduled jobs:** none for acquisition (keep off).
- [ ] **Monitoring/Alerting:** stand up connector-health + review-queue + failure alerts (Phase 6 below).
- [ ] **Human approval:** reviewer supplies contact email; Lead Ready gate enforced.
- [ ] **Rollback:** confirm `rollbackCreated` + `OA_ChangeLogService.rollback` paths.
- [ ] **Success criteria:** 1 governed Lead created, provenanced, no Accounts touched, no automation, counts reconcile.

## 5. Operations Runbook (Phase 19)
- **Daily:** connector health (`OA_Connector_Run__c` errors); review-queue backlog (`Needs Review` count/age); async job failures; campaign send/bounce; audit spot-check.
- **Weekly:** lead quality (completeness bands); candidate quality (dedup/fusion rates); exception queue triage; AI output review (if activated).
- **Monthly:** security review (permset assignments, runtime user); provenance/audit coverage; connector data-quality sampling; backup verification.
- **Quarterly:** governor-limit headroom vs volume; matching/duplicate rule tuning; connector credential rotation; DR/rollback drill.
- **Annual:** architecture review; federal-compliance posture; license/capacity planning.
- **Incident response:** detect (telemetry/alert) → classify (connector/data/security) → contain (unassign permset / disable connector `Enabled__c`) → rollback (change-log) → RCA → document.

## 6. Monitoring Architecture (Phase 20)
| Metric | Dashboard | Alert threshold | Severity | Escalation |
|---|---|---|---|---|
| Apex/Flow/Queueable failures | Ops | any unhandled | High | Eng on-call |
| Authentication/connector failures | Connector Health | >0 in 15 min | High | Eng/Admin |
| Governor limits (SOQL/DML/CPU/heap) | Ops | >80% | Med | Eng |
| Retry counts / processing latency | Ops | retries>1 or latency>2× baseline | Med | Eng |
| Candidate throughput / Lead throughput | Executive | <expected/day | Low | Ops |
| Human review queue depth/age | Operations | age>SLA | Med | Review lead |
| API health (connector 2xx rate) | Connector Health | <98% | High | Eng |
*(No native APM in Salesforce — implement via `OA_Connector_Run__c` + scheduled report subscriptions + platform events/email alerts; none active today.)*

## 7. AI Governance Review (Phase 21)
| Capability | Purpose | Prompt source | Inputs | Outputs | Human approval | Audit | Failure modes | Privacy | Security | Federal | Activation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `OA_AISummaryService`/`OA_AISummaryQueueable` | company/lead summary | in-Apex prompt | candidate/Lead fields | `AI_Summary__c` (advisory) | **required (reviewer)** | change log on write | callout error → no write | no PII beyond org data | Anthropic NC/EC | data-residency review needed | **dormant (0 async, not scheduled)** |
| `OA_ProposalAdapter` | proposal draft | Apex/template | Lead data | draft artifact | required | — | adapter error surfaced | org data | — | review | dormant |
| Qualification rules | candidate triage | `OA_Qualification_Rule__mdt` | candidate | Needs Review routing | reviewer | — | rule miss → review | — | — | deterministic | active (rules) |
**Verified:** no AI writes production Leads automatically; no AI bypasses review; AI outputs advisory + audited on write; Anthropic access via NC/EC (no secret in repo). **Activation gates:** human-in-loop confirm, cost/rate monitoring, output validation, federal data-handling review.

## 8. Repository Documentation Audit (Phase 22)
- **Volume:** **111 docs** in `docs/` (+ `docs/decisions/` ADRs, `docs/SESSION_SUMMARIES/`, `docs/templates/`).
- **Missing:** consolidated ops runbook + monitoring (this doc fills); a single "platform index" README.
- **Outdated/superseded:** early per-phase LA readiness (Phase 10/11), SAM readiness §1–§9, RC1 pre-resolution notes — historical.
- **Duplicate/overlap:** multiple release-readiness docs (LA release readiness, RC1 consolidation, RC1 certification, this) — **recommend one canonical `PLATFORM_STATUS.md` index** linking the rest.
- **Conflicting:** none material (later docs explicitly supersede).
- **Deprecated:** mark superseded readiness docs with a header banner; do not delete.
- **Recommendation:** add `docs/README.md` index; tag historical docs; keep ADRs authoritative for decisions.

## 9. Repository Certification (Phase 23)
- **Branches:** **122 feature branches** — significant sprawl; **recommend archiving/deleting fully-merged branches after RC1** (owner decision; governance keeps merged branches by default).
- **Open PRs:** **27** (#25–#51) — stacked LA/enrichment chain + BLO (#50) + certs (#51). Consolidate via the 2-squash RC1 strategy; merge docs PRs (#51) independently.
- **ADRs:** **16** under `docs/decisions/` (ADR-001…019, incl. ADR-015–019 Opportunity Intelligence) + ADR-INDEX — healthy decision record.
- **Folder structure:** standard sfdx (`force-app/main/default/...`), `docs/` with `decisions/`, `templates/`, `SESSION_SUMMARIES/` — good.
- **Naming:** consistent `OA_` prefix; two connector generations violate single-source (dead code).
- **Dead code:** legacy connector gen (`OA_IConnector`/`OA_ConnectorEngine`/`OA_USASpendingClient`/`OA_SAMConnector` etc.) + unused staging objects → **separate cleanup PR**.
- **Cleanup actions (no merges now):** (1) branch pruning post-RC1; (2) docs index + historical banners; (3) dead-code removal PR; (4) close 22 rolled-up PRs on squash-merge.

## 10. Technical Debt Updates (Phase 24 input)
Additions to the RC1 register: **duplicate-rule action verification** (Config, P1 before pilot); **repo branch sprawl (122)** (Governance, P3); **docs index/consolidation** (Ops, P3); **monitoring/alerting absent** (Ops, P2). All else per RC1 §10.

## 11. Four-Sprint Implementation Roadmap
**Sprint 1 — BLO Phase 3 Supervised Activation** · value: closes the lifecycle · deps: least-priv user, contact email, dup-rule action · risk: Med · effort: M · DoD: 1 governed Lead created + validated + rollback proven · validation: post-deploy check + pilot evidence.
**Sprint 2 — Operational Dashboards & Monitoring** · value: observability/scale prerequisite · deps: RC1 merge · risk: Low · effort: M · DoD: connector-health + lifecycle + review dashboards live + alerts · validation: two-phase analytics deploy.
**Sprint 3 — Controlled Automation & Scale Hardening** · value: supervised→unattended gate · deps: S1+S2 · risk: Med · effort: L · DoD: matching/dup rules + enqueue cadence + volume test (1k/day) + backoff · validation: load test + governor evidence.
**Sprint 4 — Repository & Release Consolidation** · value: maintainability/parity · deps: — · risk: Low · effort: S · DoD: 2-squash RC1 merges + tags + branch pruning + docs index + dead-code PR · validation: dry-merge 0-conflict + main parity.

## 12. Executive Go / No-Go Review (Phase 25)
**Executive summary:** the platform is a validated, integrated BDOS whose discovery→enrichment→campaign half is production-proven and whose Candidate→Lead bridge is engineered + check-only. Governance is strong (no auto-Lead, review-gated, audited); the gating risks are operational/administrative, not architectural.
- **Remaining blockers:** least-privilege runtime user; BLO deploy + contact email; dup-rule action confirmation; monitoring/alerting; matching/duplicate rules.
- **Production risks:** MAD runtime user [High]; temp SAM permset + raw header [Med]; no alerting [Med]; branch/doc sprawl [Low].
- **RC1 Go/No-Go:** **GO for supervised deployment** (deploy BLO dormant + run the single-candidate pilot under human control), **conditional on** provisioning a least-privilege user and confirming the dup-rule action. **No-Go for unattended/enterprise/federal.**
- **RC2 prerequisites:** dashboards + monitoring; matching/dup rules; supervised pilots at low volume; SAM hygiene.
- **Enterprise-scale prerequisites:** volume test, contact-resolution automation, dedicated integration users, backoff/recovery, connector rate governance.
- **Federal-production prerequisites:** compliance/ATO posture, least-privilege, data-handling + AI data-residency review, full audit/monitoring.

## 13. Updated PASS / WARN / FAIL — 🟢 PASS (🟡 WARN)
Certification validated against live evidence; every remaining blocker explicitly identified; operational package complete. **No production changes/deploys/merges/activation.** WARN: supervised-only readiness; least-priv user + dup-rule action + monitoring outstanding.

## 14. Merge Recommendation for PR #51
**Recommend MERGE** (docs-only, base `main`, additive, zero code/prod impact, no conflict) — either directly (squash) or folded into the Sprint-4 RC1 doc consolidation. It places the certification on `main` as the platform's baseline. *(Not merged in this sprint per instruction — this is the recommendation.)*

## 15. Exact Next Claude Engineering Sprint
**BLO Phase 3 — Supervised Candidate→Lead Activation Pilot** (gated): provision/confirm a **least-privilege runtime user**; **read `OA_Partner_Duplicate_Rule` action + `OA New Website Lead Notification` entry criteria in Setup**; deploy the BLO bundle dormant; a reviewer supplies one verified contact email; run the **single-candidate** preview→commit conversion with full validation + rollback readiness — the first governed Lead from an acquired candidate. No automation, no scheduling, no Accounts, no enrichment activation.
