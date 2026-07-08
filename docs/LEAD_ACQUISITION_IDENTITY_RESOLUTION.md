# Lead Acquisition — Identity Resolution Framework (Phase 7)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-acquisition-identity-resolution`
**Mode:** source-only Apex + check-only validation · **No deploy, no writes, no automation, no new field, no merge.**

> Determines whether organizations discovered from different sources are the **same real-world company**, solving the
> cross-identifier problem (USASpending=UEI, SEC=CIK, SAM=UEI/CAGE, IRS=EIN). Read-only; ambiguous matches route to
> REVIEW (never auto-merge); provenance always preserved. Sits between connector output and Candidate creation.

---

## 1. Existing matching audit (Phase 1)
| Component | Matching today | Limitation |
|---|---|---|
| `OA_CandidateDiscoveryService` | dedup by `Source_Payload_Hash__c` (idempotency), `Canonical_Key__c` (single-ID), Lead by **UEI/CAGE exact** | exact-only; **fails across identifier systems** (UEI vs CIK); no Account match; no domain/name matching |
| `OA_CandidateDiscovery` (driver) | none (delegates to service) | — |
| `OA_CanonicalOrg.canonicalKey()` | single-identifier hierarchy (UEI→EIN→NPI→CIK→CAGE→name-hash) | one key per org; **UEI org and CIK org never collide** even if the same company |
| `OA_CanonicalOrg.payloadHash()` | SHA-256 of identity fields | exact-duplicate detection only |

**Reuse:** canonicalKey/payloadHash, the candidate/Lead identity fields, the service's collected-id query pattern.
**Do not duplicate:** payload-hash idempotency (keep in the service). **Gap:** cross-identifier + fuzzy (domain, name+state) matching — built here as a standalone resolver.

## 2. Identity model (Phase 2) — existing fields only, **no new field**
| Identifier | Candidate (`OA_Discovered_Organization__c`) | Lead | Account |
|---|:--:|:--:|:--:|
| UEI | `UEI__c` | `UEI__c` | — |
| CAGE | `CAGE_Code__c` | `CAGE_Code__c` | — |
| CIK | `CIK__c` | `CIK__c` | — |
| EIN | `EIN__c` | `EIN__c` | — |
| Website / domain | `Website__c` | `Website` | `Website` |
| Normalized name | `Normalized_Name__c` | `Company` | `Name` |
| Address / State | `Address__c` / `State__c` | `State` | — |
| Canonical key / payload hash | `Canonical_Key__c` / `Source_Payload_Hash__c` | — | — |

**Lead carries UEI/CAGE/CIK/EIN** (full cross-identifier coverage). **Account has no government identifiers** (Name+Website only) → Account matching is name/domain-only (documented limitation; no new Account fields created). **No new field required.**

## 3. Scoring model + thresholds (Phase 3) — `OA_IdentityResolution.resolve(OA_CanonicalOrg)`
| Signal | Confidence | Decision band |
|---|---|---|
| payload-hash equal (candidate) | 100 | **EXACT_DUPLICATE** |
| shared **UEI** | 99 | MATCH |
| shared **CAGE** | 97 | MATCH |
| shared **CIK** | 96 | MATCH |
| shared **EIN** | 95 | MATCH |
| same **website domain** | 85 | MATCH |
| normalized **name + address** | 85 | MATCH |
| normalized **name + state** | 65 | **REVIEW** (ambiguous) |
| normalized **name only** | 45 | NONE (too weak) |

Thresholds: **≥85 MATCH** (auto-link to the matched record), **55–84 REVIEW** (human adjudication — never auto-merge), **<55 NONE** (new candidate). Output: `{decision, confidence, matchedType (CANDIDATE/LEAD/ACCOUNT/NONE), matchedId, matchedIdentifiers, rationale}`. **Read-only (SOQL only, no DML); connector-agnostic (no source branching).**

## 4. Cross-identifier strategy (Phase 4)
The resolver matches on **any** strong identifier independently, so an org discovered by CIK (SEC) matches an existing
Lead/Candidate that carries the same CIK — even though its `canonicalKey()` is `CIK:` and the other's is `UEI:`.
**Where sources share no strong identifier** (USASpending UEI-only vs SEC CIK-only for the same real company), the match
falls to **domain** (MATCH) or **name+state** (**REVIEW** — not auto-merge). This is the deliberate safety posture:
- Strong ID or domain → confident auto-link.
- Name+state → **ambiguous → REVIEW** (a human confirms; provenance retained).
- Name only → NONE (do not guess).
No trusted data is overwritten; nothing is merged automatically; no Lead/Account is created or modified.

## 5. Examples
- SEC (CIK 0000012927, no UEI) incoming; an existing Lead has `CIK__c=0000012927` → **MATCH/LEAD**, identifiers `[CIK]`, "shared CIK".
- USASpending (UEI:X) incoming; existing candidate has same UEI → **MATCH/CANDIDATE** (99).
- Same website `webco.example` on two records, different names → **MATCH** (85, domain).
- "AMBI CO"/TX incoming vs candidate "AMBI CO"/TX, no shared ID → **REVIEW** (65) — a human decides.
- Unknown org, no shared signals → **NONE** → becomes a new candidate.

## 6. Ambiguity handling
55–84 → REVIEW (routes to the existing `OA_Enrichment_Exception__c` / `Qualification_Status__c='Needs Review'` queue,
not a second process). Multiple candidate/Lead/Account hits → the **highest-confidence** signal wins; ties keep the first
and record all matched identifiers in `matchedIdentifiers` for the reviewer. Never auto-merges an ambiguous match.

## 7. Integration plan (Phase 5) — design; wiring deferred to a gated deploy
`OA_IdentityResolution` is standalone this sprint (fully tested). Planned integration:
- **`OA_CandidateDiscoveryService`** calls `resolve(org)` per incoming org **before** insert: `EXACT_DUPLICATE`→skip; `MATCH`→link (`Matched_Lead__c`/`Matched_Account__c` or mark candidate duplicate) + status `Duplicate`; `REVIEW`→insert as `Needs Review` with the rationale; `NONE`→insert as new `Needs Review`.
- **Preview mode** calls `resolve` and reports decisions with **0 DML**; **commit mode** applies them (candidate inserts only — never Lead/Account).
- Feeds **source fusion** (G8): a `MATCH` across sources is the trigger to fuse profiles (field-precedence merge).
- Complements **Lead Completeness** (dedup first, then score the resolved profile).
> **Not wired this sprint** — integrating changes the deployed service's dedup semantics, so it is a gated source change + deploy (documented, not executed). The resolver is deployable independently and dormant.

## 8. Tests & validation (Phases 6–7)
`OA_IdentityResolution_Test` — **9 methods, 0 failures**, ~98% coverage. Covers: exact UEI/CAGE(via)/CIK/EIN, domain, name+state (REVIEW), no-match, exact payload-hash duplicate, existing Candidate match, existing Lead match (cross-identifier CIK), existing Account match (domain), resolver does **no DML**, null-input safe. **Check-only Validation ID `0AfPn0000023dA9KAI`.** Source-only; **not deployed**.

## 9. Metadata changed
New: `OA_IdentityResolution` (+ test). **No new object/field; no change to deployed classes.** Account gov-ID gap noted (not created).

## 10. Production safety
No Lead created/modified; no Account modified; no Candidate automation enabled; no schedules; no connector activation; no unrelated metadata; no dashboards; no website; no OI work. The 6 pilot candidates remain untouched.

## 11. Risks
- **Account matching is weak** (Name/domain only — no gov IDs on Account); Account auto-link uses domain (MATCH) or exact name (REVIEW-tier). Consider Account external IDs later (not this sprint).
- **Name normalization quality** governs name-based signals; `Normalized_Name__c` must be consistent across sources.
- **Cross-source UEI↔CIK** with no shared strong ID + no domain → REVIEW (correct, but volume of REVIEW depends on data quality).
- Integration is a **future gated deploy** (changes dedup behavior).

## 12. PASS / WARN / FAIL — 🟢 PASS
Matching audited; identity model defined (existing fields, no new field); scoring implemented + validated; cross-identifier designed + implemented; tests added (9/0); check-only passed; no production changes/automation/Leads/Accounts. **WARN:** Account matching limited (no gov IDs); integration + fusion are gated future deploys.

## 13. Remaining gaps
G8 fusion merge (now unblocked by the resolver) · integration into the service (gated) · G2 NAICS · G3 SAM credential · G4 completeness surfacing · G5 candidate analytics deploy · G6 least-priv user · G7 org Matching/Duplicate Rules.

## 14. Recommended next sprint
**Phase 8 — Identity-aware discovery + fusion (gated):** wire `OA_IdentityResolution` into `OA_CandidateDiscoveryService` (source + gated deploy), implement the field-precedence **fusion merge** (G8) on `MATCH`, and re-run a supervised multi-source pilot (USASpending + SEC) to prove same-company records fuse/route-to-review correctly. Then **SAM Entity** (credential-gated) as the third source.

## 15. Next approval gate (🔴 Louis)
Deploy `OA_IdentityResolution`; wire + gated-deploy the service integration + fusion merge; SAM credential setup; least-privilege runtime user; any merge to `main`.
