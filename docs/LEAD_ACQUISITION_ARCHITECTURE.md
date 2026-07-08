# Lead Acquisition Engine — Architecture & Reuse Audit (Phase 1)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-candidate-foundation`
**Epic:** Lead Acquisition (NEW, separate from Lead Enrichment RC1 and from Opportunity Intelligence) · **Mode:** design + reuse audit; live read-only evidence
**Change:** **no new object, no new field** — the Candidate model already exists (see §2). One additive report type only (Candidate reporting).

> Every external organization flows: **API Source → Candidate → Duplicate Detection → Existing-Lead Match → Review Queue
> → Human Approval → Salesforce Lead → Lead Enrichment.** No API creates a production Lead directly. Everything auditable.
> This sprint proves the pipeline is **almost entirely already built** and specifies the thin operational wiring that remains.

---

## 1. Reuse audit (what already exists — evidence from the live org + main)

| Capability | Existing component (reused) | Verdict |
|---|---|---|
| **Connector SDK** | `OA_IEnrichmentConnector` + `OA_ConnectorRunner` | ✅ reuse as-is |
| **Connector Registry** | `OA_Connector_Registry__mdt` (per-source class wiring, Enabled flag) | ✅ reuse |
| **Proposal / qualification engine** | `OA_Enrichment_Pipeline__mdt` + `OA_Qualification_Rule__mdt` + `Qualification_Status__c`/`Recommended_Action__c` on the candidate object | ✅ reuse |
| **Review Queue** | `OA_Enrichment_Exception__c` (single review/approval queue) | ✅ reuse / extend by convention |
| **Policy Engine** | `OA_Field_Write_Policy__mdt` (FillEmptyOnly, per-field) | ✅ reuse (governs the Lead write step) |
| **Duplicate detection infra** | `Canonical_Key__c`, `Normalized_Name__c`, `Source_Payload_Hash__c`, `Matched_Lead__c`, `Matched_Account__c` on the candidate object | ✅ reuse (see [LEAD_ACQUISITION_DUPLICATE_DETECTION.md](LEAD_ACQUISITION_DUPLICATE_DETECTION.md)) |
| **Write-back framework** | `OA_LeadWritebackService` / `OA_EnrichmentWriter` (commit off by default) | ✅ reuse (the Candidate→Lead creation step is human-gated) |
| **Telemetry** | `OA_Connector_Run__c` | ✅ reuse |
| **Audit** | `OA_Enrichment_Change_Log__c` (before-snapshot + reversible) | ✅ reuse |
| **Candidate staging** | **`OA_Discovered_Organization__c`** (see §2) | ✅ **reuse — it IS the Candidate model** |
| **Candidate reporting** | *(none existed)* → **new** `OA_Discovered_Organizations` report type | 🟡 the only additive metadata this sprint |

**Genuinely missing capability:** almost none. The data model, review queue, dedup fields, policy engine, and audit all
exist. What remains is **operational wiring** (a discovery/candidate mode on connectors that writes candidates instead of
enriching Leads, and the human approval→Lead-creation step) — design specified here, **not built/activated** this sprint.

## 2. Candidate model = existing `OA_Discovered_Organization__c` (Phase 2)
The requested Candidate fields map 1:1 onto the **already-deployed** object (0 records today — dormant/clean):

| Required Candidate field | Existing field on `OA_Discovered_Organization__c` |
|---|---|
| Source System | `Source_System__c` |
| Discovery Timestamp | `CreatedDate` + `Last_Evaluated__c` |
| Organization Name | `Organization_Name__c` (+ `Normalized_Name__c`) |
| Website | `Website__c` (URL) |
| UEI | `UEI__c` |
| CAGE | `CAGE_Code__c` |
| NAICS | `NAICS__c` |
| Address | `Address__c`, `City__c`, `State__c`, `Postal_Code__c` |
| Federal Identifiers | `UEI__c`, `CAGE_Code__c`, `EIN__c`, `CIK__c`, `NPI__c` |
| Source Confidence | `Source_Confidence__c` (text) + `Confidence_Score__c` (number) |
| Duplicate Status | `Matched_Lead__c`, `Matched_Account__c`, `Canonical_Key__c`, `Source_Payload_Hash__c` (see §Duplicate doc) |
| Review Status | `Qualification_Status__c` + `Recommended_Action__c` + `Qualification_Reasons__c` |

**Conclusion:** the Candidate staging model is **fully satisfied by the existing object — no new object or field is created.**
Lifecycle fields are free-text, so review outcomes are stored as conventions (no picklist metadata change needed).

## 3. Candidate review outcomes (Phase 5 — reuse the one Review Queue)
Reuse `OA_Enrichment_Exception__c` as the single review/approval surface; encode Candidate outcomes on the candidate
record's `Qualification_Status__c` (free text) with this **convention** (no second review process, no new object):

| Outcome | `Qualification_Status__c` | Effect |
|---|---|---|
| **Approved** | `Approved` | eligible for human Lead creation → then enrichment |
| **Rejected** | `Rejected` | discarded; reason in `Qualification_Reasons__c` |
| **Duplicate** | `Duplicate` | `Matched_Lead__c`/`Matched_Account__c` set; never creates a Lead |
| **Needs Review** | `Needs Review` | routed to the review queue for a human |
| **Deferred** | `Deferred` | held for a later cycle |

**No automatic Lead creation:** a Candidate becomes a Lead only on explicit human approval (a gated step), routed through
the existing write-back/policy/audit path.

## 4. What this sprint deliberately does NOT do
No connector enablement, no discovery execution, no scheduled jobs, no automatic Lead creation, no write-back activation,
no permission assignment, no production data change. Everything remains **dormant**. Opportunity Intelligence untouched;
Website integration out of scope; LinkedIn/Meta remain dormant.
