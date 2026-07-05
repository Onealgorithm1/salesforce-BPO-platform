# SAM.gov Entity Connector — Runbook (Phase 2, DORMANT)

_Last updated: 2026-07-05 · Status: dormant foundation (source only; no live callouts; no key stored)_

The SAM.gov Entity connector is **built and dormant**. It performs **no callouts** and is
invoked by nothing. It becomes usable only after the data.gov API key is provisioned and
access is granted, each a separately-gated step.

## Components
- Apex (on the connector SDK): `OA_SAMConnector`, `OA_SAMRequest`, `OA_SAMParser`,
  `OA_SAMMapper` (+ `OA_SAMConnector_Test`, mock-only).
- Staging object: `OA_SAM_Entity_Staging__c` (human-review-gated; `Review_Status__c` defaults `Pending`).
- Credential shell: **External Credential `OA_SAM`** (Custom auth, Named Principal, `X-Api-Key`
  AuthHeader) + **Named Credential `OA_SAM`** (`https://api-alpha.sam.gov`, references the EC).
- Permission set: `OA_SAM_Connector` (staging CRUD + FLS; **unassigned**).

## Authentication (verified against official GSA docs, open.gsa.gov/api/entity-api)
- SAM.gov Entity API **requires a data.gov API key**, obtained from a SAM.gov account.
- The key is sent as an **`X-Api-Key` HTTP header** (injected by the External Credential), **not**
  as an `api_key=` URL parameter — so the key never appears in a URL, log, or this repository.
- Endpoint: `https://api.sam.gov/entity-information/v3/entities` (production) /
  `https://api-alpha.sam.gov/...` (alpha/test — used first).
- Rate limits by account tier (e.g. system account 10,000/day). No OAuth.

## Key custody — NEVER commit a real key
- **`externalCredentials/` is git-ignored by repo policy** (`.gitignore`: "External Credential
  metadata — contains live secrets"). The `OA_SAM` External Credential is therefore a **local-only
  template** and is **never committed** — this is the primary safeguard against a key leak.
- The local `externalCredentials/OA_SAM.externalCredential-meta.xml` `X-Api-Key` value is a
  **placeholder** (`PLACEHOLDER_ENTER_REAL_KEY_IN_SETUP_NEVER_COMMIT`), not a real key.
- The **real key is entered by the custodian in Salesforce Setup** (Named Credentials → External
  Credentials → OA_SAM → Principal → edit the `X-Api-Key` value). It is stored **encrypted in the
  org** and is never retrievable as metadata.
- Because the directory is git-ignored, a `sf project retrieve` of the EC cannot be accidentally
  committed — but still never paste a real key into any committed file (e.g. the Named Credential,
  which IS tracked and must stay secret-free).
- The **Named Credential `OA_SAM`** (`namedCredentials/`, tracked) holds only the endpoint + a
  reference to the External Credential. It is deployed at the key-provisioning gate, after the
  `OA_SAM` External Credential exists in the org (created/edited in Setup).

## Rotation
Regenerate the key in the SAM.gov account, update the `X-Api-Key` value in Setup, then revoke the
old key. No code change or deploy is needed.

## Gates before any live SAM.gov callout
1. data.gov API key obtained (custodian). 2. Custodian/owner identified. 3. Key entered in Setup
(not repo). 4. `OA_SAM_Connector` permission set + External Credential **principal access** granted
to a **non-admin least-privilege run user** (JIT). 5. Alpha smoke test first, then production URL.
6. Client-side daily cap + monitoring + stop thresholds. 7. Non-admin runtime user / license
blocker resolved (same as Lead Write-Back). Until all gates pass, the connector stays dormant.
