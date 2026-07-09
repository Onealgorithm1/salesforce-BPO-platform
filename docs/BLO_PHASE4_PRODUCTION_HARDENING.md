# BLO Phase 4 — Production Hardening & Supervised Scale Readiness

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/blo-phase4-production-hardening`
**Mode:** engineering · runtime hardening · monitoring · security · supervised-scale readiness. **No new deploy this sprint (BLO already live); no permission assignments; no runtime-user provisioning; no automation; no scheduling; no bulk conversion; no merge.**
**Baseline:** first governed conversion complete (Lead `00QPn000012SyPNMA0`; Deploy `0AfPn0000023g4nKAA`; PR #52 open).

---

## 1. Executive Summary
The Candidate→Lead path is **functionally proven** (1 governed conversion) and now **hardened for repeatable supervised operation**: the FLS gap from the pilot is diagnosed with a clear fix, a least-privilege `OA_BLO_Runtime` user is designed, a **runnable monitoring pack** gives immediate visibility (plus report/dashboard specs), the error-handling path is reviewed (solid; minor recommendations), and a **conservative supervised-batch design (≤3)** is specified. All work this sprint is reversible/read-only + documentation — **no production changes**. The two remaining enablers (assign `OA_BLO_Contact_Access`, provision `OA_BLO_Runtime`) are **gated** (permission/user changes). **Verdict: 🟢 PASS** (supervised-repeatable, gated only on the two admin enablers).

## 2. Baseline Verification (Phase 0 — live)
| Check | Result |
|---|---|
| Branch / Org | `feature/blo-phase4-production-hardening` / `00Dbn00000plgUfEAI` ✅ |
| PR #52 | **OPEN** (not merged) ✅ |
| BLO classes in prod | 4 ✅ |
| Lead `00QPn000012SyPNMA0` | exists ✅ |
| ORG-00011 status | Converted (Matched_Lead set) ✅ |
| TYPE_CREATE audit | 1 ✅ |
| Leads / Converted | 13,302 / 1 ✅ |
| BLO async / schedules | 0 / 0 ✅ |
| `OA_BLO_Contact_Access` assignments | 0 (unassigned) ✅ |

## 3. FLS / Permission Hardening (Phase 1)
1. **Why `oauser` lacked FLS on `Reviewed_Contact_Email__c`:** metadata field deploys do **not** set field-level security; the admin profile did not auto-grant it. Both the REST query and direct anonymous-apex field reference failed (`No such column`) — an FLS visibility failure, not a missing field.
2. **Is the service-map email path acceptable long-term?** As a **programmatic/contact-connector input**, yes — but for the **human reviewer path** it is not ideal (the reviewer should set a persisted, auditable field in the UI). Use the map for automated contact sources; use the field for reviewers.
3. **Should reviewer-email be persisted on Candidate?** **Yes** — for provenance + an auditable reviewer action. That requires FLS on `Reviewed_Contact_Email__c`.
4. **Minimum permissions:** Read/Edit FLS on `Reviewed_Contact_Email__c` for reviewers + the runtime user; candidate Read/Edit; Lead Create/Read/Edit; change-log Create/Read.
5. **Is `OA_BLO_Contact_Access` sufficient?** For the **FLS** piece, yes (it grants Read/Edit on the field). It does **not** grant object CRUD — those come from the runtime/reviewer permsets.
6. **Is `OA_BLO_Runtime` required?** **Yes, before repeatable/volume operation** — the pilot ran as `oauser`/MAD (top risk). See Phase 2.
7. **Security risks:** running as MAD (over-broad); field invisible to reviewers until FLS assigned; map-path email bypasses the persisted audit field (mitigated by Lead + change-log audit).
8. **Recommended path (gated):** **assign `OA_BLO_Contact_Access`** to reviewers + runtime user (enables the field/UI path) → **provision `OA_BLO_Runtime`** (replaces MAD) → then reviewers set the email in the UI and conversions use the persisted field. Both are 🔴 (permission/user) — **held for approval**.

## 4. `OA_BLO_Runtime` Least-Privilege User Design (Phase 2 — design only)
1. **Profile:** minimal custom profile (clone of "Minimum Access - Salesforce") or **Salesforce Integration** license (BLO makes no UI/callout needs) — Integration license viable since BLO is Apex-only, no callouts.
2. **Permission sets:** `OA_BLO_Runtime` (new, object/FLS below) + `OA_BLO_Contact_Access` (field FLS). **Not** enrichment/SAM/connector permsets, **not** MAD/ViewAll.
3. **Object CRUD:** `OA_Discovered_Organization__c` R/Edit; `Lead` Create/R/Edit; `OA_Enrichment_Change_Log__c` Create/R. Lead **Delete** only if rollback is delegated (else keep rollback with an admin).
4. **FLS:** candidate status/link + `Reviewed_Contact_Email__c`; Lead mapped fields (Company, LastName, UEI, CAGE, CIK, EIN, NAICS, address, city, state, website, Compatibility_Score, Contact_Person_s_Email).
5. **Apex class access:** the 4 BLO classes (public; granted via object/FLS — no explicit class access needed unless classes are set to profile-restricted).
6. **Flow access:** none (BLO invokes no flows).
7. **Named Credential access:** none. **8. External Credential access:** none (no callouts).
9. **Login/security:** IP/login-hours restricted; MFA; no API-only unless required; dedicated, non-human.
10. **Audit:** all writes captured in `OA_Enrichment_Change_Log__c`; login history monitored.
**Implementation steps (do NOT run unassisted — 🔴 gated):** create user/permset `OA_BLO_Runtime` → grant CRUD/FLS above → assign `OA_BLO_Runtime` + `OA_BLO_Contact_Access` → re-run a supervised conversion as that user to confirm.

## 5. Monitoring (Phase 3) — runnable pack (immediate) + report/dashboard specs
**Runnable monitoring pack (works today; no metadata needed):**
| # | Business question | SOQL |
|---|---|---|
| M1 | Candidate conversion funnel | `SELECT Qualification_Status__c, COUNT(Id) FROM OA_Discovered_Organization__c GROUP BY Qualification_Status__c` → Converted 1 / Needs Review 5 |
| M2 | BLO Lead create/rollback audit | `SELECT Change_Type__c, COUNT(Id) FROM OA_Enrichment_Change_Log__c WHERE Target_Object__c='Lead' AND Change_Type__c IN ('Create','Rollback') GROUP BY Change_Type__c` → Create 1 |
| M3 | Conversion-blocked (approved but no email) | `SELECT COUNT() FROM OA_Discovered_Organization__c WHERE Qualification_Status__c IN ('Approved','Lead Ready')` → 0 |
| M4 | BLO Lead quality | `SELECT Id, Company, UEI__c, CAGE_Code__c, Contact_Person_s_Email__c FROM Lead WHERE Id IN (SELECT Matched_Lead__c FROM OA_Discovered_Organization__c WHERE Qualification_Status__c='Converted')` |
| M5 | Unexpected automation / failures | `SELECT COUNT() FROM AsyncApexJob WHERE Status='Failed' AND CreatedDate=LAST_N_DAYS:1` → 0; BLO async 0 |
**Recommended reports/dashboards (build when volume warrants; extend the existing `OA_Discovered_Organizations` report type + a change-log report type — no new object):**
- *Candidate Conversion Funnel* (candidate by Qualification_Status).
- *BLO Conversion Audit* (change log Create/Rollback over time).
- *Conversion-Blocked Candidates* (Approved/Lead Ready with no reviewed email).
- *BLO Lead Quality* (converted Leads: UEI/CAGE/email/completeness).
- *Automation/Failure watch* (async failures, unexpected schedules).
*(Not built this sprint — data is a single conversion; the runnable pack provides immediate visibility without report-XML churn.)*

## 6. Error-Handling Review (Phase 4)
| Path | Current behavior | Assessment / recommendation |
|---|---|---|
| Validation failure | `Database.insert(..., false, USER_MODE)` → `FAILED/VALIDATION` with SF error text | ✅ solid; not silent |
| Duplicate failure | BLO UEI/CAGE dedup → `MATCH` link; org rule Allow (no block) | ✅ solid |
| Missing email | insert rejected by rule → `FAILED/VALIDATION`; preview WARNs | ✅ solid |
| Candidate-state failure | gates `ELIGIBILITY/IDEMPOTENCY` | ✅ solid |
| Lead insert failure | per-row `RowOutcome`, `allOrNone=false` (partial success safe) | ✅ solid |
| **Audit insert failure** | `OA_ChangeLogService.commitLogs` = `Database.insert(logs, false)` — best-effort, **not surfaced** | 🟡 **recommend** surfacing audit-write failures into `RunSummary` (small, additive) — deferred (avoid a redeploy for marginal value at this scale) |
| Rollback failure | `rollbackCreated` uses `Database.delete(false)` / `update(false)` — best-effort | 🟡 recommend capturing delete/reset failures — deferred |
| User/admin messages | `RowOutcome.gate/reason` (admin-readable); no end-user UI | ✅ adequate for supervised; UI later |
**Conclusion:** error handling is production-adequate for supervised operation. The two 🟡 items are minor observability improvements — **documented, not changed** this sprint (no redeploy, avoid overengineering).

## 7. Controlled Supervised Batch Design (Phase 5 — design only, NOT executed)
1. **Batch size:** **≤3 candidates** per supervised run (conservative; matches prior pilot caps).
2. **Eligibility:** status `Approved`/`Lead Ready`; has `Organization_Name__c`; not already `Converted`/linked; UEI or CAGE present (federal-contractor ICP).
3. **Verified-email rule:** each candidate must have a **human-verified** `Reviewed_Contact_Email__c` (field, after FLS assigned) — never fabricated; no batch member without one.
4. **Duplicate review:** run the dedup preview first; any `MATCH` is **linked, not created**; review before commit.
5. **Human approval:** reviewer approves each candidate + supplies each email; explicit go per batch.
6. **Rollback:** capture all created Lead Ids; `rollbackCreated(createdLeadIds)` reverses the whole batch.
7. **Monitoring checklist:** M1–M5 before + after; confirm Lead delta = batch size; 0 unexpected automation.
8. **Success criteria:** all approved candidates converted (or cleanly `FAILED`/`MATCH`); Lead delta exact; audits present; Accounts unchanged; rollback proven.
9. **Stop conditions:** any unexpected automation/schedule; Accounts modified; Lead delta ≠ expected; any missing-email member; any silent failure. **No unattended automation, no scheduling, no bulk.**

## 8. Validation (Phase 7)
- **Metadata changed this sprint:** **none** (documentation + read-only analysis; monitoring via runnable SOQL). **No new Deploy/Validation ID.** Prior deploy `0AfPn0000023g4nKAA` stands.
- **Apex tests:** unchanged (`OA_BusinessLifecycle_Test` 9/9 at deploy).
- **Before/after production state:** Leads 13,302 (unchanged), Converted 1 (unchanged), 0 async/schedules, 0 permset assignments, Accounts 1 — **no production changes this sprint**.
- **Rollback plan (pilot Lead):** `OA_LeadCreationService.rollbackCreated(new List<Id>{'00QPn000012SyPNMA0'})`.

## 9. Risks
- Runtime user = MAD until `OA_BLO_Runtime` provisioned [High] — gated fix designed.
- Reviewer field path unusable until `OA_BLO_Contact_Access` assigned [Med] — gated.
- Audit/rollback failures best-effort (not surfaced) [Low] — recommended improvement.
- No formal dashboards yet [Low] — runnable pack mitigates.

## 10. PASS / WARN / FAIL — 🟢 PASS
Candidate→Lead path is ready for **repeatable supervised** operation: clear permissions model (Phase 3/4 designs), documented FLS behavior + fix, monitoring visibility (runnable pack), rollback path, audit trail, **no unattended automation, no bulk conversion, no workstream drift, no production changes this sprint.** Gated enablers (permset assignment + runtime user) are 🔴 and held for approval.

## 11. Exact Next Engineering Sprint
**BLO Phase 5 — Supervised Batch Enablement (gated):** (1) 🔴 assign `OA_BLO_Contact_Access` + provision/assign `OA_BLO_Runtime` (least-privilege); (2) re-run a supervised **single** conversion as the runtime user via the **persisted field** path (proves FLS/UI reviewer flow); (3) execute one **≤3 supervised batch** per the Phase 5 design with full monitoring + rollback. No automation, no scheduling, no bulk.
