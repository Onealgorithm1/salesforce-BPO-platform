# ADR-015 — Opportunity Intelligence Platform

**Status:** Proposed (design-only; awaiting Louis's approval) · 2026-07-07
**Program:** 2 (after Lead Enrichment v1.1, certified/closed)
**Supersedes/relates:** parent vision **ADR-011 External Intelligence Platform** (design branch); reuses ADR-005 (connector framework), ADR-006 (canonical model), ADR-007 (entity resolution), ADR-008 (security/credential), ADR-009 (metadata registry), ADR-010 (definition of ready).

> **ADR numbering note:** filed as **ADR-015** (not ADR-013 as the sprint brief suggested) because ADR-011/012 already exist on the `design/lead-enrichment-platform` branch and **ADR-013 (LinkedIn OAuth) / ADR-014 (Enterprise Auth)** are already used by a parallel workstream. Reconciling the ADR sequence across branches is an open governance item.

## Context
Lead Enrichment (Program 1) answers *"who is this company"* — it enriches existing Leads/Accounts from public data. **Opportunity Intelligence (Program 2)** answers *"what should we pursue"* — it discovers, normalizes, scores, and routes **federal/state funding & contract opportunities** for human go/no-go decisions. It is the first concrete program under the External Intelligence Platform vision (ADR-011).

## Purpose
Turn the firehose of public procurement/grant opportunities into a **ranked, explainable, human-reviewed pursuit pipeline** — without ever auto-committing the business to anything.

## Scope (this program)
- Fetch opportunity postings from public sources (SAM.gov Contract Opportunities first).
- Normalize into a source-neutral **Opportunity Signal**.
- Deduplicate across sources and over time.
- Score **fit / go-no-go** with explainable, auditable rules (no AI required for v1).
- Create an **internal review record** (Go/No-Go Assessment + Pursuit Candidate) for a human.
- Full run telemetry + audit, dormant-by-default, reversible.

## Non-scope (explicitly NOT this program)
- **No** automatic creation of a Salesforce `Opportunity`.
- **No** outreach, email, or CampaignMember changes.
- **No** proposal submission or any external write (SAM/Grants/FedConnect are **read-only**).
- **No** grant *submission* automation (grant *management* is a later phase).
- **No** modification/redesign of Lead Enrichment, the connector framework, EDWOSB/Meeting/LinkedIn work.
- **No** AI decisioning in v1 (rules only; AI is a later, human-in-the-loop phase).

## Relationship to Lead Enrichment
- **Separate program, shared platform.** Reuses the *connector SDK* (`OA_ConnectorRunner`, `OA_ConnectorHttp`, registry CMDT, `OA_Connector_Run__c` telemetry), the *canonical common-header* pattern (ADR-006), *entity resolution* (ADR-007), and the *security standard* (ADR-008, Named/External Credentials).
- **Different grain.** Lead Enrichment writes to **Lead/Account** (entity facts). Opportunity Intelligence writes to **new Opportunity-Intelligence objects** (opportunity facts) and **never writes to Lead Enrichment objects.**
- **Optional linkage (later):** a scored opportunity may reference a matched Account/Lead via ADR-007 resolution, but that is read-only association, not enrichment.

## Object model (design only — Track D; no build here)
| Object | Grain | Purpose | Key fields (indicative) | Relationships |
|---|---|---|---|---|
| **`OA_Opportunity_Source__mdt`** (CMDT, reuse registry pattern) | config | one row per source | `Source_Key__c`, `Connector_Class__c`, `Parser_Class__c`, `Named_Credential__c`, `Endpoint_Path__c`, `Enabled__c` (default false), `Refresh_Cadence__c` | — |
| **`OA_Opportunity_Run__c`** *(or reuse `OA_Connector_Run__c`)* | run | telemetry/provenance per fetch | `Run_ID__c` (ExtId), `Source__c`, `Status__c`, `Requested/Parsed/New/Deduped__c`, `Started/Ended__c`, `Initiated_By__c` | parent of Signals |
| **`OA_Opportunity_Signal__c`** | one opportunity posting (canonical) | the normalized opportunity | `Canonical_Key__c` (ExtId/Unique = dedupe identity), `Title__c`, `Solicitation_Number__c`, `Source__c`, `Agency__c`, `NAICS__c` (multi), `Set_Aside__c`, `PSC__c`, `Place_of_Performance__c`, `Posted_Date__c`, `Response_Deadline__c`, `Estimated_Value__c`, `Type__c` (Contract/Grant/SBIR/…), `URL__c`, `Status__c`, `Confidence__c`, `Review_Status__c` (Pending) | child of Run; parent of Score/Assessment |
| **`OA_Opportunity_Score__c`** | one scoring pass on a signal | explainable scorecard | `Signal__c` (M-D), `Total_Score__c`, `Band__c` (High/Med/Low), per-factor sub-scores + reasons (`NAICS_Score__c`, `SetAside_Score__c`, `Value_Score__c`, `Deadline_Score__c`, `Geo_Score__c`, `Capability_Score__c`, `PastPerf_Score__c`, `Partner_Need__c`, `Risk__c`), `Ruleset_Version__c`, `Explanation__c` (Long Text) | child of Signal |
| **`OA_Go_NoGo_Assessment__c`** | human decision record | the review artifact | `Signal__c`, `Score__c`, `Recommendation__c` (Go/No-Go/Watch — system draft), `Decision__c` (blank until human), `Decided_By__c`, `Decided_At__c`, `Rationale__c` | child of Signal |
| **`OA_Pursuit_Candidate__c`** | a pursued opportunity | pipeline hand-off (internal) | `Signal__c`, `Assessment__c`, `Stage__c` (Draft/UnderReview/Approved/Rejected), `Owner`, `Partner_Needed__c`, `Notes__c` | child of Signal; *may* link Account (read-only) |

**Standard objects eventually touched (later phases, human-gated):** `Opportunity` (created only on human approval), `Task` (proposal tasks), `Account`/`Contact` (read-only association via ADR-007). **None touched in the first slice.**

## Connector reuse strategy
Reuse the frozen SDK: dynamic `OA_ConnectorRunner` dispatch from the registry CMDT, `OA_ConnectorHttp` wrapper, `OA_Connector_Run__c` telemetry, Named/External Credential auth (ADR-008). New sources are **config + a thin per-source Request/Parser/Mapper**, exactly like the enrichment connectors — **no framework changes.** Opportunity mappers emit `OA_Opportunity_Signal__c` rows (not Lead proposals).

## Scoring model (Track F — explainable, auditable, no AI)
A weighted, transparent rule set producing a 0–100 `Total_Score__c` and a Band. Every factor writes a sub-score **and a reason string**:
| Factor | Signal input | Rule (indicative) | Weight |
|---|---|---|---|
| NAICS match | `NAICS__c` vs OA's NAICS list | exact=full, adjacent=partial, none=0 | 20 |
| Set-aside match | `Set_Aside__c` vs OA certs (EDWOSB/WOSB/SB) | eligible=full, open=partial, ineligible=0 | 15 |
| Agency fit | `Agency__c` vs target-agency list | 12 |
| Capability fit | keywords vs OA capability library | 12 |
| Contract value | `Estimated_Value__c` in target band | sweet-spot=full, too big/small=partial | 10 |
| Deadline urgency | `Response_Deadline__c` − today | enough runway=full, too soon=penalty | 10 |
| Geography | `Place_of_Performance__c` vs OA footprint | 8 |
| Past-performance fit | vs OA past awards (USASpending — reuse!) | 8 |
| Partner need | capability gap → flag `Partner_Needed__c` | (flag, not score) | — |
| Risk level | incumbent present / short runway / clearance | penalty | −up to 15 |
Bands: **High ≥70, Med 45–69, Low <45**. `Ruleset_Version__c` stamped for auditability. Weights live in CMDT so tuning needs no code.

## Go/No-Go logic
System produces a **draft** `Recommendation__c` (Go if High band + no disqualifier; Watch if Med; No-Go if Low or hard disqualifier such as ineligible set-aside). **The system never sets `Decision__c`.** A human reviews the Assessment and records the final Go/No-Go.

## Governance & human-approval gates (Track H)
**Automated (allowed, dormant-by-default):** fetch · normalize · dedupe · score · draft recommendation · route to review · create internal `OA_Opportunity_Signal__c`/`Score__c`/`Assessment__c`/`Pursuit_Candidate__c`.
**Human approval REQUIRED before (hard gates):** creating a Salesforce `Opportunity` · sending any outreach · assigning a pursuit owner · marking go/no-go **final** · creating proposal `Task`s · **any** external submission.
**Security (ADR-008):** all sources read-only via Named/External Credentials; secrets only in External Credentials; least-privilege runtime user is the intended model (inherits the Lead-Enrichment MAD-`oauser` exception as a temporary carryover). Full run telemetry + reversible audit; connectors/sources dormant (`Enabled__c=false`) until explicitly enabled.

## First vertical slice (Track G)
**SAM.gov Contract Opportunities** — fetch → normalize to `OA_Opportunity_Signal__c` → score → create `OA_Go_NoGo_Assessment__c` (draft) for human review. **Does not** create an Opportunity, send outreach, submit anything, or touch Lead Enrichment. Detail in `SPRINT27_IMPLEMENTATION_PLAN.md`.

## Consequences
- **Positive:** reuses a proven, certified platform; explainable/auditable; safe (read-only, human-gated); incremental.
- **Negative/《risks:** SAM.gov Opportunities API is a *different* endpoint/auth than the SAM Entity API (needs its own credential — the existing SAM key work is unresolved); scoring quality depends on curated OA capability/NAICS lists; dedupe across sources is non-trivial (reuse the enrichment dedupe pattern).
- **Reversible:** design-only; nothing built or deployed.
