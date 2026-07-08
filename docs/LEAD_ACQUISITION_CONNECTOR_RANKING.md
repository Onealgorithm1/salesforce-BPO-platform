# Lead Acquisition — Connector Quality Ranking & Activation Roadmap (Phase 4–5)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` · **Mode:** evidence-based ranking (no deploy, no activation)

> Ranks every acquisition connector by **incremental business value** (not ease) and recommends the next to activate,
> supported by the field-availability evidence and the live USASpending pilot.

---

## 1. Scoring (1–5; higher = better)

| Connector | Data quality | Coverage | Reliability | Update freq | Business usefulness | Impl. complexity (5=easy) | Maint. burden (5=low) | **Weighted value** |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **SAM Entity** | 5 (UEI+CAGE+addr+web+phone) | 5 (all federal-registered orgs) | 4 | 4 (near-real-time registry) | **5** (authoritative federal identity) | 2 (key+JIT+prod endpoint) | 3 | **⭐ Highest** |
| **USASpending** | 4 (UEI+name+state+awards) | 4 (all award recipients) | 5 (proven live) | 4 | 4 (contract intent signal) | 5 (public, proven) | 4 | **High** |
| **SEC EDGAR** | 3 (CIK+addr+web, no UEI) | 3 (public filers only) | 5 (public) | 3 | 3 (large public cos, off-ICP) | 5 (public) | 4 | Medium |
| **IRS Tax-Exempt** | 3 (EIN+addr) | 3 (nonprofits) | 4 (bulk CSV) | 2 (periodic file) | 2 (nonprofit ICP fit low) | 3 (bulk parsing) | 3 | Low-Med |
| **Census** | 1 (no org identity) | — | 5 | 2 | 1 (not org discovery) | 5 | 5 | **Not suitable** |
| **Grants.gov** | 2 (opportunity-shaped) | 3 | 4 | 3 | 2 (OI-scoped, not entities) | 2 (Framework-A adapter) | 2 | Defer (OI) |

## 2. Deployment order (by incremental business value + gating reality)
1. ✅ **USASpending** — done (pilot PASS). Highest value already unblocked (public, proven).
2. **SAM Entity** — **highest remaining value** (richest identity: UEI+CAGE+address+website). Gated on data.gov key + JIT EC principal grant + alpha→prod endpoint.
3. **SEC EDGAR** — public, no gate; medium value (adds website/address for public cos). Good "second free source" while SAM credential is pending.
4. **IRS Tax-Exempt** — situational (nonprofit ICP); bulk.
5. **Census** — do not activate for discovery (not an org registry).
6. **Grants.gov** — defer (OI boundary; needs an entity-extraction adapter).

## 3. Next connector recommendation (Phase 5) — evidence-based
**Recommend: SAM Entity as the next connector to activate — highest incremental business value — with SEC EDGAR as the
immediate no-gate parallel.**

Rationale (evidence, not ease):
- The field matrix shows **SAM is the only source that supplies CAGE + full address + website + phone alongside UEI** — exactly the identity fields the Lead Completeness Model weights most and that USASpending lacks. It moves candidates furthest toward Campaign Ready in one call.
- USASpending (already live) covers award-recipient identity; SAM **complements** it with registration/firmographic identity — highest *incremental* gain.
- **But SAM is gated** (data.gov key + JIT EC principal grant + alpha→prod endpoint — 0 grants confirmed). So: **pursue the SAM credential unlock as the priority, and in parallel activate SEC EDGAR** (public, zero-gate) to keep discovery advancing while the SAM credential is resolved.
- Do **not** default to the easiest (SEC/IRS) as the *primary* choice — they add less identity value; they are the parallel/fallback, not the headline.

## 4. Recommended activation roadmap
| Step | Connector | Gate | Value |
|---|---|---|---|
| 1 (done) | USASpending | — | proven |
| 2 (priority) | **SAM Entity** | 🔴 data.gov key + JIT EC grant + prod endpoint | highest incremental |
| 3 (parallel, no gate) | **SEC EDGAR** | 🔴 deploy/run only (public) | medium, immediate |
| 4 | IRS Tax-Exempt | 🔴 bulk run | situational |
| — | Census | do not activate | n/a |
| — | Grants.gov | defer (OI) | n/a |
Each activation = enable connector + manual preview→commit pilot (reuse `OA_CandidateDiscoveryService`), then review.
