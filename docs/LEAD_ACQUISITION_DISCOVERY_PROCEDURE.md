# Lead Acquisition — Manual Candidate Discovery Procedure (Phase 4–5)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Mode:** ready-to-run procedure — **NOT executed this sprint**
**Requires (before running):** `OA_CandidateDiscoveryService` deployed (🔴), connector enabled for the source (🔴), and for SAM a data.gov key + JIT EC principal grant (🔴).

> Phase 4 (manual, no scheduler) + Phase 5 (review routing). This is the exact, controlled, **manual** procedure to
> produce a small Candidate sample per Build-Now source. It is **gated**: running it makes live callouts and writes
> production Candidate records — both 🔴 RED. **No jobs, no automation, no background execution** — one operator runs
> one source at a time and inspects the result.

---

## 1. Prerequisites (all 🔴 gated, per source)
1. Deploy `OA_CandidateDiscoveryService` (+ test) — validated (`0AfPn0000023bgDKAQ`).
2. Enable the target connector in `OA_Connector_Registry__mdt` (or instantiate it directly for a one-off manual run).
3. SAM only: enter data.gov key in the `OA_SAM` EC, JIT-grant EC principal access, move NC endpoint alpha→prod.
4. Confirm runtime user has candidate-object CRUD (reuse `OA_Connector_Staging` permset; assignment is a separate 🔴 gate).

## 2. Manual run pattern (per source) — preview first, then commit
Run in anonymous Apex, **one source at a time**, callout-before-DML:
```apex
// 1) Resolve the connector + its registry config (reuse existing SDK)
String src = 'USASpending';   // or SAM / SEC / IRS
OA_Connector_Registry__mdt cfg = [
    SELECT DeveloperName, Connector_Class__c, Endpoint_Path__c, Named_Credential__c, Enabled__c
    FROM OA_Connector_Registry__mdt WHERE DeveloperName = :src LIMIT 1];
OA_IEnrichmentConnector conn = (OA_IEnrichmentConnector) Type.forName(cfg.Connector_Class__c).newInstance();

// 2) LIVE CALLOUT (read-only fetch of a small controlled query) -> canonical orgs
OA_ConnectorResult r = conn.fetch('<small controlled search input>', cfg);

// 3) PREVIEW — zero writes; inspect classification (dedup vs Leads/Candidates)
OA_CandidateDiscoveryService.Outcome preview = OA_CandidateDiscoveryService.preview(r.organizations);
System.debug('would insert=' + preview.wouldInsert + ' duplicates=' + preview.duplicates + ' skipped=' + preview.skipped);

// 4) COMMIT (🔴 gated) — writes only new, non-duplicate Candidates (never a Lead)
// OA_CandidateDiscoveryService.Outcome committed = OA_CandidateDiscoveryService.persist(r.organizations, true);
// System.debug('candidate IDs=' + [SELECT Id FROM OA_Discovered_Organization__c WHERE Source_System__c = :src]);
```
Keep the sample tiny (target **3 candidates/source**). Preview must show only expected inserts/duplicates before commit.

## 3. Target sample (to be produced under gate)
| Source | Target | Status this sprint |
|--------|--------|--------------------|
| SAM Entity | 3 | ⏸ gated (needs key+JIT+prod endpoint) — not produced |
| USASpending | 3 | ⏸ gated (deploy service + enable connector + live callout + write) — not produced |
| SEC EDGAR | 3 | ⏸ gated — not produced |
| IRS Tax-Exempt | 3 | ⏸ gated — not produced |
| Census | — | ⚠ **WARN** — not an organization registry; cannot produce org candidates |
| Grants.gov | — | ⏸ **DEFER** — OI boundary; needs entity-extraction adapter |

## 4. Review routing (Phase 5 — reuse the single review model)
- Every persisted Candidate carries `Qualification_Status__c` ∈ {`Needs Review`, `Duplicate`, `Approved`, `Rejected`, `Deferred`} (free-text convention; no second review process).
- Discovery writes only `Needs Review` (new/unique) or `Duplicate` (matched a Lead/Candidate — `Matched_Lead__c` set).
- Reviewers work the Candidate list (surfaced by the `OA_Discovered_Organizations` report type) and the existing `OA_Enrichment_Exception__c` queue; a human sets `Approved`/`Rejected`/`Deferred`.
- **No Candidate is converted to a Lead in this sprint.** Lead creation from `Approved` candidates is a separate, gated step (reuses the write-back/policy/audit path).

## 5. Reversibility
Candidates are staging rows in `OA_Discovered_Organization__c` — a sample is trivially reversible (`delete` the run's rows,
identified by `Source_System__c` + `Last_Evaluated__c`). No Lead/Account is ever touched. `Source_Payload_Hash__c` makes
re-runs idempotent (no duplicate candidates).

## 6. What was NOT done (rules)
No connector enabled, no callout executed, no Candidate written, no Lead created, no job scheduled, no permission assigned,
no production data changed. LinkedIn/Meta audit-only (no writes).
