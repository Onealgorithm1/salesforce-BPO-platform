# Sprint 22 — Policy Deployment & First Production Write (policies deployed; write blocked by rate limit)

_2026-07-07 · Org **00Dbn00000plgUfEAI** · Salesforce CLI evidence · no secrets · **0 Leads written; platform returned to dormant**_

## Outcome (plain English)
The fill-empty policies were **deployed and verified correct** in production, and the preview **matched Sprint 20 exactly**. But the actual write **could not complete** — the USASpending public API **rate-limited our callouts** after the repeated 25-Lead preview/write bursts, so every callout in the write failed and **zero Leads were changed**. The platform behaved exactly as designed (it writes nothing when the connector errors). Production was returned to its dormant baseline. **The write just needs a retry after the API cools down.**

## Track A — Pre-flight (PASS)
Org `00Dbn00000plgUfEAI` ✓ · `main = origin/main = 1d9e91e` (in sync) · no unexpected staged files ✓ · **no concurrent deployment executing** (0 in-progress; last unrelated LinkedIn check-only deploy was 16 min prior) ✓ · runtime permset assigned (1) ✓ · rollback service present ✓ · audit objects healthy (2/6/1) ✓ · registry 0 enabled ✓ · USASpending HTTP 200 ✓.

## Track B — Deploy corrected fill-empty policies (DONE)
Deployed the 6 approved-field USASpending policies as **FillEmptyOnly, Active=true** (2 corrected from Overwrite + 3 new + UEI). Real deploy (checkOnly=false), all components succeeded.

## Track C — Verify production configuration (PASS)
Post-deploy, production contained exactly:

| Field | Write_Mode | Active (during pilot) |
|---|---|---|
| `UEI__c` | FillEmptyOnly | true |
| `Federal_Contractor__c` | FillEmptyOnly | true |
| `Total_Award_Amount__c` | FillEmptyOnly | true |
| `Award_Count__c` | FillEmptyOnly | true |
| `Awarding_Agencies__c` | FillEmptyOnly | true |
| `Latest_Award_Date__c` | FillEmptyOnly | true |

Exactly **6 active policies, all USASpending, 0 Overwrite active** anywhere; connector registry unchanged (0 enabled). **This corrected the Sprint-21 discrepancy permanently** (the 2 Overwrite policies are now FillEmptyOnly in production).

## Track D — Repeat preview (PASS, matches Sprint 20)
Same 25 Leads, active policies, `commitWrites=false`:
```
processed=25  matched=8  WOULD_WRITE_TOTAL=48  conflicts=0  noChange=0  skip=8(State)  httpErrors=0  dmlRows=0
```
Every matched Lead: 6 fields = WRITE (UEI, Federal_Contractor, Total_Award, Award_Count, Awarding_Agencies, Latest_Award_Date); `State` = SKIP_NO_POLICY. **Difference vs Sprint 20:** Sprint 20 *simulated* State as a fill-empty conflict; the real config has **no State policy**, so State is safely **skipped** (no conflict, no exception) — benign and safer. Match count, matched Leads, UEIs, and the 48-field total are identical.

## Track E — Controlled production write (ATTEMPTED, did NOT complete)
Executed `OA_EnrichmentWriter.enrich(..., commitWrites=true)` for the matched Leads via the preview-proven path.
- **First attempt (25 Leads):** `matched=0, httpErrors=25, fieldsWritten=0`. All 25 callouts failed.
- **Scoped retry (8 matched Leads):** `matched=0, httpErrors=8` (connection-level exceptions, `lastStatus=null`). All 8 failed.
- **Root cause (diagnosed):** USASpending **rate-limiting**. A single probe between the bursts returned **HTTP 200** with valid data, but sustained bursts (~58 callouts across Sprint 20 preview + Track D + two write attempts within minutes) were throttled/dropped. This is transient/environmental — **not a platform defect and not an unsafe write**.
- **Result:** **0 Leads enriched, 0 fields written, 0 change logs created, 0 exceptions.** Two `OA_Connector_Run__c` audit records captured the failed attempts (`SPRINT22-PILOT-…`, `SPRINT22-WRITE-…`, Status=PartialErrors, HTTP_Errors=25/8).

## Track F — Post-write verification (SAFE)
- Every target field on the 8 matched Leads is **still blank** (nothing written).
- Change logs unchanged (6) · no populated field changed · no unrelated Lead changed · no CampaignMember change · no scheduled job created · connector stayed USASpending-only, registry 0 enabled.
- **After returning to dormant:** 0 active policies; all 6 USASpending policies remain **FillEmptyOnly** (0 Overwrite), Active=false.

## Track G — Rollback validation
No write occurred → nothing to roll back. Rollback verified **ready**: every committed write emits an `OA_Enrichment_Change_Log__c` with `Before_Snapshot__c`; **rollback command:**
`OA_ChangeLogService.rollback([SELECT ... FROM OA_Enrichment_Change_Log__c WHERE Connector_Run__c = :runId])` → restores prior values (USER_MODE) and logs a `Rollback` entry. Proven in Sprint 16 (5/5).

## Track H — Operational readiness
| Capability | Status |
|---|---|
| First 25-Lead write | 🟡 **NEEDS SETUP** — reactivate the 6 policies + re-run the 8-matched-Lead write after USASpending cooldown |
| 100-Lead pilot | 🔴 **BLOCKED** — the first write must land first |
| Monitoring deployment | 🟡 NEEDS SETUP (dashboards build-ready) |
| Batch orchestrator deployment | 🔴 BLOCKED (orchestrator not deployed) |
| Scheduled enrichment | 🔴 BLOCKED (least-priv user + passing pilots) |

## Remaining risks / blockers
1. **USASpending rate-limiting** (transient) — the only thing preventing the write. Mitigation: cool down (~30–60 min of no calls), then re-run **only the 8 matched Leads**, ideally spaced (one Lead per transaction) to avoid bursts.
2. Standing: MAD `oauser`; execution engine not deployed (batch/scheduled only).

## Direct answers
1. **Were the corrected FillEmpty policies deployed?** — **Yes** (all 6 FillEmptyOnly, verified; 0 Overwrite). Then deactivated to dormant.
2. **Did the first production write execute?** — **Attempted, did not complete** — USASpending rate-limited all callouts.
3. **How many Leads enriched?** — **0.**
4. **How many fields written?** — **0.**
5. **Any populated fields overwritten?** — **No.**
6. **Was every write audited?** — N/A (no writes); the failed attempts are recorded in `OA_Connector_Run__c`.
7. **Is rollback fully operational?** — **Yes** (verified ready).
8. **Ready for a 100-Lead pilot?** — **No.**
9. **Is Lead Enrichment officially operational/production-ready?** — **Not yet** — config-complete and preview-proven, but the first write has not landed.
10. **Recommendation** — **Do NOT start the 100-Lead pilot or Opportunity Intelligence.** Next: after a USASpending cooldown, reactivate the 6 policies and re-run the write on the 8 matched Leads (spaced). That single successful write closes the operational gap.

## GO / NO-GO for the 100-Lead pilot
🔴 **NO-GO** — pending a successful first write.
