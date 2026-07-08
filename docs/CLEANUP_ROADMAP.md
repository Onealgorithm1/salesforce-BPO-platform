# Cleanup Roadmap — Lead Enrichment Platform

**Date:** 2026-07-08 · **Branch:** `main` (`dbf8d12`) · **Org:** `00Dbn00000plgUfEAI`
**Status:** **PLAN ONLY — nothing is deleted by this document.** · **Change made:** documentation only
**Inputs:** [REPOSITORY_INTEGRITY_REVIEW.md](REPOSITORY_INTEGRITY_REVIEW.md) · [CONNECTOR_REGISTRY_REVIEW.md](CONNECTOR_REGISTRY_REVIEW.md) · [TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)

> Every deletion of Apex/metadata from production is a 🔴 **destructive-metadata** gate requiring explicit Louis
> approval and its own deploy. This roadmap sequences that work; it does not perform it. Guiding rule:
> **disable-in-place before delete**, and never remove a `NEEDS-REVIEW` item until its live dependency is cut.

---

## 1. Cleanup candidate inventory

| ID | Item | Type | Rank | Live dependency? |
|---|---|---|---|---|
| C-1 | `OA_BookingPoller` + `OA_BookingPoller_Test` in **`force-app/`** (duplicate of `modules/` canonical) | Apex ×2 | **DEAD** | No — cannot compile core-only; canonical is in `modules/` |
| C-2 | `OA_SAMConnector` + `OA_SAMMapper` + `OA_SAMParser` + `OA_SAMRequest` (+ test) | Apex | **DEAD** | No — 0 external refs (superseded by `OA_SAM_Connector`) |
| C-3 | `OA_SAM_Entity_Staging__c` object + `OA_SAM_Connector` permission set | Object + permset | **DEAD** | No — object written only by C-2; permset grants only this object |
| C-4 | `GrantsGov` + `SAM_Opportunities` rows in `OA_Connector_Registry__mdt` | CMDT records | **DEAD-in-registry** | No — OI drives these via `OA_ConnectorEngine`, not the enrichment runner |
| C-5 | `OA_USASpendingEnrichmentService` | Apex | **DEAD** | No — 0 external refs |
| C-6 | `OA_USASpendingConnector` + `OA_USASpendingMapper` + `OA_USASpendingParser` + `OA_USASpendingRequest` (Framework-A camelCase) | Apex | **NEEDS-REVIEW** | Indirect — verify no caller before removal |
| C-7 | `OA_USASpendingClient` + `OA_USASpending_Staging__c` | Apex + object | **NEEDS-REVIEW** | **YES** — still read by LIVE `OA_LeadWritebackService`. **Do not remove until write-back is migrated off it.** |
| C-8 | `OA_IConnector` + `OA_ConnectorEngine` + `OA_ConnectorPersistence` (Framework A) | Apex | **KEEP (for now)** | **YES** — Opportunity Intelligence runs on Framework A |
| C-9 | Phantom manifest members (`OpenAI_Access` permset, `lead_by_ramesh` flow) | manifest | **DEAD ref** | No — clean the manifest entries |
| C-10 | Empty `clients/pbo/` scaffold + empty `force-app` dirs | `.gitkeep` dirs | **KEEP** | No — harmless scaffolding; leave |

## 2. Dependency map (retire in this order — leaves before roots)

```
C-1 force-app OA_BookingPoller ......... no deps                         ── remove any time
C-2 OA_SAMConnector + support .......... writes OA_SAM_Entity_Staging__c ─┐
C-3 OA_SAM_Entity_Staging__c + permset . written only by C-2            ──┘ remove C-2 THEN C-3
C-5 OA_USASpendingEnrichmentService .... reads OA_USASpending_Staging__c  ── remove (0 callers)
C-6 OA_USASpendingConnector camelCase .. verify 0 callers first          ── remove after verify
C-4 registry rows GrantsGov/SAMOpp ..... metadata only                    ── remove any time (OI unaffected)
C-7 OA_USASpendingClient/_Staging__c ... READ BY OA_LeadWritebackService ── BLOCKED until write-back migrated
C-8 Framework A (IConnector/Engine) .... USED BY Opportunity Intelligence ── BLOCKED until OI migrated to Framework B
C-9 manifest phantom members ........... manifest edit                    ── docs/manifest only (GREEN-ish)
```

Rule: an item may be retired only after every arrow pointing INTO it is gone. C-7 and C-8 are hard-blocked by live consumers.

## 3. Migration plan (to unblock the NEEDS-REVIEW / KEEP items)
- **M-1 (unblocks C-7):** migrate `OA_LeadWritebackService` off `OA_USASpending_Staging__c`/`OA_USASpendingClient` onto the Framework-B path (`OA_Discovered_Organization__c`). Engineering + regression tests + 🔴 deploy. Est. ~1–2 days.
- **M-2 (unblocks C-8):** migrate Opportunity Intelligence's GrantsGov/SAM-Opportunities connectors from Framework A (`OA_IConnector`/`OA_ConnectorEngine`) to Framework B (`OA_IEnrichmentConnector`/`OA_ConnectorRunner`), or formally split OI into its own SDK. Larger effort, **OI program work — out of scope for this maintenance sprint.** Only after M-2 can Framework A be retired.

## 4. Destructive-change plan (per 🔴 batch)
Each batch = a separate feature branch + check-only validation + explicit Louis approval + `destructiveChanges.xml` deploy.

- **Batch 1 (lowest risk, no live deps):** C-1, C-2, C-3, C-4, C-5, C-9.
  - Pre-req: re-run a reference scan confirming 0 non-test callers for each Apex class immediately before deploy.
  - `destructiveChanges.xml` lists the classes + `OA_SAM_Entity_Staging__c` + `OA_SAM_Connector` permset + the 2 registry records; `package.xml` version-only.
  - Tests: full RunLocalTests must pass with the classes removed (their tests are removed in the same package).
- **Batch 2 (after verify):** C-6 (camelCase USASpending) once M-1 confirms nothing routes through it.
- **Batch 3 (after M-1):** C-7 (`OA_USASpendingClient` + `OA_USASpending_Staging__c`).
- **Batch 4 (after M-2, OI program):** C-8 Framework A.

## 5. Rollback plan for the cleanup itself
- **Metadata is in git** — every destructive deploy is reversible by re-deploying the prior tag/commit (the removed classes/objects are restored from source). Record the pre-cleanup commit as a rollback point (recommend a tag, e.g. `pre-cleanup-YYYYMMDD`).
- **Data:** `OA_SAM_Entity_Staging__c` / `OA_USASpending_Staging__c` may hold rows — **export to CSV before deleting the object** (object deletion is irreversible for the data). Objects with data should be emptied + confirmed unused first.
- **Staged approach:** deploy Batch 1 to a sandbox first if/when TD-001 (no sandbox) is resolved; until then, check-only validation in production is the safety net.
- **Kill/abort:** if any batch validation fails, STOP — do not force; diagnose the unexpected caller and re-scope.

## 6. Recommended execution order (summary)
1. **C-9 / manifest hygiene** — lowest risk (manifest edit; near-GREEN).
2. **Batch 1** (C-1…C-5) — DEAD code/objects with no live deps → biggest noise reduction, safe.
3. **Verify + Batch 2** (C-6).
4. **M-1 migration → Batch 3** (C-7) — removes the last Framework-0 dependency from the live write path.
5. **M-2 (OI program) → Batch 4** (C-8) — consolidates to a single connector SDK. Deferred to Opportunity Intelligence.

## 7. Effort & classification
| Batch/Item | Classification | Effort | Gate |
|---|---|---|---|
| C-9 manifest hygiene | 🟢 GREEN (docs/manifest) | ~1 hr | branch/PR |
| Batch 1 (C-1…C-5) | 🔴 destructive deploy | ~0.5–1 day | Louis approval |
| C-6 verify + remove | 🔴 destructive deploy | ~0.5 day | Louis approval |
| M-1 + C-7 | 🔴 Apex + deploy | ~1–2 days | Louis approval |
| M-2 + C-8 | 🔴 (OI program) | multi-day | separate program |

**None of this cleanup is required for the certified manual/preview Lead Enrichment scope.** It is hygiene that reduces future-maintenance surface and must not block maintenance-mode entry. Recommended: do C-9 + Batch 1 opportunistically; defer C-7/C-8 to their migration programs.
