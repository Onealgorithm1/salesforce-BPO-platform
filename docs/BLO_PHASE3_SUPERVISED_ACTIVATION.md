# BLO Phase 3 — Supervised Candidate→Lead Activation Pilot (Preflight, Validation & Gated Proposal)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/blo-phase3-supervised-activation`
**Status:** read-only preflight + validation + design **COMPLETE**. Deploy + pilot **HELD at the Production Change Gate** (awaiting explicit Louis approval). **No production changes made.**

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
