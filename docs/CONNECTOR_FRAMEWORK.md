# Connector Framework — Architecture & SDK Design

**Version:** 0.1 (Proposed)
**Date:** July 1, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Design for Sprint 1B. Governed by [ADR-005](decisions/ADR-005-connector-framework.md).

This document specifies the Connector SDK: the interfaces, base classes, data contracts,
and test scaffolding that every external-data connector implements. It is the design that
Sprint 1B builds and Sprint 1C migrates `OA_USASpendingClient` onto.

> **Scope note:** This is a design document, not code. No Apex is written until Sprint 1B is
> authorized. All type names are proposals subject to review at the Sprint 1B kickoff.

---

## 1. Design goals

Derived directly from the verified defects of the current `OA_USASpendingClient`
(see [ADR-005](decisions/ADR-005-connector-framework.md) Context):

1. **Every connector is invokable and wired** — no orphaned clients.
2. **Every connector persists to staging** with a human `Review_Status__c` gate before any
   Lead write-back.
3. **Every connector is testable** via a shared `HttpCalloutMock` harness (≥75% coverage).
4. **Every connector authenticates via Named Credential** — one callout path, rotatable creds.
5. **Every connector is idempotent** — re-running an enrichment run does not duplicate rows.
6. **Every connector respects governor limits** — bulk work runs async.

---

## 2. Lifecycle

```
                 ┌────────────────────────────────────────────────────┐
   input(s)  ─▶  │  build request  ─▶  execute callout  ─▶  parse DTO  │  ─▶ staging rows
 (e.g. Lead,     │   (per source)      (framework:          (per source)│    (pending review)
  search term)   │                      Named Credential)               │
                 └────────────────────────────────────────────────────┘
                                         │
                             capture run outcome (status, errors, correlation id)
```

- **Framework owns:** callout execution, Named Credential resolution, HTTP status/error
  handling, ret/pagination helpers, staging upsert, run correlation, and the test harness.
- **Each connector owns:** its request body, its response parsing, and its DTO→staging
  field mapping. Nothing else.

---

## 3. Proposed types (`force-app/`, Layer 1, `OA-Core-Platform`, API v67)

### 3.1 Contract interfaces

```
OA_IConnector
    // Identity + capability metadata for a source.
    String    sourceKey();              // e.g. 'USASpending', 'Census'
    String    namedCredential();        // e.g. 'callout:OA_USASpending'
    SObjectType stagingType();          // e.g. OA_USASpending_Staging__c.SObjectType

OA_IConnectorRequest
    // Builds the HttpRequest for a given input.
    HttpRequest build(OA_ConnectorContext ctx, Object input);

OA_IConnectorParser
    // Parses a raw response body into normalized rows for this source.
    List<OA_ConnectorRow> parse(String body);

OA_IConnectorMapper
    // Maps one normalized row to a staging SObject for this source.
    SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx);
```

A concrete connector (`OA_USASpendingConnector`, `OA_CensusConnector`, …) implements these
four small responsibilities. Everything else is inherited.

### 3.2 Framework engine

```
OA_ConnectorEngine        // orchestrates the lifecycle for any OA_IConnector
    OA_ConnectorRunResult run(OA_IConnector connector, OA_ConnectorContext ctx, List<Object> inputs);
    // - resolves Named Credential
    // - calls request.build → HTTP send (with timeout, status handling)
    // - calls parser.parse → mapper.toStaging
    // - stamps Enrichment_Run_ID__c, Source_Endpoint__c, HTTP_Status__c, Query_Date__c
    // - idempotent upsert into stagingType()
    // - returns per-input outcomes + aggregate

OA_ConnectorContext       // run-scoped values: correlation id, initiating user, config
OA_ConnectorRow           // normalized intermediate (Map<String,Object> + typed accessors)
OA_ConnectorRunResult     // counts: requested / staged / http-errors / parse-errors; details
OA_ConnectorHttp          // thin wrapper: send(req) with timeout + status logging (mockable)
```

### 3.3 Async + invocation wrappers

```
OA_ConnectorQueueable     // bulk enrichment as Queueable(callout=true), chained per governor limits
OA_ConnectorInvocable     // @InvocableMethod so Flows can trigger a single-record enrichment
OA_ConnectorSchedulable   // optional scheduled batch enrichment (mirrors OA_DripScheduler shape)
```

### 3.4 Test scaffolding

```
OA_ConnectorMock          // implements HttpCalloutMock; fixture-driven (status + body per endpoint)
OA_ConnectorTestBase      // helpers: build a connector, set the mock, assert staging rows
```

Because the framework ships `OA_ConnectorMock`, every connector test is a few lines: register
a fixture body, run the engine, assert the staging rows and run result. This is what makes
the ≥75% coverage gate reachable for every connector from day one.

---

## 4. Staging contract

Every source has an `OA_<Source>_Staging__c` object. The framework requires these
**framework-managed fields** on each staging object (USASpending already has all of them):

| Field | Purpose |
|-------|---------|
| `Enrichment_Run_ID__c` | Correlates all rows produced by one run (idempotency key part 1). |
| `Source_Endpoint__c` | The endpoint/path that produced the row (audit). |
| `HTTP_Status__c` | Response status; non-2xx rows are retained for diagnosis. |
| `Query_Date__c` | When the row was fetched. |
| `Review_Status__c` | **Human gate.** No write-back to `Lead` until a reviewer advances this. |
| `Lead__c` | The Lead the enrichment is for (nullable for search-only rows). |
| `Notes__c` | Free-text error/diagnostic capture. |

Source-specific fields (e.g. USASpending's `Award_ID__c`, `Recipient_UEI__c`,
`Award_Amount__c`) are declared per object and populated by that connector's mapper.

**Idempotency key:** `Enrichment_Run_ID__c` + the source's external id (e.g. `Award_ID__c`
for USASpending). Re-running a run upserts rather than duplicates.

---

## 5. Reference implementation — USASpending (Sprint 1C)

The current `OA_USASpendingClient` already contains the source-specific logic; Sprint 1C
re-homes it onto the framework rather than rewriting it:

| Current (`OA_USASpendingClient`) | Framework home |
|----------------------------------|----------------|
| Hardcoded `ENDPOINT` + `new Http().send()` + Remote Site `OA_USASpending` | `namedCredential()` → `callout:OA_USASpending`; send via `OA_ConnectorHttp` |
| `buildBody(recipientName, lim)` | `OA_USASpendingConnector` request builder (`OA_IConnectorRequest`) |
| `parse(body)` → `List<AwardResult>` | `OA_IConnectorParser` → `List<OA_ConnectorRow>` |
| `AwardResult` DTO fields | mapper → `OA_USASpending_Staging__c` (fields already exist) |
| *(missing)* persistence | `OA_ConnectorEngine` idempotent upsert into staging |
| *(missing)* caller | `OA_ConnectorInvocable` (Flow) + `OA_ConnectorQueueable` (bulk) |
| *(missing)* test | `OA_USASpendingConnector_Test` via `OA_ConnectorMock` |
| API v61 | API v67 |

Field mapping (existing staging fields → source data):
`Award_ID__c`, `Recipient_Name__c`, `Recipient_UEI__c`, `Award_Amount__c`,
`Awarding_Agency__c`, `Awarding_Sub_Agency__c`, `Contract_Type__c`,
`Performance_State__c`, `Award_Description__c`, plus `Search_Term__c`.

**Auth migration:** create Named Credential `OA_USASpending` (Url
`https://api.usaspending.gov`, no External Credential — public API). Remote Site
`OA_USASpending` is retired once the connector no longer uses raw `Http`.

---

## 6. Second implementation — Census (Sprint 2, forward-looking)

The US Census Bureau API (`https://api.census.gov/data/...`) is a public endpoint (optional
API key). It validates the framework against a second shape:

- **Named Credential:** `OA_Census` (Url `https://api.census.gov`; API key, if used, via
  External Credential — this exercises the authenticated path the public USASpending case
  does not).
- **New staging object:** `OA_Census_Staging__c` with the seven framework-managed fields +
  Census-specific fields (geography, variable codes, values).
- **Connector:** `OA_CensusConnector` implementing the same four interfaces.

Any interface changes the Census work reveals are decided at the **Sprint Review gate**
before Sprint 2 code, per ADR-005.

---

## 7. What Sprint 1A does NOT decide

- Exact method signatures and field-level mapping details — finalized at Sprint 1B kickoff.
- Retry/backoff policy specifics — designed in 1B against real USASpending behavior.
- Whether Census uses an API key — confirmed at Sprint 2 planning.

These are listed so the design's open edges are explicit rather than assumed.

---

## Related documents

- [ADR-005 — Connector Framework](decisions/ADR-005-connector-framework.md)
- [Connector Framework Roadmap](CONNECTOR_FRAMEWORK_ROADMAP.md)
- [ADR-003 — Package Boundary Strategy](decisions/ADR-003-package-boundary-strategy.md)
- [Integration Registry](INTEGRATION_REGISTRY.md)
- [Technical Debt Register](TECHNICAL_DEBT.md)
