# Connector Developer Guide

_How to add an enrichment connector to the Lead Enrichment Platform. Goal: connector #20 is as
straightforward as connector #1. SAM.gov (Phase 8) is the reference implementation._

The platform (Phase 7 foundation) is connector-agnostic. A connector supplies ONLY source-specific
logic in four classes + metadata; it never modifies the platform engines. Since Phase 9, connectors
are **dispatched generically** by `OA_ConnectorRunner` from `OA_Connector_Registry__mdt` — there is no
per-connector orchestration to write and no `if source == …` anywhere.

---

## 0. How dispatch works (Phase 9 — generic connector framework)

Every connector implements one interface and is run by one dispatcher:

- **`OA_IEnrichmentConnector`** — `sourceKey()` + `fetch(input, cfg) : OA_ConnectorResult`. Source-agnostic.
- **`OA_ConnectorRunner`** — reads the registry, resolves the connector class via `Type.forName`,
  runs the identical lifecycle, and captures timing + telemetry. It knows nothing about any source.
- **`OA_ConnectorResult`** — the standard result (canonical orgs + fetch counts) every connector returns.

Lifecycle (identical for all connectors):
```
Initialize → Execute Request → Receive Response → Parse → Map →
Return Canonical Organizations → Invoke existing platform → Collect metrics → Complete
```

### Sequence — Registry → Dispatcher → Connector → Canonical → Platform
```
Caller                 OA_ConnectorRunner         OA_Connector_Registry__mdt      OA_<Src>_Connector          Platform engines
  │  run(sourceKey,input,ruleset)                         │                              │                          │
  ├──────────────►│                                       │                              │                          │
  │               │  read registry record ───────────────►│                              │                          │
  │               │◄── cfg (class, enabled, version) ──────┤                              │                          │
  │               │  if !Enabled → Skipped (stop)          │                              │                          │
  │               │  Type.forName(cfg.Connector_Class__c).newInstance()  ───────────────► │  (dynamic resolve)       │
  │               │  fetch(input, cfg) ─────────────────────────────────────────────────►│                          │
  │               │                                        │   Request→send→Parser→OA_CanonicalOrg[]                 │
  │               │◄─────────────────── OA_ConnectorResult (canonical orgs) ──────────────┤                          │
  │               │  for each org: DiscoveryQualificationEngine.evaluate(org, ruleset) ─────────────────────────────►│
  │               │◄──────────────────────────── qualified / rejected ────────────────────────────────────────────┤
  │               │  build telemetry → OA_Connector_Run__c (in-memory) + RunOutcome        │                          │
  │◄── RunOutcome (orgs + metrics + timing) ──────────────┤                              │                          │
```
(Field-write enrichment via `OA_<Src>_Mapper` → `OA_EnrichmentWriter` runs downstream, per matched Lead.)

---

## 1. What you build (per connector)

| Class | Responsibility | Reference |
|---|---|---|
| `OA_<Src>_Request` | Build the `HttpRequest`; read endpoint/Named Credential from the registry (no hardcoding); never put a secret in the URL. | `OA_SAM_Request` |
| `OA_<Src>_ResponseParser` | Owns the source JSON shape; returns `List<OA_CanonicalOrg>`; tolerant of additive changes; throws a typed `ParseException` on malformed input. | `OA_SAM_ResponseParser` |
| `OA_<Src>_Mapper` | Map `OA_CanonicalOrg` → `List<OA_EnrichmentWriter.FieldProposal>` (source→CRM field mapping). Never propose null/blank values. | `OA_SAM_Mapper` |
| `OA_<Src>_Connector` | Orchestrate request → send (`new Http().send`, mockable) → parse; read config from the registry; expose a dormant, debug-gated raw-payload option. | `OA_SAM_Connector` |

**Do NOT put source logic in** the platform: `OA_FieldWritePolicyEngine`, `OA_QualificationRuleEngine`,
`OA_ConfidenceEvaluator`, `OA_SourcePrecedenceEngine`, `OA_EnrichmentWriter`,
`OA_DiscoveryQualificationEngine`, `OA_ChangeLogService`, `OA_ExceptionRoutingService`,
`OA_CanonicalOrg`, `OA_NameNormalizer`. If you think you must, you've found a platform gap — stop and
raise it (see §9), don't special-case a connector inside the engines.

## 2. Required metadata (registration — no hardcoding)

Add records to these CMDTs (all default **dormant**: `Enabled__c=false`, `Active__c=false`, `Status=Draft`):

- **`OA_Connector_Registry__mdt`** — one record: `Source_System__c`, `Connector_Class__c`,
  `Parser_Class__c`, `Mapper_Class__c`, `Named_Credential__c`, `Endpoint_Path__c`, `Category__c`,
  `Dedupe_External_Id_Field__c`, `Enabled__c=false`, `Review_Required__c=true`, `Owner_Steward__c`.
- **`OA_Enrichment_Source__mdt`** — one record: `Source_System__c`, `Precedence__c` (lower = higher
  trust), `Trusted__c`, `Authoritative_For__c`, `Active__c=false`.
- **`OA_Enrichment_Pipeline__mdt`** — the ordered steps (Ingest → Qualify → Write) pointing at your
  connector + the platform engines, `Enabled__c=false`.
- **`OA_Field_Write_Policy__mdt`** — one record per CRM field you enrich: `Target_Object__c`,
  `Target_Field__c`, `Source_System__c`, `Write_Mode__c` (FillEmptyOnly / Overwrite / Never),
  `Confidence_Floor__c`, `Conflict_Behavior__c`, `Trusted__c`, `Active__c=false`.
- (Discovery) **`OA_Qualification_Rule__mdt`** — ICP rules for your ruleset, `Active__c=false`.

## 3. Registration process
1. Write the four classes (copy the SAM set as a template).
2. Map the source into `OA_CanonicalOrg`: identity fields (uei/cage/ein/cik/npi), firmographics, and a
   `attributes` bag for anything qualification rules reference by name (e.g. `Registration_Status`).
3. Add the CMDT records above (dormant).
4. Add tests (§6) and a runbook.
5. Check-only validate. Commit. **Nothing is enabled** until a separate, gated activation.

## 4. Parser guidelines
- Use `JSON.deserializeUntyped` — additive/unknown fields are ignored automatically.
- Missing/optional sections → null fields, never a crash; missing result set → empty list.
- Malformed body → throw your typed `ParseException` (the connector records it as a parse error).
- **Never fabricate.** If the source doesn't return a value (e.g. SAM entity sections omit NAICS,
  Exclusion Status, Phone), leave it null and document it as unavailable.
- Set `sourceConfidence`: a deterministic identifier (UEI/EIN/NPI/CIK/CAGE) → `HIGH`; name-only → `MEDIUM`.
- Stamp `sourceSystem` and `sourcePayloadHash` (`org.payloadHash()`).

## 5. Mapper guidelines
- Emit a `FieldProposal(field, value, sourceSystem, confidenceBand)` only when the value is present.
- The mapper decides *which CRM field* a source value maps to; the **write policy** decides *whether/how*
  it is written. Keep those concerns separate.

## 6. Confidence & error handling
- Confidence banding is platform logic (`OA_ConfidenceEvaluator`): exact identifier → HIGH is the only
  auto-write-eligible band. Don't re-implement it per connector.
- The connector records — never swallows — non-2xx (httpError), parse failures (parseError), and
  callout/credential exceptions (httpError + message). One bad input never aborts a batch.
- Conflicts (fill-empty on a populated field) and low-confidence/merge/policy cases route to
  `OA_Enrichment_Exception__c` via the platform — you get this for free.

## 7. Raw payload (troubleshooting)
Expose a `@TestVisible private static Boolean debugStoreRawPayload = false`. Populate the raw body only
when it is true. It must be **off by default and never enabled automatically** (a debug config/operator
turns it on deliberately).

## 8. Testing requirements (≥90% coverage on new classes)
- **Request:** endpoint routes through the Named Credential + registry path; correct method; **no key in
  the URL**.
- **Parser (contract tests):** expected fields/identifiers exist; additive/unknown fields tolerated;
  missing sections graceful; malformed → typed exception; canonical mapping correct; unavailable fields
  are null.
- **Mapper:** proposals produced for present values; nulls not proposed; source + confidence propagated.
- **Connector:** mocked success (`Test.setMock(HttpCalloutMock.class, ...)`), non-2xx, malformed,
  thrown callout; raw payload off/on; config resolved via registry override AND via query.
- **Integration:** prove the connector's canonical output flows through the UNCHANGED platform
  (policy invocation, qualification invocation, exception routing). This is the real proof of reuse.
- Never make a live callout in a test.

## 9. Common pitfalls
- **Enum refs inside an inner class** must be fully qualified: `OuterClass.Enum.VALUE`.
- **Check-only validation does not materialize new custom objects** — assert on in-memory results and
  standard objects (Lead), not on new-object persistence.
- **CMDT records + their type in the same check-only transaction** throw an opaque `UNKNOWN_EXCEPTION` —
  validate types+classes and hold the records for the deploy step (they still live in source).
- **Named-Principal callouts need External Credential principal access** (a permission-set deploy) — MAD
  does not substitute. Live calls are gated on that; keep the connector dormant until then.
- **Don't put a key in a URL** — inject it as a header via the External Credential.
- **Don't fabricate** values the source didn't return.

## 10. Checklist
```
[ ] OA_<Src>_Request / ResponseParser / Mapper / Connector written
[ ] Canonical mapping (identity + attributes bag), unavailable fields left null + documented
[ ] Registry + Source + Pipeline + Field-Policy CMDT records added (all dormant)
[ ] Tests: request, parser contract, mapper, connector (mock), integration — ≥90%
[ ] Runbook written; BUILD_VS_BORROW updated if a decision changed
[ ] Check-only validated; committed; NOT deployed/enabled
```

## 11. Wave 1 reference connectors (Sprint 10)
Four built connectors show the pattern across ingestion styles — copy the closest one:
- **SAM.gov** — REST GET, JSON object → entity identity (UEI/CAGE).
- **USASpending** — REST **POST**, JSON object; parser **aggregates** awards per recipient into one org.
- **Census** — REST GET, JSON **array-of-arrays**; produces **context** records (no identity, `NONE`
  confidence) that enrich an existing org by geography/NAICS.
- **IRS Tax-Exempt** — **BULK** (EO BMF CSV): implements the same interface but makes **no HTTP call**;
  `fetch(input)` parses provided bulk content. Proves the framework is not REST-locked.

Non-REST or context sources need **no platform change** — only a different Parser/Mapper. See
`LEAD_ENRICHMENT_PLATFORM_SPEC.md` for the full connector matrix and entity-resolution notes.
