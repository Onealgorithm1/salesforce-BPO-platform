# Technical Debt Register — One Algorithm BPO Platform

**Last updated:** June 23, 2026
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

### TD-015 — External Meeting Assistant Governance — Read AI
**Severity:** Low
**Impact:** Read AI is not referenced in any Salesforce metadata, Apex class, Named Credential, or the Integration Registry. It is not part of the BPO platform pipeline. However, it operates in the same Teams meeting context as the authoritative pipeline and warrants formal governance.

Key facts established June 2026:
1. Read AI is not referenced in Salesforce metadata or code — zero matches across the entire repository.
2. Read AI joins Teams meetings independently as a bot participant, operating outside Salesforce control.
3. Read AI stores meeting data (transcripts, summaries, video highlights) externally on readai.com servers. No data flows into Salesforce from Read AI.
4. Read AI has usage and report limits tied to the account plan. Limit exhaustion could affect summary delivery to meeting participants without impacting the Salesforce pipeline.
5. Read AI should be disabled or excluded as a meeting participant during BPO platform validation runs to prevent ambiguity about which transcript source is authoritative.
6. Authoritative source of truth for the Salesforce pipeline is: Microsoft Graph native transcript (`/onlineMeetings/{id}/transcripts/{id}/content?$format=text/vtt`) → `Lead.Transcript_Content__c` → `OA_AISummaryService` → `Lead.AI_Summary__c`. Read AI has no role in this chain.
7. Future decision required: disable Read AI for OA meetings, formally isolate it as an external participant-facing tool, or register it as INT-009 in the Integration Registry with a documented data retention and privacy scope.

**Resolution:** Make one of three decisions before campaign go-live: (A) Disable Read AI for meetings involving BPO platform validation. (B) Formally isolate — document its scope as participant-facing only, add INT-009 to Integration Registry, confirm no data bridge to Salesforce exists or will be built. (C) Govern — if Read AI summaries will ever be imported into Salesforce, treat as a new integration requiring full INT-xxx registration, data classification, and credential management.
**Owner:** Louis Rubino
**Status:** Open — decision deferred

---

## Debt Summary

| Severity | Count | Open | In Progress |
|----------|-------|------|-------------|
| Critical | 2 | 1 | 1 |
| High | 4 | 4 | 0 |
| Medium | 5 | 5 | 0 |
| Low | 4 | 3 | 0 (1 accepted) |
| **Total** | **15** | **13** | **1** |

---

## Sprint 1A Reconciliation Note (2026-07-02)

Additive note from the Evergreen Sprint 1A documentation/governance pass. **No existing debt
items above were removed or renumbered** (none verified obsolete). This note records how the new
governance baseline relates to the register. Confidence labels: `[Verified from source]`,
`[Unverified production runtime]`.

- **Connector Framework governance baseline now exists** `[Verified from source]` — ADR-005 plus
  `CONNECTOR_FRAMEWORK.md` / `CONNECTOR_FRAMEWORK_ROADMAP.md` establish the standard (Named
  Credential, staging + human review, testing). Governs remediation of connector-related debt.
- **USASpending remains pre-SDK** `[Verified from source]` — `OA_USASpendingClient` is still
  orphaned (zero callers), has **no test class**, and does not persist to
  `OA_USASpending_Staging__c`. It requires the **Sprint 1C** refactor onto the framework; not
  fixed in 1A (docs-only).
- **Remote Site Settings remain legacy/debt** `[Verified from source]` — `MicrosoftGraph`,
  `MicrosoftLogin`, `OA_USASpending` persist where Named/External Credentials are the planned
  standard (ADR-008, `SECURITY_BASELINE.md`). Relates to TD-006-era modernization; migration
  deferred to 1C+.
- **New proposed governance artifacts** `[Verified from source]` — `METADATA_REGISTRY.md`,
  `EVERGREEN_DATA_DICTIONARY.md`, `CANONICAL_DATA_MODEL.md`, `ENTITY_RESOLUTION_FRAMEWORK.md`,
  `SECURITY_BASELINE.md`, `DEFINITION_OF_READY.md` (ADR-006…ADR-010). All **Proposed**;
  documentation only, no implementation.
- **Additional findings surfaced by the Metadata Registry** `[Verified from source]`, tracked here
  for future formal TD entries (not yet numbered, to keep this edit additive):
  (a) `OA_BookingPoller` is **duplicated** in `force-app` and `modules/marketing-automation`
  (layer-boundary violation); (b) the `OA_Anthropic` Named Credential references an **External
  Credential not committed** to the repo; (c) `OA_Graph_Credential__c` stores `Client_Secret__c`
  as a Text field (credential-in-object). Runtime impact `[Unverified production runtime]`.
- **INT-numbering conflict to resolve** `[Verified from source]` — TD-015 (Read AI) reserves
  "INT-009" for Read AI *if* it is ever registered, but Sprint 1A documented **USASpending as
  INT-009** in `INTEGRATION_REGISTRY.md`. Recommendation: keep USASpending = INT-009 (now actually
  documented); if Read AI is later governed, assign it **INT-010**.
- **Unsubscribe workstream** `[Unverified production runtime]` — reported **Production Done,
  Cleanup Pending**. Out of scope for this session; **no unsubscribe records or files were
  modified.** Any remaining cleanup is owned by that workstream.
- **Source-control risk remains** `[Verified from source]` — the repo lives in OneDrive with a
  second, stale local copy (see RISK-REPO-01 / TD-011), and untracked temp files
  (`apex-temp-*.json/.apex`, an untracked `lead_by_ramesh.flow-meta.xml`) are present in the
  working tree and must be excluded from commits.

> The Debt Summary counts above are **unchanged**; formal TD entries for items (a)–(c) should be
> added in a later reconciliation once prioritized, so the summary is not silently desynced here.
