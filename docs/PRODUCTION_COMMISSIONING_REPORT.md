# Lead Enrichment Platform — Production Commissioning Report

_Status: **Track A completed → GO/NO-GO = NO-GO (conditional)** · 2026-07-06 · Org 00Dbn00000plgUfEAI_

Sprint 12 gates live commissioning (Tracks B–G) behind Track A: _"Identify every blocker … Do NOT
deploy until the deployment checklist is complete,"_ and _"After deployment prerequisites are satisfied,
validate each connector."_ Track A was executed (read-only verification against the live org). The
checklist is **not complete** — several prerequisites are unmet, one by a hard external constraint — so
**no deployment, no live callout, and no production Lead write was performed.** This report is the
deployment-readiness assessment and blocker register.

## 1. Deployment results
**No deployment occurred (by design).** The platform is not in the org. Verified via Tooling API:
- Enrichment Apex classes in org: **0** (OA_ConnectorRunner/CanonicalOrg/EnrichmentWriter/… absent).
- Enrichment objects + CMDT in org: **0** (OA_Connector_Run__c, …, OA_Connector_Registry__mdt absent).
- The full platform (6 connectors + framework + engines) lives on local feature branches only;
  `main = 1a66832`; nothing pushed/deployed.

## 2. Blocker register (Track A)
| # | Blocker | Severity | Evidence | Resolution |
|---|---|---|---|---|
| **B1** | **No least-privilege runtime user** | **CRITICAL / external** | `UserLicense Salesforce = 2 total / 2 used → 0 spare` | Acquire 1+ Salesforce license; create an integration user (Minimum Access profile, **no Modify All Data**) |
| **B2** | **Enrichment target Lead fields do not exist** | **HIGH** | FieldDefinition(Lead): UEI__c, EIN__c, CIK__c, Total_Award_Amount__c, Federal_Contractor__c, Market_Employment__c, Ticker__c, SIC_Code__c, State_Entity_Number__c — **all absent** | Add the Lead custom fields as a deploy artifact (schema step the field-agnostic platform build intentionally omitted) |
| **B3** | Platform not deployed | HIGH | 0 classes/objects in org | Deploy dormant (types first, then CMDT records) per DEPLOYMENT_PACKAGE.md |
| **B4** | Named Credentials missing for Census/SEC | MEDIUM | Only OA_SAM, OA_USASpending exist | Create secret-free OA_Census, OA_SEC NCs |
| **B5** | SAM External Credential principal access not granted | MEDIUM | OA_SAM_Connector permset = 0 assignments | Grant EC principal access via a permission-set deploy (JIT) at the key gate |
| **B6** | SAM alpha key unconfirmed | MEDIUM | Prior alpha smoke returned non-2xx | Confirm key on alpha, or point NC at prod endpoint (gated) |

## 3. Why the runtime-user blocker (B1) is decisive for safety
The platform's write guardrail is **FLS enforced in USER_MODE** — it only protects production data when
the runtime user is **not** a Modify-All-Data admin (MAD bypasses `stripInaccessible`; verified in the
Lead Write-Back canary). With **0 spare licenses**, no least-privilege user can be created. Running the
enrichment writer as the only available user (`oauser`, a SysAdmin with MAD) against production Leads
would **bypass the core safety mechanism** and mutate live data without least-privilege reversibility.
This alone makes Tracks C–D (pilot + scale writes on real Leads) unsafe today.

## 4. Track status
| Track | Status | Reason |
|---|---|---|
| A — Deployment readiness | ✅ **Done** | Verified; blockers B1–B6 identified |
| B — Live connector validation | ⛔ **Blocked** | Platform not deployed; NCs/EC incomplete (B3–B6) |
| C — Controlled pilot (10–20 Leads) | ⛔ **Blocked** | No runtime user (B1); no Lead fields (B2) |
| D — Scale validation (100–500) | ⛔ **Blocked** | Same as C |
| E — Operational monitoring | ✅ **Designed** | Dashboards specified (MONITORING_DASHBOARDS.md); build after deploy |
| F — Operational controls | ✅ **Designed/verified-by-design** | Kill switch = registry `Enabled__c`; rollback = OA_ChangeLogService; runbook documented — all config/no-code, testable post-deploy |
| G — Production acceptance (5 connectors on one Lead) | ⛔ **Blocked** | Requires live deploy + runtime user |

_Tracks B/C/D/G are **proven at the code level** by the check-only integration tests
(SAM+USASpending+Census+IRS+SEC through one runner; policy/qualification/exception/rollback), at
97%+ coverage — but cannot be executed **live** until B1–B6 close._

## 5. Field validation, policy validation, rollback
- **Field validation:** the write-policy CMDT records target Lead fields that **do not yet exist** (B2)
  — a live run today would skip them all. Fields must be added first.
- **Policy validation:** validated in tests (fill-empty/overwrite/never/conflict/floor); not exercised
  live (no deploy).
- **Rollback:** validated in tests (snapshot → restore on standard Lead fields); live rollback drill
  deferred to post-deploy canary.

## 6. Documentation issues resolved (Track A)
- **Added a required deploy artifact to the plan:** *"Create Lead enrichment custom fields"* must precede
  field-write activation (the platform is intentionally field-agnostic; the fields are a deployment-time
  schema addition). This is now called out here and should be added to DEPLOYMENT_PACKAGE.md §1.
- Named-Credential checklist updated: OA_Census/OA_SEC must be created before those connectors run.

## 7. Known issues
Runtime-user license shortage (B1); missing Lead fields (B2); missing Census/SEC NCs (B4); SAM EC
access + alpha-key confirmation (B5/B6). No code defects found.

## 8. Operational recommendations (safe path to "operational")
1. **Resolve B1** — acquire a license; create the least-privilege integration user (the gating item).
2. **Resolve B2** — deploy the Lead enrichment custom fields.
3. **Dormant deploy** the platform (types → then CMDT records), all `Enabled/Active=false`. Reversible; no runtime effect.
4. Create OA_Census/OA_SEC NCs; grant SAM EC principal access JIT; confirm SAM key.
5. **Canary:** enable ONE connector, run 1 synthetic Lead as the runtime user → verify write + audit + **live rollback** + tripwires 0.
6. **Pilot 10–20 real Leads** (JIT-assign runtime user; log every field; revoke after).
7. **Scale 20 → 100 → 500** with the async bulk orchestrator (PERFORMANCE_REVIEW.md); produce the perf report.
8. Build the 8 monitoring dashboards; drill the operational controls (F).

## 9. Lessons learned
- A "feature-complete platform" is not the same as "operational" — the binding constraints are
  **operational/licensing**, not code.
- Field-agnostic design keeps the platform reusable but pushes the concrete Lead-field schema to
  deployment time — make that an explicit deploy artifact.
- Safety hinges entirely on the least-privilege runtime user; without it, no live write is safe.

## 10. Go / No-Go
**NO-GO for live enrichment of production Leads today.** The platform is code-complete and validated,
but the operational prerequisites — above all **a least-privilege runtime user (blocked by 0 spare
licenses)** and the **missing Lead fields** — are not satisfied. **GO becomes achievable** once B1 + B2
(and B3–B6) are closed, following the staged path in §8, each step reversible and logged.
