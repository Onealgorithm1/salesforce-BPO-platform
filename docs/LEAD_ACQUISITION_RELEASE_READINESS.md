# Lead Acquisition — Platform Consolidation & Release Readiness (Phase 19)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-live-pilot`
**Mode:** live-org inventory + governance review + documentation. **No new features · no new connectors · no deploy · no merge · no scheduling · no automation · no Lead/Account change.**
**Investigation order applied:** live org → read-only runtime → repository → docs. All runtime facts below are from the **live production org**.

---

## 1. Executive Summary
Lead Acquisition has completed successful **USASpending, SEC, and SAM** pilots and the platform's **first production cross-source fusion**. The **core engine is complete and deployed dormant** (16 Apex classes live), runtime is **clean** (0 acquisition jobs, 0 acquisition schedules, all connectors `Enabled__c=false`), and there are **no secrets in the repository** and **no automatic Lead creation**. Lead Acquisition is **eligible to be declared Release Candidate 1 for supervised operation**, with a clear, bounded set of **pre-volume** conditions (least-privilege runtime user, SAM permission-set consolidation, credential-hygiene). It is **not yet ready for volume or unattended automation.** Overall readiness **≈ 72/100**. **Verdict: 🟢 PASS (sprint) with 🟡 WARN release conditions.**

## 2. Live Production Inventory
| Area | Live finding |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✅ |
| Candidates | **6** (USASpending 3, SEC 3; 2 of the USASpending rows SAM-fused) |
| Leads / Accounts | **13,301 / 1** (unchanged) |
| Review queue | 6 candidates `Needs Review`; 1 `OA_Enrichment_Exception__c` |
| Acquisition async jobs | **0** (filtered on Candidate/Discovery/Acquisition) |
| Acquisition schedules | **0** (the 12 live CronTriggers are all pre-existing: booking pollers, EDWOSB follow-up, drip, sitemap, metalytics — none acquisition) |
| Connector registry (CMDT) | 6 rows — SAM, USASpending, SEC, IRS, Census, StateRegistry — **all `Enabled__c=false` / `Draft`** |
| Apex (deployed) | 16 acquisition classes incl. `OA_CandidateDiscovery(+Service,+Queueable)`, `OA_ConnectorRunner`, `OA_IdentityResolution`, `OA_SourceFusion`, `OA_LeadCompleteness`, `OA_SAM_Connector` (+ tests) |
| Custom object | `OA_Discovered_Organization__c` (Candidate staging; full field set incl. identifiers, dedup keys, review lifecycle, `Discovery_Metadata__c` provenance) |
| Named Credentials | `OA_SAM` (`https://api.sam.gov`), `OA_USASpending`, `OA_SEC`, `OA_Census`, `OA_IRS`, `OA_StateRegistry` |
| External Credentials | `OA_SAM` (Custom auth; `X-Api-Key` Custom Header — key stored encrypted in org, **not** in git) |
| Permission sets | `OA_SAM_Connector` (staging CRUD; **no EC grant**), `OA_SAM_Temp_Principal` (**carries the EC principal grant**, assigned to `oauser`) |
| Runtime user | `oauser@pboedition.com` — assigned `OA_Lead_Enrichment_Runtime` + `OA_SAM_Temp_Principal` |
| Reports / dashboards (acquisition) | none deployed (candidate analytics = deferred E4) |
| Queueable | `OA_CandidateDiscoveryQueueable` deployed dormant (no enqueue) |

## 3. Temporary Configuration Review
| Artifact | Live state | Classification |
|---|---|---|
| `OA_SAM_Temp_Principal` (permset) | Sprint-31 test permset; carries OA_SAM EC principal grant; assigned to `oauser` | **Rename/consolidate → retire later** |
| `OA_SAM_Connector` (permset) | Exists; staging CRUD only; **no EC grant** | **Convert to permanent** — move EC principal access here + assign; then retire temp |
| OA_SAM EC principal access | Granted via `OA_SAM_Temp_Principal` only | **Must fix before volume** (consolidate to named permset) |
| Raw `X-Api-Key` Custom Header | Key entered as literal header value (encrypted in org; not in repo) | **Acceptable for supervised pilot; fix before volume** (migrate to hyphen-free `ApiKey` auth param + `{!$Credential.OA_SAM.ApiKey}`) |
| Pilot Candidate records (6) | Legitimate `Needs Review` output of the pilots | **Keep as-is** |
| Pilot documentation | SAM readiness/runbook/release docs | **Keep**; consolidate superseded readiness notes |
| Stacked feature branches (24) | Preserved per governance | **Retire later** (after merge; do not delete now) |

## 4. PR Stack Review (24 open: #25–#48; current branch not yet PR'd)
**Lead Enrichment RC1 train (#25–#32)** — linear; #25–#30/#32 docs, **#31 analytics feature** (dormant, check-only). #32 packages #25–#31. Superseded internally by #32. Separate epic (maintenance mode).
**Lead Acquisition train (#33–#48)** — linear stack (each based on the prior; #33 based on `main`):

| PR | Type | Current? | Notes / supersession |
|---|---|---|---|
| 33 Candidate Foundation | feat | ✅ | base=main; report type + designs |
| 34 Discovery + dedup | feat | ✅ | service (deployed later) |
| 35 USASpending pilot | feat | ✅ | 3 candidates (prod, done) |
| 36 Unified framework | docs | ⚠ | design; partly superseded by later code |
| 37 Company Intelligence | feat | ✅ | completeness + fusion design |
| 38 Generic driver | feat | ✅ | `OA_CandidateDiscovery` |
| 39 SEC pilot | feat | ✅ | 3 candidates (prod, done) |
| 40 Identity Resolution | feat | ✅ | validated |
| 41 Fusion Engine | feat | ✅ | **deployed** |
| 42 Connector Readiness + bulk resolver | feat | ✅ | **deployed** |
| 43 Phase 10 assessment | docs | ⚠ superseded | by Phase 18/19 |
| 44 Phase 11 op readiness | docs | ⚠ superseded | by Phase 18/19 |
| 45 Queueable + closeout | feat | ✅ | **deployed dormant** |
| 46 SAM readiness | docs | ⚠ superseded | by successful pilot (17b) |
| 47 SAM endpoint alpha→prod | fix | ✅ | **deployed** |
| 48 SAM Phase 16 gate (STOPPED) | docs | ⚠ superseded | by successful pilot (17b) |
| *(pending #49)* SAM live pilot + expansion + this readiness | docs | ✅ current tip | Phase 17b/18/19 |

**Key facts:** the stack is **linear** (clean sequential rebase); **most code is already deployed dormant to prod** (#35/#39/#41/#42/#45/#47), so merging is **source catching up to prod** — near-zero runtime risk. Several **docs PRs are superseded** by later consolidation.
**Conflict risk:** LOW within each linear stack; MODERATE only where enrichment and acquisition both touch shared analytics/permset metadata — mitigated by merging enrichment first.
**Production impact of merging:** ≈ none (dormant code; connectors off; no schedules).

## 5. Recommended Merge Strategy (do not merge — recommendation only)
**Primary (consolidated, recommended):** two **squash-merge release trains** into `main`:
1. **Lead Enrichment RC1** — squash-merge the enrichment tip (`feature/lead-enrichment-rc1`, PR #32) → `main` as one "Lead Enrichment RC1" commit; close #25–#31 as rolled-up.
2. **Lead Acquisition RC1** — after (1) lands, retarget the acquisition **tip** (pending PR #49 / `feature/lead-acquisition-sam-live-pilot`) to `main` and squash-merge as one "Lead Acquisition RC1" commit (captures the cumulative #33–#48 diff); close #33–#48 as rolled-up.
Rationale: 24 linear PRs where code is already in prod and later docs supersede earlier ones — one squash per epic gives a clean, reviewable RC1 commit without history rewrite or force-push (branches are preserved). Merge **enrichment first**, then rebase the acquisition tip on updated `main` and resolve any conflict once, at the tip.
**Conservative alternative:** merge in strict numeric order #25→#48, retargeting each PR's base to `main` after its parent merges (preserves granular history; 24 sequential merges).
**Either way:** merge only after the pre-volume governance items (§7) are accepted, and **never** enable connectors/schedules as part of the merge.

## 6. Repository Cleanup Plan (no deletions performed)
- **Stale branches:** 24 acquisition/enrichment feature branches — retain until their PRs merge; after RC1, archive/delete the fully-merged ones (owner decision; governance keeps merged branches by default).
- **Duplicate/superseded docs:** Phase 10/11 readiness (#43/#44) and SAM readiness/gate (#46/#48) are superseded by Phase 18 runbook + this Phase 19 doc — mark as historical, do not delete.
- **Obsolete runbooks:** none dangerous; `LEAD_ACQUISITION_SAM_READINESS.md` §1–§9 (pre-resolution) is historical; §10–§11 are current.
- **Stale metadata:** dead legacy connector generation noted in prior audits (legacy `OA_IConnector`/`OA_USASpendingClient`, `OA_SAM_Opportunities` unused, IRS connector missing `OA_IRS_Request`, StateRegistry template) — **out of scope this sprint**; track for a separate dead-code cleanup PR.
- **Temporary files:** none tracked; scratchpad only.
- **Branch-stack risk:** deep linear stack — addressed by the squash-per-epic strategy (§5).

## 7. Security & Governance Review
| Control | Status |
|---|---|
| No secrets committed | ✅ verified (`git grep` for key/token patterns = none) |
| No API keys in repository | ✅ External Credential files are **not tracked**; Named Credentials hold URLs only |
| External credentials handled safely | ✅ SAM key stored encrypted in org EC, never in git/logs/URL |
| Permission assignments documented | ✅ `oauser`: `OA_Lead_Enrichment_Runtime` + `OA_SAM_Temp_Principal` |
| Review-before-Lead-creation preserved | ✅ candidates stay `Needs Review`; human approval gates Lead creation |
| No automatic Lead creation / no Lead write-back | ✅ acquisition writes only `OA_Discovered_Organization__c` |
| No scheduled automation / no unauthorized activation | ✅ 0 acq schedules; all connectors `Enabled__c=false` |
| Audit / provenance preserved | ✅ `Discovery_Metadata__c` `sources[]` + change log |

**Risk classification (special attention items):**
| Risk | Class |
|---|---|
| Raw `X-Api-Key` Custom Header | **Acceptable for supervised pilot; must fix before volume** |
| `OA_SAM_Temp_Principal` (temp permset carries EC grant) | **Acceptable for supervised pilot; must fix before volume & before automation** |
| Runtime user `oauser` = admin/MAD (not least-privilege) | **Must fix before volume & before automation** (top standing risk) |
| None block the (docs/dormant-code) merge | **Nothing "must fix before merge"** |

## 8. Release Readiness Score (0–100)
| Area | Score | Basis |
|---|---:|---|
| Business | 75 | Pilots prove value (fusion, completeness lift, ICP discovery); volume/ROI unproven; review staffing undefined |
| Engineering | 90 | Core engine complete, deployed, tested (bulk-safe, queueable); only optional NAICS/E2 + dashboards/E4 remain |
| Security | 70 | No secrets, safe EC, provenance; least-priv user + temp permset + raw header are gaps for volume |
| Operational | 60 | Supervised manual proven; no dashboards/alerting/review-staffing/cadence for acquisition |
| Governance | 90 | Strong gating, review-before-Lead, no automation, audit intact, all dormant/approved |
| Scalability | 75 | Bulk resolver + queueable spacing proven; empty Matching/Duplicate rules; no volume test |
| Deployment | 65 | Code deployed dormant, but 24-PR stack unmerged (source↔prod drift) needs consolidation |
| Support | 55 | Runbooks exist; no ops dashboards/alerting/defined support process |
| **Overall** | **≈72** | **RC1-eligible for supervised operation; not volume/automation-ready** |

## 9. Final Definition of Done (Lead Acquisition)
- **Engineering (code):** ✅ complete for the core engine. Optional only: NAICS mapping (E2, externally blocked), candidate dashboards (E4, operational). *No other code work remains.*
- **Configuration:** consolidate `OA_SAM_Connector` permset (EC principal access + staging CRUD); populate org **Matching/Duplicate Rules**; registry `Enabled__c` governance.
- **Administration:** **least-privilege runtime user** (replace `oauser`/MAD); retire `OA_SAM_Temp_Principal`; migrate raw header → `ApiKey` param; PR merges; Louis approvals.
- **Operations:** candidate review dashboards/alerts; review staffing; enqueue cadence + monitoring.
- **Activation (🔴):** connector `Enabled__c=true`; scheduled/queueable cadence; committed volume writes.
- **Future enhancements:** additional sources (SEC follow-on), UEI↔CIK crosswalk, field-precedence fusion, NAICS enrichment.
> Removed from the **engineering** backlog (non-code): permset consolidation, runtime-user least-privilege, Matching/Duplicate rules, dashboard deploy, PR merges — these are configuration/administration/operations.

## 10. PASS / WARN / FAIL — 🟢 PASS (with 🟡 WARN release conditions)
**PASS:** live inventory completed; PR stack reviewed; merge strategy produced; temporary config assessed; governance risks classified; readiness scored; **no production safety violation; no Leads/Accounts modified; no automation enabled; no schedules created.**
**WARN conditions (before volume / RC1-GA):** deep 24-PR stack needs the consolidated merge strategy; SAM temp permset + raw header must be fixed before volume; least-privilege runtime user is missing.

## 11. Recommended Next Phase
**Lead Acquisition RC1 declaration + pre-volume hardening**, in this order (all gated on Louis):
1. **Pre-volume hardening (config/admin):** provision a least-privilege runtime user; consolidate `OA_SAM_Connector` permset (EC grant + assign) and retire `OA_SAM_Temp_Principal`; migrate the raw header to an `ApiKey` param; add org Matching/Duplicate rules.
2. **Merge consolidation:** execute the §5 squash-per-epic strategy; tag `lead-acquisition-rc1`.
3. **Then** resume supervised expansion (USASpending, per the Phase 18 runbook) and, only after hardening, consider cadence/activation.
**Do not** begin Opportunity Intelligence, add connectors, enable scheduling/automation, or merge until approved.
