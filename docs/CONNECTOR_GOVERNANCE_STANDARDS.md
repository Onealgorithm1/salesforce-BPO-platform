# Connector Governance Standards (Deliverable 6)

_Status: **DESIGN ONLY — for review** · 2026-07-06. Binding on **every** future connector once ratified
(ADR-011). Extends ADR-005 and ADR-008._

A connector may not move from Draft → Active in the registry until it satisfies **every** standard
below. This is the connector-level "Definition of Ready" (complements ADR-010).

---

## 1. Security
- **Named Credential for every callout** — including public no-auth endpoints (declared with no
  External Credential), per ADR-005/008. No raw `new Http()` to a hardcoded URL. No Remote Sites.
- **FLS/CRUD enforced** — persistence and any read of source fields runs `WITH USER_MODE` /
  `stripInaccessible`. Do **not** rely on Modify All Data (it bypasses FLS — a known finding from the
  write-back canary).
- **Least privilege** — access via a per-connector permission set (staging CRUD only; no
  Delete/ViewAll/ModifyAll), assigned **JIT** to a non-admin runtime user; unassigned at rest.
- **No CRM write from a connector** (ADR-008 #5). Connectors reach staging only.

## 2. Secrets
- Secrets live **only** in External Credentials, entered in Setup, never in repo/objects/logs.
- `externalCredentials/` is **git-ignored** (repo policy) — the primary leak safeguard. Named
  Credentials (tracked) hold endpoint + EC reference only.
- Keys are sent as **headers** (e.g. `X-Api-Key`), never as URL query params (avoids log exposure).
- **Rotation** documented per connector: regenerate at source → update in Setup → revoke old. No code
  change. If a key is ever exposed in plaintext (temp file, chat), **rotate** as precaution.

## 3. Logging
- Every run writes an `OA_Connector_Run__c` (counts, status, endpoint, initiating user, messages).
- **Never log** secrets, full response bodies, or PII. Store a **SHA-256 payload reference**, not the
  raw payload.
- Errors are structured (category + message), surfaced to the run summary, never silently swallowed.

## 4. Retry behavior
- Declared per connector in the registry (`Retry_Policy__c`, e.g. `exp-backoff:3`).
- **Exponential backoff** with jitter; **max attempts** capped (default 3). Retries only on transient
  classes (429, 5xx, timeout) — never on 4xx auth/validation errors.
- Retries are **idempotent** (upsert on External Id), so a retry can never duplicate a row.

## 5. Error handling
- **Record-not-throw:** a non-2xx or parse failure is recorded and the run continues (one bad input
  never aborts the batch) — the SDK engine already enforces this.
- Partial success (`allOrNone = false`); per-row outcomes captured on the staging row
  (`HTTP_Status__c`, `Error_Message__c`, `Gate_Results__c`).
- Failed rows are **retained for diagnosis**, not discarded.

## 6. Rate limiting
- Per-connector client-side cap (`Rate_Limit_Per_Min__c`) enforced by a shared governor (reuse the
  `OA_SendGovernor` pattern). Respect each source's published limit (SEC ≤10/s, NIH ~1/s, SBIR
  sensitive).
- Honor `Retry-After` on 429. Bulk/paged runs are async (Queueable/Batch) **and separately gated** —
  no scheduler is created by declaring a refresh interval.

## 7. API versioning
- Pin the source API version in the endpoint path (e.g. `/v3/entities`); record it in the registry
  `Version__c`/`Notes__c`.
- A source's breaking version change is a connector version bump + re-test, tracked in
  `TECHNICAL_DEBT.md`; old version deprecated per §9.

## 8. Source ownership
- Every connector has an accountable **Owner/Steward** (registry `Owner_Steward__c`) responsible for
  the credential, quirks, quota, and review-queue health.

## 9. Deprecation
- Lifecycle: **Draft → Active → Deprecated → Retired** (registry `Status__c`).
- Deprecated = still readable, no new runs; Retired = `Enabled__c = false`, connector classes kept for
  history or removed via a tracked change. Data is superseded, never silently deleted.

## 10. Testing
- Mock harness (`OA_ConnectorMock`); **no live callout in tests**, ever.
- **≥75% coverage** on the connector surface; must cover success, empty, missing-key, non-2xx, and
  malformed-response paths, and assert **no DML / no secret in URL**.
- Check-only validation against prod (RunLocal/SpecifiedTests) before any deploy.

## 11. Documentation
- Each connector ships: a **runbook** (`docs/<SOURCE>_CONNECTOR_RUNBOOK.md`), a **registry row**, and,
  if it introduces an architectural pattern, an **ADR**.
- Added to `METADATA_REGISTRY.md` (ADR-009) on build; roadmap status updated.

---

## Connector "Definition of Ready" checklist (all required before Active)
```
[ ] Named Credential declared (secret-free); External Credential in Setup if authenticated
[ ] Permission set (staging-only, least privilege), unassigned at rest
[ ] Request/Parser/Mapper + staging object follow the standard field contract
[ ] Dedupe_Key (ExtId/Unique) + Canonical_Key mapping defined
[ ] Retry + rate-limit policy set in registry
[ ] Tests ≥75%, all negative paths, no live callout, no-DML asserted
[ ] Runbook + registry row + METADATA_REGISTRY entry
[ ] Owner/steward assigned
[ ] Check-only validated; dormant (Enabled=false) until activation gate
```
