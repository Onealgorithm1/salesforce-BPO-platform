# Lead Acquisition — Company Intelligence Framework (Phase 4)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Branch:** `feature/lead-acquisition-company-intelligence`
**Mode:** design + one pure Apex utility (source-only, check-only validated) · **No deploy, no writes, no automation, no new object/field.**

> Goal: let every acquisition connector contribute to a **single canonical organization profile** before Candidate
> review. Finding: the existing architecture already supports canonical intelligence for **single-source** candidates;
> the one genuine gap is **cross-connector fusion** (today a second source for the same org is flagged Duplicate, not
> merged). This sprint designs the fusion strategy and implements the reusable completeness score — reusing existing
> metadata, adding no object/field.

---

## 1. Architecture review (Phase 1) — is a new framework needed?
| Component | Role today | Sufficient for canonical intelligence? |
|---|---|---|
| `OA_CanonicalOrg` | in-memory canonical org (all identity fields + `canonicalKey()`/`payloadHash()`) | ✅ yes — the canonical model |
| `OA_Discovered_Organization__c` | persisted Candidate (has `Canonical_Key__c`, `Source_System__c`, `Confidence_Score__c`, `Discovery_Metadata__c`) | ✅ yes — the persistence target |
| `OA_CandidateDiscoveryService` | persist + dedup (idempotency, canonical-key, Lead match) | ◐ partial — dedups but **does not fuse** cross-source |
| Duplicate detection | canonical-key + payload-hash + UEI/CAGE Lead match | ✅ yes |
| Candidate review | `Qualification_Status__c` + `OA_Enrichment_Exception__c` | ✅ yes |
| Lead matching | UEI/CAGE → `Matched_Lead__c` | ✅ yes |

**Verdict:** **No new framework object is needed.** ~90% already exists and should be reused. The only missing capability
is a **source-fusion merge step** inside the existing service (design in §4) plus a reusable **completeness score**
(implemented §3). Both reuse existing metadata.

## 2. Canonical intelligence mapping (Phase 2)
How each connector contributes to the single canonical profile (from evidence in [LEAD_ACQUISITION_CONNECTOR_MATRIX.md](LEAD_ACQUISITION_CONNECTOR_MATRIX.md)):

| Attribute | Contributing connectors | Improves existing Leads? | Qualifies new Candidates? |
|---|---|---|---|
| Identity (name) | all org sources | ✅ (name normalization) | ✅ |
| Government IDs — UEI | USASpending, SAM | ✅ (match/verify) | ✅ (definitive identity) |
| Government IDs — CAGE | **SAM only** | ✅ | ✅ |
| Government IDs — EIN/CIK | IRS / SEC | ◐ | ✅ |
| Website | SAM, SEC | ✅ (fills blank Website) | ✅ |
| Address | SAM, SEC, IRS (USASpending: state only) | ✅ | ✅ |
| Contact (phone) | SAM | ✅ | ◐ (email still needed) |
| Contract activity | USASpending | ✅ (intent signal) | ◐ (context) |
| Certifications / business type | SAM (attributes) | ✅ | ◐ |
| NAICS | (payloads carry it; **unmapped** — gap G2) | ✅ | ✅ |
| Business profile (revenue/employees) | none (gov sources) → Lead Enrichment | ✅ (enrichment) | ✗ |
| Source confidence / provenance / timestamps | all (computed) | ✅ | ✅ |

**Improves existing Leads vs qualifies new Candidates:** a discovered org whose UEI/CAGE matches an existing Lead →
its fields **improve that Lead** (via the gated enrichment path, never overwriting good data). A discovered org with
**no** Lead match → **qualifies a new Candidate** (`Needs Review`). The dedup step already makes this determination.

## 3. Completeness assessment (Phase 3) — implemented (pure, safe)
`OA_LeadCompleteness.evaluate(OA_CanonicalOrg)` → `{score 0-100, band, breakdown}`. **Pure computation — no DML/SOQL/
callout.** Weighted model (sums 100): Identity 10 · Government 20 (UEI 10/CAGE 5/EIN|CIK|NPI 5) · Location 12 · Website 10
· NAICS 10 · Phone 5 · Contract 15 · Business profile 13 · Email 5 (enrichment-phase). Bands: **≥90 Campaign Ready ·
70–89 Review · <70 Needs Enrichment**.
- **Check-only validated:** `0AfPn0000023cFhKAI` — 5 tests / 0 failures. Source-only; **not deployed**.
- Behaves as designed: a SAM-like acquisition profile (identity+UEI+CAGE+address+website) scores **~47 → Needs Enrichment**; a fully-fused+enriched profile scores **95 → Campaign Ready** — proving acquisition establishes identity and enrichment lifts readiness. No auto-enrichment; report-only.
- Reuses the same banded model as the enrichment quality score — one scoring philosophy, not a duplicate engine.

## 4. Source fusion strategy (Phase 4) — design (no connector-specific logic)
Today, a 2nd source for an org already staged (same `Canonical_Key__c`) is flagged **Duplicate**. Fusion upgrades this to
a **merge into the existing Candidate**, applying generic, config-driven rules:

1. **Trusted-source precedence (field-level, data-driven — not code branches):** per canonical field, a precedence order,
   e.g. identity/registration: **SAM > USASpending > SEC > IRS**; awards/contract: **USASpending** authoritative; CIK:
   **SEC**; EIN: **IRS**. Encoded as a static map or an optional CMDT (`OA_Source_Precedence__mdt`) — the fusion engine
   itself is source-agnostic.
2. **Conflict resolution:** higher-precedence source wins a conflicting field; **never overwrite a populated field with a
   blank**; equal precedence → **newest** (`Last_Evaluated__c`) wins.
3. **Newest vs authoritative:** authoritative (precedence) for stable identity/registration; **newest** for volatile
   values (award totals, registration expiration).
4. **Provenance retention:** record per-field `{value, source, timestamp}` in the existing `Discovery_Metadata__c` (JSON);
   keep `Source_System__c` as the primary/first source; no data is discarded — a reviewer can see every source's value.
5. **Confidence scoring:** fused confidence = max of contributing sources; **corroboration boost** when ≥2 independent
   sources agree on the canonical key (raises `Confidence_Score__c`).

**Implementation path (gated, future):** enhance `OA_CandidateDiscoveryService` — when an incoming org matches a staged
`Canonical_Key__c`, call a generic `fuse(existing, incoming, precedence)` and **update** the existing Candidate instead
of flagging Duplicate. Reuses `OA_Discovered_Organization__c` + `Discovery_Metadata__c`; **no new object; no new field
required** (optional `OA_Source_Precedence__mdt` config only). Not built this sprint (it does DML updates → gated).

## 5. Metadata reuse analysis (Phase 5)
| Need | Reused existing | New? |
|---|---|---|
| Canonical model | `OA_CanonicalOrg` | — |
| Candidate persistence | `OA_Discovered_Organization__c` | — |
| Provenance store | `Discovery_Metadata__c` (JSON) | — |
| Dedup / match | `OA_CandidateDiscoveryService` | — |
| Review | `OA_Enrichment_Exception__c` + `Qualification_Status__c` | — |
| Completeness score | *(none existed)* | 🟡 `OA_LeadCompleteness` (pure Apex, validated) |
| Fusion precedence config | (design) optional `OA_Source_Precedence__mdt` | future/gated |

**No duplicate metadata; no unnecessary object; no new field.** One net-new pure utility class.

## 6. Validation (Phase 5)
| Check | Result |
|---|---|
| New production Leads | ✅ none |
| Account changes | ✅ none |
| Candidate automation | ✅ none |
| Scheduling | ✅ none |
| Connector activation | ✅ none (registry unchanged, disabled) |
| Duplicate metadata | ✅ none (reuse-verified) |
| Unnecessary objects | ✅ none |
| Check-only validation | `0AfPn0000023cFhKAI` (OA_LeadCompleteness, 5 tests/0 fail) |

The 3 USASpending pilot candidates remain in `OA_Discovered_Organization__c` (Needs Review), untouched.

## 7. PASS / WARN / FAIL — 🟢 PASS
- 🟢 PASS — architecture reuse confirmed (no new framework object); canonical mapping produced; completeness score implemented + validated (pure/safe); fusion strategy designed (config-driven, no connector-specific logic); no duplicate metadata; no writes/automation.
- 🟡 WARN — fusion merge not yet implemented (gated, does DML updates); NAICS still unmapped (G2); SAM still credential-gated.
- 🔴 none.

## 8. Remaining architectural gaps
G1 generic discovery driver · **G2 NAICS parser mapping** · G3 SAM credential · **G8 source-fusion merge in the service (this sprint's design)** · G4 completeness-score persistence/report surfacing · G5 candidate analytics deploy · G6 least-privilege runtime user · G7 org Matching/Duplicate Rules.

## 9. Recommended next connector & next approval gate
**Next connector:** SAM Entity (highest incremental value; fusion pays off most once SAM adds CAGE/address/website to USASpending's UEI/awards for the same UEI) — gated on data.gov key + JIT EC grant + alpha→prod endpoint; **SEC EDGAR** as the no-gate parallel.
**Next approval gate (🔴 Louis):** SAM credential setup; implement + gated-deploy the fusion merge (G8) + NAICS mapping (G2); any connector activation/pilot; any merge to `main`.
