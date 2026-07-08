# Lead Enrichment Platform — Rollback Checklist

**Version:** 1.0 (for release `lead-enrichment-v1.2`)
**Date:** 2026-07-08
**Org:** `00Dbn00000plgUfEAI` (verify by **ID**, never by name)
**Governed by:** [CLAUDE.md](../CLAUDE.md) · [GOVERNANCE_MODEL.md](GOVERNANCE_MODEL.md)
**Companion docs:** [ROLLBACK_DEFECT_FIX.md](ROLLBACK_DEFECT_FIX.md) (the fix history) · [MAINTENANCE.md](MAINTENANCE.md) §Recovery · [OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md)

> This is the **step-by-step operational rollback procedure** — the itemized runbook the prose in
> `MAINTENANCE.md`/`OPERATIONS_GUIDE.md` refers to. Use it to reverse a Lead-Enrichment write, or to
> back out a dormant metadata deploy. `[ ]` = to do; `N/A — reason` = deliberately skipped.
>
> **Executing a data rollback writes to production Leads → this is a 🔴 RED action** (production data
> modification). Do not run the commit/rollback DML step without explicit Louis approval. Everything
> up to and including the *preview/verify* steps is 🟢 read-only and may be done to assess blast radius.

---

## 0. When to use this
Trigger a rollback if, after an enrichment write, any of these are true:
- Wrong or corrupted values landed on Leads (bad mapping, wrong policy, over-broad scope).
- A write ran under an **Overwrite** policy or wider scope than approved.
- An exception sweep or audit (`daily_enrichment_audit.sh`) reports **writes without a before-snapshot**,
  or FAIL on data integrity.
- A pilot/canary result is rejected and the org must return to its prior baseline.

If the concern is a **metadata** deploy (not data), skip to §6.

---

## 1. Scope the rollback (🟢 read-only)
- [ ] Org verified by **ID** = `00Dbn00000plgUfEAI`.
- [ ] Identify the offending run's **`Run_ID__c`** on `OA_Connector_Run__c` (e.g. `S23-...`, `SPRINT24-...`).
      Record it here: `Run_ID = ____________`.
- [ ] Count the change logs in scope:
      `SELECT COUNT() FROM OA_Enrichment_Change_Log__c WHERE Connector_Run__r.Run_ID__c = :runId AND Change_Type__c = 'Enrich'`.
      Expected fields-written count: `____`.
- [ ] Confirm **every** log in scope has a non-null `Before_Snapshot__c` and `Reversible__c = true`.
      **If any log lacks a snapshot → STOP.** That field cannot be auto-restored; escalate (manual restore
      from an external backup / report export).
- [ ] Confirm the target Leads are the intended ones (spot-check `Target_Record_Id__c` set; verify none are
      protected/campaign/internal records outside the approved pilot scope).

## 2. Capture current state (🟢 evidence, before touching anything)
- [ ] Export the affected Leads' target fields to the scratchpad (NOT committed) as a "before-rollback" snapshot.
- [ ] Record current org counts: enriched Leads, total change logs, open exceptions. Baseline reference =
      `MAINTENANCE.md` (dormant baseline).
- [ ] Confirm platform is otherwise **dormant** (0 enabled connectors, 0 active policies, 0 enrichment jobs) so
      no new writes race the rollback:
      `SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%nrich%'` = 0.

## 3. Approval gate 🔴 (required before any DML)
- [ ] Explicit Louis approval recorded to execute the data rollback (e.g. "APPROVED: rollback Run `____`").
      Reference: `____`.
- [ ] Runtime FLS permset `OA_Lead_Enrichment_Runtime` is **assigned** to the executing user (revoking it
      hides the fields → "No such column"; keep assigned — Sprint-13 invariant).

## 4. Execute the rollback (🔴 production data write)
- [ ] Run, in anonymous Apex (single transaction; callout-free — rollback does DML only):
      ```apex
      List<OA_Enrichment_Change_Log__c> logs = [
        SELECT Id, Target_Record_Id__c, Before_Snapshot__c, Field_Name__c
        FROM OA_Enrichment_Change_Log__c
        WHERE Connector_Run__r.Run_ID__c = :runId AND Change_Type__c = 'Enrich'
      ];
      OA_ChangeLogService.rollback(logs);
      ```
- [ ] Rollback **merges all per-field snapshots per record** before updating (the v1.2 multi-field fix —
      [ROLLBACK_DEFECT_FIX.md](ROLLBACK_DEFECT_FIX.md)). Do **not** batch by a single field.
- [ ] On any error: **STOP, do not auto-retry.** Diagnose (governor limit? FLS? partial success?) and
      resume only after the cause is understood.

## 5. Verify per-field restoration (🟢 read-only — the critical check)
- [ ] For every affected Lead, confirm **each** target field is back to its pre-write value (blank if the
      field was blank before a FillEmptyOnly write). Do **not** verify by record count alone — the original
      defect passed a record-count check while leaving 5 of 6 fields written.
- [ ] Confirm fields **not** touched by the run (e.g. `State`) are unchanged.
- [ ] Confirm the reversal is audited: rollback logged the restoration; original audit retained.
- [ ] Re-run `scripts/shell/daily_enrichment_audit.sh` → expect PASS (no orphan logs, integrity OK).
- [ ] Org counts match the intended post-rollback baseline (enriched-Lead count decreased by the rolled-back set).

## 6. Metadata rollback (dormant deploy back-out) — alternative to §4
Use when a **deploy** (not data) must be reversed. Metadata is additive; there are three levers:
- [ ] **Kill switch (fastest):** set the connector `OA_Connector_Registry__mdt.<src>.Enabled__c = false`
      and the relevant `OA_Field_Write_Policy__mdt.<policy>.Active__c = false` (deploy with an explicit,
      **quoted** `--source-dir` — spaces in the OneDrive path silently no-op the loop form; then verify
      active policies = 0 / enabled connectors = 0). This returns the platform to dormant without removing code.
- [ ] **Redeploy prior package:** deploy the prior Git tag/commit (e.g. `lead-enrichment-v1.2`) to restore the
      previous class/metadata versions. Discrete Salesforce deploy ID per step; objects/fields are additive so
      no destructive change is required.
- [ ] **Destructive removal** (only if explicitly approved): `destructiveChanges` — 🔴 RED, rarely needed;
      prefer disable-in-place over delete.

## 7. Return to dormant + close out
- [ ] Deactivate any policies/connectors enabled for the operation → **0 active policies, 0 enabled connectors,
      0 enrichment jobs** (verify explicitly).
- [ ] Delete only genuine test/residual telemetry created for the operation; **retain** the audit trail of the
      real rollback.
- [ ] Closeout report ([CLAUDE.md §4](../CLAUDE.md)): Run_ID, fields restored (N/N), production changed = yes,
      final dormant counts, branch/HEAD, next gate.

---

### Rollback readiness invariants (never violate)
1. Every enrichment write carries a `Before_Snapshot__c`; `Reversible__c = true`. No snapshot → not auto-reversible.
2. Rollback is rehearsed on a live pilot before scaling (proven 30/30 fields at v1.2).
3. Verify **per field**, never by record count.
4. Rollback DML is callout-free and runs in its own transaction (no callout-after-DML).
5. Return to dormant and re-run the audit after every rollback.
