# Sprint 24 — Production Acceptance Report (100-Lead Validation)

_2026-07-07 · Org **00Dbn00000plgUfEAI** · Salesforce CLI evidence · no secrets · **verdict: ACCEPTED WITH CONDITIONS**_

## Executive summary (plain English)
The 100-Lead production acceptance pilot ran. Of 100 diverse Leads, **60 matched** USASpending and **54 were enriched cleanly** (324 fields, zero overwrites, fully audited, reversible). **6 matched Leads failed to write** because of a **field-size defect** (`Awarding_Agencies__c` is 255 chars but multi-agency contractors need up to ~570) — those Leads got **no data** (safe) but produced **misleading audit rows** because the writer doesn't check the update result. No bad data was written; the platform returned to dormant. **The core platform is production-validated; two defects must be fixed before scheduled/automated use.**

## Track A — Preflight (PASS)
Org `00Dbn00000plgUfEAI` ✓ · `main=origin/main=ebc03d0` in sync · clean tree · **0 concurrent deploys** · 0 schedules · 0 enabled connectors · 0 active policies · runtime permset assigned · audit (14/54/1) + rollback healthy.

## Track B — Candidate selection
100 Leads from the safe pool (13,052). **Criteria:** `UEI__c=null` (not previously enriched — excludes the 8 Sprint-23 Leads) · `Company!=null` · `IsConverted=false` · not internal ("One Algorithm"), not Pisano/MediaNow, not a CampaignMember. **Diversity:** 36 states (Virginia 16, California 14, Florida 11, Texas 6, Maryland 6, …), broad industry mix. Before-snapshot saved (`pilot100_before.csv`); all 100 target fields confirmed blank.

## Track C — Preview (normal → GO)
| Metric | Chunk 1 (50) | Chunk 2 (50) | Total |
|---|---|---|---|
| Matched | 29 | 31 | **60 (60%)** |
| Confidence | 29 HIGH | 31 HIGH | **100% HIGH** |
| HTTP errors | 0 | 0 | 0 |
| CPU | 1275 ms | 1507 ms | ~28 ms/Lead |
| SOQL | 1 | 1 | — |
| Callouts | 50 | 50 | 100 |
| Wall time | 14.1 s | 18.7 s | ~330 ms/callout |
Match rate (60%) exceeds Sprint 20 (32%) — expected, since this sample excludes internal test Leads. Not abnormal → proceeded.

## Track D/E — Controlled write + operational metrics
Activated exactly the 6 USASpending FillEmptyOnly policies (0 Overwrite active). Wrote in 2 chunks, **callout-before-DML** (the Sprint-23 fix).

| Metric | Chunk 1 | Chunk 2 | Total / Avg |
|---|---|---|---|
| Matched | 29 | 31 | 60 |
| Leads updated (attempted) | 29 | 31 | 60 |
| Fields written (logged) | 174 | 186 | 360 |
| **Fields actually persisted** | 174 | 150 | **324** (54 Leads × 6) |
| Conflicts | 0 | 0 | 0 |
| HTTP errors | 0 | 0 | 0 |
| CPU | 2371 ms | 2659 ms | ~25 ms/Lead |
| SOQL | 1 | 1 | — |
| DML statements | 60 | 64 | (<150 limit) |
| DML rows | 205 | 219 | — |
| Heap | 31.7 KB | 33.0 KB | tiny |
| Callout time | 8.8 s | 6.4 s | ~152 ms/callout |
| Total time | 14.2 s | 10.2 s | — |

## Track F — Data integrity (with a defect)
- **54 Leads enriched cleanly**, 6 fields each (324 fields); **State values preserved** (State has no policy → 0 State change logs). **No populated field overwritten** — every target field was blank before (fill-empty only).
- **No unrelated records changed** — exactly 62 Leads org-wide have `UEI__c` (54 pilot + 8 Sprint-23); no CampaignMember/Opportunity/Meeting change; no automation fired; registry 0 enabled.
- ⚠️ **DEFECT — 6 Leads failed to write** (`4 Star Technologies`, `3T Federal Solutions`, `22Nd Century Technologies`, `1 Source Consulting`, `3Chief`, `3T-Innovations`). Root cause: **`Awarding_Agencies__c` max length 255**, but these multi-agency contractors produced 449–566-char agency strings → **`STRING_TOO_LONG`** → the whole Lead update was rejected. Because the writer calls `Database.update(..., allOrNone=false)` and **does not inspect the SaveResults**, the failure was silent **and 36 change logs (6×6) were still committed** for writes that never persisted, and **no exception was routed**.

## Two defects (fix before scaled/automated use — NOT fixed this sprint per hard rules)
1. **`Awarding_Agencies__c` too small (255).** Multi-agency contractors overflow it. Fix options: widen the field (e.g. to 1300) or truncate/limit agencies in `OA_USASpending_Mapper`. Impact: ~10% of matches (6/60) silently unwritten.
2. **`OA_EnrichmentWriter` ignores DML SaveResults.** On a failed `Database.update`, it still commits change logs and routes no exception → audit says "written" when it isn't. Fix: check `SaveResult`, only commit logs for successful records, route failures to the exception queue.

## Track G — Rollback readiness (verified; NOT executed)
- All change logs are built with a `Before_Snapshot__c` (sample: `UEI__c` Old=`null`, snapshot `{"UEI__c":null}`) and `Reversible__c=true`. (`Old_Value__c`/`Before_Snapshot__c` are Long-Text-Area → not SOQL-filterable, so verified by construction + sampling.)
- **Rollback command:** `OA_ChangeLogService.rollback([SELECT Id, Target_Object__c, Target_Record_Id__c, Before_Snapshot__c, Reversible__c FROM OA_Enrichment_Change_Log__c WHERE Change_Type__c='Enrich' AND Source_System__c='USASpending' AND Connector_Run__r.Run_ID__c LIKE 'S24-%'])`. (Rolling back the 36 failed-Lead logs is a harmless blank→blank no-op.)

## Track H — Operational readiness classification
| Mode | Verdict | Notes |
|---|---|---|
| **Manual enrichment** | 🟢 **READY** | Proven safe, audited, reversible; known multi-agency limitation. |
| **Daily enrichment** | 🟡 **READY WITH CONDITIONS** | Fix defects #1/#2 first (else ~10% silent failures + misleading audit). |
| **Weekly enrichment** | 🟡 **READY WITH CONDITIONS** | Same. |
| **Batch enrichment** | 🟡 **READY WITH CONDITIONS** | Needs `OA_EnrichmentOrchestrator` deployed + defect fixes. |
| **Scheduled enrichment** | 🔴 **BLOCKED** | Needs least-privilege runtime user + orchestrator deploy + defect fixes. |
| **24×7 automation** | 🔴 **BLOCKED** | Same. |

## Remaining operational risks / blockers
1. **DEFECT: `Awarding_Agencies__c` length** (silent ~10% write failure). 2. **DEFECT: writer ignores SaveResults** (misleading audit). 3. **MAD `oauser`** runtime user (top standing risk). 4. **Orchestrator not deployed** (batch/scheduled). 5. **Monitoring dashboards not deployed** (advisory SOQL only).

## Direct answers
1. **Production-validated?** — **Yes, with conditions** — enrichment proven at 100-Lead scale (54 clean, 0 overwrites, audited, reversible); 2 defects found.
2. **Operationally accepted?** — **ACCEPTED WITH CONDITIONS.**
3. **Ready for daily manual use?** — **Yes** (controlled/manual), with the multi-agency limitation understood.
4. **Ready for scheduled enrichment?** — **No.**
5. **Ready for 24×7 automation?** — **No.**
6. **Remaining blockers?** — the 2 defects, least-privilege user, orchestrator deploy, monitoring.
7. **Close the Lead Enrichment epic now?** — **Not yet** — fix defects #1/#2 (small Sprint 25) and re-run the 6 failed Leads, then close.
8. **Opportunity Intelligence next?** — **Not yet** — complete operational hardening (defect fixes) first.

## GO / NO-GO for scheduled enrichment
🔴 **NO-GO** for scheduled/automated. 🟢 **GO** for continued controlled/manual enrichment. **Recommended Sprint 25:** fix the two defects (field length + writer SaveResult handling), re-enrich the 6 failed Leads, deploy monitoring, then re-evaluate epic closure and the least-privilege runtime user.
