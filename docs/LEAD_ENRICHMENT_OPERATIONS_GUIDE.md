# Lead Enrichment — Operations Guide (Executive)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Baseline:** `lead-enrichment-v1.2` (`f4894e9`, dormant)
**Audience:** Louis (owner) + Operations · **Reuses:** [MAINTENANCE.md](MAINTENANCE.md), [LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md](LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md), [OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md) (incident), [LEAD_ENRICHMENT_KPI_FRAMEWORK.md](LEAD_ENRICHMENT_KPI_FRAMEWORK.md), [MONITORING_AND_ALERTS.md](MONITORING_AND_ALERTS.md)

> The single business-facing operating guide for running Lead Enrichment day-to-day. It consolidates the existing
> runbook/maintenance/monitoring docs into one cadence + business view. No new procedures invented; it points to the
> authoritative sources. Platform is dormant; these cadences apply to supervised/manual operation and, once activated,
> to live operation.

---

## 1. Daily Operations
- Run the health audit: `scripts/shell/daily_enrichment_audit.sh` → expect **PASS**.
- Confirm **dormant** unless a run is authorized (0 enabled connectors, 0 active policies, 0 enrichment jobs).
- Review **connector status** — any `OA_Connector_Run__c.Status__c` = Failed / PartialErrors (KPI-Framework: Connector Failure Rate).
- Review **exception (review) queue** — open `OA_Enrichment_Exception__c`; work oldest first (Review Queue Age target < 3 d).
- Check the **must-be-green tiles**: Failed runs = 0, Rollback failures = 0, Audit consistency = 100%.

## 2. Weekly Review (Ops)
- **Throughput:** Leads Enriched, Fields Updated, Average Fields per Lead.
- **Connector health:** Success/Failure Rate + latency per source vs targets.
- **Rollback health:** every write has a `Before_Snapshot__c` and `Reversible__c=true`.
- **Data quality:** Avg Enrichment Quality Score (target ≥ 60) + Conflict Rate.
- **Queue:** Average Approval Time; aged exceptions escalated.

## 3. Monthly Review (Owner)
- **Business value:** Meeting/Campaign/Opportunity Conversion %; Federal Contractor coverage; top agencies/industries/NAICS.
- **Data freshness:** Leads whose `USASpending_Last_Enriched__c` > 90 d → candidates for re-enrichment.
- **Platform health:** Salesforce seasonal release impact; connector API compatibility; DML/CPU headroom vs `PERFORMANCE_VALIDATION.md`.
- **Governance:** confirm runtime FLS permset still assigned; write-back Automation permset still unassigned; 0 EC principal grants unless a JIT run is active.

## 4. Connector Monitoring
Per source (USASpending/SEC/IRS/Census/SAM): success %, failure %, latency, last run. Alerts (from `MONITORING_AND_ALERTS.md`): Connector Failure (Crit), API Failure ≥3/1h (Crit), Credential 401/403 (Crit). SAM is READY-WITH-CONDITIONS (key + JIT grant + prod endpoint) — do not enable until closed.

## 5. Queue Monitoring (Review Queue) — Phase-4 verification
**Verified 2026-07-08 (live + repo): there is exactly ONE review/approval mechanism — no duplication.**
- Review queue = **`OA_Enrichment_Exception__c`** (Type = SourceConflict / PolicyException / error; Status = Open/Resolved/Rejected). Live count = 1.
- Proposal/approval flow routes through this single object; **no separate `*_Proposal__c` / `*_Review__c` object exists** (confirmed by EntityDefinition query).
- Approval = human review of exceptions + FillEmptyOnly policy (never Overwrite); write-back Automation permset stays unassigned.
- **No duplicate metadata / no duplicate review queue / no duplicate approval process** — requirement satisfied by the existing components; nothing added or replaced.
- Monitor: open-exception count, queue age, approval time (KPI Framework §1).

## 6. Data Quality Monitoring
- Avg Enrichment Quality Score (0–100) and band distribution ([LEAD_ENRICHMENT_QUALITY_SCORE.md](LEAD_ENRICHMENT_QUALITY_SCORE.md)).
- Lead Completeness %, Confidence distribution (HIGH/MED/LOW), Audit consistency = 100% (hard invariant).
- Data freshness by source.

## 7. Campaign Performance (business)
Reuse the live campaign objects (read-only): members, Meetings Generated (CampaignMember "Meeting Booked"), response/conversion, Opportunities influenced. Surfaced on the Executive Dashboard (E15–E17). No change to the protected campaign automation.

## 8. Business KPIs
Owner-facing set (targets/thresholds in [LEAD_ENRICHMENT_KPI_FRAMEWORK.md](LEAD_ENRICHMENT_KPI_FRAMEWORK.md) §2): Meeting Conversion %, Campaign Conversion %, Opportunity Conversion %, Federal Contractor Coverage, Avg Enrichment Quality Score.

## 9. Recommended Actions (by signal)
| Signal | Action |
|---|---|
| Connector Failure Rate > warning | Check endpoint/credential/rate; pause that source; do not auto-retry. |
| Credential 401/403 (SAM) | Rotate key in EC (Setup only); re-grant EC principal access JIT; verify with a smoke test. |
| Review Queue Age > 7 d | Escalate to Owner; triage oldest exceptions; check policy/config. |
| Rollback restored < requested | **Freeze writes**; follow [ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md); manual data review. |
| Active Overwrite policy detected | Deactivate immediately (must-be-zero invariant). |
| Avg Quality Score < 45 | Investigate connector coverage / matching; not a data-safety issue. |
| Dashboard refresh > 48 h | Check report subscription / refresh job. |
| Any unauthorized enabled connector | Disable immediately; investigate change history. |

## 10. Emergency stop (kill switch)
Disable connectors (`OA_Connector_Registry__mdt.<src>.Enabled__c=false`) + deactivate policies (`OA_Field_Write_Policy__mdt.<p>.Active__c=false`) — deploy with an explicit **quoted** `--source-dir`; verify **0 active policies / 0 enabled connectors**. Then verify dormant via the audit script.

---

**Reuse statement:** this guide consolidates existing operational docs into one business cadence; it introduces no new
object, field, report, dashboard, or automation. Activation of any live operation remains a 🔴 gate.
