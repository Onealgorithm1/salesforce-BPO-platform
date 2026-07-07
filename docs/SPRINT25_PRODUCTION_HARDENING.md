# Sprint 25 — Production Hardening & Final Certification ✅

_2026-07-07 · Org **00Dbn00000plgUfEAI** · Salesforce CLI evidence · no secrets · **both defects eliminated; 6 Leads repaired; platform certified; dormant**_

## Outcome (plain English)
Both Sprint-24 defects are **fixed, deployed, and proven** against the exact 6 Leads that failed. All 6 are now fully enriched, the audit trail exactly matches the data, the full test suite passes, and the platform is back to dormant. **Lead Enrichment is production-certified for controlled use.**

## Track A — Verification
Org `00Dbn00000plgUfEAI` ✓ · `main=origin/main=d21a416` in sync · dormant (0 active policies, 0 enabled connectors) · runtime permset assigned · 0 concurrent deploys · audit/rollback healthy. The exact 6 failed Leads identified (all blank, 36 orphan change logs).

## Track B — Defect #1 root cause & solution
**Root cause:** `Awarding_Agencies__c` was `Text(255)`. Multi-agency federal contractors produce agency lists of 269–570 chars → `STRING_TOO_LONG` on update.

**Options compared:**
| Criterion | A: widen field (→ Long Text Area) | B: truncate in mapper |
|---|---|---|
| Data integrity | ✅ preserves all agencies | ❌ silently loses agencies >255 |
| Future scalability | ✅ up to 131,072 chars | ❌ permanently capped |
| Maintenance | ✅ one metadata change, no code | ⚠️ ongoing mapper logic |
| Salesforce limits | Long Text Area not SOQL-filterable (irrelevant here) | none new |
| "No mapper redesign" rule | ✅ honored | ⚠️ touches frozen mapper |

**Chosen: Option A — convert `Awarding_Agencies__c` to Long Text Area(32768).** Text fields cap at 255, so widening requires the Long Text Area type. It preserves all data (paramount for certification), is future-proof, needs no code/mapper change, and its only tradeoff (not SOQL-filterable) doesn't matter for a denormalized agency-list field. **Implemented.**

## Track C — Defect #1 validation
- Field is now **`Long Text Area(32768)`** (live-verified).
- **Original 54 unaffected** — existing agency values preserved by the widening (spot-checked: Faustson `Department of Commerce`; Columbia `Department of Homeland Security,Department of Defense`).
- The 6 previously-failing Leads now write their full agency lists (269–548 chars). No mapper redesign.

## Track D — Defect #2 root cause & fix
**Root cause:** `OA_EnrichmentWriter.enrich()` called `Database.update(..., allOrNone=false)` and **never inspected the SaveResults** → on a failed update it still committed change logs (misleading "written" audit) and routed no exception.

**Fix (surgical, failure-path only):** inspect the `Database.SaveResult`.
- **Success** → unchanged behavior (commit change logs).
- **Failure** → discard the misleading change logs (`r.changeLogs.clear()`), reflect `written=0`, route a `PolicyException` capturing the exact `StatusCode`/message/fields, add a diagnostic message, and continue. Successful behavior preserved.

## Track E — Regression
- Check-only validation: `0AfPn0000023Bk9KAE` Succeeded (6 writer tests pass, incl. the new failure-path test `testSaveFailureRoutesExceptionAndDiscardsLogs`).
- **Production deploy `0AfPn0000023BnNKAU` Succeeded** (checkOnly=false, 3 components) running **RunLocalTests = 261 tests, 0 failures** → no regressions. Policies/connectors/audit/rollback behavior unchanged.

## Track F — Repair of the six failed Leads
1. Deleted the 36 orphan change logs (Defect-#2 artifacts) → audit integrity restored.
2. Activated the 6 FillEmptyOnly policies.
3. **Preview:** all 6 matched, `wouldWrite=6` each, `dmlRows=0`.
4. **Write (callout-before-DML):** matched=6, leads updated=6, **36 fields written**, exceptions=0, HTTP errors=0.
5. All 6 now enriched with full data:

| Company | UEI | Awards | Agency-list len |
|---|---|---|---|
| 1 Source Consulting, INC. | EXEYN7TNGWH7 | 64 | 548 |
| 22Nd Century Technologies INC. | QT2VZ9L1VPQ1 | 100 | 406 |
| 3Chief LLC | YZDWH8L2TBN1 | 34 | 431 |
| 3T Federal Solutions LLC | WPF1UWGEQGU1 | 100 | 269 |
| 3T-Innovations, LLC | K87QS6QJ79Z3 | 91 | 283 |
| 4 Star Technologies, INC. | UYLVJZ49BFC6 | 100 | 539 |

No duplicate audit (36 fresh logs, old orphans removed); no overwrite (State preserved); rollback available; 0 exceptions.

## Track G — Production integrity
- **68 Leads enriched total** (54 Sprint-24 + 8 Sprint-23 + 6 repaired).
- **Audit exactly matches DB:** 408 USASpending Enrich change logs = 68 Leads × 6 fields; **68 distinct Leads** in the audit = 68 enriched Leads (no orphans). Total change logs 414 (408 + 6 legacy baseline).
- Exception queue accurate: **1** (unchanged; repair added none).
- Original 54 correct; 6 repaired; expected totals match; rollback complete & reversible.

## Track H — Operational certification
| Mode | Verdict | Evidence |
|---|---|---|
| Manual enrichment | 🟢 **READY** | Defects fixed; 68 Leads enriched cleanly; audited; reversible. |
| 25-Lead runs | 🟢 **READY** | Proven (Sprint 23). |
| 100-Lead runs | 🟢 **READY** | Proven (Sprint 24) + defects now fixed. |
| Daily manual use | 🟢 **READY** | Same; callout-before-DML pattern documented. |
| Scheduled enrichment | 🔴 **BLOCKED** | Needs least-privilege runtime user + `OA_EnrichmentOrchestrator` deploy (out of this sprint's scope). |
| Batch enrichment | 🔴 **BLOCKED** | Needs orchestrator deploy. |
| 24×7 automation | 🔴 **BLOCKED** | Needs least-priv user + orchestrator + scheduler. |

## Remaining debt
- **Technical debt:** none from the two defects (both fixed). `OA_EnrichmentOrchestrator`/`Queueable`/`ProposalAdapter` remain built-but-undeployed (needed only for batch/scheduled).
- **Operational debt:** (1) MAD `oauser` runtime user (replace with least-privilege user — needs a license); (2) orchestrator deploy for batch/scheduled; (3) monitoring dashboards not deployed; (4) SAM/Census/SEC connectors still need credential provisioning.

## Direct answers
1. **Both defects eliminated?** — **Yes** (deployed; 261 tests pass; validated against the 6 Leads).
2. **All six failed Leads enriched?** — **Yes** (6/6, full data).
3. **Audit exactly matches committed data?** — **Yes** (68 Leads, 408 logs, 68 distinct, 0 orphans).
4. **Rollback still verified?** — **Yes** (before-snapshots present; reversible).
5. **Operationally certified?** — **Yes, for controlled/manual enrichment** (see certificate). Scheduled/batch/24×7 remain blocked on least-priv user + orchestrator.
6. **Close the Lead Enrichment epic?** — **Yes** — the build + hardening is complete and certified; remaining items are a separate operational-automation track.
7. **Create RELEASE_1.1 + tag `lead-enrichment-v1.1`?** — **Yes** (this sprint creates them).
8. **Opportunity Intelligence next?** — **Yes**, as the next *engineering* program; the operational-automation items (least-priv user, orchestrator, scheduler) proceed in parallel as enablement, gating only 24×7.
