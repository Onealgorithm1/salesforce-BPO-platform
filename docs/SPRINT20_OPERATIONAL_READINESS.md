# Sprint 20 — Production Operational Readiness (Evidence-Based)

_Executed 2026-07-07 · Org **00Dbn00000plgUfEAI** (onealgorithmllc.my.salesforce.com) · all findings via Salesforce CLI · no secrets exposed · platform DORMANT throughout_

## Executive summary (plain English)
- **The enrichment pipeline works against live production data — with zero writes.** A preview over the 25 pilot Leads pulled real federal-contractor records from USASpending for 8 of them, proposed 56 field values, and wrote **nothing** (`dmlRows = 0`).
- **The platform is genuinely dormant and safe:** all 6 connectors disabled, 0 active write policies, execution engine not deployed, nothing scheduled. The preview bypassed all of that in-memory without changing any production config.
- **One functional gap remains before a real 25-Lead write:** no write policy is active (0 of 19), and the Sprint 17 execution engine isn't deployed to the org. Both are small, reversible, gated steps — not new development.
- **Decision: GO for a controlled 25-Lead write pilot** once a fill-empty policy is activated and you approve — **NO-GO** for 100-Lead, scheduled, or batch execution until the engine is deployed and the least-privilege user replaces `oauser`.
- **Lead Enrichment is NOT yet operationally complete** (one controlled write pilot remains). Do **not** start Opportunity Intelligence yet.

---

## Track A — Production verification
- Org **00Dbn00000plgUfEAI**, `oauser@pboedition.com`, Connected ✓ · branch `main` = origin/main = `15d1e2a` (in sync) · tag `lead-enrichment-v1.0` = `485f7dc` (unchanged).
- **Class existence in production (Tooling API):**

| Class | In prod? | Note |
|---|---|---|
| `OA_ConnectorRunner` | ✅ Yes | v1.0 platform |
| `OA_EnrichmentWriter` | ✅ Yes | v1.0 platform |
| `OA_EnrichmentOrchestrator` | ❌ **No** | Sprint 17 — **never deployed** |
| `OA_EnrichmentQueueable` | ❌ **No** | Sprint 17 — **never deployed** |
| `OA_ProposalAdapter` | ❌ **No** | Sprint 17 — **never deployed** |

**Why missing — evidence-based, not a guess:** the three Sprint 17 classes were only ever **check-only validated** (`0AfPn0000023185KAA`, `0AfPn00000235zhKAA`) and merged to `main` (source control), but **no deploy to the org was ever run**. Not excluded, not another org, not a deploy failure — simply never deployed (Sprint 17 was intentionally "validated + dormant"). The direct enrichment path (runner → mapper → writer) does **not** require them and is fully deployed.

## Track B — Deployment audit (git ↔ production ↔ docs)
- **Apex (deployed):** all v1.0 platform + connector classes present (runner, writer, policy engine, change-log service, 6 connectors + mappers, canonical, exception routing). **Repo-ahead-of-org:** `OA_EnrichmentOrchestrator/Queueable/ProposalAdapter` and Named Credentials `OA_Census`/`OA_SEC` exist on `main` but not in the org (all additive, dormant).
- **Objects (deployed):** `OA_Connector_Run__c` (2), `OA_Enrichment_Change_Log__c` (6), `OA_Enrichment_Exception__c` (1), `OA_Discovered_Organization__c` (0), `OA_Discovered_Organization__c`, `OA_SAM_Entity_Staging__c`.
- **Custom Metadata (deployed):** `OA_Connector_Registry__mdt` × 6 (all `Enabled__c=false`, `Status__c=Draft`); `OA_Field_Write_Policy__mdt` × **19 (0 active)**.
- **Permission Sets (deployed):** `OA_Lead_Enrichment_Runtime` (1 assignment), `OA_SAM_Connector` (0), `OA_Connector_Staging` (0).
- **Named Credentials (deployed in org):** `OA_USASpending` (endpoint set), `OA_SAM` (SecuredEndpoint, alpha URL), `OA_Anthropic` (unrelated). **`OA_Census`/`OA_SEC` on `main` but NOT deployed.**
- **External Credentials (deployed):** `OA_SAM` (NamedPrincipal `OA_SAM_Principal` + `X-Api-Key` header), plus unrelated `OA_Anthropic`/`OpenAI`.
- **Doc reconciliation:** `RELEASE_1.0.md` (v1.0 baseline) still says the orchestrator is "not built" — historically correct for the tag; a forward-pointer header now marks it superseded (orchestrator built in Sprint 17, on `main`, not yet deployed).

## Track C — Connector readiness matrix (live)
| Connector | Class deployed | Registry enabled | Named Cred | Endpoint (live) | Auth | Deploy status | Op status | Class |
|---|---|---|---|---|---|---|---|---|
| **USASpending** | ✅ | ❌ (Draft) | `OA_USASpending` ✓ | `https://api.usaspending.gov` | none (public) | Deployed dormant | **Preview-proven (200 OK, 8/25 matched)** | 🟢 **READY** |
| **IRS** | ✅ | ❌ | n/a (bulk CSV) | n/a | none | Deployed dormant | No callout path | 🟢 **READY** (needs CSV input) |
| **Census** | ✅ | ❌ | `OA_Census` (on main, **not deployed**) | needs `https://api.census.gov` | none | NC prepared/validated | Cannot call until NC deployed | 🟡 **NEEDS SETUP** |
| **SEC** | ✅ | ❌ | `OA_SEC` (on main, **not deployed**) | needs `https://data.sec.gov` | User-Agent (in code) | NC prepared/validated | Cannot call until NC deployed | 🟡 **NEEDS SETUP** |
| **SAM** | ✅ | ❌ | `OA_SAM` ✓ | `https://api-alpha.sam.gov` (alpha) | `X-Api-Key` (EC) | Deployed | **No principal access** (0 grants) + alpha endpoint + unconfirmed key | 🔴 **BLOCKED** |
| **State Registry** | template only | ❌ | `OA_StateRegistry` (none) | n/a | n/a | Template | Not a real connector | 🔴 **BLOCKED (template)** |

## Track D — Runtime audit (dormancy confirmed)
- Runtime permset `OA_Lead_Enrichment_Runtime` **assigned to `oauser`** (1) — FLS on trusted enrichment fields; kept assigned (revoking hides fields).
- FLS: enrichment fields readable/writable by runtime permset (preview read all 8 mapper-target fields successfully).
- Rollback: `OA_ChangeLogService` deployed; `rollback()` proven Sprint 16 (5/5). Audit: change-log + exception objects present. Exception routing: `OA_ExceptionRoutingService` deployed.
- Qualification: `OA_DiscoveryQualificationEngine` deployed (invoked only when a ruleset is passed).
- Write policies: **19 defined, 0 active** → no write can occur. **Platform confirmed DORMANT.**

## Track E — Preview validation (LIVE, no writes)
Ran the full pipeline (connector → parser → canonical → mapper → writer preview) over the **25 pilot Leads** via anonymous Apex, using the real registry row as an **in-memory** config (deployed registry left disabled). `commitWrites=false`.

**Result summary (CLI evidence):**
```
leadsProcessed=25  matched=8  proposalsTotal=56  httpErrors=0
actualEngineWrites=0   (live policy engine → SKIP_NO_POLICY for every field: dormant)
fillEmpty_wouldWrite=48  wouldConflict=8  skipFilled=0
dmlRows=0   callouts=25
```
- **8 matched Leads** (all HIGH confidence, real UEIs): Faustson Tool (`H5C2QE2NY1B1`), Navigational Services, Telford Aviation, Columbia Industrial Products, National Crane Services, Lavin INC, Osar Solutions, Dc Fabricators.
- **Per matched Lead:** 7 proposals; under a fill-empty policy **6 would fill blanks** (`UEI__c, Federal_Contractor__c, Total_Award_Amount__c, Award_Count__c, Awarding_Agencies__c, Latest_Award_Date__c`) and **1 conflict** (`State`) — the Lead holds a full state name (e.g. "Colorado") while USASpending returns a code ("CO"), so fill-empty **routes it to the exception queue, never overwrites**. (Data-normalization nuance, not a defect.)
- **17 unmatched Leads:** no federal awards (small firms, individuals, internal "One Algorithm LLC" test Leads) — correct.
- **Confidence:** all matches HIGH. **Exceptions:** none in preview. **Rollback readiness:** service present, ready.
- **Zero side effects verified:** record counts unchanged (2/6/1/0), registry still 0 enabled, matched Lead `Faustson` still UEI/fields = null.

## Track F — Operational readiness classification
| Capability | Status | Blocker(s) |
|---|---|---|
| **Preview (no write)** | 🟢 **GREEN** | None — proven today, repeatable, zero footprint. |
| **Controlled 25-Lead write** | 🟡 **YELLOW** | Activate a fill-empty write policy (0/19 active — CMDT change, reversible) + explicit approval. Runs via the proven direct path (commit=true) or the orchestrator. Runtime = MAD `oauser` (accepted exception). |
| **Rollback** | 🟢 **GREEN** | Every commit write emits a before-snapshot change log; `rollback()` proven. |
| **Monitoring / audit** | 🟡 **YELLOW** | Auditing complete (change logs/exceptions/runs). Dashboards build-ready but **not deployed** (advisory SOQL works meanwhile). |
| **Batch execution** | 🔴 **RED** | `OA_EnrichmentOrchestrator` (Batch) **not deployed** to the org. |
| **Scheduled execution** | 🔴 **RED** | Needs orchestrator deployed + least-privilege runtime user + a passing 25→100 pilot. Out of scope. |

## Track H — Final readiness review (verified answers)
1. **Is every required production component deployed?** — **No.** v1.0 platform is fully deployed; the Sprint 17 execution layer (orchestrator/queueable/adapter) and Census/SEC NCs are on `main` but not deployed. The **direct enrichment path is fully deployed.**
2. **Can preview execute today?** — **Yes — done today** (25 Leads, 8 matched, 0 writes).
3. **Can a controlled 25-Lead enrichment execute today?** — **Yes, conditionally:** requires activating a fill-empty policy (config) + approval. No new code. Not executable "as-is" because 0 policies are active (by design).
4. **Can rollback recover every write?** — **Yes** — before-snapshot per write + proven `rollback()`.
5. **Are monitoring and auditing complete?** — **Auditing: yes. Monitoring dashboards: no** (build-ready, not deployed).
6. **Is a 100-Lead pilot justified?** — **Not yet** — run the 25-Lead write first.
7. **Is scheduled enrichment justified?** — **No** — needs orchestrator deploy + least-priv user + passing pilots.
8. **Is Lead Enrichment operationally complete?** — **No** — one controlled 25-Lead write pilot remains. **Do not declare CLOSED; do not begin Opportunity Intelligence.**

## GO / NO-GO decision
- 🟢 **GO** — first **controlled 25-Lead write** pilot, after: (1) activate the fill-empty policies for the 6 USASpending fill fields, (2) explicit approval, (3) run the proven path with `commitWrites=true`, (4) verify change logs + rollback readiness, (5) return to dormant.
- 🔴 **NO-GO** — 100-Lead, batch, or scheduled enrichment (engine not deployed; least-priv user not provisioned).

## Recommended Sprint 21
**Execute the controlled 25-Lead write pilot** (activate fill-empty policy → commit the 8 matched Leads' 48 fill-empty fields → verify audit + rollback → hold). Then decide on 100-Lead. **Opportunity Intelligence remains deferred** until Lead Enrichment is closed after a successful write pilot.
