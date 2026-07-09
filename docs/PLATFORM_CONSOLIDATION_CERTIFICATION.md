# Platform Consolidation & Repository Certification — Program 024E

**Org:** 00Dbn00000plgUfEAI (verified by ID; `https://onealgorithmllc.my.salesforce.com`)
**Mode:** Architecture / Governance · **This is a certification package — NO merges, NO deploys, NO new metadata.**
**Verdict:** **WARN** — production is authoritative and healthy; repository is *not* single-source-ready. Consolidation is required and is now unblocked by this certification.

---

## 1. Executive Summary

The platform is functionally complete and **fully deployed** in production (164 OA Apex classes, ~30 custom objects, 25 permission sets, live automation). The largest risk is no longer engineering — it is **repository fragmentation**: **59 open PRs** across **~85 branches**, with `main` frozen at "Merge PR #24" while **49 classes run in production that are not on `main`**. Additionally, **12 classes exist on `main` that are not in production** (superseded connectors). Production and repository have diverged in *both* directions.

This certification establishes production as the source of truth, inventories every branch/PR, maps dependencies, predicts conflicts, and recommends a single consolidation path: **reconcile `main` to production in one governed branch, then retire the 59 PRs** — rather than replaying 59 conflict-prone stacked merges. The platform cannot safely accept new engineers or new features until `main` == production.

---

## 2. Production Certification (Phase 0) — authoritative

| Asset | Count / evidence |
|---|---|
| **Org ID** | `00Dbn00000plgUfEAI` (verified) |
| **OA Apex classes** | **164** (incl. tests) |
| **OA custom objects** (base `__c`) | ~30 (+ `__mdt`, `__e`, `__History`, `__Share` system variants) |
| **Custom metadata types** | `OA_AI_Model`, `OA_Connector_Registry`, `OA_Engagement_Config`, `OA_Enrichment_Pipeline`, `OA_Enrichment_Source`, `OA_Field_Write_Policy`, `OA_Graph_Config`, `OA_Qualification_Rule` |
| **Permission sets** | 25 (`OA_*`) |
| **Named Credentials** | 13 — OpenAI, Anthropic, USASpending, SAM, Census, SEC, LinkedIn, Meta, OpenRouter (+ Management/Development), HdrEcho |
| **External Credentials** | 8 — OpenAI, Anthropic, SAM, LinkedIn, Meta, OpenRouter (+ Management/Development) |
| **Active Apex triggers** | **1** — `OA_UnsubscribeRequestTrigger` (on `OA_Unsubscribe_Request__e` platform event) |
| **Active scheduled jobs** | **7** — `OA Artifact Poller`, `OA Booking Poller` ×4, `OA EDWOSB Follow-Up Daily`, `OA_DripScheduler_Wave1` |
| **Platform events** | `OA_Unsubscribe_Request__e` |

**Production is healthy and authoritative.** Live automation (EDWOSB campaign drip + follow-up, booking/artifact pollers, unsubscribe) is running and must be protected during consolidation. All recent intelligence work (018→024D) is deployed **dormant** (no triggers/schedules), consistent with governance.

## 3. Repository Inventory (Phase 1)

- **`main`:** HEAD `dbf8d12` ("Merge PR #24: SAM.gov Opportunities connector"). **127 classes, 22 objects, 13 permsets.**
- **Branches:** ~85 remote feature branches. Most older ones (`lead-acquisition-*`, `blo-phase*`, `lead-enrichment-*`, `campaign-*`) are stacked chains whose code is already in production and largely on `main`.
- **Open PRs:** **59** (#25–#83).

**PR families (stacked chains — each PR based on its predecessor unless noted):**

| Family | PRs | Nature |
|---|---|---|
| Lead Enrichment readiness/ops | #25–#32 | Mostly docs/analytics on already-merged code |
| Lead Acquisition (candidate→SAM) | #33–#49 | Code + docs; Candidate/Identity/Fusion classes deployed |
| Business Lifecycle Orchestration | #50–#57 | BLO code + hardening/ops docs |
| Campaign→Meeting→Opportunity | #58–#64 | Meeting resolution/attribution + first Opportunity |
| Enterprise AI Platform/Gateway | #65–#69 | Programs 018/019 (gateway, live-validated) |
| Opportunity Intelligence | #70 | Program 020 |
| Knowledge Foundation | #71 | Program 021 |
| Acquisition & Compliance | #72–#73 | Programs 022/023 |
| Certification sprints | #74–#78 | Programs 023A–E (research/docs only) |
| BD-OS intelligence arc | #79–#83 | Programs 024–024D |

## 4. Open PR Inventory — see §3 table (59 PRs, #25–#83, base-branch chains noted in the merge order §19).

## 5. Dependency Graph (Phase 2)

**Hard dependencies (must merge in order):**
```
AI Gateway/Platform (018/019, #65–#69)
        ↓  (OA_AI_Gateway consumed by every AI workflow)
Opportunity Intelligence (020, #70)
Knowledge Foundation (021, #71)  ── consumed by ──┐
        ↓                                          │
Acquisition & Compliance (022/023, #72–#73)        │
        ↓                                          │
024 Federal Acquisition (#79) ─ OA_Opportunity_Signal__c
        ↓                                          │
024A Qualification (#80) ── reads Company Profiles ┘
        ↓
024B Partner + Investment (#81)
        ↓
024C Evidence/Document (#82)  →  024D Evidence Decisioning (#83, based on #82)
```
- **Soft dependencies:** 023A–E (#74–78) are docs that reference 022/023 but do not block code.
- **Independent chains:** Lead Enrichment (#25–32), Lead Acquisition (#33–49), BLO (#50–57), Campaign/Meeting (#58–64) — these depend on each other within-chain but their code is already largely resident in production/`main`.
- **Missing dependency on `main`:** `OA_AI_Gateway` (used by 020/021/024B/024C) is **not on `main`** — so none of the AI-consuming programs can be merged to `main` before #65–#69.
- **Conflict:** 024's Grants path (`OA_FederalOpportunityAcquisition`) **supersedes** the merged `OA_GrantsGov*` connector on `main`.

## 6. Production vs Repository Analysis (Phase 3)

**Forward drift — deployed in org, NOT on `main` (49 classes; must reach `main`):**
Core: `OA_AI_Gateway`, `OA_AI_ModelRegistry`, `OA_ComplianceScreen`, `OA_OpportunityIntelligence`, `OA_OpportunityQualification`, `OA_PartnerIntelligence`, `OA_PursuitInvestment`, `OA_DocumentIntelligence`, `OA_EvidenceCitation`, `OA_KnowledgeIntelligence`, `OA_FederalOpportunityAcquisition`, `OA_FederalAcquisitionScheduler`, `OA_USASpendingEnrichment`, `OA_IEnrichmentProvider`; Lead Acquisition: `OA_CandidateDiscovery(+Service/Queueable)`, `OA_CandidateApprovalService`, `OA_IdentityResolution`, `OA_SourceFusion`, `OA_LeadCompleteness`, `OA_LeadCreationService`; BLO: `OA_BusinessLifecycleService`, `OA_LifecycleStates`; plus `OA_AISummaryService/Queueable`, `OA_ArtifactPoller`, `OA_ReplayBookingService` (and their tests).

**Reverse drift — on `main`, NOT in org (12 classes; superseded/undeployed source):**
`OA_GrantsGovConnector`, `OA_GrantsGovMapper`, `OA_GrantsGovParser`, `OA_GrantsGovRequest`, `OA_GrantsGovService`, `OA_GrantsGov_Test`, `OA_SAMOpportunitiesService`, `OA_SAMOpportunities_Connector`, `OA_SAMOpportunities_Mapper`, `OA_SAMOpportunities_Request`, `OA_SAMOpportunities_ResponseParser`, `OA_SAMOpportunities_Test` (merged via PRs #22–#24; superseded by the 024 acquisition path). **These are dead source on `main` and should be removed during consolidation.**

## 7. Merge Conflict Assessment (Phase 4)

SFDX-decomposed metadata (one file per field) makes most additive work conflict-free. Risk per surface:

| Surface | Risk | Why |
|---|---|---|
| Apex classes (new) | **LOW** | Distinct files, additive |
| Object/field metadata | **LOW–MEDIUM** | Separate field files; but the same `object-meta.xml` touched by many programs (picklist value-set edits on `OA_Opportunity_Signal__c`, `OA_Company_Profile__c`) |
| Permission sets | **MEDIUM** | Multiple programs add FLS; if two edit one shared permset, conflict — here each program shipped its *own* permset, lowering risk |
| Superseded connectors | **HIGH (logical, not textual)** | `OA_GrantsGov*`/`OA_SAMOpportunities_*` vs 024 path — not a text conflict but a duplicate-implementation collision requiring a delete decision |
| Duplicate SAM/USASpending generations | **HIGH (debt)** | Two–three naming generations coexist in org (see §12) |
| `CLAUDE.md` / docs / `README` | **MEDIUM** | Git-only files edited across chains — likely textual conflicts if replayed sequentially |
| Live automation (triggers/schedules) | **N/A** | Consolidation is source-only; no deploy — production automation untouched |

**Per-PR risk:** #74–#78, #25–#32 (docs) = **LOW**; #65–#73, #79–#83 (additive code + own permsets) = **LOW–MEDIUM**; #33–#49 / #50–#64 (older code chains with duplicate connectors) = **MEDIUM–HIGH** if replayed.

## 8. Recommended Merge Order — **Option A: Production Reconciliation (recommended)**

Because production is the source of truth and is already the union of all merged + unmerged deployed work, the **safest, fastest** consolidation is *not* to replay 59 stacked PRs:

1. Create ONE branch off `main`: `chore/consolidate-from-production`.
2. `sf project retrieve start` the full `OA_*` metadata set from `00Dbn00000plgUfEAI` into it (classes, objects, fields, permsets, custom metadata, flows). Production defines the baseline.
3. **Delete** the 12 reverse-drift classes (§6) so `main` no longer carries source production lacks.
4. Preserve git-only artifacts (docs/, `CLAUDE.md`, `README`, scripts) — merge, don't lose them.
5. Check-only validate the branch against production → **expect a near-no-op** (proves `branch == production`).
6. Open ONE consolidation PR → review → merge → `main` == production.
7. **Close** PRs #25–#83 as "consolidated via production reconciliation," **preserving branches** (per governance) and linking each program's `docs/` file.

**Option B (not recommended): sequential stacked merge** of #65→#83 then triage #25–#64. Preserves granular history but is 59 conflict-prone operations with duplicate-connector collisions and doc conflicts. Higher risk, slower, no additional safety over Option A given production is authoritative.

## 9. PRs to Merge

Via Option A, **all live work reaches `main` in one reconciliation.** If Option B is chosen instead, merge in this order: **#65 → #66 → #67 → #68 → #69** (AI) → **#70 → #71 → #72 → #73** → **#74–#78** (docs) → **#79 → #80 → #81 → #82 → #83**; then triage the older chains #25–#64.

## 10. PRs to Revise

- **#33–#49 (Lead Acquisition)** and **#50–#64 (BLO/Campaign/Meeting):** before Option B merge, revise to remove duplicate SAM/USASpending connector generations (§12). Under Option A this is handled once by production reconciliation + §12 cleanup.
- **#83 (024D)** is based on **#82**, not `main` — re-target to `main` after #82 (or moot under Option A).

## 11. PRs to Reject / Retire

- No PR represents *bad* engineering warranting outright rejection. The **superseded `OA_GrantsGov*` / `OA_SAMOpportunities_*` source (PRs #22–#24, already merged)** should be **removed** from `main` (§6) — the 024 acquisition path replaced it.
- The **~30+ stale certification/readiness doc PRs** (023A–E, lead-enrichment readiness, lead-acquisition readiness) should be **retired/closed** once their `docs/` land via reconciliation — they add PR-queue noise without unmerged code.

## 12. Technical Debt (Phase 6)

- **Duplicate connector generations (HIGH):**
  - **SAM ×3 families** — `OA_SAM_*` (snake), `OA_SAM*` (camel: `OA_SAMConnector/Mapper/Parser/Request`), `OA_SAMOpportunities_*` (main-only). Consolidate to one.
  - **USASpending ×2–3** — `OA_USASpending_*` (snake) vs `OA_USASpending*` (`Client/Connector/Mapper/Parser/Request`) vs `OA_USASpendingEnrichment(Service)`. Consolidate.
  - **Connector framework ×2** — legacy `OA_IConnector`/`OA_ConnectorEngine` vs active `OA_IEnrichmentConnector`/`OA_ConnectorRunner`. Retire legacy.
- **Dead source on `main`:** the 12 reverse-drift classes (§6).
- **Superseded staging objects:** `OA_SAM_Entity_Staging__c`, `OA_USASpending_Staging__c` (early connector generations) — verify unused, then retire.
- **Unused permsets:** `OA_SAM_Temp_Principal`, `OA_SAM_Connector` may be obsolete if SAM connector consolidated — audit before removal.
- Cross-references: see prior `connector-cleanup-audit` (legacy vs active connector map). Nothing deleted here — this is the certified removal list for a cleanup sprint.

## 13. Architecture Review (Phase 7) — critical

1. **Over-engineering: connector layer.** Three+ SAM and two+ USASpending generations, plus two connector frameworks, are the clearest over-build. One framework + one connector per source is sufficient.
2. **Program-per-sprint branching without merging** created the fragmentation. The process, not the code, is the defect. **Fix the process:** merge each program to `main` at close going forward (the dormant-first pattern already makes this safe).
3. **Evidence layer (024C/D) is right-sized** — single object, no junction until proven, reuses Files + AI Gateway. Keep.
4. **Nothing should be deleted for being new** — but the *superseded* connectors (§12) should go.
5. **Custom metadata is well-used** (8 typed configs) — no consolidation needed there.

## 14. Simplification Recommendations

- **Reconcile from production (Option A)** — collapse 59 PRs into 1.
- **One connector framework, one connector per source** — retire duplicates (§12).
- **Merge-at-close discipline** — never let >1–2 programs sit unmerged again.
- **Delete dead `main` source** (§6) so `main` never advertises code production lacks.

## 15. Production Readiness (Phase 8)

| Ready for… | Status | Blocker |
|---|---|---|
| Production maintenance | ✅ | Org healthy, automation live |
| Future AI work | ✅ | Gateway live, OpenRouter default |
| **Single-source repository** | ❌ | `main` is 49 classes behind + 12 ahead of production |
| **New engineers** | ❌ | Cannot trust `main`; must reconcile first |
| Future feature development | ⚠️ | Safe only *after* consolidation |

**The gating issue is exactly one thing: `main` ≠ production.** Everything else is green.

## 16. Risks

- **Doing nothing:** drift widens with each new program; onboarding impossible; risk of re-implementing deployed work.
- **Sequential merge (Option B):** duplicate-connector collisions + doc conflicts across 59 PRs.
- **Reconciliation (Option A):** loses granular PR narrative (mitigated — each program's `docs/` is preserved); requires one careful "delete dead source" step.
- **Throughout:** consolidation is **source-only**; production automation (7 jobs, 1 trigger) is never touched.

## 17. Verdict — **WARN**

Production is certified authoritative and healthy; every open PR, dependency, and drift is inventoried with evidence; conflicts are predicted; the merge strategy and exact sequence are produced. **WARN (not PASS)** solely because the repository is *currently* fragmented — that is the finding, not a failure of this certification. The repository **is ready for consolidation**, which is the PASS condition for the *next* action.

## 18. Repository Certification

**CERTIFIED for consolidation via Production Reconciliation (Option A).** Production `00Dbn00000plgUfEAI` is the authoritative baseline. `main` must be reconciled to it, the 12 dead classes removed, and PRs #25–#83 retired with branches preserved. No code is lost (production holds it all); no automation is disturbed (source-only).

## 19. Exact Merge Sequence

```
1. git checkout main && git checkout -b chore/consolidate-from-production
2. sf project retrieve start -o 00Dbn00000plgUfEAI  (all OA_* metadata → branch)
3. git rm the 12 reverse-drift classes (OA_GrantsGov*, OA_SAMOpportunities_*)
4. Reconcile git-only docs/CLAUDE.md/README/scripts (keep)
5. sf project deploy start --dry-run -o 00Dbn00000plgUfEAI  (expect near no-op = parity proof)
6. Open ONE PR (base main) → review → MERGE  → main == production
7. Close PRs #25–#83 "consolidated via reconciliation" (preserve branches)
8. (Separate cleanup sprint) retire duplicate SAM/USASpending/connector-framework generations (§12)
```
All steps except 6 are GREEN/reversible; step 6 (merge) and any later deploy are **RED — require Louis's approval.**

## 20. Exact Next Engineering Program

**024F — Production Reconciliation & `main` Consolidation** (execute §19 steps 1–7): bring `main` to parity with production, remove dead source, retire the 59 PRs — the one action that unblocks everything else. **Only after `main` == production**, the highest-leverage *feature* unlock is **SAM.gov Activation** (provision the data.gov key + `OA_SAM_Opportunities` NC/EC) — it converts the BD-OS from grants-only to live federal *contract* opportunities where Qualification and Investment finally light up GO / HIGH. Recommend 024F first, SAM.gov immediately after.
