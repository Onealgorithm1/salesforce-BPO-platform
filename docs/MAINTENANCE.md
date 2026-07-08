# Lead Enrichment — Maintenance Mode

_Engineering complete. This is the standing operations reference. For deeper detail see
`OPERATIONS_GUIDE.md`, `LEAD_ENRICHMENT_MONITORING.md`, `DML_SCALABILITY_FIX.md`._

## Current State
- **Production Org:** `00Dbn00000plgUfEAI`
- **Current release:** `lead-enrichment-v1.2` (tag commit `f4894e9`; deploy `0AfPn0000023Kx7KAE`)
- **Supported connectors:** USASpending (live-proven), Census, SEC (NCs live HTTP 200); SAM (prod key,
  JIT principal grant required); IRS, StateRegistry (dormant scaffolding). All disabled by default.
- **Runtime model:** temporary MAD `oauser` (see `RUNTIME_USER_EXCEPTION.md`) — top standing risk;
  replace with a least-privilege user when a license is available. All writes go through the policy
  engine (FillEmptyOnly) + audit; nothing bypasses it.
- **Dormant model:** kill switch = disable connectors (`OA_Connector_Registry__mdt.Enabled__c=false`)
  + deactivate policies (`OA_Field_Write_Policy__mdt.Active__c=false`). Dormant = 0 enabled connectors,
  0 active policies, 0 enrichment cron, 0 running jobs.

## Daily Operations
- Run the Claude audit: `scripts/shell/daily_enrichment_audit.sh` → PASS / WARN / FAIL.
- Review open exceptions (conflict/error queue) and work them down.
- Review connector status (any run `Status=Failed` / `PartialErrors`).
- Verify dormant state after any run.

## Weekly Operations
- Review throughput (fields written/day, Leads enriched).
- Review rollback health (every write has `Before_Snapshot__c`, `Reversible__c=true`).
- Review API status (HTTP-error trend vs baseline; credential expiry).
- Review connector health (success rate + latency per source).

## Monthly Operations
- Salesforce release review (seasonal platform release impact).
- API compatibility review (connector endpoints/response shapes unchanged).
- Performance review (DML/CPU headroom; batch sizes vs `PERFORMANCE_VALIDATION.md`).

## Recovery
- **Pause enrichment:** delete the scheduled job(s); set `Enabled__c=false`; set `Active__c=false`.
- **Resume enrichment:** re-enable the target connector + intended policies; run a 1-Lead canary
  (`commitWrites=false` then `true`) before any scope.
- **Rollback:** `OA_ChangeLogService.rollback(<logs for the Run_ID>)` restores prior values and logs
  the reversal; audit is retained.
- **Verify dormant:** `daily_enrichment_audit.sh` (dormant line) or
  `SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%nrich%'` = 0.

## Engineering Reopen Criteria
Reopen Lead Enrichment engineering **only** for:
- a production defect,
- a Salesforce platform change,
- a connector API change,
- a security issue,
- a governor-limit regression.

**No feature requests belong in Lead Enrichment.** New capabilities are a separate program.
