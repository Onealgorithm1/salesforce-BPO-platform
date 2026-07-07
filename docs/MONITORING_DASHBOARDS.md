# Lead Enrichment — Monitoring Dashboards (design only)

_Status: **design — not deployed** · 2026-07-06. Standard Salesforce reports/dashboards over existing
objects; no new schema. Build these when the platform is activated._

Primary sources: `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Exception__c` (review),
`OA_Enrichment_Change_Log__c` (writes), `OA_Discovered_Organization__c` (discovery/qualification).

| # | Dashboard | Source | Grouping / metric | Chart | Alert threshold |
|---|---|---|---|---|---|
| 1 | **Connector Health** | `OA_Connector_Run__c` | Success rate = Succeeded ÷ all, by `Source_System__c` (last 7d) | Gauge / bar | any connector < 95% |
| 2 | **Connector Duration** | `OA_Connector_Run__c` | p50/p95 of (`Ended__c` − `Started__c`) by connector | Line (trend) | p95 > 30s |
| 3 | **Connector Failures** | `OA_Connector_Run__c` | Count where `Status__c` in (Failed, PartialErrors); split by `HTTP_Errors__c`/`Parse_Errors__c` | Stacked bar | > 0 sustained |
| 4 | **Connector Throughput** | `OA_Connector_Run__c` | Sum `Parsed__c` per connector per day | Column (time) | drop vs 7d avg |
| 5 | **Organizations Enriched** | `OA_Enrichment_Change_Log__c` | Distinct `Target_Record_Id__c` where `Change_Type__c='Enrich'` per day | Column | — |
| 6 | **Organizations Created** | `OA_Discovered_Organization__c` | Count where `Qualification_Status__c='Qualified'` + a created Lead link, per day | Column | spike (mis-ICP) |
| 7 | **Exceptions** | `OA_Enrichment_Exception__c` | Open count by `Exception_Type__c`; oldest-open age | Bar + table | open age > 3d |
| 8 | **Qualification Statistics** | `OA_Discovered_Organization__c` | Qualified vs NotQualified vs NeedsData (from runner `recordsQualified/rejected`) | Donut | qualified-rate anomaly |

**Must-be-zero tiles (compliance):** writes without snapshot; below-floor writes; rollback failures.
Surface these as single-number components on Dashboard 1 (any non-zero = red / page the owner).

**Implementation note:** all metrics come from fields that already exist on the four objects — no
schema change and no new engine. The runner writes `Messages__c` with `duration_ms`/`qualified`/
`rejected` for sources that need per-run detail beyond the numeric fields.
