# Operational Baseline — Salesforce BPO Platform (AUTHORITATIVE)

**This is the single authoritative operational document.** Earlier status docs (024E–025B, listed in §Historical) are **historical, not authoritative**.

| | |
|---|---|
| **Production Org ID** | `00Dbn00000plgUfEAI` (verify by ID, never alias) |
| **main commit** | `2ab2d87` (PR #85 merged 2026-07-10T00:36Z) |
| **Production baseline** | main == production (164 OA classes, verified across all 3 package dirs) |
| **Prior/rollback commit** | `dbf8d12` |
| **Next review date** | 2026-08-09 (or before first scheduled activation) |

## Program 025C outcome
PR #85 merged; **main proven == production**; **test coverage refreshed** (was stale, now persisted); full Apex suite = **873 pass / 7 fail**, all 7 classified **test-quality/isolation, not runtime defects** (each critical one passes in isolation). Least-privilege PSG built + validated (unassigned). **Runtime is verified sound; activation remains gated on operational steps below.**

## Deployed subsystems (production, verified)
| Subsystem | Coverage | State |
|---|---|---|
| AI Gateway (`OA_AI_Gateway`) | 94% | LIVE (17 calls logged) |
| Grants.gov acquisition (`OA_FederalOpportunityAcquisition`) | 88% | Deployed; Remote Site `OA_GrantsGov` active; piloted (024C) |
| USASpending enrichment (`OA_USASpendingEnrichment`) | — | Deployed; `OA_USASpending` NC live |
| Compliance (`OA_ComplianceScreen`) | 93% | Deployed; SDVOSB→NO-GO verified correct |
| Qualification (`OA_OpportunityQualification`) | 89% | Deployed |
| Investment (`OA_PursuitInvestment`) | 91% | Deployed |
| Partner Intelligence (`OA_PartnerIntelligence`) | 75% | Deployed; partner data incomplete |
| Evidence/Document (`OA_EvidenceCitation`/`OA_DocumentIntelligence`) | 97/92% | Deployed; piloted (text only) |
| Knowledge Foundation (`OA_KnowledgeIntelligence`) | — | Deployed |
| Opportunity Intelligence (`OA_OpportunityIntelligence`) | — | Deployed |
| Lead Enrichment (`OA_LeadWritebackService`) | 80% | Deployed (v1.2); WITH USER_MODE writeback |
| Review Queue (`OA_Opportunity_Signal__c`) | — | LIVE (18 staged, Pending) |

## Active runtime (production)
- **Scheduled jobs (7, live):** OA Artifact Poller; OA Booking Poller ×4; OA EDWOSB Follow-Up Daily; OA_DripScheduler_Wave1 (campaign + booking only).
- **Active trigger (1):** `OA_UnsubscribeRequestTrigger` (platform event).
- **Runtime user:** `oauser@pboedition.com` — **System Administrator / Modify All Data (must be replaced, see Blockers).**

## Dormant subsystems (deployed, not scheduled)
Grants.gov acquisition scheduler (`OA_FederalAcquisitionScheduler`), all intelligence engines, evidence/document, enrichment batch. All run only on manual invocation.

## Known blockers (to daily operation)
1. **Least-privilege runtime** — automation runs as System Admin/MAD. PSG `OA_Runtime_Operations` built + validated (`0AfPn0000023xs1KAA`); needs a dedicated non-admin user (license) to assign it to. **[Louis]**
2. **Scheduling not enabled** — Grants.gov + enrichment jobs dormant. **[Louis approval]**
3. **Test-quality debt** — 7 tests not parallel-safe (isolation failures); could fail a future RunLocalTests deploy gate. Harden before next production deploy. **[Claude, non-urgent]**
4. **SAM.gov** — NOT BUILT in prod (connector undeployed); needs engineering + data.gov key. **[deferred fast-follow]**
5. **Microsoft Graph cloud intake** — NOT BUILT (no class/credential). **[deferred fast-follow]**
6. **Operational dashboards** — procurement/connector/runtime dashboards absent (4 campaign/BPO dashboards exist). **[Claude prep + Louis deploy]**
7. **Monitoring alerts** — telemetry flows; no proactive subscriptions. **[config]**

## Credentials required
data.gov API key (SAM); `OA_SAM_Opportunities` NC/EC (SAM); Azure Graph app-only credential + `OA_Graph` NC/EC (cloud email); dedicated runtime user license (least-privilege). **No secrets in source/logs.**

## Approved schedules
**None yet.** No scheduled acquisition/enrichment automation is approved. Campaign drip + booking pollers remain the only live jobs.

## Monitoring
Telemetry objects (populated): `OA_AI_Request_Log__c`, `OA_Enrichment_Change_Log__c`, `OA_Connector_Run__c`, `OA_Enrichment_Exception__c`, `OA_Knowledge_Document__c`, plus `AsyncApexJob`. Proactive alerting = **not yet configured** (report subscriptions + dashboard alerts recommended on the above).

## Rollback procedures
- **Repository:** `main` mergeable revert of PR #85 → `dbf8d12`; all feature branches preserved.
- **Least-priv PSG:** unassigned + destructive-deploy if needed (metadata-only).
- **Pilots:** delete pilot `OA_Opportunity_Signal__c` rows; `OA_LeadWritebackService` rollback for any enrichment write.
- **Production data:** never deleted in this baseline; review-queue records are working data (safe to remove).

## Business operating procedures (once activated)
Daily: review the opportunity queue (screened/qualified/invested/evidence-backed) → human promotes GO to Opportunity; review enrichment writeback proposals; check dashboards. Weekly: pipeline + AI cost + exception review. Monthly: KPIs; fast-follow decisions. **Human review mandatory; no auto-Opportunity; no unreviewed writeback.**

## Definition of Operational
`main` == production ✅ · coverage ≥75% persisted ✅ · least-privilege runtime (no MAD) ⛔ · credentials per activated source (Grants ✅ / SAM ⛔ / Graph ⛔) · procurement + runtime dashboards ⛔ · monitoring alerts ⛔ · a 30-day pilot with **0 governance violations** ⛔. **Operational when all ✅.**

## Historical (non-authoritative) documents
`ENTERPRISE_*`, `EVIDENCE_BACKED_DECISIONING.md`, `PLATFORM_CONSOLIDATION_CERTIFICATION.md` (024E), `RECONCILIATION_*` (024F), `POST_RECONCILIATION_ACTIVATION_READINESS.md` (024G), `PRODUCTION_ACTIVATION_OPERATIONAL_READINESS.md` (025), `ACTIVATION_GAP_VERIFICATION.md` (025A), `EXECUTIVE_GO_LIVE_PACKAGE.md` (025B) — retained as evidence; **this document supersedes their status claims.**
