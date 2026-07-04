# Operations Change Log

Append-only ledger of **runtime / configuration** changes to production automation —
Custom Setting values, scheduled-job cron expressions, and feature toggles that are
**not** represented in repository metadata. Code and metadata changes are tracked in
git history and pull requests; this log captures org-side configuration that git does
not otherwise record. **Newest entries on top. Do not rewrite past entries** — append
follow-ups instead.

---

## 2026-07-04 — Campaign send ramp: 25 → 100 total sends / business day

- **Date of change:** 2026-07-04, ~00:31 ET (~04:31 UTC)
- **Change owner:** Louis Rubino (approver)
- **Executing org / user:** `oauser@pboedition.com` (executed by Claude Code on approval)
- **Production org:** One Algorithm LLC — `00Dbn00000plgUfEAI`
- **Campaign name:** EDWOSB Teaming Outreach - Prime Subcontract
- **Campaign id:** `701Pn00001ZOyj8IAD`
- **Change type:** Configuration only (no code / metadata change)

### Prior configuration
- `OA_Campaign_Settings__c.Daily_Send_Cap__c` = **25**
- `OA_DripScheduler_Wave1` cron = **`0 0 11 ? * MON-FRI`** (one run, 11:00 AM ET)
- `OA EDWOSB Follow-Up Daily` cron = `0 0 12 * * ?` (12:00 PM ET)

### New configuration
- `OA_Campaign_Settings__c.Daily_Send_Cap__c` = **100**
- `OA_DripScheduler_Wave1` cron = **`0 0 8,14 ? * MON-FRI`** (two runs: **8:00 AM ET** and **2:00 PM ET**)
- `OA EDWOSB Follow-Up Daily` cron = **`0 0 12 * * ?` (12:00 PM ET) — UNCHANGED**
- Old drip job `08ePn00001aMbJqIAK` aborted; new job `08ePn00001bl8XN` scheduled
  (same class `OA_DripScheduler`, same job name, US Eastern scheduling context).

### Reason for the ramp
Enrollment at 25/day was too slow for the ~5,670-lead eligible-uncontacted queue.
Ramped to **100 total sends per business day** using **two governor-safe runs of no
more than 50 records each** — the send architecture is safe only at ≤ 50 emails per
transaction (`OA_DripScheduler.MAX_SYNC_BATCH = 50`,
`OA_EmailSender.MAX_INVOCABLE_REQUESTS = 50`, and per-recipient unsubscribe-token DML
that must stay under the 150-DML-statement limit). Increasing run **frequency** (not
batch size) keeps every transaction within governor limits without any Apex change.

### "100/day" means TOTAL sends
100/day is the **total** daily send volume — **new Day-1 sends and follow-ups
combined**. `OA_DripScheduler` and `OA_FollowUpScheduler` share a single daily counter
(`OA_Campaign_Settings__c.Sends_Today__c` via `OA_SendGovernor`), so follow-up volume
consumes the same 100 and can reduce new enrollment on a given day. There is no
separate reserve for follow-ups.

### Verification performed (2026-07-04, read-only)
- `Daily_Send_Cap__c` = 100 confirmed.
- Exactly **one** active `OA_DripScheduler_Wave1` CronTrigger with cron
  `0 0 8,14 ? * MON-FRI`; **no duplicate drip jobs**.
- `OA EDWOSB Follow-Up Daily` unchanged (`0 0 12 * * ?`).
- No failed or aborted async jobs created by the change.
- Send / enrollment automation untouched (Flow `OA EDWOSB Outreach Sequence` still
  Version 2, LastModified 2026-07-02).
- **CampaignMembers remained stable at 125 immediately after the config change**
  (0 members created by the change; no Lead or CampaignMember records modified).

### First real run & load-test status
- **First real post-ramp run: Monday, 2026-07-06** (drip fires 8:00 AM & 2:00 PM ET;
  follow-up 12:00 PM ET).
- **The 2026-07-04 verification was a configuration-armed confirmation ONLY — it is
  NOT a load-test pass.** At verification time the new schedule had not fired
  (`TimesTriggered = 0`), and CampaignMembers were still 125.

### Required Monday health check
After Monday 2026-07-06 (once both drip runs and the noon follow-up have fired, i.e.
after ~18:00 UTC), run the read-only health-check set and evaluate against the stop
thresholds below. Confirm: `TimesTriggered` advanced for the day, `Sends_Today__c`
reset then incremented, new Day-1 volume, follow-up split, and all compliance /
deliverability signals. **The ramp is not considered validated until this check passes.**

### Stop thresholds (any breach → hard stop and roll back)
- Any opted-out Lead newly enrolled
- Any converted Lead enrolled
- Any test Lead enrolled
- Any duplicate CampaignMember created
- Any failed or aborted scheduler / async job
- Send-failure rate above 5%
- Bounce rate at or above 5% cumulative (warn at 2%)
- Unsubscribe rate at or above 3% cumulative (warn at 1%)
- Any unsubscribe-endpoint failure

*Pre-ramp baselines for reference:* 125 members; 122 contacted; bounces 2 (~1.6%);
unsubscribes 2 (~1.6%); replies 1; send-failure Tasks 0.

### Rollback plan (configuration rollback — NOT an email recall)
1. Set `OA_Campaign_Settings__c.Daily_Send_Cap__c` back to **25**.
2. Reschedule `OA_DripScheduler_Wave1` to **`0 0 11 ? * MON-FRI`** (abort the current
   CronTrigger and re-schedule the same class under the same name).
3. Confirm exactly one active drip job remains.
4. Confirm `OA EDWOSB Follow-Up Daily` remains unchanged.

> Emails already sent cannot be recalled. Rollback restores **configuration**
> (cap + schedule) only, not email delivery.

### Scope notes
- **No Apex changed.**
- **No Flow changed.**
- **No email templates changed.**
- **No unsubscribe logic changed.**
- **No Lead records changed.**
- **No CampaignMember records changed.**
- **No metadata or permissions changed.**
- **Separate from the Lead Write-Back workstream** (the uncommitted `UEI_*` /
  `USASpending_*` Lead & `OA_USASpending_Staging__c` fields, and the modified
  `Review_Status__c`, in the working tree). This entry documents the campaign ramp
  **only** and is committed independently of those files.
