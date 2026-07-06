# Build vs. Borrow — Matching, Dedupe, Confidence, Normalization

_Status: **DESIGN DECISION — for review** · 2026-07-06. Evaluated before implementing the
foundation's matching/normalization logic (Phase 7)._

## Decision rule (binding)
1. **No external runtime dependencies.** The platform runs inside Salesforce (Apex). We do not
   stand up an external service, move CRM/PII data out of the org, or add a library the org must call.
2. **Borrow concepts, not code.** Open-source projects inform algorithm choice and API shapes.
3. **Keep the implementation Salesforce-native** unless a specific external step is explicitly approved.

## Evaluation

| Project | What it is | License | Verdict for this foundation |
|---|---|---|---|
| **fullstackgtm/core** | External TypeScript/Node CLI: canonical model, deterministic match, per-field write policy (fill-blanks/never), approval-gated writeback, ICP-scored acquire | Apache-2.0 | **Borrow concepts.** Independently validates our design (per-field policy, refuse-to-guess, gated write). Not Salesforce-native, commercial sources only, beta/0-star → not adopted as runtime. Our `OA_FieldWritePolicyEngine` + `OA_DiscoveryQualificationEngine` mirror its good ideas, in Apex. |
| **Splink** (MoJ) | Python probabilistic record linkage (Fellegi-Sunter), SQL backends | MIT | **Borrow concept (fuzzy, later).** Best-in-class probabilistic matching, but Python/external. Our deterministic HIGH-confidence path needs no probabilistic engine. If fuzzy matching is approved later, port the Fellegi-Sunter *approach* or run Splink as an offline batch scorer — not an in-org dependency. |
| **Zingg** | ML/Spark entity resolution & MDM | AGPL-3.0 | **Reject as dependency.** Spark/Java external service; AGPL is a licensing concern for embedding. Concept reference only. |
| **Python `dedupe`** | Active-learning dedupe library | MIT | **Reject as dependency.** Python/external. Concept reference for blocking + active learning if ever needed offline. |
| **`recordlinkage` toolkit** | Python record-linkage toolkit | BSD-3 | **Reject as dependency.** Python/external. Concept reference for comparison metrics. |
| **makegov/procurement-tools** | Python SAM.gov + USASpending client library, Pydantic models | Apache-2.0 | **Borrow reference.** Useful as a *field-mapping / endpoint reference* when we build the SAM & USASpending Apex connectors. Not run in-org. |
| **fedspendingtransparency/usaspending-api** | Official USASpending server app | (US Gov) | **Borrow reference.** Authoritative endpoint + response-shape reference for the USASpending connector/parser. Not a dependency. |

## What we built instead (Salesforce-native)
- **Normalization:** `OA_NameNormalizer` — deterministic uppercase/punctuation/suffix-strip + a simple
  Jaccard token similarity. Concept from Splink/dedupe practice; ~40 lines of Apex, no dependency.
- **Confidence:** `OA_ConfidenceEvaluator` — deterministic-first banding (exact id → HIGH). A
  probabilistic scorer can replace the fuzzy tail later without changing callers.
- **Per-field write policy:** `OA_FieldWritePolicyEngine` — metadata-driven, mirrors fullstackgtm's
  fill-blanks/never/overwrite model.
- **Qualification / dedupe identity:** `OA_QualificationRuleEngine`, `OA_CanonicalOrg.canonicalKey()`.

## Re-open this decision if…
…fuzzy (non-deterministic) matching becomes a hard requirement at scale — at that point, evaluate
running **Splink** as an *offline, approved* batch step that writes match candidates back for review,
rather than embedding any library in the org.

## Update — Phase 8 (SAM.gov connector), 2026-07-06
No decisions changed. Building the SAM.gov connector confirmed the Salesforce-native, borrow-concepts
approach: SAM plugged into the platform using only `OA_SAM_Request` / `OA_SAM_ResponseParser` /
`OA_SAM_Mapper` / `OA_SAM_Connector` + metadata, with **no external runtime dependency** and **no change
to the platform engines**. The `makegov/procurement-tools` reference informed the SAM v3 entity
endpoint/field shapes only. Deterministic identity (UEI) → HIGH confidence needed no probabilistic
library, consistent with the original decision.
