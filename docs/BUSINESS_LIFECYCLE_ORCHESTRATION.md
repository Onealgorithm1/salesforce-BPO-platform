# Business Lifecycle Orchestration (BLO) — Phase 1: Candidate Approval, Lead Creation & Lifecycle Engine

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/business-lifecycle-orchestration`
**Mode:** engineering (source-only) + **check-only validation** (`0AfPn0000023fThKAI`, 8/8 tests pass). **No deploy · no merge · no automation · no scheduling · no production writes · human approval never bypassed.**
**Inspection order:** live org → runtime → repository → docs.

---

## 1. Executive Summary
The final foundational bridge between **Lead Acquisition** and **Lead Enrichment** is engineered: a governed, reusable **Business Lifecycle Engine** that converts *human-approved* candidates into Leads without ever bypassing review, duplicate detection, policy, or validation rules. It is delivered as **4 Apex classes + 1 test (8 tests, all green in check-only)**, **reuses** the existing candidate object, audit/rollback engine, and identity model, and **introduces no new object, field, or CMDT**. It is **dormant** (manual invocation only — no trigger/flow/schedule) and **not deployed**. A key live finding: candidates carry **no contact email**, and the active `Require_Email_Or_Contact_Person_Email` Lead rule is **honored, not bypassed** — so "contact availability" is a real entry criterion the engine surfaces rather than circumvents. **Verdict: 🟢 PASS.**

## 2. Current State Audit (reused, not rebuilt)
| Capability | Existing asset (reused) |
|---|---|
| Candidate store + states | `OA_Discovered_Organization__c` (`Qualification_Status__c` Text(20), `Recommended_Action__c`, `Matched_Lead__c`, `Matched_Account__c`, provenance in `Discovery_Metadata__c`) |
| Identity / dedup | `OA_IdentityResolution` + UEI/CAGE keys (Lead `UEI__c`, `CAGE_Code__c`) |
| Audit + rollback | `OA_ChangeLogService` (`snapshot`, `buildLog` `TYPE_CREATE`/`TYPE_ROLLBACK`, `commitLogs`, `rollback`) → `OA_Enrichment_Change_Log__c` (474 live rows) |
| Policy engine | `OA_FieldWritePolicyEngine` (`FillEmptyOnly`/`Overwrite`/`Never`, `OA_Field_Write_Policy__mdt`) |
| Exception / review queue | `OA_Enrichment_Exception__c`, `OA_ExceptionRoutingService` |
| Enrichment writeback pattern | `OA_LeadWritebackService` (preview/commit, gates, snapshot, RunSummary) — mirrored for insert |
| Lead target fields | `Company`, `LastName` (required); `Company_Name__c`, `UEI__c`, `CAGE_Code__c`, `CIK__c`, `EIN__c`, `Primary_NAICS_code__c`, `Address_line_1__c`, `City__c`, `State__c`, `Website__c`, `Compatibility_Score__c`, `Contact_Person_s_Email__c` |
| Constraint | active validation rule **`Require_Email_Or_Contact_Person_Email`** — candidates have **no email field** |

**No duplicate metadata created.** Provenance is preserved via the candidate↔Lead link (`Matched_Lead__c`) + `TYPE_CREATE` audit row — not by inventing Lead fields.

## 3. Lifecycle Architecture
| State | Purpose | Owner | Entry criteria | Exit criteria | Audit | Rollback | Security |
|---|---|---|---|---|---|---|---|
| External Source | raw federal data | Connector | approved connector | canonical org produced | `OA_Connector_Run__c` | n/a | NC/EC |
| Candidate | staged org | Discovery | connector output | dedup evaluated | Discovery_Metadata | delete candidate | object CRUD |
| Identity Resolution | match to existing | Engine | candidate exists | decision (MATCH/REVIEW/NONE) | change log | re-run | system |
| Source Fusion | enrich fill-empty | Engine | ≥2 sources | fields fused | provenance sources[] | fill-empty reversible | policy |
| Completeness | 0–100 score | Engine | fused record | score assigned | Last_Evaluated | recompute | read |
| **Needs Review** | human triage | Reviewer | scored candidate | human decision | status log | — | review perms |
| **Approved** | cleared for Lead | Reviewer | legal transition from Needs Review/Deferred | Lead Ready / Converted | status log | revert status | approval |
| **Lead Ready** | contact-complete | Reviewer/Contact step | Approved + contact email | Converted | status log | revert status | approval |
| **Lead Created** | governed Lead | Lead Creation Service | eligible + not dup + valid | Enrichment Requested | `TYPE_CREATE` | `rollbackCreated` (delete + reset) | USER_MODE + validation rule |
| Enrichment Requested→Complete | fill-empty enrich | Enrichment platform | Lead exists | enriched | change log | writeback rollback | policy/FLS |
| Campaign Eligible→Member | outreach | Campaign engine | enriched Lead | enrolled | flow logs | remove member | campaign perms |
| Meeting Booked→Completed | engagement | Booking/ERE | member | outcome | Event/ERE | reschedule | meeting perms |
| Qualified Opportunity → Customer | close | *(future program)* | meeting completed | won | — | — | — |

**No skipped states** — the engine enforces `OA_LifecycleStates` transitions; CONVERTED is reachable only through Lead creation.

## 4. Lifecycle Engine (`OA_BusinessLifecycleService`)
Stateless (all static) · Idempotent (skips CONVERTED/linked) · Bulk-safe (batched queries + DML) · Policy-driven (`OA_LifecycleStates`) · Connector-agnostic (operates on candidates, not sources) · Audit-first (every applied transition logs) · Rollback-aware (`createdLeadIds` + `rollbackCreated`) · Human-approved (acts only on APPROVED/LEAD_READY). **No direct automation — manual invocation only.** Entry points: `createLeads(...)`, `advance(...)`, `preview(...)`.

## 5. Candidate Approval Engine (`OA_CandidateApprovalService`)
States: Needs Review → Approved | Rejected | Deferred → Lead Ready → Converted. Every transition **validates policy** (state machine; illegal transitions blocked; `CONVERT_GUARD` prevents setting Converted here), **records audit** (`OA_ChangeLogService`), **prevents duplicates** (linked candidates can't be re-approved for creation), and **preserves provenance** (never clears source/canonical/metadata). Preview = 0 DML.

## 6. Lead Creation Service (`OA_LeadCreationService`)
Creates Leads from approved candidates with gates **ELIGIBILITY → IDEMPOTENCY → MATCH(dedup) → DATA → VALIDATION**. Populates Company/LastName/Company_Name/UEI/CAGE/CIK/EIN/NAICS/Address/City/State/Website/Compatibility_Score; **ownership** = running user (default); **source/canonical/discovery/confidence/review** provenance preserved via candidate link + `TYPE_CREATE` audit (no invented fields). **Never overwrites existing Leads** (dedup → link, insert-only), **never bypasses duplicate detection or the org validation rule** (insert in USER_MODE, `allOrNone=false`; no-email → `FAILED/VALIDATION`, candidate untouched). On success → candidate `Matched_Lead__c` set + status `Converted`. Contact email supplied via an optional `Map<Id,String>` (future contact-discovery feeds it — never fabricated). Rollback: `rollbackCreated` deletes Leads, resets candidates to Lead Ready, logs `TYPE_ROLLBACK`.

## 6b. Lead Enrichment Integration (Phase 6 — validated, NOT activated)
| Integration point | Status |
|---|---|
| Proposal Engine (`OA_ProposalAdapter`/`OA_AISummaryService`) | compatible; advisory/dormant; no auto-write |
| Policy Engine (`OA_FieldWritePolicyEngine`, FillEmptyOnly) | created Leads are fresh → enrichment fill-empty applies cleanly downstream |
| Queue (`OA_EnrichmentQueueable`) | created Leads are standard Leads → enqueue-eligible (gated) |
| Audit (`OA_Enrichment_Change_Log__c`) | shared log; BLO writes `TYPE_CREATE`, enrichment writes `TYPE_ENRICH` |
| Preview / FillEmptyOnly / Rollback | shared semantics (preview 0 DML; fill-empty; snapshot rollback) |
| Exception handling (`OA_Enrichment_Exception__c`) | reused for review/exception routing |
**Enrichment is not activated** — only compatibility validated. A BLO-created Lead is a normal Lead the enrichment platform already handles.

## 7. Governance Model
Every transition is auditable (change log). **Human review** gates approval; **AI assistance** (summary/proposal) is advisory + dormant and writes no Leads; **Lead approval** requires an explicit APPROVED/LEAD_READY state set by a human; **enrichment approval** remains the enrichment platform's gated path; **campaign eligibility** stays with the existing campaign engine; **exceptions** route to `OA_Enrichment_Exception__c`; **rollback** is explicit/caller-invoked. **No AI, and no BLO code, writes a production Lead automatically or bypasses review** — creation acts only on human-approved candidates and only on manual invocation.

## 8. KPI Framework (design only)
**Executive:** Candidates · Approved · Rejected · Lead Creation Rate · Enrichment Rate · Campaign Rate · Meeting Rate · Opportunity Rate. **Operations:** Queue latency · Review backlog (Needs Review age) · Approval time · Duplicate rate (MATCH/attempted) · Enrichment latency · Lifecycle failures (FAILED gates). **Business Development:** Agency coverage · Prime-contractor coverage · Meeting conversion · Opportunity conversion. Sourced from `OA_Discovered_Organization__c`, `OA_Enrichment_Change_Log__c`, `OA_Connector_Run__c`, Lead, CampaignMember, Event — **no new object required**.

## 9. Validation (Phase 9)
- **No automatic Lead creation** (manual invocation only; no trigger/flow/schedule). ✅
- **No production Leads created** (check-only validate; Leads = 13,301 unchanged). ✅
- **No production Accounts modified** (1 unchanged). ✅ · **No automation / schedules / connector / Opportunity changes.** ✅
- **No production deployment** — check-only validate `0AfPn0000023fThKAI`, 8/8 tests pass; BLO classes in org = **0**. ✅

## 10. Executive Certification (Phase 10)
- **Is BLO complete?** **Yes for Phase 1** — the governed approval + Lead-creation + lifecycle engine is engineered, tested (check-only), and dormant.
- **Is Candidate approval complete?** **Yes** — full state machine + audit + guards.
- **Is Lead creation complete?** **Yes (engineering)** — gated, dedup-safe, validation-respecting, rollback-aware; **operational activation** requires a contact-email source (below).
- **Is the bridge to Lead Enrichment complete?** **Yes (validated)** — created Leads are standard Leads the enrichment platform already processes; enrichment not activated.
- **What remains before controlled production activation?** (a) **contact-email acquisition** (or an approved policy) so BLO-created Leads satisfy `Require_Email_Or_Contact_Person_Email`; (b) **deploy** the 4 classes (RED); (c) **least-privilege runtime user**; (d) a **reviewer approval UI/list action** (config); (e) first **supervised conversion pilot** (≤3, human-approved). None require new connectors or Opportunity Intelligence.

## 11. Technical Debt (classified)
- **Engineering:** contact-email/contact-discovery input for creation (the one functional gap); optional NAICS/E2; legacy connector dead-code (separate PR).
- **Configuration:** reviewer approval action/list views; SAM permset consolidation; Matching/Duplicate rules.
- **Administration:** least-privilege runtime user; deploy BLO; RC1 merges.
- **Operations:** lifecycle dashboards; review staffing; monitoring.
- **Future:** Meeting→Opportunity→Customer (close half).
*(Non-code removed from the engineering backlog.)*

## 12. Remaining Activation Gates (all 🔴)
1. Deploy BLO (4 classes + test) to production.
2. Provide a contact-email source (contact discovery or approved exception) — or accept that creation `FAILED/VALIDATION` until contact exists.
3. Least-privilege runtime user.
4. Reviewer approval action (config).
5. Supervised conversion pilot (≤3, human-approved, preview→commit).

## 13. PASS / WARN / FAIL — 🟢 PASS
Lifecycle architecture completed · lifecycle service engineered · candidate approval engineered · Lead creation engineered · enrichment integration validated · governance completed · KPI framework completed · **no duplicate metadata · no production writes · no automation · no schedules · one feature branch · (one PR to open) · no merge.**

## 14. Definition of Done & Exact Next Engineering Program
**DoD (Phase 1):** engine + approval + creation + integration validated, check-only green, dormant, documented — **met.**
**Exact next engineering program:** **BLO Phase 2 — Contact Resolution & Supervised Conversion Activation**: add a governed contact-email input (contact-discovery adapter or approved policy) so created Leads satisfy the org validation rule, then deploy the 4 classes and run the first supervised ≤3 human-approved conversion pilot (preview→commit) with least-privilege runtime user. This completes controlled production activation of the acquisition→enrichment bridge — the last step before Opportunity Intelligence.
