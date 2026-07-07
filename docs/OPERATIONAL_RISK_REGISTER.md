# Operational Risk Register — Lead Enrichment Platform v1.0

_Sprint 18 · Org **00Dbn00000plgUfEAI** · reassessed 2026-07-07 (live-verified dormant) · pre-live-pilot baseline_

Risks are scored **Likelihood × Impact** (Low / Med / High) as of the current **dormant** state (0 connectors
enabled, 0 policies active, 0 enrichment jobs). Ranked most-severe first. Each risk names a concrete mitigation
already in place or required before scaling.

## Risk table

| # | Category | Risk | Likelihood | Impact | Score | Mitigation |
|---|---|---|---|---|---|---|
| R1 | **Security** | **Runtime user is `oauser` (admin / Modify-All-Data).** MAD weakens the intended FLS least-privilege guardrail; a bug or bad policy could write beyond trusted fields. | Med | High | 🔴 **High** | Temporary, documented exception (`RUNTIME_USER_EXCEPTION.md`). Conservative controls: fill-empty policies, full snapshots, tiny scope, connectors dormant by default. **Required fix:** provision a dedicated least-privilege runtime user (needs a Salesforce license) before scheduled/24-7 enrichment. *Top standing risk.* |
| R2 | **Security** | **SAM data.gov key unconfirmed / previously exposed.** Prior alpha smoke test returned non-2xx; key was plaintext-visible in an earlier session. | Med | High | 🔴 **High** | SAM kept out of the first pilot. Rotate the key; store only in the `OA_SAM` External Credential (never in git/logs). Grant EC principal access JIT and revoke after. Validate with a low-risk smoke test before any SAM pilot. |
| R3 | **Operational** | **Production data corruption via wrong write policy / overwrite.** An overwrite policy or bad mapping could clobber good Lead data at scale. | Low | High | 🟠 **Med** | Fill-empty policies only for pilots; preview (`commitWrites=false`) first cycle; per-field policy engine + `Before_Snapshot__c` on every write; proven rollback (5/5). Must-be-zero tiles: overwrites, writes-without-snapshot. |
| R4 | **Governance** | **Live enrichment enabled before go-live gate is complete** (credentials, monitoring, pilots, least-priv user). | Low | High | 🟠 **Med** | `GO_LIVE_CHECKLIST.md` gates each item with sign-off; RED actions require Louis's explicit approval; gated workflow model. Platform ships dormant; activation is a deliberate multi-step act. |
| R5 | **Technical** | **Connector callout failure / auth / rate-limit** (SAM key, endpoint blank, API throttling) during a live run. | Med | Med | 🟠 **Med** | Connectors return non-2xx on `OA_ConnectorResult` (never throw for expected failures); orchestrator retries transient once, **stops on `Failed`**. Alerts on repeated HTTP errors / 401-403 (`OPERATIONAL_ALERTS.md`). Batch size 50 keeps callout headroom. |
| R6 | **Operational** | **Governor limits at scale** (100 callouts/txn, CPU, DML) on a large backfill. | Low | Med | 🟡 **Low-Med** | `PERFORMANCE_VALIDATION.md`: measured ~11 ms CPU/Lead, 0 in-loop SOQL; callouts are the binding limit → batch 50 (callout) / 200 (IRS), start at 20. Run backfills off-peak in waves. |
| R7 | **Deployment** | **Sprint 17 merged/deployed without a clean gate**, or the 3 excluded untracked files committed by accident. | Low | Med | 🟡 **Low-Med** | Sprint 17 is a clean 2-commit branch off `main` tip (no conflicts). Excluded files (`apex-temp-*.json/.apex`, `lead_by_ramesh.flow-meta.xml`) stay untracked — verify `git status` before any commit. Merge is a RED action pending approval. |
| R8 | **Operational** | **Runtime FLS permset accidentally revoked** → fields hidden ("No such column" — the Sprint-13 bug). | Low | Med | 🟡 **Low-Med** | `OA_Lead_Enrichment_Runtime` **kept assigned** (live-verified: 1 assignment). Monthly check confirms assignment. Documented in the ops guide as a standing invariant. |
| R9 | **Governance** | **No monitoring/alerting wired yet** — a live failure could go unseen. | Med | Low | 🟡 **Low** | Dashboards + alerts are build-ready (`MONITORING_DASHBOARDS.md` / `OPERATIONAL_ALERTS.md`); building them is a go-live-window prerequisite before any schedule. First pilots are supervised live, so gap is bounded. |
| R10 | **Technical** | **Missing Named Credentials for Census/SEC** block those connectors. | High | Low | 🟡 **Low** | Known and expected; secret-free NCs (`OA_Census`, `OA_SEC`) are simple Setup tasks. Connectors stay dormant until created; not a data-safety risk. |
| R11 | **Operational** | **Single-owner key-person dependency** (Louis approves all RED actions; non-technical). | Med | Low | 🟡 **Low** | Plain-English reporting, documented runbooks/checklists, GPT governance layer. Pilots are supervised and reversible. |

## Category summary (highest residual first)
- **Security (R1, R2):** the two 🔴 High risks. Both are *known, accepted, and controlled* for the dormant/pilot
  phase; both must be closed (least-priv user; SAM key rotation+validation) before 24-7 automation.
- **Operational (R3, R6, R8, R11):** bounded by fill-empty policies, snapshots, proven rollback, and measured limits.
- **Governance (R4, R9):** bounded by the go-live checklist and the gated approval model.
- **Deployment (R7):** low — clean additive branch, excluded files understood.
- **Technical (R5, R10):** normal connector-integration risks; handled by the platform's error model and Setup tasks.

## Standing invariants (never violate)
1. Connectors dormant by default; enabling is a deliberate RED act.
2. `commitWrites=false` for the first cycle of any new scope/schedule.
3. Fill-empty policies for pilots; every write carries a before-snapshot; rollback rehearsed before scaling.
4. Runtime FLS permset stays assigned; the Automation permset stays unassigned until a least-priv user exists.
5. No secret in git/logs; secrets only in External Credentials; SAM EC principal access is JIT then revoked.
6. No scheduled/24-7 enrichment until R1 (least-priv user), all credentials, monitoring, and 25→100 pilots are closed.
