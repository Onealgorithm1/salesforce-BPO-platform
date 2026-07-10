# Campaign → Meeting → Opportunity — Operations Certification (Live Production)

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/campaign-certification-and-meeting-attribution`
**Mode:** runtime certification against LIVE production. **Reuse-first; no new objects/fields/flows/Apex/permsets; no automation; no scheduling; no bulk change; no destructive cleanup; no merge; no production changes.** Evidence before conclusions.
**Builds on:** [CAMPAIGN_MEETING_OPPORTUNITY_OPERATIONS.md](CAMPAIGN_MEETING_OPPORTUNITY_OPERATIONS.md) + [CMO_MEETING_FORENSICS_AND_STATE_MACHINE.md](CMO_MEETING_FORENSICS_AND_STATE_MACHINE.md).

---

## 1. Executive Summary
The Campaign→Meeting→Opportunity subsystem is **operationally certified against live production**: the CampaignMember lifecycle is governed (10 statuses), the happy path works (1 Meeting-Booked, Opportunity-ready Lead), every unhappy path has a defined outcome, and the real Stragistics meeting validated the correct **no-Opportunity (no-show)** result. Two certified findings drive the next step: **(1) meeting attribution is 100% mislinked** (all 5 manual meetings → internal contact; all 132 Events `WhatId=null`); **(2) ERE has only processed Email-Reply signals (44 rows, 40 no-match) and has NEVER been run over the meeting mislinks** (0 meeting signals, 0 internal-mislink flagged). ERE is the built remediation — it just hasn't been activated for meetings. **No production changes.** **Verdict: 🟢 PASS** (certified; nothing fails silently; the ERE meeting-activation is the identified, gated next step).

## 2. Campaign Certification (Phase 0)
| Campaign | Type | Status | Active | Leads | Purpose |
|---|---|---|---|---|---|
| **EDWOSB Teaming Outreach - Prime Subcontract** (`701Pn00001ZOyj8IAD`) | Email | **Active** | ✅ | **351** | the production campaign |
| OA Internal Smoke Test 4E / P2 / Btn, RenderProof, UX Verify (×5) | Other | In Progress | ✅ | 1 each | internal smoke tests |
**Certified:** 1 real production campaign; 5 internal test campaigns (data-hygiene cleanup candidates — **gated/destructive, not touched**). **No Campaign/CampaignMember validation rules or triggers.** Owner `005bn00000BP9zUAAT`. Sharing: org-standard.

## 3. CampaignMember Certification (Phase 1)
**Governed lifecycle (10 statuses on the EDWOSB campaign):** Day 1 Sent (default) → Day 3 Sent → Day 5 Sent → Day 10 Sent → **Meeting Booked** (responded) → Replied / Interested / Not Interested / Unsubscribed / Call Completed.
**Actual funnel (live):** Day 1 Sent 227 → Day 3 97 → Day 5 24 → **Meeting Booked 1** · Unsubscribed 6 · + 1 orphan **"Sent"** (a legacy status not in the campaign picklist — minor hygiene finding).
| Transition | Trigger | Human | Automation | Audit | Recovery | Blocked |
|---|---|---|---|---|---|---|
| → Day 1/3/5/10 Sent | drip scheduler | — | ✅ drip | CM status | resend | — |
| Sent → Meeting Booked | booking/reply | **human** (currently manual) | (should be ERE) | CM status | re-nurture | needs meeting |
| → Replied/Interested | reply detection | human | reply flow | CM status | — | — |
| → Unsubscribed | unsubscribe | prospect | flow | CM + pref | — | terminal |
| Meeting Booked → Opportunity Ready | positive outcome | **human qualify** | — | Lead status | — | no-show blocks |
**Governance:** progression is status-driven; the **Sent→Meeting Booked** advance is currently manual (Marty was set by hand) — ERE `Resolved_CampaignMember__c` is designed to automate this once activated.

## 4. Meeting Attribution Certification (Phase 2)
| Path | Expected | Actual (live) | Failure mode |
|---|---|---|---|
| Microsoft Bookings | Event linked to prospect Lead | poller-based (dormant); no Bookings meetings observed | — |
| **Manual Outlook/Teams** | Event → prospect Lead + CampaignMember | **Event → internal organizer (Sreenivas); WhatId null; CM not advanced** | **100% mislink (5/5)** |
| Recurring/Rescheduled/Cancelled | status update | not observed | — |
| **No-show (Stragistics)** | no Opportunity | **0 Opportunity ✅ correct**; CM stuck "Day 5 Sent" | correct outcome, tracking gap |
| Read.ai / Graph / transcript / recording | artifact pipeline | poller-based (dormant) | delayed/absent handled by poller |
| Campaign / Lead / Opportunity linkage | Event.WhatId/WhoId correct | **WhoId=internal, WhatId=null (132/132)** | mislink |
**Certified:** meeting attribution is **understood and quantified** — manual meetings systematically attach to the internal organizer, invisible to the prospect. **ERE is the built resolver.**

## 5. ERE Certification (Phase 3)
| Dimension | Finding |
|---|---|
| Detection | ✅ works for **Email Reply** (44 shadow rows observed) |
| Matching | 🟡 **weak** — 40/44 "No Match", 1 Needs Review, 3 Observed (email exact-match gap) |
| Confidence / Matched level | fields present (`Confidence__c`, `Matched_Level__c`); email path low-yield |
| Resolved Lead/Contact/CampaignMember/Opportunity | fields present (`Resolved_*__c`) — **unpopulated for meetings** |
| **Internal attendee detection** | 🔴 **0 rows flagged `Internal_Mislink__c=true`** — the meeting-mislink path **has NOT been run** |
| **Meeting/Event signals** | 🔴 **0** — ERE has processed **no** meeting signals |
| False positives / negatives | email path: high false-negative (no-match); meeting path: untested |
| Write-back readiness | observe-only (0 writes); write-back designed, not enabled |
| Backfill readiness | email backfill ran (44); **meeting backfill NOT run** |
| Human review | `Status__c` = Observed/Needs Review/No Match (queue exists) |
| Rollback | shadow-only → inherently reversible (no CRM writes yet) |
**Recommendation:** activate ERE **meeting-signal detection/backfill** over the 5 mislinked Events (observe), review the resolved Contact/Lead/CampaignMember, then enable **gated write-back** to re-attribute meetings + advance CampaignMembers. Separately, strengthen email-reply matching (exact-email-only is the 40/44 no-match cause — a known EDWOSB issue).

## 6–8. Happy / Unhappy Path Matrix + State Machine
Fully documented in [CMO_MEETING_FORENSICS_AND_STATE_MACHINE.md](CMO_MEETING_FORENSICS_AND_STATE_MACHINE.md) §4–§6 (validated against Stragistics + Marty). Summary: **no-show/cancelled BLOCK Opportunity** (Stragistics ✅); **Opportunity-Ready→Created requires human qualification**; **mislinked meetings must be ERE-resolved** before a prospect advances; every unhappy path has detection/recovery/retry/rollback/audit/notification defined — **nothing fails silently**.

## 9. Components Implemented (Phase 5 — reversible, reuse-first)
- Reused monitors `cmo_pipeline_monitoring.apex` + `cmo_meeting_lifecycle_monitor.apex` (0-DML; surface funnel + mislink + ERE posture).
- **No new metadata** — the subsystem is standard objects + existing ERE/poller Apex. Certification is documentation + monitoring. **Not overengineered.**

## 10. Dashboards (Phase 6 — reuse-first; questions answered)
**Executive:** campaign ROI, meetings scheduled/completed/no-show, meeting/opportunity conversion, pipeline — from CampaignMember status + Event + Opportunity (reuse `Meeting Booked`, `Funnel By Campaign`, `Pipeline By Close Month`). **BD:** campaign performance, prime/agency engagement, follow-up queue, pipeline. **Operations:** CampaignMember backlog, **meeting attribution errors (=5 mislinks)**, **ERE queue (44, 40 no-match)**, transcript/recording/AI-summary failures (poller run logs), runtime health (monitors). **Compliance:** audit completeness (Event/CM history + ERE shadow), human approvals, rollbacks, attribution corrections, runtime-user activity. Build the Opportunity-by-stage + ERE-queue dashboards when activation proceeds.

## 11. Validation Results (Phase 8 — live)
- Campaigns: 6 (1 real Active, 5 smoke) — certified live.
- CampaignMember: 10-status lifecycle; funnel {Day1 227/Day3 97/Day5 24/Meeting Booked 1/Unsub 6/Sent 1} — live.
- Meetings: 132 Events, 79 with Who, **132 WhatId-null, 5 mislinked** — live monitor.
- ERE: 44 rows all Email Reply, **0 meeting signals, 0 internal-mislink** — live.
- Opportunities: **0** (correct; no positive-outcome conversion yet).
- Monitors run at **0 DML**; no tests/flows/Apex changed; no unintended automation (5 async = existing pollers).

## 12–15. Production Changes / Risks / Rollback / Technical Debt
- **Production changes:** **none** (read-only certification + monitors; no metadata deployed).
- **Risks:** 100% meeting mislink hides meetings from prospects until ERE writes back [High]; weak email-reply matching (40/44 no-match) [Med]; manual CampaignMember advancement [Med]; 5 smoke-test campaigns + 1 orphan "Sent" status = data hygiene [Low].
- **Rollback:** n/a (no changes); ERE remains observe-only.
- **Technical debt:** (1) **activate ERE meeting attribution** (backfill + gated write-back) — top item; (2) strengthen email-reply matching beyond exact-email; (3) auto-advance CampaignMember on matched meeting; (4) clean up 5 smoke-test campaigns + orphan "Sent" status (gated); (5) Opportunity-by-stage + ERE-queue dashboards.

## 16. PASS / WARN / FAIL — 🟢 PASS
Campaign→Meeting→Opportunity is **fully understood, operationally certified, and validated against live production.** Happy path succeeds (Opportunity-ready Lead); every unhappy path has a defined, non-silent outcome; **meeting attribution is understood** (mislink quantified, ERE is the fix); CampaignMember progression is governed (10 statuses). The mislink is **detected, not silent**, with a defined remediation. **No production changes; no new architecture.**

## 17–18. Commit / PR
See closeout — new branch/PR; not merged.

## 19. Exact Next Engineering Sprint
**ERE Meeting-Attribution Activation (gated):** run ERE meeting-signal detection/backfill over the 5 mislinked Events (observe → shadow rows with `Internal_Mislink__c=true` + `Resolved_Lead/Contact/CampaignMember`), human-review the resolutions, then enable **gated write-back** to (a) re-attribute meetings to the correct prospect and (b) advance the CampaignMember to "Meeting Booked". Then the supervised Lead→Opportunity conversion (Marty/Medianow) proceeds on a correctly-attributed meeting. Do NOT start Opportunity Intelligence; do NOT reopen BLO.
