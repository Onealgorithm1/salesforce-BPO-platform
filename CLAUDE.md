# CLAUDE.md — Governed Autonomy Guide

How Claude Code should operate **autonomously but safely** in the One Algorithm **salesforce-BPO-platform** repository. The goal is to reduce unnecessary confirmation prompts for low-risk work while preserving strict production governance. When in doubt, treat an action as the more restrictive tier.

---

## 0. Standing Session Rules (apply to EVERY session — non-negotiable)

1. **Approval authority is Louis.** Never set any staging/proposal row to `Approved`, and never write to a Lead, without **explicit approved numbers from Louis in the current session**. Silence or ambiguity ≠ approval.
2. **Verify Org ID = `00Dbn00000plgUfEAI` before ANY org operation.** Mismatch = **STOP**.
3. **Path A is the only certified Lead-enrichment write path** — `OA_USASpendingEnrichmentService` → `OA_USASpending_Staging__c` (review-gated) → `OA_LeadWritebackService`. **Path B's ungated commit (`OA_EnrichmentWriter` `commitWrites=true`) must NEVER be used for committed Lead writes** — tech debt pending disable.
4. **All connectors return to dormant** (`OA_Connector_Registry__mdt.*.Enabled__c = false`) **before any session ends**, whatever happened.
5. **No** schedules created/enabled · **no** Opportunity creation · **no** Lead conversion · **no** campaign sends · **no** secrets in output, commits, or docs.
6. **At session start, read `docs/` for the latest `SESSION_STATE_*` note and resume from it** (don't re-discover state).

---

## 1. Project Context

- **Production Org ID:** `00Dbn00000plgUfEAI` — always verify by **ID**, never by org name/alias.
- **Repository:** `salesforce-BPO-platform` (GitHub `Onealgorithm1/salesforce-BPO-platform`).
- **`main` is governance-protected** — the source of truth mirrored to production. No direct work on `main`.
- **DevHub is separate** — this production org is not a DevHub; scratch/DevHub operations are out of scope unless explicitly requested.
- **Lead Enrichment is in maintenance mode** — production-certified (v1.2); do not reopen except for a defect/security/governor issue.
- **Analytics and ERE Phase 1 are deployed** — Executive Analytics (reports/dashboard/snapshot object) and the Engagement Resolution Engine shadow log (observe-only, dormant) are live in production.
- **The EDWOSB campaign is live** — active outreach (drip + follow-up schedulers, ~275+ members). Its automation is protected (see §9).

---

## 2. Autonomy Rules

### 🟢 GREEN — proceed without asking
- Read-only audits and SOQL queries
- Source inspection / reading code
- Metadata inventory (`sf org list metadata`, describes)
- `git status` / branch / diff inspection
- Creating feature branches
- Source-only changes on feature branches
- Documentation updates
- Check-only validation (`--dry-run`)
- Running Apex tests (in validation/check-only)
- Commits to feature branches
- Pushing feature branches
- Opening PRs

### 🟡 YELLOW — proceed, but report clearly
- Additive metadata on feature branches (new objects/fields/report types)
- New tests
- New reports / dashboards
- New documentation
- Reversible refactors
- Dormant / observe-only components (no active trigger/flow/schedule)

> For YELLOW: act, then clearly state what was added, that it is additive/reversible, and that nothing was deployed or merged.

### 🔴 RED — STOP for explicit Louis approval
- Production deploys (`sf project deploy start` without `--dry-run`)
- PR merges to `main`
- Destructive changes (deletes, `destructiveChanges`, history rewrites)
- Production data updates (any DML to live records)
- **Permission set assignments**
- Creating/scheduling jobs (`System.schedule`, scheduled Apex/Flow)
- Batch / backfill execution (`Database.executeBatch`, anonymous Apex that writes)
- Campaign automation changes
- Lead / CampaignMember / Event / EmailMessage / Task / Contact updates
- Named Credentials / External Credentials
- Secrets of any kind
- M365 / Graph / Bookings / Teams changes
- Cloudflare / DNS / domain changes

> RED actions require an explicit, specific approval from Louis (e.g., "APPROVED: deploy X"). Approval for one RED action never implies approval for the next.

---

## 3. Required Preflight (start of every task)
1. Verify **Org ID** = `00Dbn00000plgUfEAI` (by ID).
2. Verify current **git branch** (never operate on `main`).
3. Verify **working tree** is clean (or account for expected changes).
4. Verify **`main` == `origin/main`** (in sync).
5. Verify the **active workstream** and that the branch matches it.
6. Verify **no unrelated files** are staged or in scope.

If anything is unexpected, STOP and report before proceeding.

---

## 4. Required Closeout (end of every task)
Report:
- **Files changed**
- **Validation IDs** (check-only and/or deploy)
- **Test results** (+ coverage where relevant)
- **Production changed? yes/no** (explicitly)
- **Branch and HEAD** commit
- **Working tree status**
- **Next approval gate** (what RED action, if any, awaits Louis)

---

## 5. Deployment Policy
- **Never deploy without explicit approval.**
- **Never merge to `main` without explicit approval.**
- **A deploy is not done until it is merged.** Every production deploy must be followed the same day by a PR to `main` whose body carries the deploy ID. `main` mirrors production; a deployed-but-unmerged branch is active drift (root cause of the 2026-07-16 near-rollback).
- **No UI/Setup edits to governed metadata** (Apex, triggers, flows, email templates, custom metadata types/records). If a UI edit is unavoidable, retrieve and commit it the same day.
- **Drift check:** run `scripts/drift-check.ps1` (retrieve governed components + normalized diff vs `main`) after any suspected out-of-band change and periodically; treat any content diff as an incident to reconcile before the next deploy.
- **Never mix workstreams** in one deploy/PR.
- **Never deploy unrelated work together.**
- **Stop immediately on any deployment/validation error** — do not auto-retry.
- **Diagnose before any retry.** A retry is only valid after the root cause is understood and confirmed (e.g., a corrected source file), not as a blind repeat.
- Prefer **two-phase clarity** when dependencies exist, but note: custom-report-type reports deploy fine in one transaction when the metadata syntax is correct (see §7 lessons).

---

## 6. Source-Control Policy
- **No work on `main`.**
- **One feature branch per workstream** (`feature/<workstream>`).
- **No history rewrites** (no rebase of shared branches, no force-push).
- **No `--amend` after push.**
- **No empty commits.**
- **Preserve feature branches** after merge unless explicitly told to delete.
- Commit only files belonging to the active workstream; verify staged files before committing.
- Co-author trailer on commits as configured; end PR bodies with the standard generated-by line.

---

## 7. Salesforce Safety Policy
- **Verify Org ID, never org name.**
- **Reuse before build** — audit existing metadata (reports, objects, permsets, classes) and extend rather than duplicate.
- **Prefer additive and reversible** changes over in-place edits to shared assets.
- **Use least privilege** — dedicated permission sets over profile edits; unassigned by default; grant only what's needed (Read vs Edit deliberately).
- **Do not touch protected automations** (§9) unless explicitly approved.
- **Do not write production data** unless explicitly approved.

**Hard-won lessons (apply going forward):**
- Custom-report-type **reports** must reference the type as `Name__c` and fields as `Object$Field` (not `.`); a grouping field cannot also be a detail column. Template from an existing working report rather than hand-guessing.
- **Metadata-API field deploys omit field-level security** — always bundle a permission set granting FLS with any new reportable custom fields, or the fields are invisible to everyone (including admins).
- Observe-only / single-write-path design + no active trigger = a component that is safe to deploy dormant and prove before it ever acts.

---

## 8. Recommended Claude Code Permission Mode
- Use **Auto Mode / `acceptEdits`** for source-only, feature-branch work (edits, commits, check-only validation, PRs) — this is where prompt reduction is safe.
- **Do not use `bypassPermissions` on this repo** — it would remove the guardrails that protect production.
- If `bypassPermissions` is ever required, it must run inside an **isolated container/VM with no production credentials** (no access to the `oauser@pboedition.com` auth, no Named Credentials, no secrets).
- RED actions (§2) should always surface a confirmation regardless of mode.

---

## 9. Explicit Protected Areas (do not modify without explicit approval)
- `OA_EDWOSB_Outreach_Sequence` (campaign enrollment + Day-1 flow)
- `OA_Reply_Detection` (inbound reply flow)
- `OA_PostMeeting_Nurture`
- `OA_EmailSender` (outbound send path)
- **Lead Enrichment writeback** (`OA_LeadWritebackService` and related)
- **Named / External Credentials** (all)
- **M365 Graph / Bookings / Teams** integrations
- **Production data** (Lead, CampaignMember, Event, EmailMessage, Task, Contact, Campaign)
- **Cloudflare / DNS / domain** settings
- **`www.onealgorithm.com`**

---

*This guide governs autonomous operation. GREEN work proceeds freely; YELLOW work proceeds with a clear report; RED work always stops for Louis. When uncertain, choose the safer tier.*
