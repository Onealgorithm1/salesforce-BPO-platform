# Lead Enrichment Foundation — Build Notes (Phase 7)

_Status: **BUILT — dormant, source only (check-only validated, not deployed)** · 2026-07-06._

The reusable, Salesforce-native platform layer that future connectors plug into. **Nothing is
deployed, activated, scheduled, or connected to a live API.** No Queueable/Batch/Scheduled jobs
exist. The enrichment writer is dormant (callable only by tests or a controlled service call).

## What was built

### Custom Metadata Types (5) — all sample records dormant (Active/Enabled = false)
- `OA_Field_Write_Policy__mdt` — per-field write behavior (object, field, source, mode, floor, trusted, active).
- `OA_Qualification_Rule__mdt` — ICP rules (ruleset, criterion, operator, value, weight, required, threshold).
- `OA_Connector_Registry__mdt` — connector registration (classes, source, staging object, named credential, enabled, status).
- `OA_Enrichment_Source__mdt` — source precedence & trust.
- `OA_Enrichment_Pipeline__mdt` — pipeline step order.

### Platform objects (4)
- `OA_Connector_Run__c` — connector telemetry / provenance.
- `OA_Enrichment_Change_Log__c` — before/after audit + rollback snapshot.
- `OA_Enrichment_Exception__c` — human-review queue (the four exception types).
- `OA_Discovered_Organization__c` — net-new discovered orgs + qualification result (auto-create dormant).

### Apex services (10 classes) + tests
| Class | Role |
|---|---|
| `OA_CanonicalOrg` | In-memory canonical organization model (name, normalized name, UEI/CAGE/EIN/CIK/NPI, NAICS, address, website, phone, source, confidence, payload hash, discovery metadata). |
| `OA_NameNormalizer` | Deterministic normalization + simple similarity. |
| `OA_ConfidenceEvaluator` | Confidence band + score; deterministic-first. |
| `OA_SourcePrecedenceEngine` | Metadata-driven source-of-truth precedence. |
| `OA_FieldWritePolicyEngine` | Per-field write decision (fill-empty / overwrite / never / conflict / floor). |
| `OA_ChangeLogService` | Snapshot, change-log build/commit, rollback. |
| `OA_ExceptionRoutingService` | Routes the four human cases to `OA_Enrichment_Exception__c`. |
| `OA_EnrichmentWriter` | Dormant writer: preview (no DML) or commit (FLS-enforced CRM write + audit). |
| `OA_QualificationRuleEngine` | Metadata-driven ICP qualification. |
| `OA_DiscoveryQualificationEngine` | Recommendation-only (Qualified/NotQualified/NeedsData, score, reasons, match, action). No Lead creation. |

All metadata-driven engines expose a `@TestVisible` override so tests inject metadata rows — no
hardcoded business rules; behavior comes entirely from the CMDT.

## Safety properties
- **Dormant by default:** every sample metadata record is `Active`/`Enabled = false`; the field-write
  engine only acts on Active + Trusted policies, so the shipped samples never cause a write.
- **Deterministic high-confidence path only:** the writer writes only when the per-field policy allows
  and confidence meets the floor; everything else skips or routes to an exception.
- **No auto-create:** `OA_DiscoveryQualificationEngine` returns a recommendation and never inserts a
  Lead; auto-create is gated behind a dormant switch that is off (only a test can flip it), and even
  then this foundation performs no insert.
- **FLS on CRM writes:** the writer updates the target record in `USER_MODE`. Internal audit rows
  (change log, exception) are framework records inserted in system mode.
- **Full audit + rollback:** every write produces a change-log row with a before-snapshot; rollback
  restores from it.

## How a future connector plugs in (the goal of this phase)
Adding SAM.gov / USASpending / Census should require **connector logic + metadata registration only**,
not new core architecture:

1. **Connector code** (already patterned by the SAM/USASpending SDK connectors): Request / Parser /
   Mapper + a staging object.
2. **Map source rows → `OA_CanonicalOrg`** (identity + `attributes` bag for rule-referenced fields).
3. **Register** the connector in `OA_Connector_Registry__mdt` (Enabled = false until activated).
4. **Declare source precedence** in `OA_Enrichment_Source__mdt`.
5. **Declare field write policies** in `OA_Field_Write_Policy__mdt` (which CRM fields, which mode).
6. **Declare ICP rules** in `OA_Qualification_Rule__mdt` (for discovery qualification).
7. Enrichment then flows through the shared engines: resolve → confidence → per-field write (preview or
   commit) → change log → exceptions; discovery flows through qualify → recommend.

No engine change is needed to onboard a source — only connector/parser/mapper logic plus metadata.

## Not done (by design, per Phase 7 constraints)
No deploy, no push, no activation, no scheduler/Queueable/Batch, no live API calls, no connector
implementations, no CRM records modified. Activation of real auto-write remains gated (ADR-012):
least-privilege runtime user, approved field/ICP metadata, tripwire kill-switch, monitoring.

See also: `ADR-012-automated-lead-enrichment`, `LEAD_ENRICHMENT_PLATFORM.md`,
`AUTOMATED_MATCH_AND_WRITE_POLICY.md`, `DISCOVERY_QUALIFICATION_ENGINE.md`, `BUILD_VS_BORROW.md`.
(These design docs live on the `design/lead-enrichment-platform` branch.)
