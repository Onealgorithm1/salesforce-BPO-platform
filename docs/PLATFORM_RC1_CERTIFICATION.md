# Salesforce BPO Platform — RC1 Certification (Integrated Business Development Operating System)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/platform-rc1-certification`
**Mode:** architecture · governance · runtime certification · documentation. **NO features/objects/fields/automation/deploys/merges.** Live production org is the sole source of truth for runtime behavior.

---

## 0. Platform Runtime Inventory (live)
| Category | Live count / detail |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✅ |
| Custom objects (`OA_*__c`) | **12** — `OA_Discovered_Organization__c` (candidate), `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Change_Log__c` (audit, 474 rows), `OA_Enrichment_Exception__c` (review), `OA_Engagement_Resolution__c` (ERE, 44), `OA_Communication_Preference(_Audit/_Token)__c`, `OA_Campaign_Settings__c`, `OA_Graph_Credential__c`, `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c` (legacy) |
| Custom metadata types | **7** — `OA_Connector_Registry__mdt`, `OA_Engagement_Config__mdt`, `OA_Enrichment_Pipeline__mdt`, `OA_Enrichment_Source__mdt`, `OA_Field_Write_Policy__mdt`, `OA_Graph_Config__mdt`, `OA_Qualification_Rule__mdt` |
| Apex classes (`OA_*`) | ~90 (discovery, identity, fusion, completeness, connectors ×2 generations, enrichment, ERE, comms, unsubscribe, send governance, proposal/AI) |
| Active flows | **4** — OA EDWOSB Outreach Sequence, OA New Website Lead Notification, OA PostMeeting Nurture, OA Reply Detection |
| Active validation rules (platform objects) | **1** — `Require_Email_Or_Contact_Person_Email` (Lead) |
| Duplicate rules (Lead) | `OA_Partner_Duplicate_Rule` **active**; Standard_Rule_for_Leads_with_Duplicate_Contacts inactive |
| Matching rules | back `OA_Partner_Duplicate_Rule` (not data-queryable; retrieve to inspect) |
| Approval processes | **0** on platform objects |
| Apex triggers (Lead) | `updatePackages` (LMA managed) |
| Named Credentials | **7** — OA_Anthropic, OA_Census, OA_LinkedIn, OA_Meta, OA_SAM, OA_SEC, OA_USASpending |
| External Credentials | **4** — OA_Anthropic, OA_LinkedIn, OA_Meta, OA_SAM (SEC/USASpending/Census = public, no EC) |
| Permission sets (OA) | **14** (incl. OA_Lead_Enrichment_Runtime, OA_SAM_Connector, OA_SAM_Temp_Principal, OA_Engagement_Reviewer, OA_Executive_Analytics_Access, connector permsets) |
| Scheduled Apex jobs | 7 (booking pollers ×4, artifact poller, EDWOSB follow-up, drip) + managed (sitemap/metalytics/semantic) — **none acquisition** |
| Queueables | `OA_CandidateDiscoveryQueueable`, `OA_EnrichmentQueueable`, `OA_AISummaryQueueable`, `OA_EngagementResolverQueueable/Batch` (all dormant/gated) |
| Reports / Dashboards | **85 / 9** |
| Record types (platform) | none material on `OA_*` objects |
| Runtime data | Candidates 6 · Leads 13,301 · Accounts 1 · Contacts 8 · Campaigns 6 · CampaignMembers 306 · Events 132 · Opportunities **0** |

## 1. Enterprise Architecture Certification
| Stage | SF object | Apex | Flow | AI | Human approval | External API | Governance gate |
|---|---|---|---|---|---|---|---|
| External Sources | — | connectors | — | — | — | USASpending/SAM/SEC | NC/EC; registry `Enabled__c` |
| Candidate Discovery | `OA_Discovered_Organization__c` | `OA_CandidateDiscovery(+Service,+Queueable)` | — | — | — | via connectors | preview/commit; dormant |
| Identity Resolution | candidate | `OA_IdentityResolution` | — | — | — | — | bulk-safe; deterministic |
| Source Fusion | candidate | `OA_SourceFusion` | — | — | — | — | fill-empty; provenance |
| Completeness | candidate | `OA_LeadCompleteness` | — | — | — | — | 0–100 score |
| Human Review | candidate + `OA_Enrichment_Exception__c` | approval svc | — | (advisory) | **Needs Review → Approved** | — | **review-before-Lead** |
| Lead Creation | Lead | `OA_LeadCreationService` (BLO, check-only) | 2 after-save flows fire | — | **reviewed email required** | — | validation rule; dedup; USER_MODE |
| Lead Enrichment | Lead | `OA_EnrichmentOrchestrator/Queueable/Writer` | — | — | gated | USASpending | policy engine; FLS; rollback |
| Campaign | CampaignMember | `OA_SendGovernor/EmailSender/DripScheduler` | OA EDWOSB Outreach | — | — | SendGrid/M365 | send caps; unsubscribe |
| Meeting | Event | `OA_BookingPoller`, ERE | OA PostMeeting Nurture | — | — | M365/Bookings | — |
| Opportunity | Opportunity | — | — | — | — | — | **not built (0)** |
| Customer | Account | — | — | — | — | — | **not built** |
| AI (cross-cutting) | — | `OA_AISummaryService/Queueable`, `OA_ProposalAdapter` | — | **advisory/dormant** | required | Anthropic | no auto-Lead write |

## 2. Object Dependency Certification (key objects)
- **`OA_Discovered_Organization__c`** — purpose: candidate staging/company intelligence. Owner: Discovery. Updates: self. References: Lead/Account (Matched_*), Connector_Run. Validation: none. Flows/Triggers: none. Dedup: Apex (UEI/CAGE) + payload hash. CRUD/FLS: connector/reviewer permsets. Business owner: Acquisition.
- **`Lead`** — purpose: BD prospect. Validation: `Require_Email_Or_Contact_Person_Email`. Dup rule: `OA_Partner_Duplicate_Rule` (active). Flows: OA New Website Lead Notification, OA PostMeeting Nurture (after-save). Trigger: `updatePackages`. Updated by: enrichment writeback, BLO creation, campaign. Business owner: BD/Marketing.
- **`OA_Enrichment_Change_Log__c`** — audit + rollback (474 rows); referenced by enrichment + BLO (`TYPE_CREATE`/`TYPE_ROLLBACK`). Owner: platform framework.
- **`OA_Connector_Run__c`** — telemetry (18 rows); httpErrors/parseErrors. Owner: connector framework.
- **`OA_Enrichment_Exception__c`** — review/exception queue (1 row). Owner: Review.
- **`OA_Engagement_Resolution__c`** — ERE shadow (44 rows), observe-only. Owner: Engagement.
- **CampaignMember (306)/Event (132)** — campaign + meeting; owned by Marketing/BD.

## 3. Automation Certification (graph)
| Automation | Trigger | Order | Dependencies | Risk |
|---|---|---|---|---|
| OA EDWOSB Outreach Sequence (flow) | CampaignMember/Lead after-save | on enroll | send governor, templates | protected; live |
| OA Reply Detection (flow) | EmailMessage/after-save | inbound reply | ERE | protected |
| OA PostMeeting Nurture (flow) | Lead after-save | post-meeting | meeting fields | entry-gated |
| OA New Website Lead Notification (flow) | Lead after-save | on new Lead | — | **fires on BLO-created Leads — verify entry criteria** |
| `updatePackages` trigger | Lead | — | LMA package | benign (managed) |
| Drip/FollowUp/Booking/Artifact schedulers (7 scheduled Apex) | time-based | cron | M365/SendGrid | protected; live |
| Discovery/Enrichment/AI/ERE queueables | manual enqueue | — | connectors/policy | **dormant (0 running)** |
| Acquisition connectors | manual run | — | NC/EC | **dormant (`Enabled__c=false`)** |
No platform events in acquisition; no acquisition schedules/jobs.

## 4. Connector Certification
| Connector | Auth | Status | Confidence | Business value | Data produced | Activation |
|---|---|---|---|---|---|---|
| USASpending | public (no key) | **live-proven** (200, 28/term) | High | UEI, name, awards, state | discovery seed | dormant |
| SAM | data.gov key (EC header) | **live-proven** (200, fusion) | High | CAGE, address, website, registration | enrichment | dormant |
| SEC | public | **live-proven** (200, RTX) | Med | CIK, public filers | public-company identity | dormant |
| IRS | NC present | **not viable** (no `OA_IRS_Request`) | — | (nonprofit EO) | off-ICP | dormant |
| Census | NC present | not an org registry | — | aggregate stats | low | dormant |
| State Registry | template | not built | — | — | — | dormant |
| LinkedIn | OAuth (EC) | **live** (userinfo 200) | — | profile (own-account) | compliance-bound | dormant |
| Meta | OAuth (EC) | **live** (/me 200) | — | marketing | compliance-bound | dormant |
| Website | — | out of scope | — | — | — | — |
Readiness: USASpending/SAM/SEC production-ready (supervised); others future/off-ICP. **No connector is auto-activated.**

## 5. Data Lineage Certification (key Lead fields)
| Lead field | Origin | Transformation | Reviewer | Enrichment | AI | Confidence | Manual |
|---|---|---|---|---|---|---|---|
| Company / Company_Name__c | Candidate `Organization_Name__c` | direct map | approves | — | — | source conf | — |
| UEI__c / CAGE_Code__c / CIK__c / EIN__c | USASpending/SAM/SEC | canonical + fusion | approves | — | — | HIGH | — |
| Primary_NAICS_code__c | source `NAICS__c` | map (SIC≠NAICS gap) | — | — | — | varies | — |
| Address/City/State/Website | SAM/USASpending fusion | fill-empty + provenance | — | SAM | — | HIGH | — |
| **Contact_Person_s_Email__c** | **reviewer-supplied** `Reviewed_Contact_Email__c` | — | **reviewer (required)** | (future connector) | — | human | **yes** |
| Compatibility_Score__c | candidate `Confidence_Score__c` | map | — | — | — | computed | — |
| USASpending_* | USASpending | enrichment writeback | — | ✅ | — | HIGH | — |
| AI_Summary__c | Anthropic | `OA_AISummaryService` | reviews | — | ✅ (advisory) | — | — |
Provenance is preserved on the candidate (`Discovery_Metadata__c sources[]`) + `OA_Enrichment_Change_Log__c` (`TYPE_CREATE`). **No field left un-provenanced.**

## 6. Security Certification
| Control | Status |
|---|---|
| Secrets in repo | **none** (EC files gitignored; NCs hold URLs only) |
| External Credentials | 4 (Anthropic/LinkedIn/Meta/SAM); secrets encrypted in org |
| Named Credentials | 7; secret-free metadata |
| Runtime user | `oauser` = **admin/MAD (NOT least-privilege)** — top risk |
| CRUD/FLS | permset-based; new BLO field bundled with FLS permset (unassigned) |
| Sharing | services `with sharing`; Lead insert USER_MODE |
| Audit trail | `OA_Enrichment_Change_Log__c` (474) + provenance |
| Least privilege | **gap** — runtime user + `OA_SAM_Temp_Principal` (temp permset carries EC grant) + raw `X-Api-Key` header |
| Monitoring | telemetry object exists; **no alerting** |
**Production risks:** (1) MAD runtime user [HIGH]; (2) temp SAM permset + raw header [MED]; (3) no acquisition monitoring/alerting [MED]; (4) empty Matching/Duplicate rules for candidate dedup at scale [MED].

## 7. Scalability Certification
| Volume | Assessment |
|---|---|
| 100/day | ✅ comfortable (bulk resolver ≤5 SOQL/50 orgs; batched DML; queueable spacing) |
| 1,000/day | ✅ with queueable cadence (one fetch/txn spaces callouts) |
| 10,000/day | 🟡 needs: connector rate-limit governance, org Matching/Duplicate rules, review-queue staffing, monitoring; SOQL/DML bulk-safe already |
| 100,000/day | 🔴 needs: batch/async redesign for review throughput, contact-resolution automation, sharding/partitioning, dedicated integration user pool, backoff/retry hardening |
Governor posture: SOQL bounded (fixed queries/batch), DML batched, queueable chaining for callout spacing, no per-record SOQL. Gaps: no explicit backoff beyond one retry; recovery/monitoring manual; single runtime user (locking/concurrency at high volume).

## 8. Failure Mode Analysis
| Stage | Failure | Detection | Recovery | Rollback | Escalation | Impact |
|---|---|---|---|---|---|---|
| Connector callout | HTTP/timeout | `OA_Connector_Run__c` httpErrors + result messages | 1 retry (queueable) | n/a | log | discovery gap |
| Credential | EC not resolved | CalloutException (surfaced) | fix EC/permset | n/a | manual | connector blocked |
| Identity/fusion | bad match | REVIEW decision | human review | change log | review queue | data quality |
| Candidate persist | DML error | Outcome gate=DML | allOrNone=false capture | delete candidate | log | partial batch |
| Lead creation | validation/dup | RowOutcome gate=VALIDATION/MATCH | reviewer supplies email / links | `rollbackCreated` | review | no Lead |
| Enrichment writeback | FLS/DML | RowOutcome + change log | snapshot rollback | `OA_ChangeLogService.rollback` | log | stale Lead |
| Campaign send | cap/bounce | send governor + unsubscribe | throttle | — | ops | deliverability |
**Nothing fails silently** — every stage surfaces a gate/outcome/log. Gaps: no automated alerting (detection is pull-based), no dead-letter queue.

## 9. Executive Dashboard Matrix (design; 85 reports/9 dashboards exist to extend)
| Dashboard | Business question |
|---|---|
| Executive | Are we converting discovery → pipeline? (candidates→approved→leads→meetings→opps) |
| Operations | Is the pipeline healthy? (queue latency, review backlog, failures) |
| Compliance | Is every Lead provenanced + review-gated? (audit coverage, unsubscribe) |
| Business Development | Which agencies/primes/NAICS convert? (coverage + conversion) |
| Connector Health | Are sources up? (`OA_Connector_Run__c` errors, latency) |
| AI Operations | Is AI advisory-only + cost-bounded? (AI summaries, Anthropic usage) |
| Lead Quality | Are leads campaign-ready? (completeness bands, contact coverage) |
| Campaign Performance | Are sends working? (send/open/reply, caps) |
| Pipeline | What's in flight? (stage counts, aging) |
| Opportunity Conversion | Do meetings become opps? (0 today — future) |

## 10. Technical Debt Register
| Item | Category | Priority | Risk | Effort | Sprint | Owner |
|---|---|---|---|---|---|---|
| MAD runtime user → least-privilege | Security/Admin | P1 | High | S | pre-volume | Admin |
| Deploy BLO bridge + assign FLS permset | Engineering/Admin | P1 | Med | S | BLO Ph3 | Eng/Admin |
| Contact-resolution (reviewer email; future connector) | Engineering | P1 | Med | M | BLO Ph3 | Eng |
| SAM permset consolidation + retire temp + header hygiene | Config | P2 | Med | S | pre-volume | Admin |
| Org Matching/Duplicate rules for candidate dedup | Config | P2 | Med | S | scale | Admin |
| Acquisition/lifecycle dashboards + alerting | Operations | P2 | Med | M | Ops | Ops |
| RC1 merges (2 squash) | Governance | P2 | Low | S | RC1 | Eng |
| Legacy connector dead-code removal | Engineering | P3 | Low | M | cleanup | Eng |
| NAICS mapping (E2) | Engineering | P3 | Low | M | future | Eng |
| Meeting→Opportunity→Customer | Future | P3 | — | L | OI program | Eng |

## 11. Operational Readiness
- **Is RC1 production-ready?** **Yes for supervised discovery → enrichment → campaign** (deployed dormant, pilots proven). The **Candidate→Lead bridge is engineered + check-only, not deployed**.
- **Blocks supervised operation:** deploy BLO + reviewer-supplied contact email + assign permsets; recommended least-privilege user.
- **Blocks unattended operation:** automation/scheduling (deliberately off), least-privilege user, monitoring/alerting, org Matching/Duplicate rules.
- **Blocks enterprise scale:** volume testing, contact-resolution automation, dashboards, connector rate-limit governance, dedicated integration user(s).
- **Blocks AI-assisted operation:** AI activation governance (human-in-loop confirm), Anthropic cost/monitoring, output validation.
- **Blocks federal production:** compliance/ATO posture, least-privilege, data-handling review, full audit/monitoring — a dedicated federal-readiness program.

## 12. Platform Scorecard (evidence-based)
| Dimension | Score | Evidence |
|---|---:|---|
| Architecture | 88 | layered, registry-driven, reuse-first; 12 objects/7 CMDT; clean pipeline |
| Engineering | 86 | core complete/tested/deployed; BLO check-only 9/9; legacy dup debt |
| Security | 70 | no repo secrets, EC-safe, audit; MAD user + temp permset + raw header |
| Governance | 90 | review-before-Lead, no auto-Lead, audit/provenance, all dormant/approved |
| Scalability | 74 | bulk-safe + queueable spacing; no volume test; empty matching rules |
| Maintainability | 72 | documented + structured; 2 connector generations; ~90 classes |
| Business Readiness | 68 | campaign live (306), enrichment certified; 0 opps; bridge not in prod |
| Operational Readiness | 60 | telemetry/audit live; no acquisition dashboards/alerting; manual review |
| AI Readiness | 65 | AI advisory/dormant, governed, no auto-write; not activated |
| **Overall Platform Readiness** | **≈74** | **RC1 for supervised operation; not unattended/enterprise/federal** |

## 13. Strategic Roadmap (next 3 only, ranked)
1. **BLO Phase 3 — Supervised Candidate→Lead Activation** (deploy bridge + contact email + least-priv user + 1-candidate pilot). *Why:* connects the two certified halves into one operating flow — the single missing lifecycle link. *Dependencies:* contact email, least-privilege user, RC1 merge.
2. **Operational Dashboards & Monitoring** (extend the 85 reports/9 dashboards to acquisition/lifecycle + connector health + alerting). *Why:* turns supervised operation observable + scalable; prerequisite for any volume. *Dependencies:* #1, RC1 merge.
3. **Controlled Automation & Scale Hardening** (org Matching/Duplicate rules, enqueue cadence, contact-resolution automation, volume test, backoff/retry). *Why:* the gate between supervised and unattended/enterprise scale. *Dependencies:* #1 + #2.
*(Opportunity Intelligence / federal-readiness follow after these — not in the next 3.)*

## 14–15. Definition of Done & PASS / WARN / FAIL — 🟢 PASS (🟡 WARN conditions)
All 16 deliverables produced from live evidence; platform understood as an integrated BDOS. **No production changes, no deploys, no merges.** **WARN:** RC1 is production-ready for **supervised** operation only — the Candidate→Lead bridge is not deployed, least-privilege runtime user is outstanding, and unattended/enterprise/federal scale each have named blockers.

## 16. Exact Next Claude Engineering Sprint
**BLO Phase 3 — Supervised Candidate→Lead Activation Pilot** (gated, on explicit authorization): deploy the BLO bundle (4 classes + `Reviewed_Contact_Email__c` + `OA_BLO_Contact_Access`), assign the FLS permset to a **least-privilege runtime user**, confirm `OA_Partner_Duplicate_Rule` action + the two after-save flows' entry criteria, have a reviewer supply one verified contact email, and run the **single-candidate** preview→commit conversion with full validation + rollback readiness — the first governed Lead created from an acquired candidate. No automation, no scheduling, no Accounts, no enrichment activation.
