# Lead Enrichment — Monitoring Dashboards (Track D build package)

_Status: **build-ready · not deployed** (deploy is out of scope for Sprint 17; build in the go-live
window where folders/report-types materialize and can be validated). 2026-07-06 · Org 00Dbn00000plgUfEAI._

Standard Salesforce reports/dashboards over **existing** objects — **no new schema, no new code**. Every
metric maps to a field the platform already persists. This document is a build package precise enough for an
admin (or a go-live deploy) to create the reports/dashboards in minutes.

Sources: `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Change_Log__c` (writes/rollbacks),
`OA_Enrichment_Exception__c` (review queue), `OA_Discovered_Organization__c` (discovery/qualification).

## Report inventory (build these first)
Create a report folder **"OA Enrichment Ops"** and a Custom Report Type per source object (or use the
auto-generated custom-object report types). Then build:

| # | Report (metric) | Object | Filter | Group by | Summarize | Chart |
|---|---|---|---|---|---|---|
| R1 | **Connector Health** | Connector Run | last 7d | `Source_System__c`, `Status__c` | record count | Stacked bar |
| R2 | **Connector Success Rate** | Connector Run | last 7d | `Source_System__c` | % `Status__c='Succeeded'` (formula) | Gauge/bar |
| R3 | **Connector Duration** | Connector Run | last 7d | `Source_System__c`, day | avg/p95 of `Ended__c`−`Started__c`* | Line |
| R4 | **Records Enriched** | Connector Run | last 30d | day | sum `Records_Enriched__c` | Column |
| R5 | **Records Updated (fields)** | Change Log | `Change_Type__c='Enrich'`, 30d | day, `Source_System__c` | record count | Column |
| R6 | **Exceptions** | Exception | `Status__c='Open'` | `Exception_Type__c` | count + oldest `CreatedDate` | Bar + table |
| R7 | **Rollback Events** | Change Log | `Change_Type__c='Rollback'`, 30d | day | record count | Column (should be ~0) |
| R8 | **Qualification Results** | Discovered Org | 30d | `Qualification_Status__c` | record count | Donut |
| R9 | **Platform Health tiles** | Connector Run | last 24h | — | count `Status__c='Failed'`; sum `HTTP_Errors__c`; sum `Exceptions_Raised__c` | Metric |
| R10 | **Executive Summary** | Connector Run | last 30d | — | runs, sum `Records_Enriched__c`, success % | Metric row |

\* Duration: either add a formula column `Ended__c − Started__c` in the report, or read `duration_ms` which the
runner already writes into `Messages__c`.

## Dashboard layout (2 dashboards, 10 components)
**Dashboard A — "OA Enrichment — Executive Summary"** (for Louis): R10 (headline metrics), R4 (records
enriched trend), R2 (success rate), R8 (qualification donut).

**Dashboard B — "OA Enrichment — Platform Health / Ops"** (for operators): R9 (health tiles),
R1 (connector health), R3 (duration), R5 (records updated), R6 (exceptions), R7 (rollback events).

## Must-be-zero compliance tiles (red if non-zero → page the owner)
Single-number components on Dashboard B, sourced from the exception/change-log data:
- **Rollback failures** (R7-derived) · **Writes without snapshot** (Change Log where `Before_Snapshot__c`
  is blank) · **Policy/floor violations** (Exception `Exception_Type__c='PolicyException'`).

## Deploy notes
- Nothing here is deployed. When authorized, create the folder + report type first, then reports, then the
  two dashboards (dashboards reference reports by folder/name, so build in that order).
- Once live, wire **report subscriptions** for the alert thresholds in `OPERATIONAL_ALERTS.md`.
- All metrics come from existing fields on the four objects — confirmed present via the runtime permset FLS.
