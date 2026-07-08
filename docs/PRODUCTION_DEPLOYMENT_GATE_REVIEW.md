# Production Deployment Gate Review — Lead Enrichment

**Date:** 2026-07-08 · **Mode:** READ-ONLY · **Org:** `00Dbn00000plgUfEAI` (verified by ID)

> Phase 5. Every remaining RED gate, with reason, risk, live evidence, owner, action, estimated time, and whether it
> blocks production. **Key framing:** the dormant platform is **already deployed and live** (see
> `PRODUCTION_ENVIRONMENT_VERIFICATION.md`). Gates below almost all block **activation**, not a dormant deploy.

---

## 1. Gate register

### G1 — Least-privilege runtime user (replace MAD `oauser`)
- **Reason:** enrichment runs as `oauser@pboedition.com`, a Modify-All-Data admin.
- **Risk:** MAD bypasses FLS → a bug/bad policy could write beyond trusted fields at scale (R1, top risk).
- **Evidence (live):** `PermissionSetAssignment` shows `OA_Lead_Enrichment_Runtime` + `OA_Lead_Writeback_Reviewer` on `oauser`; user is MAD admin.
- **Owner:** Louis (license procurement) + admin.
- **Action:** provision a dedicated integration user, Minimum-Access profile, full SF license, JIT permsets.
- **Est. time:** ~0.5 day once a license is available (license = external constraint).
- **Blocking production?** Dormant deploy: **NO.** Manual/supervised write: acceptable with controls. **Scheduled/24×7: YES.**

### G2 — SAM credential (data.gov key + JIT EC principal grant)
- **Reason:** SAM connector cannot authenticate without a valid key and an EC principal-access grant.
- **Risk:** SAM runs fail (401/403); key was previously exposed (R2).
- **Evidence (live):** `SetupEntityAccess WHERE SetupEntityType='ExternalCredential'` → **0 grants**; EC `OA_SAM` exists but unassigned; NC endpoint = `api-alpha.sam.gov`.
- **Owner:** Louis (data.gov key) + admin (JIT grant).
- **Action:** enter/rotate key in the `OA_SAM` EC (Setup only); grant EC principal access via permset JIT; move endpoint alpha→prod.
- **Est. time:** ~0.5 day + external key availability.
- **Blocking production?** **SAM connector only: YES.** USASpending/SEC/IRS/Census: **NO** (they don't use SAM).

### G3 — Monitoring/alerting deployment
- **Reason:** no enrichment dashboards/reports/alerts deployed.
- **Risk:** an unattended failure goes unseen (R9).
- **Evidence (live):** 9 dashboards in org, **none enrichment-specific**; alerts designed, not wired.
- **Owner:** admin (UI/metadata build) + Louis (approve deploy).
- **Action:** build/deploy reports + dashboards + alert subscriptions per `MONITORING_AND_ALERTS.md`.
- **Est. time:** ~1 day.
- **Blocking production?** Dormant/manual: **NO** (audit script covers). **Scheduled/24×7: YES.**

### G4 — Connector enablement / write-policy activation
- **Reason:** all connectors `Enabled__c=false`, all 22 policies `Active__c=false`.
- **Risk:** activation is the moment writes become possible; must be deliberate + FillEmptyOnly only.
- **Evidence (live):** registry 6/6 disabled; 0 active policies.
- **Owner:** Louis (explicit approval per activation).
- **Action:** enable one connector + activate FillEmptyOnly policies for a scoped pilot; never activate Overwrite.
- **Est. time:** minutes per activation (behind gate).
- **Blocking production?** **YES for any active enrichment** (by design). **NO for dormant.**

### G5 — Permission-set assignment (write-back Automation)
- **Reason:** `OA_Lead_Writeback_Automation` grants Lead Edit for writes; kept unassigned.
- **Risk:** assigning it enables the write path.
- **Evidence (live):** permset **unassigned**.
- **Owner:** Louis.
- **Action:** JIT-assign to the (least-privilege) runtime user for a run; revoke after.
- **Est. time:** minutes (behind gate; depends on G1).
- **Blocking production?** **YES for automated writes.** **NO for dormant/preview.**

### G6 — Doc PR merges (#25 → #26 → #27, and this #28)
- **Reason:** readiness/hardening/certification docs are on stacked branches, not merged to `main`.
- **Risk:** none to production (docs only); repo `main` lags the certified doc set.
- **Evidence:** PRs #25/#26/#27 open; this review = #28.
- **Owner:** Louis (merge approval).
- **Action:** merge in order (or retarget to `main`). No metadata/Apex deploy.
- **Est. time:** minutes.
- **Blocking production?** **NO** (documentation only).

### G7 (hygiene, non-blocking) — repo↔prod drift + registry vestige + OIQ app
- **Reason:** `OpenAI` NC/EC in org not in repo; `GrantsGov`/`SAM_Opportunities` registry rows + NCs in repo not in prod; `OIQ_Integration` connected app unidentified (TD-009).
- **Risk:** low — none affects the Lead-Enrichment live path (prod registry is the clean 6).
- **Evidence (live):** NC list (8), registry (6), ConnectedApplication (OIQ present).
- **Owner:** admin.
- **Action:** reconcile drift docs; identify/document or revoke `OIQ_Integration`; fix vestigial repo rows before OI deploy.
- **Est. time:** ~0.5 day.
- **Blocking production?** **NO.**

## 2. Gate summary
| Gate | Blocks dormant deploy | Blocks manual/supervised | Blocks scheduled 24×7 |
|---|---|---|---|
| G1 least-priv user | No | No (with controls) | **YES** |
| G2 SAM credential | No | SAM only | SAM only |
| G3 monitoring deploy | No | No | **YES** |
| G4 connector/policy activation | No | **YES** (must activate to run) | **YES** |
| G5 write permset assign | No | **YES** for writes | **YES** |
| G6 doc merges | No | No | No |
| G7 hygiene/drift | No | No | No |

**Bottom line:** **nothing blocks the dormant production state — it is already live and verified.** For a first
**supervised manual USASpending** enrichment: G4 + G5 (activation + JIT permset) behind Louis approval, with G1 accepted
under the documented MAD exception. For **scheduled/24×7**: G1 + G3 (+ G2 for SAM) must close first.
