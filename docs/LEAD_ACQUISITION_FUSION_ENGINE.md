# Lead Acquisition — Identity-Aware Fusion Engine (Phase 8)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (Enterprise, production — verified by ID) · **Branch:** `feature/lead-acquisition-fusion-engine`
**Scope executed (authorized):** deploy the identity-aware, fusion-enabled discovery pipeline + a supervised **preview** pilot. **No new Candidate inserts; no Candidate updates persisted; no Leads/Accounts modified; no automation; no schedules.** Verdict: **🟢 PASS.**

> Completes the Lead Acquisition foundation: Identity Resolution now runs inside `OA_CandidateDiscoveryService`, and a
> connector-agnostic **fill-empty fusion** merges multiple sources into ONE organization profile (with provenance)
> instead of creating fragmented Candidates. Complements [LEAD_ACQUISITION_IDENTITY_RESOLUTION.md](LEAD_ACQUISITION_IDENTITY_RESOLUTION.md),
> [LEAD_ACQUISITION_LEAD_COMPLETENESS_MODEL.md](LEAD_ACQUISITION_LEAD_COMPLETENESS_MODEL.md), and [LEAD_ACQUISITION_MULTI_SOURCE_VALIDATION.md](LEAD_ACQUISITION_MULTI_SOURCE_VALIDATION.md).

---

## 1. Architecture (Phase 1–2)
Pipeline (per incoming `OA_CanonicalOrg`, connector-agnostic):
```
Connector -> OA_CanonicalOrg -> OA_IdentityResolution.resolve -> decision -> OA_SourceFusion / insert -> Candidate
```
Integrated in `OA_CandidateDiscoveryService.run()` (preview/commit preserved):
| Decision | Action |
|---|---|
| EXACT_DUPLICATE | skip (idempotent) |
| MATCH → CANDIDATE | **fuse** into the existing Candidate (fill-empty + provenance) → UPDATE (no new record) |
| MATCH → LEAD / ACCOUNT | mark `Duplicate` + link `Matched_Lead__c`/`Matched_Account__c`; insert an auditable marker |
| REVIEW (ambiguous) | insert `Needs Review` with the match rationale (never auto-merge) |
| NONE | insert new `Needs Review` |
Reuses the existing driver, service, canonical model, staging object, and review queue — **no new object/field**.

## 2. Fusion strategy (Phase 3) — `OA_SourceFusion.fuse(existing, incoming)`
- **Fill-empty only:** fills a blank field from the incoming source; **NEVER overwrites a populated field** (with a blank or a conflicting value). Matches the platform's FillEmptyOnly write philosophy.
- **Preserve every source / timestamp / confidence / provenance:** each fusion appends `{system, confidence, payloadHash, canonicalKey, fusedAt}` to the existing `Discovery_Metadata__c` (JSON) and bumps `fusionCount`; sets `Last_Evaluated__c`.
- **Confidence corroboration:** raises `Source_Confidence__c` to the strongest contributing value.
- **Fields fused:** name, normalized name, UEI, CAGE, CIK, EIN, NPI, NAICS, address/city/state/postal, website, phone.
- **Connector-agnostic:** no source-specific branching; PURE (no DML/SOQL — the service persists).
- **Trusted-source precedence:** the safe default is fill-empty (conflicts are NOT overwritten — the alternate value is retained in provenance for review). Field-level precedence overrides remain a documented future config (`OA_Source_Precedence__mdt`), not required for the conservative default.

## 3. Confidence thresholds (from Identity Resolution)
payload-hash = EXACT_DUPLICATE (100) · UEI 99 / CAGE 97 / CIK 96 / EIN 95 → MATCH · domain 85 / name+address 85 → MATCH · **name+state 65 → REVIEW** · name-only 45 → NONE. **MATCH ≥85 (auto-fuse/link), REVIEW 55–84 (human), <55 NONE.** Uncertain matches route to review — never fused on weak evidence.

## 4. Deployment (Phase 6)
| Item | Value |
|---|---|
| Bundle validation | `0AfPn0000023dIDKAY` (24 tests / 0 fail) |
| **Bundle deploy** | **`0AfPn0000023dJpKAI`** Succeeded — `OA_IdentityResolution`, `OA_SourceFusion`, integrated `OA_CandidateDiscoveryService` (+ tests) |
| Completeness utility deploy | **`0AfPn0000023dLRKAY`** Succeeded — `OA_LeadCompleteness` (pure, for Phase-5 readiness) |
| Tests | 24 + 5 run, **0 failures** | Production changed: additive/updated Apex only (dormant) |

## 5. Supervised pilot (Phase 4–5) — PREVIEW, 0 DML
Target: the existing **THE AEROSPACE CORPORATION** USASpending candidate (UEI `YA8LJBJCND19`; had name+UEI+state, no website/CAGE/address). Fed a **simulated second source (SAM-like)** sharing the same UEI + website/CAGE/address (**preview only — never persisted**):
| Signal | Result |
|---|---|
| Identity decision | **MATCH → CANDIDATE** (shared UEI, confidence 99) |
| Fusion | `fused=1, inserted=0, updated=0` (preview), **DML=0** |
| Fused profile (in memory) | website `https://aerospace.org`, CAGE `7ABC1`, address filled; **provenance recorded**; confidence HIGH |
| **Lead Completeness** | **BEFORE = 23 → AFTER = 41** (+18) — multi-source measurably improves one profile |
| Exact-duplicate case | re-fed the candidate's own canonical → **skipped** (idempotent) |
| New-org case | unknown org → **wouldInsert** (Needs Review) |

Same-company detection, identity scoring, fusion, provenance, completeness improvement, and review routing all verified — with **zero production writes** and **no Lead creation**.

## 6. Before/after counts (production unchanged)
Candidates **6 → 6** (3 USASpending + 3 SEC) · Leads **13,301** unchanged · Accounts **1** unchanged. The Aerospace Corp candidate's website/CAGE remain **null** (the simulated data was previewed, never persisted — data integrity preserved).

## 7. Why the committed fusion write was deferred (honesty)
A real *committed* fusion needs a **genuine second source sharing a strong identifier** with an existing candidate. The two live sources don't overlap by strong ID (USASpending=UEI aerospace recipients; SEC=CIK defense primes), and **SAM (the natural UEI/CAGE fusion partner) is credential-gated**. Rather than persist fabricated firmographics onto a real production candidate, the committed fusion is **deferred to the SAM pilot**; the merge *write* path is proven by the deployed unit tests (rollback context) and the completeness gain by the production preview.

## 8. Validation summary
Check-only bundle `0AfPn0000023dIDKAY` (24 tests/0 fail). Deployed `0AfPn0000023dJpKAI` + `0AfPn0000023dLRKAY`. Unit tests prove: preview 0 DML; NONE→insert; Lead match→Duplicate (no Lead created); exact-dup skip; **cross-source MATCH→fusion fills blanks + provenance + confidence upgrade (UPDATE not insert)**; fill-empty never overwrites populated; provenance appends across fusions.

## 9. Production safety (Phase 6)
No Lead created/modified; no Account modified; no Contact modified; no connector automation; no scheduling; no campaign change; no enrichment write-back; no OI work; no dashboards. Candidate object unchanged (preview only). Registry connectors still `Enabled=false`.

## 10. Risks / limitations
- **Per-org SOQL in the resolver** (candidate/Lead/Account queries per incoming org) → fine for controlled pilots (≤tens); **bulk volume needs a batched resolver** before any high-volume or scheduled use. (Documented gap.)
- **Account matching weak** (Name/domain only — no gov IDs).
- **Committed cross-source fusion** awaits a real second source (SAM) sharing a strong ID.
- Conflicts are not auto-resolved (fill-empty keeps existing) — field-precedence config is future.

## 11. PASS / WARN / FAIL — 🟢 PASS
Identity Resolution integrated; fusion implemented (fill-empty + provenance, connector-agnostic); multi-source pilot completed (preview); provenance preserved; completeness improved (23→41); no Lead/Account changes; no automation/schedules; existing architecture reused; production evidence documented. **WARN:** committed fusion deferred to SAM (real second source); per-org SOQL needs bulk refactor before volume.

## 12. Remaining gaps → recommended next sprint
G3 **SAM credential** (unlocks the first real committed cross-source fusion) · bulk-batched resolver (before volume) · G2 NAICS · G4 completeness surfacing · G5 candidate analytics deploy · G6 least-privilege runtime user · G7 org Matching/Duplicate Rules · field-precedence config.
**Next sprint:** SAM Entity credential + supervised SAM pilot proving a **real committed fusion** (SAM UEI/CAGE merging into an existing USASpending UEI candidate) + bulk-safe resolver.

## 13. Next approval gate (🔴 Louis)
SAM credential setup (data.gov key + JIT EC principal grant + alpha→prod endpoint); bulk resolver refactor; least-privilege runtime user; any merge to `main`.
