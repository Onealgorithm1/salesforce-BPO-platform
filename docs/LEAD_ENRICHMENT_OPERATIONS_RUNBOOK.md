# Lead Enrichment Platform — Operations Runbook

_Status: **operational procedures for when the platform is activated** · 2026-07-06. The platform is
dormant today; these are the standing procedures for controlled operation._

## Daily monitoring (start of day)
1. **Runs:** `OA_Connector_Run__c` for the last 24h — check `Status__c` (Succeeded / PartialErrors /
   Failed), per-connector counts, durations.
2. **Exceptions:** open `OA_Enrichment_Exception__c` (`Status__c = Open`) — triage the 4 types.
3. **Writes:** `OA_Enrichment_Change_Log__c` volume + any `Reversible__c = false` (should be zero).
4. **Tripwire (must be zero):** writes without a snapshot; below-floor writes; writes to non-trusted
   fields; rollback failures. Any > 0 → **emergency shutdown** (below).

## Connector failures
| Symptom (on `OA_Connector_Run__c`) | Likely cause | Action |
|---|---|---|
| `HTTP_Errors__c` > 0, status 401/403 | Credential/key or EC principal access | Verify NC/EC; re-grant EC access; rotate key if needed |
| `HTTP_Errors__c` > 0, status 429 | Rate limit | Back off; reduce batch; honor `Retry-After` |
| `HTTP_Errors__c` > 0, status 5xx / timeout | Source outage | Retry later; do not hammer |
| `Parse_Errors__c` > 0 | Source schema change | Inspect payload; update the connector's Parser (connector-only fix) |
| `Unresolved` status | Registry class name wrong / class missing | Fix `OA_Connector_Registry.<src>.Connector_Class__c` |
| `Skipped` status | `Enabled__c = false` | Expected when dormant; enable deliberately |

## Retry procedures
- Retries are **idempotent** (upsert on external id / canonical key) — a retry never duplicates.
- Transient classes only (429, 5xx, timeout); never retry 4xx auth/validation.
- Exponential backoff with jitter; cap attempts (registry `Retry_Policy__c`). Re-invoke the runner for
  the same input; the change log + dedupe make re-runs safe.

## Emergency shutdown (kill switch)
1. Set the offending `OA_Connector_Registry.<src>.Enabled__c = false` (dispatcher skips it) — or all.
2. Revoke JIT permission-set assignments from the runtime user (stops writes immediately).
3. If a bad batch wrote data: `OA_ChangeLogService.rollback(<affected logs>)` to restore snapshots.
4. Record the incident; do not re-enable until root cause is fixed.

## Recovery
1. Fix root cause (connector parser, credential, rule, or field policy).
2. Re-validate (check-only) the fix; confirm coverage.
3. Re-enable one connector; run a small canary input; verify `OA_Connector_Run__c` clean + tripwires 0.
4. Scale up gradually; monitor duration/throughput.

## Connector health (weekly)
- Success rate per connector (Succeeded / total runs).
- p50/p95 duration (from `Started__c`/`Ended__c`).
- Exception rate + open-exception age.
- Schema drift: any new `Parse_Errors__c` trend → connector parser review.
- Credential expiry (SAM registration/key), User-Agent still valid (SEC).

## Exception handling (the only routine human work)
Resolve `OA_Enrichment_Exception__c` by type:
- **LowConfidenceMatch** — confirm/reject the entity match; feed back to strengthen rules.
- **SourceConflict** — decide which source value wins (source precedence guides); apply or reject.
- **DuplicateMerge** — approve/reject a non-deterministic merge.
- **PolicyException** — a field flagged for review or a type mismatch; adjust policy or data.
Set `Status__c = Resolved` (+ `Resolved_By__c`/`Resolved_At__c`). Everything deterministic is automatic.
