# BPO Campaign Pilot Operator Runbook
**Version:** 2.0 — Pre-Pilot Safety Layer Complete  
**Target Org:** onealgorithmllc.my.salesforce.com  
**Org ID:** 00Dbn00000plgUfEAI  
**Username:** oauser@pboedition.com  
**Campaign:** EDWOSB Teaming Outreach - Prime Subcontract  
**Campaign ID:** 701Pn00001ZOyj8IAD  
**Pilot Scale:** 10–15 hand-selected SAM.gov leads  

---

## CRITICAL WARNING

> **Campaign.Status does NOT pause OA_FollowUpScheduler.**  
> Setting the Campaign to "Planned," "Completed," or any other status does NOT stop follow-up emails from going out.  
>  
> To pause follow-up outreach you must abort the scheduled job:  
> **OA EDWOSB Follow-Up Daily**  
>  
> See Section 15 for the pause and resume procedure.  
>  
> Do not rely on changing Campaign.Status.

---

## What Not to Touch

| Item | Why |
|---|---|
| OA_DripScheduler | Do not schedule. 13,279 SAM.gov leads would auto-enroll and receive Day 1 emails immediately. |
| OA_EDWOSB_Outreach_Sequence flow | Do not deactivate or modify. It sends the Day 1 email on CampaignMember creation. |
| OA_Reply_Detection flow | Do not deactivate. It handles reply suppression. |
| OA_PostMeeting_Nurture flow | Do not deactivate. Creates post-meeting tasks when Relationship_Status__c = Call Complete. |
| Any scheduled job | Do not delete any WAITING job without recording the cron expression first. |
| OA_Graph_Credential__c | Contains Azure app credentials. Do not share or export. |
| Email templates | Do not modify subject lines or merge fields without separate authorization. |
| Lead.Meeting_Booked_Date__c | Do not manually set this field — it is the idempotency guard for the booking pipeline. |

---

## Section 1 — Selecting 10–15 Pilot Leads

Source: SAM.gov leads in Salesforce not yet enrolled in the campaign.

Good pilot lead criteria:
- LeadSource = SAM.gov
- HasOptedOutOfEmail = false
- IsConverted = false
- Email is populated
- Company is a real government contractor (not a test/placeholder name)
- Not already in the campaign

SOQL to find candidates (run in Developer Console > Query Editor):
```sql
SELECT Id, FirstName, LastName, Email, Company, LeadSource
FROM Lead
WHERE LeadSource = 'SAM.gov'
  AND HasOptedOutOfEmail = false
  AND IsConverted = false
  AND Email != null
  AND Id NOT IN (
      SELECT LeadId FROM CampaignMember
      WHERE CampaignId = '701Pn00001ZOyj8IAD'
      AND LeadId != null
  )
ORDER BY CreatedDate ASC
LIMIT 20
```

Review the results manually. Select 10–15 real prospects. Do not enroll all 20 at once.

---

## Section 2 — Setting Outreach_Cohort__c Before Enrollment

Before enrolling a pilot lead, open their Lead record and set:

- **Outreach Cohort:** `Pilot Batch 1`
- **Is Test Lead:** Leave unchecked (false)

For future batches: `Pilot Batch 2`, `Pilot Batch 3`, `Production Ramp`.

---

## Section 3 — Confirming Is_Test_Lead__c = false

Before enrolling any lead, confirm:
- The **Is Test Lead** checkbox is unchecked (false)
- The lead's email does not match `lronealgorithm@gmail.com`, `oa-validation-test@onealgorithm.com`, or any `@onealgorithm.com` address

If in doubt, do not enroll.

---

## Section 4 — Manually Enrolling Pilot Leads

Add leads directly to the campaign. Do NOT use OA_DripScheduler.

Steps:
1. Open the Lead record in Salesforce
2. Scroll to the **Campaign History** related list
3. Click **Add to Campaign**
4. Search for: `EDWOSB Teaming Outreach - Prime Subcontract`
5. Select it and click **Save**

**OA_EDWOSB_Outreach_Sequence fires automatically within seconds** and sends the Day 1 email.

Enroll no more than 5 leads at a time. Wait 24 hours and verify Day 1 delivery (Section 5) before enrolling more.

---

## Section 5 — Verifying Day 1 Email Delivery

After enrolling a pilot lead:

1. Open the Lead record
2. Check **Activity History** for an email activity within the last 5 minutes
3. Verify subject matches the EDWOSB_Sub_Prospect_Email_1 or Teaming_Partner_Email_1 template
4. Check **Campaign History** — Status should read `Day 1 Sent`

If the email does not appear within 5 minutes:
- Check Setup → Apex Jobs for any FAILED AsyncApexJob entries
- Do not enroll more leads until the cause is identified

---

## Section 6 — Checking Day 3 / Day 5 / Day 10 Follow-Up

OA_FollowUpScheduler runs daily at **12:00 PM UTC (8:00 AM ET)**.

| Follow-up | Fires when |
|---|---|
| Day 3 | CampaignMember.Status = `Day 1 Sent` AND CreatedDate 3+ days ago |
| Day 5 | CampaignMember.Status = `Day 3 Sent` AND LastModifiedDate 5+ days ago |
| Day 10 | CampaignMember.Status = `Day 5 Sent` AND LastModifiedDate 10+ days ago |

Statuses that stop all follow-up: `Replied`, `Meeting Booked`, `Call Completed`, `Interested`, `Not Interested`, `Unsubscribed`.

To verify a follow-up was sent: open the Lead record the morning after the expected fire date, check Activity History for a new email, and confirm CampaignMember status advanced.

---

## Section 7 — Handling Replies

When a lead replies:
1. OA_Reply_Detection sets CampaignMember.Status = `Replied` automatically (if the reply email matches Lead.Email exactly)
2. OA_FollowUpScheduler will not send further emails to `Replied` leads
3. Review the reply within 24 hours

Reply actions:
- **Interested / wants to meet:** Set Status = `Interested`, respond directly, send Bookings link
- **Not interested:** Set Status = `Not Interested`
- **Unclear:** Leave as `Replied` until reviewed

If a lead replies from a different email address than what is in Salesforce, OA_Reply_Detection will not catch it. Monitor your inbox directly.

---

## Section 8 — Handling Unsubscribe Requests

1. Open the Lead record
2. Check the **Email Opt Out** checkbox (HasOptedOutOfEmail = true)
3. Set CampaignMember.Status = `Unsubscribed`
4. Reply to the lead confirming removal

---

## Section 9 — Handling Booked Meetings with Blank Teams Meeting ID

After a meeting is detected:
- Lead.Meeting_Booked_Date__c is stamped
- Lead.Relationship_Status__c = `Meeting Booked`
- CampaignMember.Status = `Meeting Booked`
- A PREP task is created

If Teams_Meeting_Id__c is blank after booking:
- The ArtifactPoller will not retrieve a recording for this lead
- Check the calendar event in Teams/Outlook for a recording manually
- These leads appear in the **BPO Exception Monitor** report

---

## Section 10 — Handling Missing Transcript

If Recording_Id__c is populated but Transcript_Id__c is blank after 2+ hours:
- ArtifactPoller retries each hour until Recording_Retrieved__c = true
- If Teams transcription was not enabled for that meeting, the transcript will never populate
- Recording_Retrieved__c will be set true once the recording is confirmed, even without a transcript

To check ArtifactPoller status in Developer Console:
```sql
SELECT Id, ApexClass.Name, Status, NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name = 'OA_ArtifactPoller'
ORDER BY CreatedDate DESC
LIMIT 5
```

---

## Section 11 — Handling Missing AI Summary

If Transcript_Id__c is populated but AI_Summary__c is blank:

Check for Queueable failures:
```sql
SELECT Id, ApexClass.Name, Status, ExtendedStatus, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name = 'OA_AISummaryQueueable'
ORDER BY CreatedDate DESC
LIMIT 10
```

If a job shows FAILED:
- Check the Anthropic named credential and external credential principal (OA_Anthropic-Principal)
- Re-trigger manually in Developer Console Execute Anonymous: `System.enqueueJob(new OA_AISummaryQueueable('<LeadId>'));`

---

## Section 12 — Logging Meeting Outcomes

Log outcomes on the Lead record within 24 hours of each meeting:

| Outcome | Action |
|---|---|
| Meeting held — interested | Set Lead.Relationship_Status__c = `Call Complete` |
| Meeting held — not a fit | Set CampaignMember.Status = `Not Interested` |
| No-show | Leave as `Meeting Booked`; add a note; follow up manually |
| Cancelled | Update Meeting_Booked_Date__c when rescheduled |

**WARNING — OA_PostMeeting_Nurture duplicate task risk:**  
When you set Lead.Relationship_Status__c = `Call Complete`, the flow fires and creates two tasks:
- "Send Capability Statement" (due tomorrow, High priority)
- "30-Day Follow-Up Check-In" (due in 30 days, Normal priority)

**Do not save the Lead record again for any other reason while Relationship_Status__c = `Call Complete`.** Every save triggers the flow again and creates duplicate tasks. This is a known limitation scheduled for a future fix.

---

## Section 13 — Daily Pilot Checklist

Run each morning:

**Step 1 — Scheduler health** (Developer Console → Query Editor):
```sql
SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'OA%'
ORDER BY CronJobDetail.Name
```
All 6 jobs must show State = `WAITING`. If any show `DELETED` or `ERROR`, see Section 15.

**Step 2 — Job error check:**
```sql
SELECT Id, ApexClass.Name, Status, NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE CreatedDate = TODAY
  AND JobType IN ('Future','Queueable')
  AND Status = 'Failed'
ORDER BY CreatedDate DESC
```
Zero results = healthy.

**Step 3 — Check inbox** for any replies to outreach emails.

**Step 4 — Check Tasks** for any open `PREP:` tasks (prep before meetings).

**Step 5 — Log outcomes** for any meetings that occurred yesterday.

---

## Section 14 — GO / NO-GO for Expanding Beyond Pilot

Expand beyond 15 leads when ALL of these are true:

- [ ] At least 10 pilot leads completed the full Day 1 → Day 10 sequence without Apex errors
- [ ] At least 2 real meetings booked from SAM.gov leads
- [ ] At least 1 meeting has Teams_Meeting_Id__c and AI_Summary__c populated
- [ ] Zero failed AsyncApexJobs in the last 7 days
- [ ] All 6 scheduled jobs show WAITING state
- [ ] Reply detection has caught at least one reply correctly
- [ ] All held meetings have logged outcomes (Relationship_Status__c or CampaignMember Status)
- [ ] BPO Exception Monitor report shows zero unresolved items
- [ ] You understand what OA_PostMeeting_Nurture does and have seen it fire correctly

When ready: schedule OA_DripScheduler with batch size 25 (`batchSize` is auto-ramped but the initial pool of 25 leads per day is the floor). Monitor for 48 hours before increasing.

---

## Section 15 — Pausing Follow-Up Outreach

To pause OA_FollowUpScheduler (Developer Console → Execute Anonymous):
```apex
CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger
                  WHERE CronJobDetail.Name = 'OA EDWOSB Follow-Up Daily' LIMIT 1];
System.debug('SAVE THIS CRON EXPRESSION: ' + ct.CronExpression);
System.abortJob(ct.Id);
```

Record the cron expression from the debug log before running.

To resume:
```apex
System.schedule('OA EDWOSB Follow-Up Daily', '0 0 12 * * ?', new OA_FollowUpScheduler());
```

---

## Section 16 — Emergency Stop Procedure

**Step 1 — Abort FollowUpScheduler:**
```apex
System.abortJob([SELECT Id FROM CronTrigger
                 WHERE CronJobDetail.Name = 'OA EDWOSB Follow-Up Daily' LIMIT 1].Id);
```

**Step 2 — Abort all Booking Pollers:**
```apex
for (CronTrigger ct : [SELECT Id FROM CronTrigger
                       WHERE CronJobDetail.Name LIKE 'OA Booking Poller%']) {
    System.abortJob(ct.Id);
}
```

**Do NOT abort ArtifactPoller** — it only reads recordings and cannot send emails.

**Standard cron expressions to restore:**

| Job | Expression |
|---|---|
| OA EDWOSB Follow-Up Daily | `0 0 12 * * ?` |
| OA Booking Poller 00 | `0 0 * * * ?` |
| OA Booking Poller 15 | `0 15 * * * ?` |
| OA Booking Poller 30 | `0 30 * * * ?` |
| OA Booking Poller 45 | `0 45 * * * ?` |
| OA Artifact Poller | `0 15 * * * ?` |

Do NOT set Campaign.Status as a stop mechanism. It does not work.

---

## Section 17 — Scheduler Health Reference

| Job | Schedule | What It Does |
|---|---|---|
| OA EDWOSB Follow-Up Daily | Daily 12:00 UTC | Sends Day 3, Day 5, Day 10 follow-up emails |
| OA Booking Poller 00 | Every hour :00 | Detects new Microsoft Bookings meetings via Graph API |
| OA Booking Poller 15 | Every hour :15 | Same |
| OA Booking Poller 30 | Every hour :30 | Same |
| OA Booking Poller 45 | Every hour :45 | Same |
| OA Artifact Poller | Every hour :15 | Retrieves Teams recordings and transcripts |

**OA_DripScheduler: NOT scheduled. Do not schedule until Section 14 criteria are met.**

---

## Section 18 — Reports Reference

All reports are in the **OA BPO Pilot** folder in Salesforce Reports.

| Report | Purpose | Default Filter |
|---|---|---|
| BPO Lead Outreach Status | SAM.gov leads with cohort and relationship status | LeadSource = SAM.gov |
| BPO Artifact Pipeline Health | Leads with booked meetings and artifact pipeline state | Meeting_Booked_Date__c not null |
| BPO Exception Monitor | Leads with meetings but missing Teams Meeting ID | Auto-excludes test leads |

**Campaign Member funnel by status** (Day 1 Sent, Day 3 Sent, etc.):  
Create manually in Salesforce Reports using report type "Campaigns with Campaign Members," group by Member Status, filter Campaign Name = EDWOSB Teaming Outreach - Prime Subcontract.

**Scheduler health:** Use the SOQL in Section 13, Step 1. CronTrigger is not a reportable object in standard reports.
