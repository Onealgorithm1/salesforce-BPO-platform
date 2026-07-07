# Sprint 23 — First Successful Production Enrichment Write ✅

_2026-07-07 · Org **00Dbn00000plgUfEAI** · Salesforce CLI evidence · no secrets · **8 Leads enriched, 48 fields written, 0 overwrites, fully audited, returned to dormant**_

## Outcome (plain English)
The first real production enrichment **succeeded.** Eight Leads were enriched with live USASpending federal-contractor data — 48 blank fields filled, **zero** existing values overwritten, every change logged with a rollback snapshot. The platform was returned to dormant afterward, with the enrichment preserved.

**Root-cause correction:** Sprint 22's failure was **misdiagnosed as USASpending rate-limiting.** The real cause was a **transaction-ordering bug in the pilot script** — it performed DML (`insert` the run record) **before** the callout, which triggers Salesforce's *"You have uncommitted work pending"* `CalloutException` (surfaced as `httpErrors`/`lastStatus=null`). Fix: **do the callout first, then the DML.** With that fix, every callout returned HTTP 200. This was never an API/platform-connector problem.

## Track A — Preflight (PASS)
Org `00Dbn00000plgUfEAI` ✓ · `main = origin/main = d3ec73a` (in sync) · no staged files ✓ · **no concurrent deployment** (0 in-progress) ✓ · USASpending isolated probe HTTP 200 ✓ · runtime permset assigned (1) ✓ · 6 USASpending FillEmptyOnly policies exist & dormant (0 active) ✓ · 8 matched Leads exist, all 6 target fields blank ✓ · audit objects queryable ✓ · rollback service present ✓.

## Track B — USASpending rate-limit findings
- USASpending exposes **no** rate-limit headers (`Retry-After`, `X-RateLimit-*` absent — confirmed via probe).
- Cross-sprint evidence: the connector works reliably at **1 callout per transaction with callout-before-DML ordering**. The Sprint-22 "burst failures" were the DML-ordering bug, **not** throttling (a 25-callout preview with no pre-callout DML had always returned 200).
- **Recommended pacing:** honor the transaction rule (callout before any DML); one Lead per transaction is safe and was used here. No backoff needed for correctly-ordered calls. Keep per-transaction callouts modest for bulk (≤50) — the constraint is Apex governor limits, not an observed API rate cap.

## Track C — Write strategy used
One Lead per transaction, **separate CLI executions** per Lead (8 total), **callout before DML**, capture every status, stop-on-sustained-failure. No 25-call burst. A canary (Faustson) was written and verified first, then the remaining 7.

## Track D — Policies activated
Deployed the 6 approved USASpending policies `Active=true`; verified **exactly 6 active, all FillEmptyOnly, 0 active Overwrite**; no other connectors/policies/scheduling touched.

## Track E — Per-Lead write results (all 8 succeeded)
| Lead | Company | HTTP | Fields written | Conflicts | Exceptions |
|---|---|---|---|---|---|
| 00QPn000011DshUMAS | Faustson Tool CORP. | 200 | 6 | 0 | 0 |
| 00QPn000011DsheMAC | Navigational Services | 200 | 6 | 0 | 0 |
| 00QPn000011DshmMAC | Telford Aviation, INC. | 200 | 6 | 0 | 0 |
| 00QPn000011DshvMAC | Columbia Industrial Products INC. | 200 | 6 | 0 | 0 |
| 00QPn000011DshwMAC | National Crane Services INC | 200 | 6 | 0 | 0 |
| 00QPn000011DshdMAC | Lavin INC | 200 | 6 | 0 | 0 |
| 00QPn000011DshkMAC | Osar Solutions LLC | 200 | 6 | 0 | 0 |
| 00QPn000011DsiKMAS | Dc Fabricators INC | 200 | 6 | 0 | 0 |

Fields written per Lead: `UEI__c, Federal_Contractor__c, Total_Award_Amount__c, Award_Count__c, Awarding_Agencies__c, Latest_Award_Date__c`. `State` = SKIP_NO_POLICY (no State policy → never touched). **Total: 8 Leads, 48 fields.**

Sample enriched values: Faustson `H5C2QE2NY1B1 / $368.33 / 1 award / Dept of Commerce`; Telford Aviation `VKKLX3BEJ8V7 / $390.9M / 17 awards / 4 agencies`; Dc Fabricators `E8LNMDLEKM35 / $5.68M / 100 awards / Dept of Defense`.

## Track F — Post-write verification (PASS)
- **8 Leads updated, 48 fields written**; every written field was blank before (preflight-confirmed).
- **No populated field overwritten** — `State` values (Colorado, Oregon, …) unchanged.
- **No unrelated Lead changed** — exactly **8 Leads org-wide** now have `UEI__c` (was 0 before), i.e. only the pilot set.
- No CampaignMember changed; no scheduled jobs created; connector stayed USASpending-only; registry 0 enabled.
- Audit: change logs 6 → **54** (48 new Enrich logs). Exceptions unchanged (1). Connector runs: 8 successful `S23-*` (Succeeded, Records_Enriched=6 each) + 2 earlier failed-ordering attempts (PartialErrors, 0 written) retained as audit.

## Track G — Rollback readiness (verified; NOT executed)
- All 48 Enrich logs are `Reversible__c=true` with a non-blank `Before_Snapshot__c` (sample: `UEI__c` Old=`null`, snapshot `{"UEI__c":null}`).
- Rollback identifies all writes via `Connector_Run__c` (8 runs × 6 logs).
- **Rollback command (if ever needed):**
  `OA_ChangeLogService.rollback([SELECT Id, Target_Object__c, Target_Record_Id__c, Before_Snapshot__c, Reversible__c FROM OA_Enrichment_Change_Log__c WHERE Change_Type__c='Enrich' AND Source_System__c='USASpending' AND Connector_Run__r.Run_ID__c LIKE 'S23-%'])`
  → restores prior (blank) values under USER_MODE and logs `Rollback` entries. Proven pattern (Sprint 16, 5/5).

## Track H — Return to dormant (DONE)
Deactivated all 6 policies (deployed `Active=false`). Confirmed: **0 active policies, 0 enabled connectors, no schedules**, and **8 Leads remain enriched** (data preserved, audit retained).

## Remaining risks
1. **MAD `oauser` runtime user** (temporary exception) — top standing risk; replace with least-privilege user before scaling to 24/7.
2. Execution engine (`OA_EnrichmentOrchestrator`) not deployed — required for batch/scheduled, not for controlled writes.
3. Parallel LinkedIn/OAuth session files remain untracked in the working tree (untouched).

## Direct answers
1. **Did the first production write succeed?** — **YES.**
2. **How many Leads enriched?** — **8.**
3. **How many fields written?** — **48** (6 × 8).
4. **Any populated fields overwritten?** — **No** (State preserved; fill-empty only).
5. **Every write audited?** — **Yes** — 48 change logs, each with a before-snapshot.
6. **Is rollback ready?** — **Yes** (verified; command documented).
7. **Ready for a 100-Lead pilot?** — **YES (GO)** — same proven path, callout-before-DML, per-Lead or modest batches.
8. **Ready for scheduled enrichment?** — **No** — needs least-privilege user + orchestrator deploy.
9. **Can Opportunity Intelligence begin now?** — **No** — complete the 100-Lead pilot first.

## GO / NO-GO for the 100-Lead pilot
🟢 **GO** — the write path is proven safe, audited, and reversible. Recommend Sprint 24 = controlled 100-Lead pilot (activate policies → enrich in modest per-transaction batches with correct ordering → verify → dormant), then reassess least-privilege user + orchestrator before any scheduling.
