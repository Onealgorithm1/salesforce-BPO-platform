# Engagement Resolution Engine (ERE)

Status: **Phase 1 (Shadow Log) built on `feature/ere-shadow-log`. Source only. NOT deployed, NOT merged.**
Org: `00Dbn00000plgUfEAI` · API 61.0 (Apex)

ERE normalizes every engagement signal (inbound email reply, meeting Event) into a common shape, runs a deterministic matching hierarchy, and writes an auditable resolution record — so a campaign-relevant signal is **never dropped silently**. It fixes two verified defects: `OA_Reply_Detection` matches exact `Lead.Email` only (silent no-match exit), and manually-created Teams Events mislink 100% to an internal contact with no prospect.

---

## 1. Phase 1 scope (this PR)

**Observe / shadow-log ONLY.** No prospect data is changed. Phase 1 delivers:

- **`OA_Engagement_Resolution__c`** — shadow-log / review-queue object (13 fields).
- **`OA_Engagement_Config__mdt`** — campaign scope, matching toggles, assistant prefixes, free-provider domains, internal domain (not hardcoded in Apex). One default record `EDWOSB_Default` (Observe_Only = true).
- **Apex (observe-only):** `OA_EngagementSignal`, `OA_EngagementResolver`, `OA_EngagementResolverQueueable`, `OA_EngagementResolverBatch`, `OA_EngagementResolverTest`.
- **`OA_Engagement_Reviewer`** permission set (read-only).
- **`Needs Review`** list view + **`Engagement Resolution Review`** report (+ report type + folder).

Matching hierarchy implemented: **L1** exact Lead email · **L2** Contact email · **L3** corporate domain (free providers excluded; single unambiguous lead only) · **L6** human review. Every signal produces exactly one shadow-log row. Meeting Events are flagged `Internal_Mislink__c` and routed to review.

---

## 2. No-write guarantee

The resolver's **only** DML statement is `insert` on `OA_Engagement_Resolution__c`. It never inserts, updates, or deletes **Lead, Contact, CampaignMember, Event, EmailMessage, Task**, or any campaign record. There is:

- **No auto-apply** — nothing acts on a resolution.
- **No Contact creation.**
- **No status update** to prospect records.
- **No campaign automation change.**

Enforced structurally (single DML target) and verified by test `testObserveOnlyNoProspectWrites` (asserts Lead/Contact/CampaignMember counts and Lead fields are unchanged).

---

## 3. Architecture decisions

- **Dormant entry by design.** Phase 1 ships **no active trigger or flow**. Nothing fires on prospect activity. The safe minimal entry point is `OA_EngagementResolverBatch`, run manually by an admin (`Database.executeBatch(new OA_EngagementResolverBatch())`) to backfill inbound emails since 2026-07-01 into the log. `OA_EngagementResolverQueueable` is available for future event-driven use but is not wired to any trigger.
- **Config-driven, campaign-agnostic.** Campaign id and all thresholds live in `OA_Engagement_Config__mdt`, not Apex. Default scope = EDWOSB campaign `701Pn00001ZOyj8IAD`.
- **Bulk-safe.** Email/domain matches use set-based SOQL (`Email IN`, one dynamic domain query); no SOQL/DML in loops.
- **Free-provider exclusion** prevents L3 domain fan-out (gmail/outlook/etc.).
- **Test isolation.** `OA_EngagementResolver.overrideCfg` injects config so tests never depend on a deployed CMDT record.

---

## 4. Known deferred items (Phase 2+)

- **L4** assistant/shared-mailbox heuristics + Contact auto-create.
- **L5** conversation/thread matching — **blocked**: `OA_EmailSender` stamps no Message-ID/References headers; needs an outbound-header spike or reliable EAC headers first.
- **Bookings adapter** refactor (fold in `OA_BookingPoller`).
- **Auto-apply** (high-confidence L1) — Phase 4 only, behind the `OA_LeadWritebackService` preview→gate→commit→rollback harness.
- **Dedicated least-privilege runtime user** before any write phase (MAD currently bypasses FLS).
- **Absorb Meeting Tracking** (`OA_Meeting_Scheduled_Link`) — preserve its branch; do not deploy standalone.
- Active observe-only trigger on EmailMessage/Event (Phase 2), still write-free.

---

## 5. Test cases

| Test | Verifies |
|---|---|
| `testMatchingHierarchy` | L1/L2/L3-single/L3-ambiguous/free-domain-no-match all classify correctly; all 5 signals logged; CampaignMember mapped for L1 |
| `testObserveOnlyNoProspectWrites` | Lead/Contact/CampaignMember counts + Lead fields unchanged; only shadow log written |
| `testObserveEmailsInMemory` | Only inbound emails observed (outbound skipped) |
| `testObserveEventsInternalMislink` | Events with null WhatId and internal-domain contacts both flagged `Internal_Mislink__c` and routed to review |
| `testQueueableAndBatch` | Queueable `execute` and Batch `execute`/`start`/`finish` run and log |
| `testDefaultConfigFallback` | Safe built-in config path when no CMDT record present |

---

## 6. Rollback

Entirely additive and isolated; no prospect data touched.

1. Remove Apex classes, permission set, report + report type, list view.
2. Remove `OA_Engagement_Config__mdt` record + type.
3. Remove `OA_Engagement_Resolution__c` object (delete any shadow-log rows first, or destructive delete removes object + rows).

Shadow-log rows exist only after an admin runs the backfill batch; there are none at deploy time. Nothing in Lead/Contact/CampaignMember/Event/EmailMessage was changed, so there is nothing to reverse there.

---

## 7. Deployment notes

- Deploy the object + report type **before** the report (same Salesforce check-only limitation as any new custom report type: reports can't resolve a report type created in the same validation transaction — deploys fine as a unit / two-phase).
- After deploy: assign `OA_Engagement_Reviewer` to reviewers; optionally run `Database.executeBatch(new OA_EngagementResolverBatch())` to backfill the log; review the `Needs Review` list view and `Engagement Resolution Review` report.
- No schedule, no trigger to activate in Phase 1.

---

## 8. Manual correction items — STILL NOT EXECUTED

These approved-but-unexecuted manual UI corrections (Field History = rollback) are **not** performed by this engine and remain outstanding:

- **Stragistics** — Lead `00QPn000011DshWMAS` (Relationship_Status / Meeting_Booked_Date 2026-07-08 / Teams_Meeting_Id 280125100495816); CampaignMember `00vPn00001EgUVnIAN` Day 5 Sent → Meeting Booked; reply `02sPn00001WnsKeIAJ` relate; Event `00UPn00000xBZDNMA4` WhoId→prospect / WhatId→lead; create Contact for **Perjeah Dhevun / adminasst@stragistics.com** (has no record — blocking decision).
- **Marty / MediaNow** — Lead `00QPn000011DshtMAC` (Relationship_Status / Meeting_Booked_Date 2026-07-10 / Status Open → Working); Event `00UPn00000wzdflMAA` relink (CampaignMember already correct).

Phase 1 will **surface** these patterns in the shadow log; it does not fix them.
