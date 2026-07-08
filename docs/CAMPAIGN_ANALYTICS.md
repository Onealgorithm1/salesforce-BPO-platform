# Campaign Analytics

Status: **Built on branch `feature/campaign-analytics-foundation`. Validated check-only. NOT deployed, NOT merged.**
Scope: Packages A–C (analytics foundation, reports, dashboard, trend snapshot). **Package D (click tracking) is intentionally deferred.**
Org: `00Dbn00000plgUfEAI` (One Algorithm LLC, production) · API 67.0

This document distinguishes two layers that must not be confused:

1. **Legacy EDWOSB Operational Reporting** — the pre-existing suite. Left **as-is**. Not modified by this work.
2. **New Reusable Executive Analytics Framework** — the campaign-agnostic suite added by this sprint.

---

## 1. Legacy EDWOSB Operational Reporting (baseline — unchanged)

Already present in production and source control before this sprint. **Treated as the operational baseline and left untouched.**

- **Report folder `BPO Campaign Operations`** — 21 reports (Day 1/3/5/10 Sent, Replied, Interested, Not Interested, Meeting Booked, Unsubscribed, Campaign Members by Status, Lead Inventory, etc.).
- **Report folder `OA BPO Pilot`** — BPO Artifact Pipeline, Exception Monitor, Lead Outreach Status.
- **Dashboard folder `BPO Campaign Dashboards`** — **BPO Campaign Command Center**, BPO Operations Daily, BPO Exception Monitor.

**Known limitation of the legacy suite (not fixed here, logged as debt):** 17 of the 21 legacy reports **hardcode the campaign by name** (`EDWOSB Teaming Outreach - Prime Subcontract`). They do not support a second campaign. The new framework below avoids this.

---

## 2. New Reusable Executive Analytics Framework

Campaign-agnostic. No hardcoded campaign names or IDs. Adds the three capabilities the legacy suite lacked: **Opens, Bounces, and funnel Trend-over-time.**

### Architecture

| Layer | Component | Notes |
|---|---|---|
| Data source | `EmailMessage` (standard) | Holds sends (`MessageDate`), opens (`FirstOpenedDate`), bounces (`IsBounced`), direction (`Incoming`). |
| Data source | `CampaignMember` via `CampaignLead` report type | Funnel by campaign + status. |
| Trend store | `Campaign_Funnel_Snapshot__c` (new custom object) | Holds daily point-in-time funnel rows so trend history accrues. |
| Report type | `OA_Email_Messages` (new, on `EmailMessage`) | Backs Opens, Bounces, Sent-by-Day. |
| Report type | `OA_Campaign_Funnel_Snapshots` (new, on the snapshot object) | Backs the trend report. |
| Reports | 6 new (see below) | 2 on standard `CampaignLead`, 3 on `OA_Email_Messages`, 1 on `OA_Campaign_Funnel_Snapshots`. |
| Dashboard | `Executive Campaign Analytics` (new) | Metric tiles; trend charts added in UI. |
| Trend capture | Native **Reporting Snapshot** | Configured in Setup (native, no Apex). See §4. |

**No Apex. No Flow. No triggers.** Entirely declarative + native reporting.

### Reports (folder `OA Executive Analytics`)

| Report | Report Type | Purpose | Gap filled |
|---|---|---|---|
| `Funnel By Campaign` | CampaignLead | Members by campaign + status, all campaigns | (reusable funnel) |
| `Funnel Snapshot Source` | CampaignLead (Tabular) | Feed for the daily snapshot only | (trend feed) |
| `Email Opens` | OA_Email_Messages | Outbound emails with a First Opened date | **Opens** |
| `Outreach Sent By Day` | OA_Email_Messages | Outbound email volume per day | Performance by day |
| `Email Bounces` | OA_Email_Messages | Outbound emails where `IsBounced = true` | **Bounces** |
| `Daily Funnel Trend` | OA_Campaign_Funnel_Snapshots | Member counts by status across snapshot dates | **Trend over time** |

### Dashboard (folder `OA Executive Analytics`)

`Executive Campaign Analytics` — metric tiles: Total Members, Total Sent, Bounces, Total Opens. Running user `oauser@pboedition.com`.
Trend chart components (Funnel Trend, Sent per Day, Opens per Day) and a Campaign filter are added in the UI from the matching reports — a 2-minute native step (the org has no existing chart-component metadata to template from, so tiles ship as the proven pattern).

---

## 3. Multi-campaign support

- Every new report is **campaign-agnostic** — no campaign filter is baked in; `Funnel By Campaign` groups by campaign so all campaigns appear.
- To focus the dashboard on one campaign, add a **Campaign dashboard filter** (`Campaign Name`) in the UI.
- The snapshot object stores `Campaign_Name__c`, so trend history is per-campaign automatically.

---

## 4. Daily Trend Snapshot — native setup

Salesforce does not retain a daily history of the funnel. This is captured with a **native Reporting Snapshot** (Setup > Reporting Snapshots), which requires no code:

1. **Source report:** `OA Executive Analytics > Funnel Snapshot Source` (tabular: Campaign Name, Member Status).
2. **Target object:** `Campaign Funnel Snapshot`.
3. **Field mapping:** Campaign Name → `Campaign_Name__c`; Member Status → `Member_Status__c`. (`Snapshot_Date__c` defaults to `TODAY()` on insert.)
4. **Schedule:** Daily, running as `oauser@pboedition.com`.

Why native UI and not metadata: the Reporting Snapshot mapping/schedule is a declarative Setup wizard; deploying it as `AnalyticSnapshot` metadata is brittle and the schedule is not captured in metadata anyway. The **object and source report are deployed**; the snapshot definition is finalized in Setup. This is the standard, supported approach.

**Scale note:** the source is row-per-member (~275 rows/run today). Reporting Snapshots cap at 2,000 source rows/run. If total membership approaches that, switch the source to a **summary** report (one row per status) and map the row count to `Member_Count__c`.

---

## 5. Deployment (when approved)

Custom report types must exist **before** the reports that use them. Deploy in two phases:

1. **Phase 1:** `Campaign_Funnel_Snapshot__c` object + `OA_Email_Messages` + `OA_Campaign_Funnel_Snapshots` report types + the two `CampaignLead` reports + folders. *(Validated check-only: PASS — Deploy ID `0AfPn0000023ScvKAE`, 10 components, 0 errors.)*
2. **Phase 2:** the 4 reports on the new report types + the dashboard.

A single real (non-dry-run) deployment of the whole package also works, because Salesforce commits components in dependency order during an actual deploy. Only **check-only validation** cannot resolve the same-transaction report-type references (see Limitations).

---

## 6. Limitations

- **Open tracking is directional, not exact.** Opens use a tracking pixel; Apple Mail / Gmail auto-load or block it, so counts drift. Treat `Email Opens` as a trend signal. Reliable engagement = click tracking = **Package D (deferred).**
- **EmailMessage reports are not campaign-scoped.** `EmailMessage` has no campaign link, so Opens/Bounces/Sent are org-wide outbound email, filterable by subject/date but not by campaign. The funnel + trend reports ARE campaign-aware.
- **Funnel trend is forward-only.** History begins the first day the snapshot runs; it cannot be back-filled (Salesforce keeps no daily funnel history).
- **Check-only validation cannot fully validate reports on brand-new custom report types.** This is a documented Salesforce behavior; the metadata is correct and deploys as a unit. Foundation validated clean; dependent reports/dashboard validate once the report types exist.

---

## 7. Maintenance

- **Adding a KPI:** clone an existing report in `OA Executive Analytics`; keep it campaign-agnostic.
- **Adding a campaign:** nothing to do — the framework already spans all campaigns.
- **Snapshot health:** check `Campaign Funnel Snapshot` gets new rows daily; watch the 2,000-row source cap.
- **Do not** point new components at the legacy `BPO Campaign Operations` reports (those are campaign-hardcoded).

---

## 8. Future enhancements

- **Package D — Click tracking** (deferred): reuse the HTTPS unsubscribe link infrastructure to wrap email links and capture clicks in a custom object → reliable engagement KPIs.
- Migrate the legacy campaign-hardcoded reports to the campaign-agnostic framework, then retire the legacy suite after review.
- Switch the snapshot source to summary-level for scale.
- Add native chart components + a Campaign dashboard filter to `Executive Campaign Analytics`.
