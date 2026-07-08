# Opportunity Intelligence — Staging Design

**Program 2 · Phase 0 (design only) · 2026-07-08**
Relates to [ADR-017](decisions/ADR-017-opportunity-data-model-and-staging-grain.md).

"Staging" in OI = the landing zone where normalized external opportunities sit **for human review
before any downstream action.** For the MVP, staging and the review queue are the **same object**
(`OA_Opportunity_Signal__c`) in `Review_Status__c = Pending` — deliberately simple.

---

## 1. Staging principle

**All external opportunity data lands in staging/review first.** There is no path from an external
API to a CRM record. The flow is strictly:

```
external source ──(GET)──► parse ──► normalize ──► dedupe ──► OA_Opportunity_Signal__c (Pending)
                                                                      │  human review
                                                                      ▼
                                                        Reviewed / Dismissed / Promoted
```

## 2. Why NOT reuse existing staging objects

| Existing object | Grain | Why unsuitable for OI |
|---|---|---|
| `OA_SAM_Entity_Staging__c` | company/entity (UEI, CAGE, legal name, registration status) | an opportunity is a *solicitation*, not a company; different fields, different dedupe key |
| `OA_USASpending_Staging__c` | awarded-contract lineage per entity | *awards*, not *open opportunities* |
| `OA_Discovered_Organization__c` | discovered company | entity grain |

Reusing any of these would (a) mix opportunity rows into entity data used by Lead Enrichment
(**forbidden** — no-touch), and (b) force opportunity fields onto a company-shaped schema. OI
therefore stages into its **own** object. Full rationale:
[ADR-017](decisions/ADR-017-opportunity-data-model-and-staging-grain.md).

## 3. Staging object (MVP)

`OA_Opportunity_Signal__c` doubles as staging + review queue. Key staging-relevant fields
(full list in [OI_DATA_MODEL.md](OI_DATA_MODEL.md)):

| Field | Staging role |
|---|---|
| `Canonical_Key__c` (ExtId, Unique) | **idempotency** — re-running a fetch upserts, never duplicates |
| `Connector_Run__c` | **provenance / reversibility** — delete-by-run to unwind a bad fetch |
| `Raw_Payload_Ref__c` | **lineage** — hash/pointer to the source payload (no PII stored) |
| `Confidence__c` | quality band for triage |
| `Review_Status__c` (default Pending) | gate — nothing leaves staging without a human |
| `Status__c` (New/Active/Expired) | source-side lifecycle, refreshed on re-ingest |

## 4. Ingestion rules

- **Callout-before-DML**, ≤50 records/txn (Lead-Enrichment learning).
- **Preview mode (`commit=false`, default):** produces proposed signals **in memory with zero
  DML** for inspection before any persist.
- **Commit mode:** bulk `insert`/`upsert` on `Canonical_Key__c` (idempotent); each row stamped with
  its `Connector_Run__c`.
- **Dedupe:** source-scoped `Canonical_Key__c` (e.g. `GRANTS:<oppNumber>`, `SAM:<noticeId>`);
  registry `Dedupe_External_Id_Field__c` points the SDK at it.
- **Anomalies** (missing key, parse failure, low confidence) → `OA_Enrichment_Exception__c` via the
  reused `OA_ExceptionRoutingService`; the run continues (one bad row never fails the batch).
- **Re-ingest / refresh:** upsert by `Canonical_Key__c` updates `Status__c` (e.g. → Expired) and
  source fields; **never overwrites** human review fields (`Review_Status__c`, notes, reviewer).

## 5. Reversibility

- **MVP:** delete every `OA_Opportunity_Signal__c` where `Connector_Run__c = <runId>` — clean,
  complete unwind of a single fetch. No CRM side effects because none are created.
- **Phase 5 (writeback):** any CRM record created from a promoted signal is audited and rolled back
  via `OA_ChangeLogService` before/after snapshots.

## 6. Retention & housekeeping (operational, later)

- Signals are retained for audit even after Dismissed/Expired (no hard delete in normal operation).
- Optional periodic archival of long-expired, never-reviewed signals is a Phase-4 operational
  policy, not an engineering need for the MVP.

## 7. Dormancy

The staging object ships **empty**. No data lands until a connector is enabled (G1) and a human
runs a preview then approves a commit (G2). Until then, staging is an empty, inert object.
