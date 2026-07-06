# Grants.gov Opportunity Connector — Runbook (DORMANT)

_Last updated: 2026-07-06 · Status: dormant foundation (source only; no live callouts; no secret stored)_

The Grants.gov connector is **built and dormant**. It performs **no callouts** and is invoked
by nothing. It becomes usable only after a separately-gated live-callout verification and, later,
a controlled invocation surface are approved.

## What this connector is (read first)

Grants.gov returns **funding opportunities** (Notices of Funding Opportunity) — titles, agencies,
CFDA/ALN numbers, open/close dates, status — **not company/firmographic data**. It is therefore an
**opportunity-signal** source (outreach-timing intelligence), classified as such in
[`LEAD_GEN_ENRICHMENT_OPERATING_MODEL.md`](LEAD_GEN_ENRICHMENT_OPERATING_MODEL.md) (priority 5,
"Signal — neither gen nor enrich").

- Results land in **`OA_Grants_Opportunity_Staging__c`**, an opportunity-signal object — **not** a
  Lead-firmographic staging object.
- There is **NO Lead write-back**. `Lead__c` is an optional *loose* association set only later by a
  reviewed, human-approved match (e.g. by NAICS/keyword). It stays blank in this dormant foundation.
- Every row lands `Review_Status__c = 'Pending'`; nothing is acted on without human review
  (ADR-005 review gate; ADR-008 rule #5 — no automatic write-back).

## Components
- Apex (on the connector SDK): `OA_GrantsConnector`, `OA_GrantsRequest`, `OA_GrantsParser`,
  `OA_GrantsMapper` (+ `OA_GrantsConnector_Test`, mock-only).
- Staging object: `OA_Grants_Opportunity_Staging__c` (22 fields; `Review_Status__c` defaults `Pending`;
  `Dedupe_Key__c` External Id + Unique for idempotent upsert).
- Credential: **Named Credential `OA_Grants`** — `https://api.grants.gov`, `NoAuthentication`,
  `Anonymous`. **No External Credential, no API key, no secret.**
- Permission set: `OA_Grants_Connector` (staging CRUD + FLS; **unassigned**).

## Authentication
- The Grants.gov **Search2 REST API** (`POST /v1/api/search2`) is **public and keyless** — no API
  key, no OAuth, no Authorization header. This is why Grants.gov is a low-risk next connector.
- Because there is no secret, there is **no External Credential** and nothing to rotate or custody.
- **Verify before first live callout** (currently out of scope / dormant): confirm the endpoint,
  path, request body shape, and that no key is required, with one read-only check against
  `https://api.grants.gov/v1/api/search2`.

## Request shape (built by `OA_GrantsRequest`)
- `POST callout:OA_Grants/v1/api/search2`, `Content-Type: application/json`.
- Body: `{ "keyword": <input>, "oppStatuses": "posted", "rows": 10, "startRecordNum": 0 }`.
- `oppStatuses` and `pageSize` (rows, clamped 1–25) are overridable via the run context config.
- Defaults to **open (`posted`) opportunities** — the outreach-timing signal.

## Idempotency, pagination, data quality
- **Dedupe:** `Dedupe_Key__c` = `Source_Run_ID__c` + "|" + `Opportunity_Number__c` (falls back to
  opportunity id). External Id + Unique → re-runs upsert, not duplicate.
- **Pagination:** Search2 supports `rows` + `startRecordNum`. v1 uses a small single page; bulk/paged
  retrieval is deferred to a future Queueable.
- **Traceability:** `Source_Payload_Ref__c` stores a **SHA-256 hash** of identity fields, never the
  raw payload. All fields are length-abbreviated on map.
- **Errors:** non-2xx and parse failures are recorded (`HTTP_Status__c`, run messages), never silently
  swallowed; one bad input never aborts the run (SDK engine behavior).

## Gates before any live Grants.gov callout (all deferred / dormant today)
1. Confirm the public Search2 endpoint + response shape with one read-only check.
2. Build a controlled invocation surface (mirror `OA_USASpendingEnrichmentService`) — gated.
3. Assign `OA_Grants_Connector` permission set to a run user (JIT); no External Credential access is
   needed (public API).
4. Client-side daily cap + monitoring + stop thresholds for any scheduled/bulk run.
5. Any Lead association remains a separate, human-reviewed step — never automatic.

Until these gates pass, the connector stays dormant: no callouts, no persistence, no scheduler,
no Lead writes.
