# OPERATIONS.md — BPO Platform Operations (master)

Production operations reference for the Salesforce BPO Platform. Pairs with [DAILY_OPERATIONS.md](DAILY_OPERATIONS.md) and [WEEKLY_OPERATIONS.md](WEEKLY_OPERATIONS.md). Governance rules live in [../CLAUDE.md](../CLAUDE.md).

## Production coordinates
- **Org ID:** `00Dbn00000plgUfEAI` (verify by **ID**, never name) · instance `onealgorithmllc.my.salesforce.com` · admin `oauser@pboedition.com`
- **Repo `main`** mirrors production; protected. `git rev-parse main origin/main` should match.
- **EDWOSB campaign:** `701Pn00001ZOyj8IAD`

## Deployed operational assets (as of 2026-07-08)
| Area | Assets | State |
|---|---|---|
| **Executive Analytics** | Object `Campaign_Funnel_Snapshot__c`; report types `OA_Email_Messages__c`, `OA_Campaign_Funnel_Snapshots__c`; folder `OA Executive Analytics` (6 reports); dashboard `Executive Campaign Analytics` (running user `oauser`); permset `OA_Executive_Analytics_Access` (assigned: oauser, onealgorithm) | Live |
| **ERE Phase 1** | Object `OA_Engagement_Resolution__c` (shadow log); CMDT `OA_Engagement_Config__mdt` (`EDWOSB_Default`, Observe_Only=true); classes `OA_EngagementSignal/Resolver/ResolverQueueable/ResolverBatch`; permset `OA_Engagement_Reviewer` (assigned: oauser); report `Engagement Resolution Review` | Live, **observe-only, dormant** |
| **Legacy** | `BPO Campaign Operations` reports + `BPO Campaign Dashboards` (Command Center) | Live (baseline) |
| **Lead Enrichment** | v1.2 certified | **Maintenance mode** — see [LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md](LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md) |

## Protected areas (no change without explicit approval)
`OA_EDWOSB_Outreach_Sequence` · `OA_Reply_Detection` · `OA_PostMeeting_Nurture` · `OA_EmailSender` · Lead Enrichment writeback · Named/External Credentials · M365 Graph/Bookings/Teams · production data · Cloudflare/DNS · www.onealgorithm.com. Full list + autonomy tiers in [../CLAUDE.md](../CLAUDE.md).

## Standing operational facts
- **ERE is observe-only.** Its only DML is `insert OA_Engagement_Resolution__c` (`OA_EngagementResolver.cls`). It must never write Lead/CampaignMember/Event/EmailMessage/Task/Contact.
- **Send governance:** 100 emails/business day (shared drip + follow-up), 2 drip runs (08:00 & 14:00 ET). Stop thresholds: bounce ≥5% / unsubscribe ≥3% cumulative.
- **ERE runtime user** is `oauser` (admin/MAD) — acceptable for observe-only; a least-privilege user is required before any ERE write phase.

## Quick health snapshot (one-shot)
```bash
sf org display --target-org oauser@pboedition.com                 # org id + connection
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM AsyncApexJob WHERE Status IN ('Failed','Aborted') AND CreatedDate=TODAY"
sf data query -o oauser@pboedition.com -q "SELECT COUNT() FROM OA_Engagement_Resolution__c"
sf data query -o oauser@pboedition.com -q "SELECT Status, COUNT(Id) FROM CampaignMember WHERE CampaignId='701Pn00001ZOyj8IAD' GROUP BY Status"
sf org list limits --target-org oauser@pboedition.com
```

## Remaining operational (manual / approval-gated) tasks
1. **Configure the Reporting Snapshot** (Setup UI — see DAILY_OPERATIONS §Snapshot). Forward-only; the sooner the more trend history.
2. **Run one Event-observe pass** to surface meeting-Event mislinks (backfill was email-only).
3. **Human-review** the ERE L3/Needs-Review items (e.g., Stragistics) and the Stragistics/Marty manual corrections.
4. Provision a **least-privilege ERE runtime user** before any ERE write phase.
5. Optional: add dashboard **chart components + Campaign filter** (deployable when approved).
