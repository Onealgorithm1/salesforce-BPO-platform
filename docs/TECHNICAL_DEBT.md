# Technical Debt Register — One Algorithm BPO Platform

**Last updated:** June 19, 2026
**Source:** Salesforce Platform Baseline Assessment

---

## Critical

### TD-001 — No Sandbox Environment
**Severity:** Critical
**Impact:** All changes deploy directly to production. No UAT, no rollback path.
**Resolution:** Provision Full Sandbox (clone of production). Estimated cost: ~$0 if Enterprise license includes sandbox (verify). Estimated time to provision: 1–3 hours.
**Owner:** Unassigned
**Status:** Open

### TD-002 — Zero Metadata in Version Control
**Severity:** Critical
**Impact:** No audit trail for code changes. No rollback capability. No CI/CD possible.
**Resolution:** This repository. Baseline retrieval is the immediate next step.
**Owner:** Louis Rubino
**Status:** In Progress (Phase 0)

---

## High

### TD-003 — OA_EDWOSB_Outreach_Sequence Flow Deactivated
**Severity:** High
**Impact:** Primary email outreach sequence is not running. OA_FollowUpScheduler Apex is filling the gap but is not equivalent — misses conditional branching, reply detection integration.
**Resolution:** Investigate why flow was deactivated. Reactivate or rebuild with updated logic.
**Owner:** Unassigned
**Status:** Open

### TD-004 — 2 Paused FlowInterviews (lead_by_ramesh)
**Severity:** High
**Impact:** 2 flow interviews stuck at `sending_email` element, created by now-deactivated user Louis R (louisrubino@onealgorithm.com). These leads are not progressing through the sequence.
**Resolution:** Manually terminate paused interviews via Setup > Paused and Waiting Interviews. Reassign lead_by_ramesh flow owner to active user.
**Owner:** Unassigned
**Status:** Open

### TD-005 — AI Scoring Fields 0% Populated
**Severity:** High
**Impact:** Compatibility_Score__c and Geography_Tier__c exist on Lead object but are empty on all 13,286 leads. AI-driven lead prioritization is completely non-functional.
**Resolution:** Build OA_AI_LeadScorer Apex class with OpenAI callout. Batch-score existing leads. Implement trigger/flow for new leads.
**Owner:** Unassigned
**Status:** Open

### TD-006 — Apex API Version Debt
**Severity:** High
**Impact:** OA_ Apex classes at API v61. Current org API: v67. Gap of 6 versions. Older API versions lose access to new platform features and may encounter deprecation warnings.
**Resolution:** Update `<apiVersion>` in all class metadata files to 67.0. Test in sandbox first.
**Owner:** Unassigned
**Status:** Open

---

## Medium

### TD-007 — Duplicate Email Templates
**Severity:** Medium
**Impact:** Day 3, Day 5, and Day 10 email templates exist in two versions each (in stale temp directory). Org may have redundant templates causing confusion about which is active.
**Resolution:** Audit EmailTemplate records in org. Identify active vs stale. Remove redundant versions.
**Owner:** Unassigned
**Status:** Open

### TD-008 — tbid.digital.salesforce.com OAuth App (Unidentified)
**Severity:** Medium
**Impact:** An OAuth connected app from tbid.digital.salesforce.com is authorized in the org. Purpose unknown. Could be a vendor integration or a test connection that was never cleaned up.
**Resolution:** Identify the vendor/purpose. If legitimate, document it. If unknown, revoke.
**Owner:** Unassigned
**Status:** Open

### TD-009 — OIQ_Integration Connected App (Unidentified)
**Severity:** Medium
**Impact:** OIQ_Integration connected app exists. Purpose undocumented. OIQ could refer to an analytics or intelligence tool.
**Resolution:** Identify purpose. Document or remove.
**Owner:** Unassigned
**Status:** Open

### TD-010 — Former User Data Exposure (louisrubino@onealgorithm.com)
**Severity:** Medium
**Impact:** Louis R was deactivated June 19, 2026. Records previously owned by this user (flows, campaigns, etc.) may show a deactivated owner. Automated processes that ran as this user context may need reassignment.
**Resolution:** Audit WhoId/OwnerId on active records. Reassign where appropriate.
**Owner:** Unassigned
**Status:** Open

### TD-011 — OneDrive Sync Risk on Metadata Retrieval
**Severity:** Medium
**Impact:** Repository lives inside OneDrive/Documents/GitHub/. OneDrive actively syncs this path. Large metadata retrievals (hundreds of files) risk OneDrive conflict-copy events or file locks mid-write.
**Resolution:** Pause OneDrive sync before every `sf project retrieve start`. Resume after completion. Long-term: move repo out of OneDrive path.
**Owner:** Louis Rubino
**Status:** Open

---

## Low

### TD-012 — linkCOACustomerToLMALicense Trigger at API v61
**Severity:** Low
**Impact:** Single org-owned trigger at v61. Same issue as TD-006 but isolated to one file.
**Resolution:** Update with Apex class version upgrade (same PR as TD-006).
**Owner:** Unassigned
**Status:** Open

### TD-013 — Communities/Site Apex Classes (16 classes, low active use)
**Severity:** Low
**Impact:** 16 of the 27 org-owned classes are standard Salesforce Communities/Site template classes (ChangePasswordController, SiteLoginController, etc.). These are rarely modified but add noise to the class list.
**Resolution:** Retrieve and store but do not prioritize maintenance. Mark clearly in code as Salesforce-generated.
**Owner:** N/A
**Status:** Accepted (track only)

### TD-014 — No GitHub Actions CI/CD Pipeline
**Severity:** Low (escalates to High once team scales)
**Impact:** No automated validation on PRs. No automated deployment on merge. All deployments are manual.
**Resolution:** Add .github/workflows/validate-pr.yml using sf project deploy validate.
**Owner:** Unassigned
**Status:** Open

---

## Debt Summary

| Severity | Count | Open | In Progress |
|----------|-------|------|-------------|
| Critical | 2 | 1 | 1 |
| High | 4 | 4 | 0 |
| Medium | 5 | 5 | 0 |
| Low | 3 | 2 | 0 (1 accepted) |
| **Total** | **14** | **12** | **1** |
