# Lead Acquisition — Production Candidate Pilot (USASpending)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (Enterprise, production — verified by ID) · **Branch:** `feature/lead-acquisition-usaspending-pilot`
**Scope executed (authorized):** deploy `OA_CandidateDiscoveryService` + insert **3 Candidate records** from **USASpending** into `OA_Discovered_Organization__c`. **No Leads/Accounts/Contacts touched; no schedules; no automation enabled.**

> First controlled end-to-end production pilot of the Candidate Discovery engine. Candidates are **not** Leads. Result: **PASS.**

---

## 1. Org & precondition verification (Phase 1)
| Item | Value |
|---|---|
| Production Org ID | `00Dbn00000plgUfEAI` ✅ (Enterprise, not sandbox) |
| DevHub Org ID (unused this sprint) | `00Dd0000000haZPEAY` |
| Branch / HEAD (pre-pilot) | `feature/lead-acquisition-discovery` @ `b4cf414`, clean |
| Candidates before | 0 |
| Leads before | 13,301 |
| Accounts before | 1 |

## 2. Deployment (Phase 3)
| Item | Value |
|---|---|
| Validation ID | `0AfPn0000023bptKAA` (SUCCESS) |
| **Deployment ID** | **`0AfPn0000023bt7KAA`** (Succeeded, checkOnly=false) |
| Files deployed | `OA_CandidateDiscoveryService.cls` (+meta), `OA_CandidateDiscoveryService_Test.cls` (+meta) |
| Tests | 5 run / **0 failures** | Coverage ~97% |
| Production changed | **Yes** — 2 additive Apex classes (dormant; do nothing until invoked) |

## 3. USASpending readiness (Phase 4)
| Item | Value |
|---|---|
| Connector class | `OA_USASpending_Connector` (deployed) |
| Registry entry | `USASpending` (NC `OA_USASpending`, path `/api/v2/search/spending_by_award/`, Enabled=false) |
| Credential / endpoint | public, keyless (`NoAuthentication`); no secret sent |
| Input | `recipient_search_text` (search term) |
| Response shape | `results[]` award rows → aggregated per recipient into `OA_CanonicalOrg` (UEI/name/state + awards) |
| Candidate suitability | Good for identity (UEI, name, state, awards). **Limitation:** this endpoint returns **no CAGE / NAICS / website / full address** |
| Rate limits | none hit; single POST, `limit=100`, sorted by award desc |
| Failure handling | connector returns non-2xx on `OA_ConnectorResult` (no throw); this run HTTP 200, 0 errors |

## 4. Manual preview evidence (Phase 5 — 0 DML)
- **Source query:** `recipient_search_text = "aerospace"` (POST spending_by_award). HTTP **200**, **28 recipients** parsed.
- **Top 3 previewed** (award-amount desc):
  | Name | UEI | State | Confidence | Canonical Key |
  |---|---|---|---|---|
  | THE AEROSPACE CORPORATION | YA8LJBJCND19 | CA | HIGH | UEI:YA8LJBJCND19 |
  | AEROSPACE TESTING ALLIANCE | RNLAYLG64XA5 | TN | HIGH | UEI:RNLAYLG64XA5 |
  | NATIONAL AEROSPACE SOLUTIONS, LLC | KAA7ML3GU9A6 | TN | HIGH | UEI:KAA7ML3GU9A6 |
- Preview outcome: evaluated=3, wouldInsert=3, duplicates=0, skipped=0, **inserted=0, DML rows=0, committed=false**. ✅

## 5. Candidate records created (Phase 6)
| Candidate ID | Organization | UEI | State | Confidence | Status | Matched Lead |
|---|---|---|---|---|---|---|
| `a0qPn00000jySqkIAE` | THE AEROSPACE CORPORATION | YA8LJBJCND19 | CA | HIGH | Needs Review | — |
| `a0qPn00000jySqlIAE` | AEROSPACE TESTING ALLIANCE | RNLAYLG64XA5 | TN | HIGH | Needs Review | — |
| `a0qPn00000jySqmIAE` | NATIONAL AEROSPACE SOLUTIONS, LLC | KAA7ML3GU9A6 | TN | HIGH | Needs Review | — |

All carry: `Source_System__c=USASpending`, `Canonical_Key__c` (UEI-based), `Source_Payload_Hash__c` (SHA-256), `Last_Evaluated__c` (2026-07-08T21:38:57Z), `Qualification_Status__c=Needs Review`.

## 6. Before/after counts + production safety (Phases 6–7)
| Object | Before | After | Δ |
|---|---|---|---|
| `OA_Discovered_Organization__c` (Candidates) | 0 | **3** | +3 (== hard cap) |
| Lead | 13,301 | 13,301 | **0** ✅ |
| Account | 1 | 1 | **0** ✅ |
| Acquisition/candidate CronTriggers | 0 | 0 | 0 ✅ |

No Lead created/modified; no Account modified; no Contact modified; no schedules; no connector automation enabled; no enrichment write-back; no Meta/LinkedIn/website/campaign change.

## 7. KPI baseline (Phase 7)
| KPI | Value |
|---|---|
| Candidates discovered (this run) | 28 (parsed); 3 staged |
| Inserted | 3 |
| Skipped as duplicate (idempotency) | 0 |
| Requiring review | 3 (100%) |
| Duplicate rate (vs existing Leads/Candidates) | 0% |
| Source confidence | 3/3 HIGH (100%) |
| Missing-identifier count | 0 (all have UEI) |
| Failed API calls | 0 (HTTP 200) |
| API latency | sub-second (not precisely instrumented) |
| Review-queue status | 3 `Needs Review` awaiting human adjudication |

## 8. Limitations
- USASpending `spending_by_award` yields **UEI + name + state + awards only** — **no CAGE / NAICS / website / address**; candidates are identity-complete but firmographically thin (enrich later via the enrichment platform after Lead creation).
- Discovery is **seed-term driven** (`recipient_search_text`), not open crawl — appropriate and compliant.

## 9. Remaining risks
- Duplicate detection validated at 0% here because these recipients aren't among the 78 enriched Leads; broader terms will surface duplicates (dedup logic unit-tested + live-safe).
- Runtime user is still MAD `oauser` (R1) — acceptable for a supervised 3-record pilot; least-privilege user required before volume.
- No approval→Lead-creation step yet (by design; gated).

## 10. Rollback / remediation
Reversible: `delete [SELECT Id FROM OA_Discovered_Organization__c WHERE Source_System__c='USASpending' AND CreatedDate = TODAY]` (the 3 pilot rows). No Lead/Account impact. `Source_Payload_Hash__c` makes re-runs idempotent (no duplicates).

## 11. Recommendation for next connector
**SEC EDGAR** next (public, NoAuth, deployed) for a second Build-Now source — adds CIK/name/state candidates with no credential gate. **SAM Entity** after that (richest identity: UEI+CAGE+registration) once the data.gov key + JIT EC principal grant + alpha→prod endpoint are resolved. Grants.gov remains deferred (OI boundary). Census stays WARN (not an org registry).

## 12. Verdict — 🟢 PASS
USASpending manual pilot completed; 3 Candidate records created (== cap); no Leads/Accounts modified; no schedules/automation; duplicate detection + review-queue compatibility verified; evidence documented; production Org ID verified.
