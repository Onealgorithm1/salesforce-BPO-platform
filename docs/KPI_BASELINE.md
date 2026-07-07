# Lead Enrichment — Production KPI Baseline

_Established 2026-07-07 (Sprint 24, 100-Lead acceptance pilot) · Org **00Dbn00000plgUfEAI** · connector: USASpending · FillEmptyOnly · this is the permanent operational baseline_

## Baseline sample
100 production Leads (36 states, mixed industries), USASpending, fill-empty, per-transaction chunks of 50 with callout-before-DML ordering.

## KPI table
| KPI | Baseline | Notes |
|---|---|---|
| **Lead match rate** | **60%** (60/100) | Higher than the 25-Lead sample (32%) which included internal test Leads. |
| **Non-match rate** | 40% | Companies with no federal awards. |
| **Write success rate (of matched)** | **90%** (54/60) | 6 failed on `STRING_TOO_LONG` (defect). |
| **Fields written (persisted)** | **324** | 54 Leads × 6 fields. |
| **Average fields added per enriched Lead** | **6.0** | UEI, Federal_Contractor, Total_Award_Amount, Award_Count, Awarding_Agencies, Latest_Award_Date. |
| **Fields skipped** | State (60) | No State policy → SKIP_NO_POLICY (never touched). |
| **Conflict %** | **0%** | No fill-empty conflicts (all targets blank). |
| **Connector success rate** | **100%** | 0 HTTP errors across 200 callouts (100 preview + 100 write). |
| **Connector failure rate** | **0%** | — |
| **Average confidence** | **HIGH** | 60/60 matches HIGH. |
| **High confidence %** | **100%** | |
| **Medium confidence %** | 0% | |
| **Low confidence %** | 0% | |
| **Average enrichment CPU** | **~25 ms / Lead** | Apex compute only. |
| **Average API latency** | **~150 ms / callout** | Range 128–330 ms observed. |
| **Average execution time** | **~12 s / 50-Lead chunk** | Callout-latency bound. |
| **SOQL per chunk** | 1 | CMDT cached; does not scale with volume. |
| **Heap** | ~32 KB / 50-Lead chunk | Non-issue. |
| **DML statements** | 60–64 / 50-Lead chunk | Well under 150 limit. |
| **Callouts** | 50 / chunk | Under 100/txn limit. |
| **Exceptions** | 0 routed | ⚠️ 6 failures were NOT routed (writer defect). |
| **Audit success** | 324/324 persisted writes logged | ⚠️ +36 logs for non-persisted (failed) writes. |
| **Rollback success** | Verified ready (not executed) | Every write has a before-snapshot; proven Svc (Sprint 16). |

## Throughput reference (observed)
- 50 Leads/transaction (50 callouts) ≈ 10–14 s. 100 Leads ≈ 2 chunks ≈ ~25 s.
- Extrapolated: 1,000 Leads ≈ ~5–10 min; 10,000 ≈ ~1–2 hrs (callout-latency bound; run off-peak).

## Known limitations captured in this baseline
1. **`Awarding_Agencies__c` (255 chars)** overflows for multi-agency contractors (449–566 chars observed) → silent write failure (~10% of matches). *Fix pending.*
2. **`OA_EnrichmentWriter`** does not inspect `Database.update` SaveResults → commits change logs for failed updates and routes no exception. *Fix pending.*

## How to reproduce / measure
- Preview: fetch → `OA_USASpending_Mapper.toLeadProposals` → `OA_EnrichmentWriter.preview` (commit=false), sample `Limits.*`.
- Write: callout-before-DML, `OA_EnrichmentWriter.enrich(..., commitWrites=true)`.
- Metrics sources: `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Change_Log__c` (writes), `OA_Enrichment_Exception__c` (review queue).

_Revisit this baseline after the defect fixes (Sprint 25) and after the least-privilege runtime user replaces `oauser`._
