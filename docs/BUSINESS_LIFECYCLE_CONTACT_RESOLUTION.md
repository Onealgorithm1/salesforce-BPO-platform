# Business Lifecycle Orchestration — Phase 2: Company Intelligence, Contact Resolution & Lead-Ready Conversion

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/business-lifecycle-orchestration`
**Mode:** engineering (source-only) + **check-only validation** (`0AfPn0000023fjpKAA`, 9/9 tests pass). **No deploy · no merge · no automation · no scheduling · no production writes · human review never bypassed · no fake contact data.**
**Inspection order:** live org → runtime → repository → docs.

---

## 1. Executive Summary
The Lead-readiness gap is solved **without fabricating contact data or bypassing validation**. Live audit confirmed the exact rule — `AND(ISBLANK(Email), ISBLANK(Contact_Person_s_Email__c))` — and that the Candidate object has **no email field**. The minimal, governed fix: **one new Candidate field `Reviewed_Contact_Email__c` (Email)** that a **human reviewer supplies during approval**, plus a **`READINESS` gate** (a candidate cannot reach *Lead Ready* without it) and a Lead-creation service that **reads the reviewed email and still refuses to bypass** the org rule. Delivered source-only with an FLS permission set, **check-only validated (9/9)**, **not deployed**. **Verdict: 🟡 WARN** (by design — new metadata is required and contact data must be human-supplied), success criteria otherwise **PASS**.

## 2. Live Org Audit
| Item | Finding |
|---|---|
| Org / counts | `00Dbn00000plgUfEAI`; Candidates **6**, Leads **13,301**, Accounts **1** |
| Active Lead validation rule | `Require_Email_Or_Contact_Person_Email` = `AND(ISBLANK(Email), ISBLANK(Contact_Person_s_Email__c))` → blocks Leads with neither |
| Required Lead fields | `Company`, `LastName`, `Status`, `OwnerId` (std); email satisfied by `Email` **or** `Contact_Person_s_Email__c` |
| Candidate fields (email?) | **No email field**; has `Phone__c`, `Website__c`, identifiers, `Discovery_Metadata__c`, review fields — but **no contact email/person** |
| Existing enrichment fields (Lead) | rich set incl. `Company_Name__c`, `UEI__c`, `CAGE_Code__c`, `CIK__c`, `EIN__c`, `Primary_NAICS_code__c`, `Contact_Person_Name__c`, `Contact_Person_s_Email__c`, `AI_Summary__c`, `Compatibility_Score__c`, `USASpending_*` |
| Review queue / states | `Qualification_Status__c` Text(20) free-text; `Recommended_Action__c`, `Qualification_Reasons__c`; exception queue `OA_Enrichment_Exception__c` |
| Approval states (BLO Phase 1) | Needs Review → Approved/Rejected/Deferred → Lead Ready → Converted |

**Conclusion:** contact email is genuinely absent on candidates → a reviewer-supplied field is required (WARN).

## 3. Lead Ready Criteria
| Criterion | Tier |
|---|---|
| Company (`Organization_Name__c`→Company/LastName) | **Required by Salesforce** |
| Lead Status / Owner | **Required by Salesforce** (Status default; Owner = running user) |
| **Email or Contact Person Email** (`Reviewed_Contact_Email__c`→`Contact_Person_s_Email__c`) | **Required by Salesforce** (validation rule) + **Required by governance** (human-supplied) |
| Human approval (status APPROVED/LEAD_READY) | **Required by governance** |
| Duplicate check (UEI/CAGE vs existing Leads) | **Required by governance** |
| Provenance (candidate link + audit) | **Required by governance** |
| Confidence score (`Confidence_Score__c`→`Compatibility_Score__c`) | **Campaign quality** |
| Website / Phone / Address / UEI / CAGE / CIK / EIN / NAICS | **Campaign quality** (mapped where present) |
| Contact person name, SAM/USASpending/SEC enrichment | **Optional enrichment** (downstream) |

## 4. Company Intelligence Model (reuse-first — no new object)
The **existing `OA_Discovered_Organization__c`** already IS the company-intelligence model: identity (`Organization_Name__c`/`Normalized_Name__c`), gov identifiers (`UEI__c`/`CAGE_Code__c`/`CIK__c`/`EIN__c`/`NPI__c`), website/domain (`Website__c`), address (`Address__c`/`City__c`/`State__c`/`Postal_Code__c`), phone (`Phone__c`), NAICS (`NAICS__c`), confidence (`Source_Confidence__c`/`Confidence_Score__c`), completeness (`OA_LeadCompleteness`), provenance (`Discovery_Metadata__c` `sources[]`), missing-data reasons (`Qualification_Reasons__c`). SAM/USASpending/SEC data is **fused into these fields** (proven in Phase 17b). **No duplicate object or field created for company intelligence** — the only new field is the contact-email gap below.

## 5. Contact Resolution Strategy (approved sources only)
| Option | Verdict |
|---|---|
| Existing candidate data | No email present — insufficient alone |
| SAM website/phone | Available (website/phone), **but no public contact email** in entity sections |
| **Reviewer supplies contact email during approval** | ✅ **CHOSEN** — human-verified, auditable, no scraping, no fabrication |
| Domain-derived business email | ❌ guessed/synthetic — not used (no fake data) |
| Website contact-form scraping / LinkedIn / Meta | ❌ prohibited |
| Future approved contact-resolution connector | 🟡 future — the service already accepts a programmatic email map for this |

**No scraping, no invented emails, no placeholders.** The reviewer (a human) supplies a verified contact email; a future *approved* connector may later populate the same field/map.

## 6. Metadata Reuse / Gap Analysis
- **Reused (no new metadata):** the entire candidate/company-intelligence model, audit/rollback (`OA_ChangeLogService`), identity/dedup, policy engine, Lead target fields.
- **Genuine gap → minimum new metadata (2 components):**
  1. **`OA_Discovered_Organization__c.Reviewed_Contact_Email__c`** (Email) — the reviewer-supplied contact email. No existing candidate field can safely hold it.
  2. **`OA_BLO_Contact_Access`** permission set — FLS (Read+Edit) on that field for reviewers/runtime user (per the "bundle FLS with new fields" rule). Unassigned by default.
- **No new object, no changes to Lead metadata, no picklist changes.**

## 7. Service Changes (source-only, check-only validated)
- **`OA_LeadCreationService`** — SOQL now selects `Reviewed_Contact_Email__c`; resolves the contact email as *explicit map param → else the reviewed field* (**never fabricated**); preview WARNs when absent; commit still inserts in USER_MODE with `allOrNone=false` so the org rule blocks a no-email Lead as `FAILED/VALIDATION` (candidate untouched). Idempotent, bulk-safe, dedup + provenance unchanged.
- **`OA_CandidateApprovalService`** — new **`READINESS`** gate: a transition to **Lead Ready** is blocked unless `Reviewed_Contact_Email__c` is present. Also fixed to update via a fresh sObject (only changed fields) so a USER_MODE write never touches a field the user lacks FLS on.
- **`OA_BusinessLifecycleService` / `OA_LifecycleStates`** — unchanged behavior; orchestrator passes the email map through.
- **Test** — `OA_BusinessLifecycle_Test` extended: field-read happy path, READINESS block then allow, map override, no-email VALIDATION block, dedup/idempotency, rollback. **9/9 pass.**

## 8. Reviewer Workflow
```
Candidate Needs Review
  → Reviewer verifies company (identity, UEI/CAGE, website)
  → Reviewer sets Reviewed_Contact_Email__c (verified contact) + Approves
  → Approve to "Lead Ready"  (READINESS gate: requires the reviewed email)
  → Manual conversion (OA_BusinessLifecycleService.createLeads / OA_LeadCreationService.create)
  → Lead created (Contact_Person_s_Email__c set) — satisfies the org rule
  → Enrichment queued/marked needed (existing platform; gated)
```
**UI/config needs (no automation):** assign `OA_BLO_Contact_Access` to reviewers; add `Reviewed_Contact_Email__c` + `Qualification_Status__c` + `Recommended_Action__c` to the candidate page layout / a review list view; provide a "Lead Ready" quick action or reviewers run the manual conversion. No trigger/flow/schedule.

## 8b. Lead target-state preflight (live org — inspected BEFORE the pilot, not after)
Runtime constraints on **Lead insert** that the pilot must account for:
| Constraint | Finding | Pilot implication |
|---|---|---|
| Validation rule | `Require_Email_Or_Contact_Person_Email` (active) | satisfied by the reviewed contact email (handled) |
| Required create fields | Company, LastName(→Name), Status(default), OwnerId(=running user) | set/defaulted by the service (handled) |
| **Duplicate rule** | **`OA_Partner_Duplicate_Rule` ACTIVE** on Lead | evaluates on the BLO insert; **confirm alert-vs-block + matching criteria first** — a block action could reject the insert (captured as `FAILED`, not bypassed) |
| **After-save flows** | **`OA New Website Lead Notification`, `OA PostMeeting Nurture`** fire on new Leads | **confirm entry criteria** so an acquired Lead does not wrongly notify as a "website lead" |
| Apex trigger | `updatePackages` (LMA managed) | benign |
| Approval process / assignment rule | none active | Owner = running user (handled) |

## 9. Supervised Pilot Runbook (execute only if authorized after this sprint)
- **Scope:** max **1** candidate; human-approved; **reviewed contact email required**; no Accounts; no campaign automation; no enrichment activation; no scheduling.
- **Prereqs (RED):** deploy the 4 classes + field + permset; assign `OA_BLO_Contact_Access` to the runtime user; least-privilege runtime user. **Confirm `OA_Partner_Duplicate_Rule` action and the two after-save flows' entry criteria (§8b) before the insert.**
- **Steps:**
  1. Reviewer sets `Reviewed_Contact_Email__c` on ONE approved candidate (verified email).
  2. `OA_CandidateApprovalService.transition([id],'Lead Ready','<reviewer>','verified',true)` → expect `applied=1` (READINESS satisfied).
  3. **Preview:** `OA_LeadCreationService.preview([id])` → `PREVIEW_OK`, `dmlRows=0`.
  4. **Commit:** `OA_BusinessLifecycleService.createLeads([id], null, true)` → `created=1`; candidate → `Converted`, `Matched_Lead__c` set; `TYPE_CREATE` audit written.
  5. **Validate:** exactly 1 Lead created with `Contact_Person_s_Email__c`; Accounts unchanged; 0 schedules/jobs; no enrichment run.
  6. **Rollback (if needed):** `OA_LeadCreationService.rollbackCreated([leadId])` → deletes Lead, resets candidate to Lead Ready, `TYPE_ROLLBACK` audit.

## 10. Validation
Check-only validate **`0AfPn0000023fjpKAA`** — **9/9 tests pass**. Post-checks: no production Leads created/modified (13,301 unchanged); Accounts unchanged (1); new field in org = **0**; new permset in org = **0**; no automation, no schedules, no connector changes, no Opportunity work.

## 11. PASS / WARN / FAIL — 🟡 WARN (success criteria otherwise met)
Active validation understood ✅ · Lead Ready model complete ✅ · contact-resolution path designed ✅ · BLO service updated ✅ · **no fake data / no bypassed validation** ✅ · check-only passed ✅ · no prod writes / no automation / no schedules ✅ · one PR ✅ · no merge ✅. **WARN drivers (expected):** new metadata is required (1 field + 1 permset) and **contact data must be human-supplied** (external automated contact source remains future work).

## 12. Remaining Activation Gates (🔴)
1. Deploy 4 classes + `Reviewed_Contact_Email__c` field + `OA_BLO_Contact_Access` permset.
2. Assign `OA_BLO_Contact_Access` to reviewers + runtime user; add field to layout/list view.
3. Least-privilege runtime user.
4. First supervised **1-candidate** Candidate→Lead pilot (Phase 9 runbook).
5. (Future) approved automated contact-resolution source to reduce manual email entry.

## 13. Exact Next Claude Workload
**BLO Phase 3 — Supervised Candidate→Lead Activation Pilot:** on explicit authorization, deploy the BLO bundle, assign the FLS permset to a least-privilege runtime user, have a reviewer supply one verified contact email, and run the **single-candidate** preview→commit conversion with full validation + rollback readiness — the first governed Lead created from an acquired candidate. No automation, no scheduling, no Accounts, no enrichment activation.
