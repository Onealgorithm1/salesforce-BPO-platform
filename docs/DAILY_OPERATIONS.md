# DAILY_OPERATIONS.md — Daily Checklist

Read-only daily health sweep for the BPO Platform. All commands are read-only. `-o` = `--target-org oauser@pboedition.com`. Record the **bold** numbers each day; escalate per the thresholds.

## Daily checklist

### 1. Platform
```bash
sf org display -o oauser@pboedition.com | grep -Ei "Id|Status"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM AsyncApexJob WHERE Status IN ('Failed','Aborted') AND CreatedDate=TODAY"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM AsyncApexJob WHERE ExtendedStatus LIKE '%Exception%' AND CreatedDate=TODAY"
sf data query -o oauser@pboedition.com -q "SELECT CronJobDetail.Name, State, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE 'OA%' ORDER BY NextFireTime"
sf org list limits -o oauser@pboedition.com
```
Record: **failed jobs**, **exceptions**, **API % used**, **SingleEmail used/5000**, **DataStorage %**.
Escalate if: failed jobs **> 0**; exceptions **> 0**; any cron not `WAITING`/firing; API **> 80%**; storage **> 90%**.

### 2. EDWOSB campaign
```bash
sf data query -o oauser@pboedition.com -q "SELECT Status, COUNT(Id) FROM CampaignMember WHERE CampaignId='701Pn00001ZOyj8IAD' GROUP BY Status ORDER BY COUNT(Id) DESC"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM EmailMessage WHERE CreatedDate=TODAY AND Incoming=false"          # sends today
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM Task WHERE Subject='Email Send Failed' AND CreatedDate=TODAY"      # bounces today
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM Lead WHERE HasOptedOutOfEmail=true AND Id IN (SELECT LeadId FROM CampaignMember WHERE CampaignId='701Pn00001ZOyj8IAD')"  # unsubscribes
```
Record: **members by stage**, **sends today**, **bounces today**, **unsubscribes**, **meetings booked**.
Escalate if: cumulative bounce **≥5%**; cumulative unsubscribe **≥3%**; sends stalled on a business day; funnel not progressing.

### 3. ERE (observe-only guardrail)
```bash
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM OA_Engagement_Resolution__c"                                       # total
sf data query -o oauser@pboedition.com -q "SELECT Matched_Level__c, Status__c, COUNT(Id) FROM OA_Engagement_Resolution__c WHERE CreatedDate=TODAY GROUP BY Matched_Level__c, Status__c"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name LIKE 'OA_Engagement%' AND Status IN ('Queued','Processing','Holding')"
# Zero-write guardrail (must match prior baseline unless the live campaign changed them):
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM CampaignMember WHERE CampaignId='701Pn00001ZOyj8IAD'"             # 275
```
Record: **shadow total**, **new rows today**, **new L1/L3/Needs-Review**.
Escalate if: **new shadow rows appear without an approved run**; any prospect object changed **and attributable to ERE**; any ERE async job Failed.

### 4. Analytics
```bash
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM Report WHERE FolderName='OA Executive Analytics'"                  # expect 6
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM Campaign_Funnel_Snapshot__c"                                       # 0 until snapshot runs
```
Escalate if: reports/dashboard missing; once the snapshot is live, **0 new rows on a scheduled day**.

## Reporting Snapshot — setup (one-time, Setup UI)
> The mapping + schedule are a Setup wizard (not reliably Metadata-API configurable). The **source report + target object are already deployed**; finish in the UI:
1. **Setup → Reporting Snapshots → New Reporting Snapshot**
2. **Source report:** `OA Executive Analytics ▸ Funnel Snapshot Source`
3. **Target object:** `Campaign Funnel Snapshot`
4. **Field mappings:** `Campaign Name → Campaign_Name__c`, `Member Status → Member_Status__c` (`Snapshot_Date__c` defaults to `TODAY()`)
5. **Running user:** `oauser@pboedition.com` (has `OA_Executive_Analytics_Access`)
6. **Schedule:** Daily (e.g., 07:00 ET)
7. **Verify:** click **Run Now**, then `SELECT COUNT() FROM Campaign_Funnel_Snapshot__c` returns rows; open `Daily Funnel Trend` and confirm it renders.

## What to review manually each day
- New **L3 / Needs-Review** ERE rows (e.g., Stragistics) → confirm the correct human action; **do not auto-apply**.
- New **No-Match** senders → skim for a genuine prospect hiding (e.g., a prospect replying from gmail).
- Any **paused Flow interviews** trending up (`SELECT COUNT() FROM FlowInterview`).
