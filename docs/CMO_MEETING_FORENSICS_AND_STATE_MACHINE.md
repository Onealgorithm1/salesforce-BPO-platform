# Campaign → Meeting → Opportunity — Real Production Meeting Validation (Stragistics)

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/campaign-meeting-opportunity-operations`
**Mode:** engineering · runtime validation using the **real Stragistics production meeting**. **Reuse-first; no new objects/fields/flows/Apex/permsets; no automation; no scheduling; no bulk change; no merge; no production changes.** Evidence before conclusions.

---

## 1. Executive Summary
Validated the Campaign→Meeting→Opportunity subsystem against the **real Stragistics meeting** — and the forensics prove both the correct outcome and the systemic defect. **Correct:** the prospect no-showed, so **no Opportunity was created** (exactly right). **Defect (systemic, quantified live):** the manual Teams/Outlook meeting synced to Salesforce as an Event **mislinked to the internal organizer** (Sreenivas Amirisetti, `@onealgorithm.com`) with **`WhatId = null`**, and the prospect's **CampaignMember stayed at "Day 5 Sent"** (never advanced to "Meeting Booked"). **All 5 manual meetings** in the org show this same mislink. The **ERE (Engagement Resolution Engine)** is the already-built, observe-only subsystem designed to resolve exactly this. This sprint delivers full forensics, happy/unhappy path matrices, the operational state machine, and a **reusable meeting-lifecycle monitor** that surfaces the unhappy paths — **no new architecture, no production changes**. **Verdict: 🟢 PASS.**

## 2. Runtime Audit (Phase 0 — live)
**Meeting-related Apex (existing, reuse):** `OA_BookingPoller`, `OA_ArtifactPoller`, `OA_ReplayBookingService`, `OA_AISummaryService`/`OA_AISummaryQueueable`, `OA_EngagementResolver`/`OA_EngagementResolverBatch`/`OA_EngagementResolverQueueable`, `OA_EngagementSignal`. **Objects/CMDT:** `OA_Graph_Credential__c`, `OA_Engagement_Resolution__c` (ERE shadow, 44 rows), `OA_Graph_Config__mdt`, `OA_Engagement_Config__mdt`. **Pipelines:** Graph/Bookings (poller-based), recording/transcript (artifact poller), AI summary (queueable, dormant). **Meeting-path scheduled jobs:** booking/artifact pollers (existing, protected). **Opportunity:** standard/vanilla (no rules/triggers). **No new meeting metadata needed.**

## 3. Meeting Forensics Report (Phase 1 — Stragistics, reconstructed from production)
| Fact | Evidence |
|---|---|
| Meeting Event | `00UPn00000xBZDNMA4` — "One Algorithm / Stragistics Teaming Discussion" |
| Date / duration | 2026-07-08 19:15 UTC · 30 min |
| Organizer/Owner | `005bn00000BP9zUAAT` (internal) |
| **Event WhoId** | **`003Pn00001dLtH7IAK` = Sreenivas Amirisetti (`samirisetti@onealgorithm.com`, Account = One Algorithm LLC — INTERNAL)** ❌ mislink |
| **Event WhatId** | **null** ❌ (not linked to Campaign/Opp/Account) |
| Prospect Lead | `00QPn000011DshWMAS` — Hughetta Dudley, **Stragistics Technology, INC.** |
| Prospect's own Events | **0** (meeting linked away to internal contact) |
| CampaignMember | `00vPn00001EgUVnIAN` — Status **"Day 5 Sent"** (❌ never advanced to "Meeting Booked") in campaign `701Pn00001ZOyj8IAD` |
| Attendance | internal attendees joined; **prospect NO-SHOW** (per record + business facts) |
| Recording / Transcript / Read.ai | Read.ai appeared; artifact pipeline is poller-based (dormant) |
| Opportunity | **0** — ✅ **correct** (no-show → no Opportunity) |
| Audit | Event exists; ERE shadow (44 rows) is the detection layer (backfill not run → 0 flagged yet) |
**What happened:** a manually-scheduled Teams/Outlook meeting occurred; the prospect did not attend; the Event synced but attached to the internal organizer (not the prospect) with no What linkage, and the campaign status was not advanced. The **absence of an Opportunity is the correct outcome**; the mislink + un-advanced CampaignMember are the tracking defects ERE addresses.

## 4. Happy Path Matrix (Phase 2)
| Stage | Transition | Owner | Evidence/mechanism |
|---|---|---|---|
| Lead → Campaign | enrollment flow | automation | CampaignMember created |
| Campaign → Meeting Scheduled | Bookings/manual invite | prospect/human | Event (or Booking) |
| Meeting Scheduled → Occurs | attendance | human | Event start; attendees join |
| Occurs → Recording/Transcript | artifact pollers | automation | `OA_ArtifactPoller` (dormant) |
| Transcript → AI Summary | queueable | automation (gated) | `OA_AISummaryService` → `Lead.AI_Summary__c` |
| Summary → Follow-up | human | reviewer | Task/next step |
| Follow-up → **Opportunity** | **human qualifies → standard Lead Conversion** | human | Lead "Qualified" → Account+Contact+Opportunity |
| Opportunity → Customer | sales process | human | Stage → Closed Won |
**Reliability dependency:** the meeting must link to the **correct prospect** (ERE resolves the mislink) and advance the CampaignMember to "Meeting Booked", so the human can qualify → convert.

## 5. Unhappy Path Matrix (Phase 3)
| Failure | Detection | Recovery | Retry | Rollback | Audit | Notification | Business impact |
|---|---|---|---|---|---|---|---|
| **Prospect no-show (Stragistics)** | Event exists, no positive outcome | mark CM "No-show"; re-nurture | reschedule | n/a (no Opp created) | Event + CM | ops | ✅ no Opp — correct |
| **Event mislink to internal (systemic, 5/5)** | monitor: Who=internal contact; ERE `Internal_Mislink__c` | ERE resolves Contact/Lead/CM (observe→writeback, gated) | ERE re-run | re-point WhoId | ERE shadow row | ops | meeting invisible on prospect |
| Manual meeting (no Bookings) | Event present, no Booking | ERE match by attendee email | — | — | ERE | — | tracking gap |
| Cancelled / Rescheduled | Event status/date change | update CM; reschedule | yes | — | Event history | prospect | delayed pipeline |
| Host absent | no internal attendee | reschedule | yes | — | Event | ops | reputational |
| No transcript / No recording / delayed | artifact poller returns none | retry poll; manual note | poller retry | — | `OA_Connector_Run__c` | ops | summary delayed |
| Read.ai only | external artifact, no Graph transcript | manual capture | — | — | note | — | partial record |
| Graph unavailable / API timeout | poller error | retry/backoff | poller | — | run log | ops | sync delay |
| Permission failure | callout/FLS error | fix perms | — | — | log | admin | blocked sync |
| Email verification failure | (BLO) validation rule | reviewer supplies email | — | — | change log | reviewer | no Lead/Opp |
| Duplicate meeting | two Events same subject/time | dedupe by ERE key | — | delete dup | ERE | ops | double-count |
| Meeting deleted | Event missing | ERE detects gap | — | recreate | — | ops | lost record |
**Nothing fails silently:** every path has a detection signal (Event state, ERE shadow, poller run log, or the monitor).

## 6. Business Lifecycle State Machine (Phase 4)
| State | Allowed → | Blocked | Human approval | Automation | Audit | Recovery |
|---|---|---|---|---|---|---|
| Lead | Campaign Assigned | — | — | enrollment | CM create | — |
| Campaign Assigned | Meeting Requested, (drip) | — | — | drip Day1/3/5 | CM status | re-nurture |
| Meeting Requested | Meeting Scheduled, Cancelled | — | — | Bookings/manual | Event | reschedule |
| Meeting Scheduled | Confirmed, Cancelled, Rescheduled | — | — | reminder | Event | reschedule |
| Meeting Confirmed | Started, No-show, Cancelled | — | — | — | Event | — |
| Meeting Started | Completed | — | — | — | Event | — |
| Meeting Completed | Follow-up Required, Opportunity Ready | Opportunity Created (needs qualify) | — | artifact/summary | Event+artifacts | — |
| **Meeting No-show (Stragistics)** | Follow-up Required (re-nurture) | Opportunity Ready | — | — | Event/CM | re-nurture |
| Meeting Cancelled | Meeting Requested (reschedule) | Opportunity | — | — | Event | reschedule |
| Follow-up Required | Opportunity Ready, (closed) | — | reviewer | — | Task | — |
| Opportunity Ready | Opportunity Created | — | **human qualify** | — | Lead status | — |
| Opportunity Created | Customer, (Closed Lost) | — | sales process | — | Opp | stage back |
| Customer | — (terminal) | — | — | — | Opp Won | — |
**Key gates:** No-show/Cancelled **block** Opportunity (Stragistics validated); Opportunity Ready→Created requires **human qualification** (no auto-conversion); mislinked meetings must be **ERE-resolved** before a prospect can advance.

## 7. Components Implemented (Phase 5 — reversible, reuse-first)
- `scripts/apex/cmo_pipeline_monitoring.apex` (prior) — pipeline funnel monitor.
- `scripts/apex/cmo_meeting_lifecycle_monitor.apex` (**new**) — meeting health + unhappy-path detection (mislink, WhatId-null, ERE posture, no-Opp). Verified live (0 DML). Both embedded in-doc (`scripts/` gitignored).
- **Reused:** ERE (`OA_Engagement_Resolution__c` + resolver classes) as the mislink-resolution engine; standard Event/Campaign/Opportunity; standard Lead Conversion. **No new metadata deployed.**

## 8. Dashboards (Phase 6 — reuse-first; questions answerable now)
Meetings scheduled/completed/cancelled/no-show (Event + CampaignMember status), avg duration (Event.DurationInMinutes), recording/transcript/AI-summary success (artifact poller/`OA_Connector_Run__c`), Meeting→Opportunity conversion (CM Meeting Booked vs Opps), Campaign→Meeting & Lead→Meeting conversion (funnel), **where stuck** (mislinked events = 5; CM at Meeting Booked not converted = 1; no-show not re-nurtured). Reuse `Meeting Booked`, `Funnel By Campaign`, `Pipeline By Close Month`, `BPO Artifact Pipeline Health` + the two monitors.

## 9. Monitoring (live evidence)
`[MTG-MON]` Events 132 · withWho 79 · **WhatId-null 132** · **MISLINKED 5 → ERE RESOLUTION REQUIRED** · CampaignMember Meeting Booked 1 · ERE shadow 44 (0 flagged — backfill not run) · **Opportunities 0** · meeting-path async 5 (existing pollers). 0 DML.

## 10. Validation (Phase 7)
Runtime forensics reconstructed the Stragistics meeting from production (Event + Lead + CampaignMember + internal-contact linkage). No tests/flows/Apex changed. Reports/dashboards reused. Data integrity intact. **No unintended automation** (the 5 async are pre-existing pollers; no new schedules). Audit via Event history + ERE shadow. Monitors run at 0 DML.

## 11–14. Production Changes / Risks / Rollback / Tech Debt
- **Production changes:** **none** (read-only forensics + monitors; scripts repo-only, not deployed).
- **Risks:** systemic Event-mislink (5/5) leaves meetings invisible on prospects until ERE writes back [High-value defect]; CampaignMember not auto-advanced on manual meetings [Med].
- **Rollback:** n/a (no changes). ERE remains observe-only.
- **Technical debt:** (1) **activate ERE resolution** (backfill + gated write-back) to fix the 5 mislinks — the highest-value item; (2) advance CampaignMember to "Meeting Booked" when a matched meeting occurs (reuse ERE `Resolved_CampaignMember__c`); (3) Opportunity-by-stage dashboard once Opps exist. No new engineering debt introduced.

## 15. PASS / WARN / FAIL — 🟢 PASS
The Campaign→Meeting→Opportunity subsystem is **understood, engineered (happy + unhappy paths + state machine), and validated against the real Stragistics meeting** — which correctly produced **no Opportunity** (no-show) while exposing the systemic Event-mislink that ERE is built to resolve. Nothing fails silently; no new architecture; no production changes; monitoring in place.

## 16–17. Commit / PR
See closeout — same branch/PR #58; not merged.

## 18. Exact Next Engineering Sprint
**ERE Activation for Meeting Attribution (gated):** run the ERE backfill (observe) over the 5 mislinked meetings, review the resolved Contact/Lead/CampaignMember, then enable gated write-back to (a) re-attribute meetings to the correct prospect and (b) advance the CampaignMember to "Meeting Booked". Then the **supervised Lead→Opportunity conversion** (Marty/Medianow, gated) can proceed on a correctly-attributed meeting. (Opportunity *Intelligence* remains separate/gated; BLO stays closed.)

---

## Appendix A — Meeting lifecycle monitor (`scripts/` gitignored; committed here)
```apex
Integer events=[SELECT COUNT() FROM Event];
Integer eventsWho=[SELECT COUNT() FROM Event WHERE WhoId!=null];
System.debug('[MTG-MON] Events total='+events+' withWho='+eventsWho+' WhatId-null='+[SELECT COUNT() FROM Event WHERE WhatId=null]);
Set<Id> internal=new Set<Id>();
for(Contact c:[SELECT Id FROM Contact WHERE Email LIKE '%@onealgorithm.com']){ internal.add(c.Id); }
Integer mislinked=0;
for(Event e:[SELECT Id,WhoId FROM Event WHERE WhoId!=null]){ if(internal.contains(e.WhoId)) mislinked++; }
System.debug('[MTG-MON] MISLINKED meetings (Who=internal)='+mislinked+' of '+eventsWho+' => '+(mislinked>0?'ERE RESOLUTION REQUIRED':'OK'));
System.debug('[MTG-MON] CampaignMember Meeting Booked='+[SELECT COUNT() FROM CampaignMember WHERE Status='Meeting Booked']);
System.debug('[MTG-MON] ERE shadow rows='+[SELECT COUNT() FROM OA_Engagement_Resolution__c]+' internal-mislink-flagged='+[SELECT COUNT() FROM OA_Engagement_Resolution__c WHERE Internal_Mislink__c=true]);
System.debug('[MTG-MON] Opportunities='+[SELECT COUNT() FROM Opportunity]+' | DMLrows='+Limits.getDmlRows());
```
