# WEEKLY_OPERATIONS.md — Weekly & Monthly Checklists

Read-only management cadence for the BPO Platform. Complements [DAILY_OPERATIONS.md](DAILY_OPERATIONS.md). `-o` = `--target-org oauser@pboedition.com`.

## Weekly checklist

### 1. Campaign performance (management metrics)
```bash
sf data query -o oauser@pboedition.com -q "SELECT Status, COUNT(Id) FROM CampaignMember WHERE CampaignId='701Pn00001ZOyj8IAD' GROUP BY Status ORDER BY COUNT(Id) DESC"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM EmailMessage WHERE CreatedDate=LAST_N_DAYS:7 AND Incoming=false"        # sends this week
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM Task WHERE Subject='Email Send Failed' AND CreatedDate=LAST_N_DAYS:7"   # bounces this week
```
Report to management: total members, funnel distribution, **meetings booked**, **reply/meeting conversion**, weekly send volume, bounce & unsubscribe rates vs. thresholds (bounce <5%, unsub <3%).

### 2. ERE observation summary
```bash
sf data query -o oauser@pboedition.com -q "SELECT Matched_Level__c, Status__c, COUNT(Id) FROM OA_Engagement_Resolution__c GROUP BY Matched_Level__c, Status__c ORDER BY Matched_Level__c"
sf data query -o oauser@pboedition.com -q "SELECT Party_Domain__c, COUNT(Id) FROM OA_Engagement_Resolution__c GROUP BY Party_Domain__c ORDER BY COUNT(Id) DESC LIMIT 15"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM OA_Engagement_Resolution__c WHERE Internal_Mislink__c=true"
```
Assess: reply-capture **uplift vs. the old exact-match flow** (L3/domain matches the old flow would have missed); false-positive review; whether to advance to ERE Phase 2 (resolver proposes) or run an Event-observe pass.

### 3. Production health
```bash
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM AsyncApexJob WHERE Status='Failed' AND CreatedDate=LAST_N_DAYS:7"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM FlowInterview"                                                          # paused interviews
sf org list limits -o oauser@pboedition.com                                                                                            # storage/API trend
```
Escalate: any failed jobs this week; rising paused Flow interviews; storage/API trending toward limits.

### 4. Git / repository
```bash
git rev-parse main origin/main            # in sync
gh pr list --state open                   # review open PRs
```

## Monthly checklist
- **Storage & API trend** — `sf org list limits`; project runway; archive/cleanup if DataStorage > 75%.
- **Scheduled-job audit** — confirm all `OA*` crons still scheduled with correct cadence; no orphaned/duplicate jobs.
- **Permission-set assignment review** — least privilege; confirm `OA_Engagement_Reviewer` / `OA_Executive_Analytics_Access` assignees are still correct.
- **ERE runtime user** — reassess whether a least-privilege runtime user is needed (mandatory before any ERE write phase).
- **Send-cap & threshold review** — confirm 100/day cap + bounce/unsub thresholds still appropriate for volume.
- **Documentation refresh** — reconcile OPERATIONS.md / this file with any new deploys; update the change log.
- **Backup/recovery posture** — confirm `main` = production; tags for released baselines.

## Escalation contacts / gates
- **RED actions** (deploy, merge, data writes, permset assignment, scheduled jobs, backfill, campaign automation, credentials) → explicit Louis approval (see [../CLAUDE.md](../CLAUDE.md)).
- **Stop-the-campaign** triggers: bounce ≥5% or unsubscribe ≥3% cumulative → pause sends and revert per [OPERATIONS.md](OPERATIONS.md).
