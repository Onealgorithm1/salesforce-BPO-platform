# Production Environment Verification — Lead Enrichment

**Date:** 2026-07-08 · **Mode:** READ-ONLY live-org audit (`sf` CLI, user `oauser@pboedition.com`, Connected)
**Verified by ID:** `00Dbn00000plgUfEAI` · **Method:** SOQL + Tooling API + metadata list against the live org
**Evidence rule:** every statement below is a point-in-time query result from the production org, not the repo.

> Phase 1. Answers: what is actually deployed and running in production for Lead Enrichment right now?

---

## 1. Org identity — 🟢 verified
| Field | Value |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✅ (matches governance) |
| Name | One Algorithm LLC |
| Edition | **Enterprise Edition** |
| Instance | USA350 |
| IsSandbox | **false** (production) |
| Language | en_US |
| Source API version (project) | 67.0 |

## 2. Deployed Apex (Tooling API) — 🟢 platform present, all v67
All Lead Enrichment engine + connector classes are physically deployed in production at ApiVersion **67**:
`OA_EnrichmentOrchestrator`, `OA_EnrichmentQueueable`, `OA_EnrichmentWriter`, `OA_ConnectorRunner`,
`OA_ChangeLogService`, `OA_ExceptionRoutingService`, `OA_LeadWritebackService`, and connectors
`OA_USASpending_Connector`, `OA_SAM_Connector`, `OA_SEC_Connector`, `OA_IRS_Connector`, `OA_Census_Connector`,
`OA_StateRegistry_Template`. Legacy `OA_USASpendingClient` also present (write-back dependency).

**Not in production:** `OA_GrantsGovConnector`, `OA_SAMOpportunities_Connector`, `OA_GrantsGovService`,
`OA_SAMOpportunitiesService` — the Opportunity Intelligence Phase 1/2 classes are **repo-only, never deployed**.
→ The production Lead-Enrichment code surface is clean (no OI sediment).

## 3. Installed configuration (CMDT) — 🟢 fully dormant
| CMDT | In prod | Enabled/Active = true |
|---|---|---|
| `OA_Connector_Registry__mdt` | **6 rows** (Census, IRS, SAM, SEC, StateRegistry, USASpending) | **0** (all `Enabled__c=false`, Draft) |
| `OA_Field_Write_Policy__mdt` | 22 rows | **0 active** |
| `OA_Enrichment_Pipeline__mdt` | present | **0 enabled** |
| `OA_Enrichment_Source__mdt` | present | **0 active** |

**Repo↔org drift (documented):** the repo has **8** registry rows; production has **6**. The two extra repo rows
(`GrantsGov`, `SAM_Opportunities`) are Opportunity-Intelligence connectors **not deployed to prod** — so the two
"latent FAIL" rows flagged in `CONNECTOR_REGISTRY_REVIEW.md` **do not exist in production**. Live org is cleaner than
the repo on this point.

## 4. Scheduled jobs (CronTrigger) — 🟢 no enrichment schedule
12 scheduled jobs, **none for Lead Enrichment**:
- Campaign (protected): `OA EDWOSB Follow-Up Daily`, `OA_DripScheduler_Wave1`.
- Integrations: `OA Booking Poller 00/15/30/45`, `OA Artifact Poller`.
- Platform/managed: `SRT Semantic Graph…`, `ReportType Edge Data Loader…`, `Metalytics Data Loader…`, `CommSitemapJob…`, `CommIncrementalSitemapJob…`.

## 5. Active async Apex jobs — 🟢 no enrichment job
Queued ScheduledApex: `OA_FollowUpScheduler`, `OA_DripScheduler`, `OA_ArtifactPoller`, `OA_BookingPoller` (×4),
`PublishExpiryEvent` (×2). **No `OA_EnrichmentQueueable` / `OA_EnrichmentOrchestrator` / batch running.**

## 6. Data baseline (dormant state) — 🟢 matches certified baseline
| Metric | Live count |
|---|---|
| Leads with `UEI__c` populated (enriched) | **78** |
| `OA_Connector_Run__c` (telemetry) | 18 |
| `OA_Enrichment_Change_Log__c` (audit) | 474 |
| `OA_Enrichment_Exception__c` | 1 |

These match the documented v1.2 dormant baseline exactly → **no unexpected writes or drift** in production.

## 7. Phase-1 verdict — 🟢 PASS
Production is the correct Enterprise org; the full Lead-Enrichment platform is **deployed and dormant** (code present,
0 connectors enabled, 0 policies active, 0 enrichment jobs scheduled or running, baseline data unchanged).
**A dormant production deployment is, in effect, already complete and live-verified.** No enrichment automation is
active. Repo↔org drifts (registry 8 vs 6; OI classes/NCs repo-only) are documented and are *not* Lead-Enrichment risks.
