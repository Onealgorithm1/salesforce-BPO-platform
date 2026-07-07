# Lead Enrichment Platform — Operations Guide (Track G)

_v1.0 · Org 00Dbn00000plgUfEAI · runtime user: temporary `oauser` (see `RUNTIME_USER_EXCEPTION.md`)_

The single operational reference for running Lead Enrichment Platform v1.0. Complements the deeper
`LEAD_ENRICHMENT_OPERATIONS_RUNBOOK.md` (daily monitoring detail) and `DEPLOYMENT_PACKAGE.md` (deploy steps).
**Current state: platform deployed dormant — 0 connectors enabled, 0 active policies, nothing scheduled.**

## Execution surface (Sprint 17; **deployed to prod dormant Sprint 28**)
- **Batch:** `OA_EnrichmentOrchestrator.enqueueBatch(source, ruleset, scopeQuery, commitWrites, batchSize)`
- **Queueable (manual/small):** `System.enqueueJob(new OA_EnrichmentQueueable(leadIds, source, ruleset, commitWrites))`
- **Deployed & Active (dormant)** as of Sprint 28 — nothing invokes/schedules them; the direct callout-before-DML
  path remains the proven manual method. **Safe by default:** `commitWrites = false` = preview (no Lead DML).
  All writes go through the existing policy engine + audit; nothing bypasses it.

## Startup (enable operation — requires Louis authorization)
1. Confirm runtime FLS: `OA_Lead_Enrichment_Runtime` **assigned** to the runtime user and **kept assigned**
   (revoking it hides fields → "No such column"). Verified assigned.
2. Close credential gaps (`CREDENTIAL_STATUS.md`): SAM endpoint + EC principal access + key; Census NC; SEC NC.
3. Enable the target connector(s): set `OA_Connector_Registry__mdt.Enabled__c = true` for that source.
4. Activate the intended write policies (`OA_Field_Write_Policy__mdt`) — prefer **fill-empty**.
5. Run a **manual canary** (1 Lead, `commitWrites=false` then `true`); verify change log + rollback.
6. Pilot: 25 Leads → 100 Leads (`PERFORMANCE_VALIDATION.md` batch sizes) before any schedule.

## Shutdown / pause (return to dormant)
1. **Deactivate schedules** (if any): `Setup → Scheduled Jobs` → delete the enrichment job(s).
2. Disable connectors: `Enabled__c = false` on the registry rows.
3. Deactivate write policies (`Active__c = false`). The platform is now inert; data untouched.

## Emergency stop (fastest → safest)
1. **Abort running jobs:** `Setup → Apex Jobs` → Abort; or `System.abortJob(jobId)`.
2. **Kill writes immediately:** deactivate all `OA_Field_Write_Policy__mdt` (no active policy ⇒ writer
   produces no WRITE outcomes even if a connector runs).
3. **Cut callouts:** disable connectors in the registry, and/or revoke the SAM EC principal access.
4. Confirm dormant: `SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%Enrichment%'` = 0.

## Credential rotation
- **SAM (data.gov key):** rotate in `Setup → Named/External Credentials → OA_SAM` (update the `X-Api-Key`
  Custom Header on the External Credential). Never commit keys; secrets live only in the EC. Re-run a smoke
  test after rotating. Rotate immediately if a key is ever exposed in logs/screens.
- **Census/SEC:** public (no secret) — only the endpoint/User-Agent matter.
- **EC principal access** is granted **JIT** at go-live and revoked when not actively enriching.

## Recovery (after a failed run)
1. Read the run: `OA_Connector_Run__c` (`Status__c`, `HTTP_Errors__c`, `Messages__c`) for the failed `Run_ID__c`.
2. Triage by cause: auth → rotate/re-grant; endpoint/rate-limit → wait/back off, lower batch size; parse →
   connector issue (log, do not auto-retry).
3. Re-run only the affected scope (`OA_EnrichmentQueueable` with the specific Lead Ids), `commitWrites=false`
   first, then `true`.

## Rollback
- Every write has a `Before_Snapshot__c` on `OA_Enrichment_Change_Log__c`. To revert a run:
  `OA_ChangeLogService.rollback(<logs for that Run_ID>)` — restores prior field values and logs the reversal
  (`Change_Type__c='Rollback'`). Proven on the Sprint-16 canary + 5-Lead pilot (5/5 restored).
- Audit is retained after rollback (logs are not deleted).

## Routine checks
**Daily:** Executive + Platform Health dashboards; any `Status__c='Failed'`; open exception count/age;
any unexpected rollback. **Weekly:** success-rate & duration trend per connector; exception queue worked
down; API-usage headroom; credential expiry. **Monthly:** rotate SAM key (or per policy); review batch sizes
vs `PERFORMANCE_VALIDATION.md`; confirm runtime permset still assigned; revisit the least-privilege runtime
user (retire the `oauser`/MAD exception when a license is available — top standing risk).

## Operational learnings (Sprints 23–24)
- **Callout ordering (critical):** make the connector callout(s) **before any DML** in the transaction. Doing DML (e.g. inserting the run record) first triggers `CalloutException: uncommitted work pending` — every callout then fails with `lastStatus=null`. Pattern: collect all fetch results first, then insert run + `enrich(commit=true)`. (This — not rate limiting — was the Sprint-22 blocker.)
- **Batch sizing:** ~50 Leads per transaction is safe (50 callouts < 100 limit; ~25 ms CPU/Lead; DML < 150 stmts). USASpending latency ~150 ms/callout.
- **RESOLVED (Sprint 25):** `Awarding_Agencies__c` is now **Long Text Area(32768)** (was Text 255) — multi-agency contractors no longer overflow. And `OA_EnrichmentWriter` now **inspects `Database.SaveResult`**: a failed write routes an exception and never leaves misleading audit. See `SPRINT25_PRODUCTION_HARDENING.md` / `PRODUCTION_CERTIFICATION.md`.

## Guardrails (always true)
- No live enrichment until credentials + a passing pilot; connectors dormant by default.
- `commitWrites=false` for the first cycle of any new schedule/scope.
- Runtime FLS permset stays assigned; the Automation permset stays unassigned until a least-priv user exists.
