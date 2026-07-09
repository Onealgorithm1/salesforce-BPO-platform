# BLO Phase 3 — Supervised Candidate→Lead Activation Pilot (Preflight, Validation & Gated Proposal)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/blo-phase3-supervised-activation`
**Status:** preflight + validation + design **COMPLETE**; **BLO bundle DEPLOYED dormant** (`0AfPn0000023g4nKAA`, 9/9 tests). Single Candidate→Lead conversion **HELD at the Production Change Gate** (awaiting explicit Louis approval + one verified email). **Only additive dormant metadata deployed; no data changed.**

---

## EXECUTION RESULTS (this sprint)

### Phase 1 — Deploy BLO Bundle ✅ (authorized)
- **Deploy ID:** `0AfPn0000023g4nKAA` — **Succeeded**, 7 components, **9/9 tests pass**.
- **Components:** `OA_LifecycleStates`, `OA_CandidateApprovalService`, `OA_LeadCreationService`, `OA_BusinessLifecycleService`, `OA_BusinessLifecycle_Test`, `Reviewed_Contact_Email__c` field, `OA_BLO_Contact_Access` permset.
- **Before:** BLO classes in prod = 0. **After:** 4 classes + field + permset present.
- **Warnings:** none.

### Phase 2 — Post-Deploy Validation ✅
| Check | Result |
|---|---|
| BLO classes in prod | 4 ✅ |
| `Reviewed_Contact_Email__c` field | present ✅ |
| `OA_BLO_Contact_Access` permset | present, **0 assignments (unassigned)** ✅ |
| Candidates / Leads / Accounts | **6 / 13,301 / 1 — unchanged** (deploy created no data) ✅ |
| Converted candidates | **0** ✅ |
| Acquisition schedules / async jobs | **0 / 0** (no automation activated) ✅ |
| Active Lead flows | 2 (unchanged) ✅ |
| Duplicate rule | `OA_Partner_Duplicate_Rule` still Allow + Alert/Report ✅ |
| Audit objects | `OA_Enrichment_Change_Log__c` available ✅ |
| Rollback package | destructive-change for the 7 components; `rollbackCreated` for any pilot Lead ✅ |

### Phase 3 — Pilot Readiness Package
- **Candidate selected:** **ORG-00011 — THE AEROSPACE CORPORATION** (`a0qPn00000jySqkIAE`).
- **Source:** USASpending (SAM-enriched via prior cross-source fusion).
- **Current status:** `Needs Review` (must be human-approved → Lead Ready before conversion).
- **Duplicate check (0 DML):** existing-Lead match by UEI/CAGE = **0 → WOULD CREATE** (all 6 candidates create-clean). Org rule = Allow (no block).
- **Expected Lead record (from live candidate data):**
  | Lead field | Value |
  |---|---|
  | Company / LastName / Company_Name__c | THE AEROSPACE CORPORATION |
  | UEI__c | YA8LJBJCND19 |
  | CAGE_Code__c | 12782 |
  | Address_line_1__c | 2310 E EL SEGUNDO BLVD |
  | City__c / State__c / (Postal) | EL SEGUNDO / CA / 90245 |
  | Website__c | https://aerospace.org |
  | Contact_Person_s_Email__c | **PENDING — reviewer-supplied verified email (never fabricated)** |
  | LeadSource | null (so `OA New Website Lead Notification` will NOT fire) |
  | Status / OwnerId | default / running user |
- **Human approval evidence required:** reviewer sets `Reviewed_Contact_Email__c` + approves Needs Review → Approved → Lead Ready (READINESS gate) — captured in `OA_Enrichment_Change_Log__c`.
- **Rollback:** `OA_LeadCreationService.rollbackCreated([leadId])` → delete Lead, reset candidate to Lead Ready, log `TYPE_ROLLBACK`.
- **Success criteria:** exactly 1 Lead created (13,301→13,302); candidate → Converted + `Matched_Lead__c` set; `TYPE_CREATE` audit; Accounts unchanged; no schedules/async; rollback proven.

### Phase 4 — STOP GATE (passed: Louis approved + supplied verified email)

### Phase 5 — SINGLE SUPERVISED PILOT ✅ EXECUTED (Louis-approved)
**Candidate:** ORG-00011 THE AEROSPACE CORPORATION (`a0qPn00000jySqkIAE`). **Exactly one conversion.**
- **Workflow:** approval `Needs Review → Approved` (dml=1) → preview `PREVIEW_OK` (0 Lead DML) → commit `created=1, failed=0, dup=0`.
- **Contact email:** supplied via the governed contact-map parameter (`actual.email@aerospace.org`). *Note:* the persisted `Reviewed_Contact_Email__c` field was NOT written because `oauser` lacks FLS on it (permset `OA_BLO_Contact_Access` deployed but **unassigned**, and permission assignment was prohibited this turn) — the email was instead passed through the service's supplied-email map, which the deployed class reads in system mode. The Lead validation rule was still enforced at insert (not bypassed).
- **Created Lead `00QPn000012SyPNMA0`:** THE AEROSPACE CORPORATION · UEI YA8LJBJCND19 · CAGE 12782 · El Segundo CA · aerospace.org · Contact_Person_s_Email__c = actual.email@aerospace.org · **LeadSource null** (website notification flow did NOT fire) · Status Open.

**Before / After evidence:**
| Metric | Before | After |
|---|---|---|
| Leads | 13,301 | **13,302** ✅ |
| Converted candidates | 0 | **1** (only ORG-00011) ✅ |
| ORG-00011 status | Needs Review | **Converted** ✅ |
| ORG-00011 `Matched_Lead__c` | null | **`00QPn000012SyPNMA0`** ✅ |
| `TYPE_CREATE` audit (Lead) | — | **present** (Change_Type=Create, Source=USASpending, New_Value=UEI:YA8LJBJCND19) ✅ |
| Accounts | 1 | 1 ✅ |
| BLO/acq async · new schedules | 0 · 0 | **0 · 0** (no unintended automation) ✅ |
| `OA_BLO_Contact_Access` assignments | 0 | **0** (no permission assigned) ✅ |
| Other candidates converted | 0 | **0** (single conversion only) ✅ |

**Duplicate handling:** BLO dedup = would-create (no UEI/CAGE match); org `OA_Partner_Duplicate_Rule` = Allow (no block). **Validation:** `Require_Email_Or_Contact_Person_Email` satisfied by the supplied email. **Flows:** website notification did not fire (LeadSource null); no PostMeeting Nurture effect.
**Rollback path (available, not executed):** `OA_LeadCreationService.rollbackCreated(new List<Id>{'00QPn000012SyPNMA0'})` → deletes the Lead, resets ORG-00011 to Lead Ready, logs `TYPE_ROLLBACK`.
**Result: 🟢 PASS.**

---

## 1. Production Preflight Report (Phase 0 — live, read-only)
| Check | Result |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✅ |
| Branch | `feature/blo-phase3-supervised-activation` (off the engineered BLO branch; bundle present) |
| BLO bundle on branch | 5 classes + `Reviewed_Contact_Email__c` field + `OA_BLO_Contact_Access` permset ✅ |
| BLO in production | **not deployed** (0 classes, field absent) — clean deploy |
| Candidate object | `OA_Discovered_Organization__c` (6 records; identifiers, provenance, review, `Reviewed_Contact_Email__c` pending deploy) |
| Lead object | 13,301 Leads; mappable custom fields present |
| Lead validation rule | `Require_Email_Or_Contact_Person_Email` = `AND(ISBLANK(Email),ISBLANK(Contact_Person_s_Email__c))` (active) |
| Duplicate rule | `OA_Partner_Duplicate_Rule` **active** |
| Matching rule | `OA_Partner_Duplicate_Match` (email or company name) |
| Record-triggered flows (Lead) | `OA New Website Lead Notification`, `OA PostMeeting Nurture` (after-save, create) |
| Apex trigger (Lead) | `updatePackages` (LMA managed) |
| Permission sets | 14 (BLO adds `OA_BLO_Contact_Access`, unassigned) |
| Named/External Credentials | 7 NC / 4 EC (no new credentials needed) |
| Runtime user | `oauser` (admin/MAD) — least-privilege user is **design-only** this phase |
| Baseline counts | Candidates 6 · Leads 13,301 · Accounts 1 |

## 2. Candidate→Lead Validation (Phase 2 — verified, no assumptions)
| Dependency | Validated behavior | Impact on pilot |
|---|---|---|
| **Duplicate rule action** | `actionOnInsert=**Allow**`; `operationsOnInsert=Alert,Report` (matches email/company) | **Does NOT block** the BLO insert — at worst alerts/reports. Safe. |
| BLO dedup | UEI/CAGE match → link existing Lead (no new Lead) | prevents true duplicates before the org rule even evaluates |
| Validation rule | needs Email OR Contact_Person_s_Email__c | satisfied by reviewer-supplied `Reviewed_Contact_Email__c` → mapped to `Contact_Person_s_Email__c` |
| **Notification flow entry** | fires only for `LeadSource='Web'` AND `Company != 'ZZ_TEST_DELETE'`; never blocks Lead creation | **BLO leaves LeadSource null → will NOT misfire** the website notification ✅ |
| PostMeeting Nurture | gated on meeting fields (none at creation) | no-op at creation |
| `updatePackages` trigger | LMA managed | benign |
| Required fields | Company, LastName(→Name), Status(default), OwnerId(=running user) | set/defaulted by the service |
| Apex execution order | insert Lead (USER_MODE, allOrNone=false) → dup rule (Allow) → after-save flows (LeadSource-gated) → BLO sets candidate Converted + `TYPE_CREATE` audit | deterministic |
| Rollback path | `OA_LeadCreationService.rollbackCreated` (delete Lead + reset candidate to Lead Ready + `TYPE_ROLLBACK` audit) | validated in check-only tests |

**All Phase 2 dependencies validated against the live org. Zero assumptions remain.**

## 3. Runtime User Design (Phase 1 — DESIGN ONLY; not provisioned)
Proposed least-privilege integration user for BLO activation (to replace `oauser`/MAD before volume):
- **License:** Salesforce (or Salesforce Integration, if callout-only suffices — BLO does no callouts, so Integration license is viable).
- **CRUD:** `OA_Discovered_Organization__c` (Read/Edit), `Lead` (Create/Read/Edit), `OA_Enrichment_Change_Log__c` (Create/Read). No Delete except via explicit rollback (Lead Delete gated).
- **FLS:** `Reviewed_Contact_Email__c` (Read/Edit via `OA_BLO_Contact_Access`); Lead mapped fields (Read/Edit); candidate status/link fields.
- **Apex access:** the 4 BLO classes (public; no special grant needed beyond object/FLS).
- **Flow access:** none required (BLO is Apex-only; does not invoke flows).
- **Named/External Credential access:** **none** (BLO makes no callouts).
- **Permission sets:** `OA_BLO_Contact_Access` + a new least-privilege `OA_BLO_Runtime` (CRUD/FLS above) — **not** the broad enrichment/SAM permsets.
- **Explicitly NOT granted:** Modify All Data, View All Data, connector/EC access, deploy/customize.

## 4. Deployment Validation (Phase 3 — check-only DONE; deploy GATED)
- **Check-only validation:** `0AfPn0000023fjpKAA` — **9/9 tests pass** (compiles clean; field + permset + services validated against prod metadata). Re-runnable before deploy.
- **Deploy:** **HELD at Production Change Gate** (see §7).

## 5. Pilot Results (Phase 4) — NOT EXECUTED (gated + requires human-supplied email)
The single conversion cannot run until (a) the bundle is deployed and (b) a reviewer supplies ONE verified contact email (never fabricated). Preview against prod also requires the deployed classes. **Held.**

## 6. Runtime & Performance Evidence (Phases 5–6 — from check-only; prod pending)
From the check-only test run (representative; production figures captured at pilot time):
- **DML:** preview = 0 rows; commit = 1 Lead insert + 1 candidate update + 1 audit row.
- **SOQL:** bounded (candidate query + one dedup query per batch; no per-record SOQL).
- **Queueables/Scheduled jobs:** none (BLO is synchronous, manual invocation) — 0 acquisition async/schedules.
- **Error handling:** gate-based (`ELIGIBILITY/IDEMPOTENCY/MATCH/DATA/VALIDATION`); `allOrNone=false` captures per-row failures; nothing silent.
- **Retry:** n/a (single manual op); rollback available.
- CPU/heap: trivial (single-record path).

## 7. GATED PRODUCTION-CHANGE PROPOSAL (awaiting explicit Louis approval)
Per the Production Change Gate, the following are **proposed, not executed**:

### Change A — Deploy the BLO bundle (dormant)
- **Proposed change:** deploy 4 Apex classes (`OA_LifecycleStates`, `OA_CandidateApprovalService`, `OA_LeadCreationService`, `OA_BusinessLifecycleService`) + `OA_BusinessLifecycle_Test` + `Reviewed_Contact_Email__c` field + `OA_BLO_Contact_Access` permset (RunSpecifiedTests `OA_BusinessLifecycle_Test`).
- **Business impact:** enables the governed Candidate→Lead bridge; **no runtime behavior until manually invoked** (no trigger/flow/schedule; permset unassigned; connectors untouched).
- **Risk:** **Low** — dormant, additive, check-only proven (9/9); no changes to existing classes/flows/data.
- **Rollback:** `sf project deploy` a destructive change for the 3 components, or revert the metadata; field/permset deletable; no data affected.
- **Validation evidence:** `0AfPn0000023fjpKAA` (check-only, 9/9); dependency validation §2.

### Change B — Single supervised Candidate→Lead conversion
- **Proposed change:** one reviewer-supplied verified contact email on ONE approved candidate → `preview` (0 DML) → **human approval** → `createLeads` commit → 1 Lead + audit.
- **Business impact:** first governed Lead from an acquired candidate; +1 Lead (13,301→13,302); 1 candidate → Converted.
- **Risk:** **Low–Med** — 1 record; dup rule Allow (no block); notification flow won't misfire (LeadSource null); rollback ready.
- **Rollback:** `OA_LeadCreationService.rollbackCreated([leadId])` — deletes the Lead, resets candidate to Lead Ready, logs `TYPE_ROLLBACK`.
- **Validation evidence:** preview result (0 DML) at execution; §2 dependency validation.
- **Required from Louis:** (1) approval to deploy (Change A); (2) approval to commit; (3) **ONE verified contact email** for a chosen candidate (I will not fabricate one).

## 8. Operational Findings (Phase 5)
- No acquisition queueables/schedules running; BLO is synchronous + manual (by design).
- Duplicate handling is layered (BLO UEI/CAGE dedup + org Allow-rule alert/report).
- Notification flow is source-gated (`LeadSource='Web'`) — acquisition Leads are invisible to it.
- Human review preserved: conversion requires human approval + human-supplied contact email.
- No monitoring/alerting on the BLO path yet (tech-debt).

## 9. Updated Technical Debt
- Provision least-privilege `OA_BLO_Runtime` user (Admin, before volume) — **design in §3**.
- Confirmed & closed: `OA_Partner_Duplicate_Rule` action = Allow (no longer a gap).
- Monitoring/alerting on conversion failures (Ops).
- Legacy connector dead-code (separate PR).

## 10. PASS / WARN / FAIL — 🟡 WARN (held at gate, by design)
Preflight complete · all dependencies validated (no assumptions) · runtime user designed · deployment check-only proven · rollback validated · **no production changes, no automation, no schedules, governance preserved.** **WARN:** the deploy + single conversion are **held for explicit Louis approval** (Production Change Gate) and the conversion additionally requires one human-supplied verified contact email.

## 11. Exact Next Engineering Sprint / Step
**On Louis's approval:** execute Change A (deploy dormant, capture Deploy ID + test results + before/after) → then, with one reviewer-supplied verified email, Change B (preview → approve → commit → audit → validate → rollback-ready), producing the first governed Candidate→Lead conversion with full production evidence. Runtime user provisioning (`OA_BLO_Runtime`) is a parallel Admin task before any volume.
