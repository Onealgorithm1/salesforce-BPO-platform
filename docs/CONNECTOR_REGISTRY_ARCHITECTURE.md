# Connector Registry Architecture (Deliverable 2)

_Status: **DESIGN ONLY — for review** · 2026-07-06. No Apex or metadata is built here._

Goal: let the Connector SDK **discover** connectors from **metadata** instead of hardcoded `new
OA_XConnector()` calls, so adding a source is a metadata declaration + the four SDK classes, not an
edit to a central switch statement.

---

## 1. Two-part registry (why not one)

A registry has two kinds of data with different lifecycles:

| Kind | Example fields | Lifecycle | Storage |
|---|---|---|---|
| **Declaration** (static, deployable, versioned) | class names, endpoint, category, auth type, refresh interval, review-required | Changes by deploy | **`OA_Connector_Registry__mdt`** (Custom Metadata Type) |
| **Runtime state** (mutable, per-run) | last run, last status, records ingested, error counts, next-run-due | Changes every run | **`OA_Connector_Run__c`** (Custom Object) + a rollup |

Custom Metadata is the right home for *declarations* — it is cache-backed (no SOQL limits), deployable
across orgs, and versioned in source control. It **cannot** be written by Apex at runtime, so live
health/telemetry belongs in `OA_Connector_Run__c` (see object model). CMDT precedent already exists in
the repo (`OA_Graph_Config__mdt`).

---

## 2. `OA_Connector_Registry__mdt` — field design

| Field (API) | Type | Purpose |
|---|---|---|
| `DeveloperName` / `Label` | — | Registry key, e.g. `SAM`, `USASpending`, `Grants` |
| `Connector_Name__c` | Text | Human name ("SAM.gov Entity") |
| `Category__c` | Picklist | Entity / Opportunity / Contract / Relationship / Compliance / Market |
| `Enabled__c` | Checkbox | Master on/off for discovery (**default false = dormant**) |
| `Version__c` | Text | Connector semver, e.g. `1.0.0` |
| `Authentication_Type__c` | Picklist | None / ApiKey / OAuth / S2S |
| `Named_Credential__c` | Text | e.g. `OA_SAM` (the callout prefix, no secret) |
| `Endpoint_Path__c` | Text | Path appended to the Named Credential, e.g. `/entity-information/v3/entities` |
| `Staging_Object__c` | Text | e.g. `OA_SAM_Entity_Staging__c` |
| `Connector_Class__c` | Text | Apex class implementing `OA_IConnector`, e.g. `OA_SAMConnector` |
| `Parser_Class__c` | Text | Apex class implementing `OA_IConnectorParser` |
| `Mapper_Class__c` | Text | Apex class implementing `OA_IConnectorMapper` |
| `Dedupe_External_Id_Field__c` | Text | e.g. `Dedupe_Key__c` (idempotency key field) |
| `Refresh_Interval__c` | Picklist | OnDemand / Daily / Weekly / Monthly / Quarterly / Annual |
| `Retry_Policy__c` | Text/Picklist | e.g. `exp-backoff:3` (max attempts + strategy) |
| `Rate_Limit_Per_Min__c` | Number | Client-side cap (governor input) |
| `Review_Required__c` | Checkbox | **Default true** — human gate mandatory |
| `Status__c` | Picklist | Draft / Active / Deprecated / Retired (declared lifecycle) |
| `Owner_Steward__c` | Text | Accountable owner (name/email) |
| `Notes__c` | Long Text | Runbook link, quirks, known limits |

> **Safety defaults:** `Enabled__c = false`, `Review_Required__c = true`, `Status__c = Draft`. A newly
> declared connector is inert until someone deliberately flips `Enabled__c` **and** provisions any
> credential. Metadata alone never causes a callout.

---

## 3. Discovery flow (design, no code)

```
OA_ConnectorRegistry (new service)
  ├─ read all OA_Connector_Registry__mdt where Enabled__c = true          (cache-backed, no SOQL)
  ├─ for a requested sourceKey → find its declaration
  ├─ instantiate:  (OA_IConnector) Type.forName(Connector_Class__c).newInstance()
  │                (validates the class exists + implements the interface)
  └─ hand the connector + declaration to OA_ConnectorEngine.run(...)
```

- **Backward compatible.** Existing connectors (`OA_SAMConnector`, `OA_USASpendingConnector`,
  `OA_GrantsConnector`) already implement `OA_IConnector`. They gain a registry row; **no change to
  their code** and no change to `OA_ConnectorEngine`. The registry is an *optional discovery front
  door*, not a rewrite.
- **`Type.forName` guardrails.** If a class name is missing/misspelled or doesn't implement the
  interface, discovery fails **loudly at run start** (recorded on `OA_Connector_Run__c`), never
  silently. Enabled-but-unresolvable = configuration error surfaced to the owner.
- **No dynamic secrets.** The registry stores only the Named Credential *name* and endpoint *path* —
  never a key. Secrets stay in the External Credential (ADR-008).

---

## 4. What the registry deliberately does NOT do

- It does **not** schedule anything. `Refresh_Interval__c` is *declared intent*; a scheduler is a
  future, separately-gated component. Declaring "Daily" does not create a job.
- It does **not** enable callouts by itself. `Enabled__c = true` only makes a connector *discoverable*;
  a run is still an explicit, gated invocation.
- It does **not** replace `METADATA_REGISTRY.md` (ADR-009). That doc inventories *all committed
  metadata* for drift control; this CMDT declares *runnable connectors*. Different jobs, both kept.

---

## 5. Migration path (when approved, later)

1. Add `OA_Connector_Registry__mdt` (no rows enabled).
2. Add one row per existing connector with `Enabled__c = false`, `Status__c = Active`.
3. Add `OA_ConnectorRegistry` discovery service (+ tests) — pure read, no callout.
4. Optionally route the existing enrichment services through discovery.
5. Every new connector (SBIR, NIH, …) ships with its registry row from day one.

All steps additive and dormant; none activates a callout.
