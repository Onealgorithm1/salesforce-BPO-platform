# Connector Deployment Readiness — Lead Enrichment (Production)

**Date:** 2026-07-08 · **Mode:** READ-ONLY live-org audit · **Org:** `00Dbn00000plgUfEAI` (verified by ID)
**Legend:** ✅ present/verified · ❌ absent · 🔴 gate · dormant = deployed but disabled

> Phase 3. Each connector cross-checked: repository ↔ production class ↔ credential ↔ registry ↔ enabled ↔
> permission ↔ scheduler ↔ runtime state ↔ expected behavior. All facts from live queries.

---

## 1. Enrichment connector matrix (live)

| Connector | Repo | Prod class | Credential (prod) | Registry (prod) | Enabled | Permset | Scheduler | Runtime state | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **USASpending** | ✅ | ✅ `OA_USASpending_Connector` | NC `OA_USASpending` ✅ (NoAuth, public) | ✅ row | false | staging unassigned | none | dormant | 🟢 **READY** (certified, live-proven) |
| **SAM Entity** | ✅ | ✅ `OA_SAM_Connector` | NC `OA_SAM` ✅ (endpoint **alpha**) + EC `OA_SAM` ✅ but **0 principal grants** | ✅ row | false | `OA_SAM_Connector` unassigned | none | dormant | 🟡 **READY-WITH-CONDITIONS** — needs data.gov key, JIT EC principal grant, alpha→prod endpoint |
| **SEC** | ✅ | ✅ `OA_SEC_Connector` | NC `OA_SEC` ✅ (NoAuth, public) | ✅ row | false | unassigned | none | dormant | 🟢 **READY** |
| **IRS** | ✅ | ✅ `OA_IRS_Connector` | none (bulk CSV, no callout NC) | ✅ row | false | unassigned | none | dormant | 🟢 **READY** |
| **Census** | ✅ | ✅ `OA_Census_Connector` | NC `OA_Census` ✅ (NoAuth, public) | ✅ row | false | unassigned | none | dormant | 🟢 **READY** |
| **State Registry** | ✅ | ✅ `OA_StateRegistry_Template` | none (template) | ✅ row (template) | false | unassigned | none | dormant | 🟡 **TEMPLATE** — scaffold, no live source; keep dormant |
| **SAM Opportunities** | ✅ | ❌ not deployed | NC `OA_SAM_Opportunities` ❌ not in prod | ❌ not in prod | n/a | n/a | none | **not deployed** | ⚪ **OI, out of LE scope** (repo-only) |
| **Grants.gov** | ✅ | ❌ not deployed | NC `OA_GrantsGov` ❌ not in prod | ❌ not in prod | n/a | n/a | none | **not deployed** | ⚪ **OI, out of LE scope** (repo-only) |
| **Meta** | ✅ | ✅ (NC `OA_Meta` + EC ✅) | NC/EC ✅ | not a registry connector | n/a | `OA_Meta_Connector` unassigned | none | live (social) | ⚪ **Social/marketing, not enrichment** |
| **LinkedIn** | ✅ | ✅ (NC `OA_LinkedIn` + EC + AuthProvider ✅) | NC/EC ✅ | not a registry connector | n/a | `OA_LinkedIn_Connector` unassigned | none | live (social) | ⚪ **Social/marketing, not enrichment** |

## 2. Notes per connector
- **USASpending** — the certified, live-proven source (78 Leads enriched via it). Public API, no secret. Ready to enable behind the go-live gate.
- **SAM Entity** — plumbing complete (class, NC, EC) but three conditions remain: (1) confirmed data.gov key in the EC, (2) JIT EC principal-access grant (live check: **0 grants** — cannot authenticate today), (3) NC endpoint on **alpha** (`api-alpha.sam.gov`) should move to prod `api.sam.gov`. All 🔴-gated.
- **SEC / Census** — public NoAuth NCs verified live; ready.
- **IRS** — bulk CSV, no callout credential; ready.
- **State Registry** — deliberate template; not a real source. Keep dormant or remove its registry row (Registry Review R-3).
- **SAM Opportunities / Grants.gov** — Opportunity Intelligence connectors; **classes, NCs, and registry rows are NOT in production** (repo-only, dormant). Explicitly out of Lead-Enrichment scope; no LE risk.
- **Meta / LinkedIn** — social/marketing connectors (live for their own use); not part of the Lead-Enrichment registry or write path.

## 3. Phase-3 verdict
| Group | Verdict |
|---|---|
| USASpending, SEC, IRS, Census | 🟢 READY (dormant; enable behind go-live gate) |
| SAM Entity | 🟡 READY-WITH-CONDITIONS (key + JIT grant + prod endpoint) |
| State Registry | 🟡 template (keep dormant) |
| SAM Opportunities, Grants.gov | ⚪ OI, not deployed, out of scope |
| Meta, LinkedIn | ⚪ social, not enrichment |

**Overall:** the Lead-Enrichment connector fleet is **deployed dormant and internally consistent in production**.
Four of five real enrichment connectors are READY; SAM is the only one with open credential conditions. Enabling any
connector (`Enabled__c=true`), assigning any permset, or granting EC principal access are all 🔴 gates.
