# Daily Lead Generation + Enrichment — Production Operating Model

_Last updated: 2026-07-04 · Status: design (no code built, nothing scheduled, real-data write-back NOT authorized)_

This document is the blueprint for the eventual daily background pipeline that generates new
Leads, enriches existing Leads from approved public government APIs, writes verified data back
to Salesforce under strict governance, and provides monitoring, rollback, and hard stops. It
builds on the already-deployed **dormant** primitives: the connector SDK
(`OA_IConnector*` / `OA_ConnectorEngine` / `OA_ConnectorPersistence` / `OA_ConnectorHttp`),
the staging object `OA_USASpending_Staging__c`, the FLS-enforced write-back + rollback engine
`OA_LeadWritebackService`, the send-governor daily-counter pattern
(`OA_SendGovernor` / `OA_Campaign_Settings__c`), and the three permission sets.

---

## A. Purpose

- **Daily background new-Lead generation** from approved public sources.
- **Daily enrichment of existing Leads** with award history + entity/certification data.
- **Governed, staging-first write-back** to the 16 deployed Lead write-back fields.
- **Monitoring, rollback, and hard stop thresholds** on every stage.

Everything is **staging-first and human/gate-approved**; no source data ever touches a Lead
without passing the governance gates in §E.

---

## B. Baseline Status (as of 2026-07-04)

- PR #10 (campaign ops-log) — **MERGED**.
- PR #11 (Lead Write-Back package) — **MERGED**.
- Lead Write-Back engine — **deployed, Active, DORMANT** (deploy `0AfPn0000022YCXKA2` / rollback-enabled `0AfPn0000022Z29KAE`).
- Rollback helper — **deployed, DORMANT**.
- Functional canary — **COMPLETE** (`WB-…1783185213233`).
- Rollback drill — **COMPLETE** (`RB-…1783185291326`).
- Least-privilege canary — **DEFERRED** (no spare full Salesforce license).
- Real-data write-back — **NOT AUTHORIZED**.
- Connector — **DORMANT** (`OA_Connector_Staging` 0 assignments, staging holds only 1 synthetic test row).

---

## C. Target Workflows

### C.1 New Lead Generation (create Leads from approved public sources)

| Stage | Rule |
|---|---|
| Source discovery | Query an approved public API by targeting criteria (NAICS, set-aside/cert, state, agency) → candidate entities into a **discovery staging** row (never directly a Lead). |
| Staging | Each candidate persisted to a staging row with source, run id, raw + mapped fields; status `Pending`. |
| Dedupe | Deterministic `Dedupe_Key__c` (source + entity key); check existing Leads by UEI first, then prior discovery rows; re-run = refresh/upsert, never a duplicate. |
| Identity matching | Deterministic only (UEI exact, or exact normalized name+state). **No fuzzy match as a create key** (scores advisory only). |
| Approval / auto-verification | Tier-A deterministic signals may auto-qualify; anything below → human review before Lead creation. |
| Exclusions | Never create/enroll opted-out, converted, or test entities. |
| Audit logging | Every discovery/creation decision logged (source, run id, gate results) on the staging row. |
| Rollback | Staging-only at this stage; a bad discovery run is reversible by deleting rows by run id. Created Leads are tracked by creation run id for controlled removal if needed. |

New Leads are **not** auto-enrolled — campaign enrollment remains governed by the existing
campaign automation + send governor (a separate, already-live workstream).

### C.2 Existing Lead Enrichment (the already-built path, generalized)

| Stage | Rule |
|---|---|
| Source discovery / selection | Leads with a resolvable key (UEI or trusted name), not opted-out/converted/test, stale or never-enriched (`USASpending_Last_Enriched__c` null/old). |
| Staging | Connector callout → parse → map → idempotent upsert into the per-source staging object on `Dedupe_Key__c`; status `Pending` (or `Auto Verified` if Tier-A passes). |
| Dedupe | `Dedupe_Key__c` unique per source+entity; re-run refreshes. |
| Identity matching | Deterministic `Lead__c` link only; no fuzzy/auto-UEI fallback for write. |
| Approval / auto-verification | Tier-A deterministic → `Auto Verified` (`Auto_Verified_Date__c`, `Auto_Verification_Method__c`); below-Tier-A → `Pending` / `Exception / Needs Review` for a human (`Approved` / `Rejected`). |
| Exclusions | Skip opted-out / converted / test Leads. |
| Audit logging | `Gate_Results__c`, `Enrichment_Run_ID__c`, `Written_Back_By__c`, `Written_Back_Date__c`. |
| Write-back | Only `Approved` / `Auto Verified` rows via `OA_LeadWritebackService.writeBack(...)` — snapshot-first, FLS-enforced, capped. |
| Rollback | `OA_LeadWritebackService.rollback(...)` restores the 16 Lead fields from `Before_Snapshot__c`. |

---

## D. API Source Roadmap

| # | Prio | Source | Purpose | Input keys | Output fields | SF target/staging | Role | Risk |
|---|---|---|---|---|---|---|---|---|
| 1 | **High** | **SAM.gov Entity API** | Authoritative entity registry + socio-economic certs | UEI / legal name / NAICS / state / set-aside | Legal name, UEI, CAGE, registration status/expiry, NAICS, business types, WOSB/EDWOSB/SDVOSB/8(a), POC | `OA_SAM_Entity_Staging__c` (new) + Lead cert/UEI fields | **Both** | **Requires data.gov API key (NOT no-auth)** → secret in Named/External Credential; rate limits; POC PII |
| 2 | **High** | **USASpending API** | Federal award/spend history | UEI / recipient name | Award amount/id/desc, agencies, contract type, perf state | `OA_USASpending_Staging__c` (built) | Enrich (primary); Gen (recipients by NAICS/agency) | Already dormant/proven; name-match ambiguity → deterministic only |
| 3 | Low | FPDS / contract detail | Contract-action-level detail | PIID / UEI | Vehicle, obligated amounts, dates, place of performance | extend USASpending staging or new | Enrich | Clunky ATOM feed; largely superseded by USASpending → **likely Defer** |
| 4 | Low | SBA / DSBS-style | Small-business certification/profile | UEI / name | Cert status (8a/HUBZone/WOSB/SDVOSB), capabilities, NAICS | overlaps `OA_SAM_Entity_Staging__c` | **Both** | **No clean public API** (DSBS is a search UI); do NOT scrape — only if SBA offers a sanctioned API |
| 5 | Low | Grants.gov opportunity | Funding-opportunity intelligence (timing signal) | keyword / CFDA / agency | Open opportunities, deadlines, eligibility | `OA_Opportunity_Signal__c` (new, non-Lead) | Signal (neither gen nor enrich) | Opportunity-facing, not lead-facing → outreach-timing intel only |
| 6 | Separate | Metricool / marketing analytics | Social/web marketing metrics | account / channel | Reach, engagement, campaign perf | separate marketing objects | Neither | **Separate marketing workstream** — out of scope for lead gen/enrichment |

**Sequencing:** SAM.gov (identity + cert spine → feeds gen and enrichment, validates UEIs) → USASpending (already built, award history) → the rest are lower-priority or blocked on a clean API; Metricool is a different track.

---

## E. Governance Gates

| Gate | Rule |
|---|---|
| Source trust | Only approved public gov APIs via Named/External Credential; every row stamps `Source_Endpoint__c` + `Enrichment_Run_ID__c` |
| Identity match | Deterministic only — UEI exact, or exact normalized name+state; **no fuzzy match as a write/create key** |
| Duplicate detection | `Dedupe_Key__c` unique; re-run upserts/refreshes; Lead-create checks existing Leads by UEI first |
| Opt-out exclusion | Exclude any opted-out Lead/contact at both create and enroll |
| Converted exclusion | Exclude converted / won Leads |
| Test exclusion | Exclude `Is_Test_Lead__c = true` and `PREVIEW_TEST_DO_NOT_CONTACT` markers |
| Manual review | Below Tier-A → `Pending` / `Exception / Needs Review`; human sets `Approved` / `Rejected` |
| Auto-verification | Tier-A deterministic signals only → `Auto Verified` |
| Write-back approval | Only `Approved` / `Auto Verified` + deterministic `Lead__c` + required source fields |
| Rollback readiness | `Before_Snapshot__c` persisted before every Lead write; write proceeds only if snapshot persisted (tripwire = 0) |
| Daily cap | Shared daily counter per stage (mirrors `OA_SendGovernor` / `Sends_Today__c`); hard clamp; log truncation |

---

## F. Scheduling Model (design only — do not implement)

| Job | Purpose | Cadence | Start cap | Stop conditions | Required permissions (JIT) | Rollback | Monitoring output |
|---|---|---|---|---|---|---|---|
| 1. Source Discovery | Query approved API → discovery staging | Daily, off-peak | 25 candidates/run | API error / rate-limit; cap hit; dedupe anomaly | Connector read + discovery-write permset | Delete run by run id (staging only) | discovered / new / dupes / errors |
| 2. Enrichment Staging | Callout for selected Leads → staging | Daily | 25 Leads/run | API error; cap; 0 eligible | `OA_Connector_Staging` | Delete staging by run id | staged / http-errors / parse-errors |
| 3. Auto-Verification | Apply Tier-A gates → `Auto Verified` vs `Pending` | Daily (after job 2) | 200 rows | Gate-ambiguity spike | Reviewer read + verify permset | Reset status by run id | auto-verified / needs-review |
| 4. Write-Back | Promote `Approved`/`Auto Verified` → Lead | **Manual/JIT first; later daily** | **1 → 5 → 25 → 200** | Any tripwire > 0; FLS block; DML fail-rate | `OA_Lead_Writeback_Automation` (JIT → revoke) | `rollback(stagingIds)` | written / failed / snapshots / tripwires |
| 5. Monitoring / Report | Aggregate daily KPIs vs stop thresholds | Daily (after 1–4) | — | — | Reviewer read | — | full daily report (§H) |

Discipline: none scheduled initially. Jobs 1–3 are staging-only (safe to schedule earlier);
**job 4 stays manual/JIT until the least-privilege runtime user exists (§G) and a real canary
passes.** "Scheduled" ≠ "unattended" — every run must emit the §H report and honor §I stops.

---

## G. Runtime User Model

- **Why `oauser` is not acceptable long-term:** `oauser` is a System Administrator with
  **Modify All Data**, which bypasses the write-side FLS guardrail (`stripInaccessible`). Running
  production write-back as `oauser` voids the least-privilege guarantee and concentrates risk on a
  human admin account. (The `WITH USER_MODE` read guardrail holds even for MAD — proven in the
  functional canary.)
- **Full Salesforce license requirement:** write-back touches **Lead** (a core CRM object), which
  requires a full **`Salesforce`** license — Integration/Platform/Limited licenses cannot access
  Lead and therefore cannot do write-back.
- **Least-privilege user:** a dedicated **non-admin** identity on a **Minimum Access - Salesforce**
  profile, whose only Lead/staging access comes from permission sets.
- **Required permission sets (JIT → run → revoke):** `OA_Connector_Staging` (read staging source
  fields + object) **+** `OA_Lead_Writeback_Automation` (edit the 16 Lead fields + audit fields).
  Never standing.
- **Named Credential access:** granted to the runtime user via permission set (not profile) —
  `OA_USASpending`, future `OA_SAM`.
- **JWT / Connected App option:** for headless scheduled runs, a Connected App with **JWT bearer
  flow** (server cert) authenticating **as the least-privilege user** — enables non-interactive
  execution without a stored password; the clean path for scheduled jobs.
- **Fallback if no spare license:** org currently has **0 free `Salesforce` licenses** (2/2, both
  real people). Options: (a) procure/allocate a license; (b) temporarily free one (coordinate with
  the second admin) for a gated canary window; (c) an **Integration** license via JWT for
  **headless staging/enrichment only** (jobs 1–3) — but it **cannot** do write-back (no Lead access).
- **Blocked until resolved:** the **least-privilege canary** and any **real-data write-back**
  (Phases 5–6). Staging/enrichment design and dormant connector builds can proceed regardless.

---

## H. Monitoring / Reporting (minimum daily report)

new leads discovered · new leads created · existing leads enriched · staging rows created ·
rows auto-verified · rows needing review · rows written back · rows skipped (idempotency) ·
rows failed (by category) · API errors / rate-limit events · rollback-ready count ·
**stop-threshold status** (green / breached per §I).

Sourced from run-summary objects/logs (a small `OA_Run_Log__c` when operationalized — deferred;
until then, from the engine's in-memory `RunSummary` + `Gate_Results__c`). The four
**must-be-zero tripwires** (write-without-snapshot / -approval / -runId / fuzzy-match) are surfaced
as red/green tiles.

---

## I. Stop Thresholds (any breach → hard stop + roll back the affected run)

- **Write without snapshot** > 0 · **Write without approval** > 0 · **Write without run ID** > 0 · **Fuzzy match used** > 0 *(must-be-zero)*
- **Rollback failure** > 0
- **Duplicate Lead created** > 0
- **Opted-out Lead touched** > 0 · **Converted Lead touched** unexpectedly > 0
- **Campaign / send contamination** (any enrollment/send triggered by gen/enrichment) > 0
- **API failure rate** > ~10% or sustained **rate-limit (429)** events
- **Daily cap exceeded** (any stage over its clamp)
- **Connector callout failures** (non-2xx spike / Named-Credential/auth failure)

---

## J. Phased Roadmap

| Phase | Build category | Smallest deliverable | Production value | Risk | Entry criteria | Exit criteria |
|---|---|---|---|---|---|---|
| 1 — Operating model doc | **Document Now** | This document in `docs/` | Shared blueprint + guardrails | Low | Design approved | Doc merged to `main` |
| 2 — SAM.gov dormant connector foundation | **Build Now (dormant)** | `OA_SAM*` connector on the SDK + tests + `OA_SAM_Entity_Staging__c` + External/Named Credential definition (secret in credential store only), **not invoked** | Identity/cert spine ready | Med (API-key/secret handling) | Phase 1 done; data.gov API key provisioning approach agreed | Check-only validated; deployed dormant; 0 callouts; 0 assignments |
| 3 — USASpending staging execution | **Build Later** | Re-enable proven USASpending enrichment into staging on a small gated manual run | Real award-history staging | Med | Phase 2 pattern proven; runtime-user progress | Staging rows created + reviewed; 0 Lead writes |
| 4 — Scheduled staging-only enrichment pilot | **Build Later** | Jobs 1–3 scheduled at tiny caps (staging only, **no write-back**) | Daily staging pipeline | Med | Runtime user (or JWT headless read); monitoring live | N consecutive clean days; report green |
| 5 — Write-back pilot | **Defer (gated)** | Least-priv canary → 1→5→25→200 real-Lead writes with rollback drills | Governed real enrichment | **High** | **Least-priv full-license user + JWT; real canary passed; explicit approval** | Canary + pilot pass all §I thresholds; rollback proven |
| 6 — Daily production automation | **Defer (gated)** | Jobs 1–5 scheduled end-to-end at production caps | Full daily lead-gen + enrichment | **High** | Phase 5 passed; monitoring + stop-automation in place | Sustained green operation |

---

## K. Next Build Recommendation

**Phase 2 — SAM.gov Entity API dormant connector foundation** (source + check-only validation only;
no deploy, no callouts, no execution). It reuses the proven connector SDK, delivers the identity/
certification spine that powers both lead-gen and enrichment, needs no live callouts / permission
assignments / writes to prove out, and is **not blocked by the license issue** (a dormant build
needs no runtime user).

**Dependency — API key:** SAM.gov **requires a data.gov API key** (it is *not* a no-auth public
API like USASpending). **Do NOT hardcode the key.** Use a **Named Credential / External Credential**
or approved org secret storage; the repository must never contain a live key.

Real-data write-back (Phases 5–6) remains **DEFERRED** behind a non-admin, full-Salesforce-license
runtime identity (ideally with JWT), and no real Lead is written until that gate is consciously opened.
