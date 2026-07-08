# One Algorithm Salesforce BPO Platform

> Entry point for the repository. Executive summary above, developer guidance below.
> Full documentation index: [`docs/README.md`](docs/README.md).

**Confidence labels used in this document**
`[Verified from source]` — confirmed by reading repository code/metadata.
`[Unverified production runtime]` — org/live state that was **not** checked from this repo; verify before relying on it.
`[Proposed]` — planned/design-stage; not yet built or not yet ratified.

---

## Current Project Status

- **`main` is the production baseline.** It reflects what is deployed to the production org.
- **Lead Enrichment Platform v1.2** is **engineering complete, production certified, and in Maintenance
  Mode.** See [`docs/MAINTENANCE.md`](docs/MAINTENANCE.md), [`docs/RELEASE_1.2.md`](docs/RELEASE_1.2.md),
  and [`docs/LEAD_ENRICHMENT_MONITORING.md`](docs/LEAD_ENRICHMENT_MONITORING.md).
- **Future Lead Enrichment work is limited to** production defects, security fixes, connector/API
  maintenance, Salesforce platform compatibility, or governor-limit regressions — **no new features.**
- **Active / non-`main` workstreams live on feature or backup branches**, not on `main`. Currently known:
  - Meta/Facebook Integration
  - LinkedIn / Authentication foundation
  - Meeting Tracking
  - Opportunity Intelligence (design)
- The branch **`backup/untracked-auth-linkedin-meta-2026-07-08`** exists **only** to preserve uncommitted
  design/metadata work; it is **not production-ready** and must not be treated as such.

**Before starting work, check:** current branch · org ID · working tree · which workstream you are in ·
and whether the change belongs on `main`, a feature branch, or a backup branch.

---

## Executive Summary

This repository contains the Salesforce-native **BPO Platform** for One Algorithm. It is the
source of truth for the platform's unmanaged metadata and supporting documentation. The
platform supports:

- **CRM** — Lead/Contact/Campaign data model on Salesforce.
- **Campaign automation** — scheduled enrollment, daily-governed email sends, follow-up cadence.
- **Microsoft Graph integration** — OAuth callouts to Microsoft 365 / Graph.
- **Bookings** — Microsoft Bookings polling.
- **Teams meetings** — meeting retrieval.
- **Recordings** — meeting recording retrieval.
- **Transcripts** — native Graph transcript retrieval.
- **AI summaries** — transcript-to-summary processing.
- **Communication preferences** — preference/opt-out framework and public unsubscribe endpoint.
- **Lead Enrichment Platform v1.1** — metadata-driven, connector-agnostic enrichment from public
  data sources, with governed per-field writes, audit + rollback. **CLOSED / operational baseline
  `lead-enrichment-ops-v1.1` (2026-07-07): certified for controlled/manual enrichment; 68 Leads enriched;
  execution layer deployed dormant; Census/SEC/USASpending/IRS credential-ready; dormant by default.**
  See `LEAD_ENRICHMENT_FINAL_CLOSURE.md`. Remaining = operational maintenance (UI dashboards, least-priv
  user license, SAM key).
  See `RELEASE_1.1.md` + `PRODUCTION_CERTIFICATION.md`, and [Lead Enrichment Platform v1.0](#lead-enrichment-platform-v10) and
  [`docs/RELEASE_1.0.md`](docs/RELEASE_1.0.md). `[Verified from source]`

---

## Current Production Status

The platform runs an **active production campaign**.

- **Campaign:** EDWOSB Teaming Outreach – Prime Subcontract *(name as provided by the operator; `[Unverified production runtime]`)*
- **Campaign Id:** `701Pn00001ZOyj8IAD` `[Verified from source]` — hardcoded in `OA_DripScheduler`, `OA_FollowUpScheduler`, and `OA_EDWOSB_Outreach_Sequence`.
- **Status:** Production / Active / Stable, **subject to continued verification.** Runtime health (records enrolled, sends today, job schedule) is `[Unverified production runtime]` from this repo.

### Safeguards `[Verified from source]`

| Safeguard | Mechanism |
|-----------|-----------|
| **Daily send governor** | `OA_SendGovernor` — `Daily_Send_Cap__c` (default **200**), `Sends_Today__c`, daily auto-reset via `Cap_Reset_Date__c`. `checkAndReserve()` throws `CapExceededException` at cap. |
| **Business-day scheduling** | `OA_SendGovernor.isBusinessDay()` returns false on Saturday/Sunday; schedulers no-op on non-business days. |
| **Federal holiday skipping** | `OA_SendGovernor.isFederalHoliday()` — New Year's, MLK, Presidents, Memorial, Juneteenth, Independence, Labor, Columbus, Veterans, Thanksgiving, Christmas. |
| **No mass-send behavior** | Both schedulers cap each run at `MAX_SYNC_BATCH = 50` and further limit by `remainingToday()`. |
| **CampaignMember duplicate prevention** | Enrollment query excludes Leads already in the campaign (`Id NOT IN (SELECT LeadId FROM CampaignMember WHERE CampaignId = …)`). |
| **Opt-out protection** | Enrollment requires `HasOptedOutOfEmail = false`; follow-ups stop on `Unsubscribed` status. |
| **Test lead exclusion** | Enrollment requires `Is_Test_Lead__c = false`. |
| **Cohort-based enrollment** | Enrollment requires `Outreach_Cohort__c = 'Wave 1'` (see the cohort caveat under [Current Known Risks](#current-known-risks)). |

---

## Campaign Automation Overview

### Enrollment gate — `OA_DripScheduler` `[Verified from source]`

`OA_DripScheduler` is the **only** component that enrolls Leads. It enrolls a Lead **only when
all** of the following hold:

- `LeadSource = 'SAM.gov'`
- `Outreach_Cohort__c = 'Wave 1'`
- `Is_Test_Lead__c = false`
- `HasOptedOutOfEmail = false`
- `IsConverted = false`
- `Email != null`
- The Lead is **not already** a `CampaignMember` of the production campaign

Enrollment is further throttled by `OA_SendGovernor.remainingToday()` and `MAX_SYNC_BATCH = 50`,
and runs only on business days.

### Roles of the automation components

- **`OA_EDWOSB_Outreach_Sequence` (Flow) does *not* enroll Leads.** `[Verified from source]` It is a
  record-triggered (CampaignMember *Create*) autolaunched flow that runs **after** enrollment:
  it branches on `Outreach_Segment__c` to select the Day-1 email template, sends via
  `OA_EmailSender`, and sets `CampaignMember.Status = 'Day 1 Sent'`.
- **`OA_SendGovernor`** controls daily capacity, business-day/holiday gating, and per-run limits. `[Verified from source]`
- **`OA_FollowUpScheduler`** manages follow-up behavior: Day-1→Day-3→Day-5→Day-10 email cadence
  driven by `CampaignMember.Status`, halting on stop-statuses (`Replied`, `Meeting Booked`,
  `Interested`, `Not Interested`, `Unsubscribed`, `Call Completed`). `[Verified from source]`

> **Note `[Verified from source]` / contradiction:** `docs/TECHNICAL_DEBT.md` (TD-003) states the
> flow is *deactivated and missing enrollment logic*. The committed flow metadata shows
> `<status>Active</status>` and already passes `campaignId`/`campaignMemberId` to `OA_EmailSender`.
> Whether the **production org's** active flow matches this source is `[Unverified production runtime]`.

---

## Communication Preference / Unsubscribe Framework

- A **Communication Preference Framework** exists in the platform (`OA_CommPreferenceService`,
  `OA_Communication_Preference__c` / `_Audit__c` / `_Token__c` objects). `[Verified from source]`
- The **public unsubscribe endpoint** work was completed separately (`OA_UnsubscribeEndpoint`,
  `OA_UnsubscribeTokenService`, `OA_UnsubscribeEventHandler`, `OA_Unsubscribe_Request__e`). `[Verified from source]`

Operating rules for this surface:

- **GET must never unsubscribe** — a GET request only renders/validates; it must not mutate preference state.
- **POST performs the token-based unsubscribe** — mutation happens only via authenticated token on POST.
- **Guest access must remain minimal** — via `OA_Unsubscribe_Guest_Access` permission set only.
- **No guest object CRUD/FLS** should be granted beyond the minimum the endpoint requires.

> Unsubscribe work may be actively maintained in a separate session. Keep it isolated from
> campaign and Evergreen changes (see [How to Work in This Repo](#how-to-work-in-this-repo)).

---

## Microsoft Graph Platform

The platform integrates with Microsoft 365 via Graph `[Verified from source]` (classes include
`OA_BookingPoller`; supporting object `OA_Graph_Credential__c`; Remote Sites `MicrosoftGraph`,
`MicrosoftLogin`). Capabilities:

- **Microsoft Graph integration** (OAuth client-credentials callout)
- **Bookings polling**
- **Teams meeting retrieval**
- **Recording retrieval**
- **Transcript retrieval** (native Graph VTT transcript)
- **AI summary processing** (transcript → summary)

**Security debt — review required `[Verified from source]`:** `OA_Graph_Credential__c` holds
credential material as custom-object fields (`Client_Secret__c`, `Client_Id__c`, `Tenant_Id__c`)
rather than a Named/External Credential. Graph credential handling should be reviewed and
migrated toward **Named/External Credentials**, matching the pattern already used for
`OA_Anthropic`. Track under Technical Debt.

---

## Lead Enrichment Platform v1.0

The **Lead Enrichment Platform** is the connector/intelligence layer that enriches the CRM from
public data sources. **v1.0 is built, deployed (dormant), commissioned, and proven on production
Leads** with durable audit and verified rollback. `[Verified from source]` The permanent baseline is
[`docs/RELEASE_1.0.md`](docs/RELEASE_1.0.md); the epic is **closed**.

**Architecture** — metadata-driven and connector-agnostic (Apex). One generic framework; add a source
with Request + Parser + Mapper + a Connector implementing the interface + metadata — no platform code change.
- **Framework:** `OA_IEnrichmentConnector` (interface), `OA_ConnectorRunner` (registry-driven dispatcher,
  `Type.forName`), `OA_ConnectorResult`.
- **Canonical model + engines:** `OA_CanonicalOrg`; Field Write Policy, Qualification, Confidence,
  Source Precedence, Discovery Qualification.
- **Governed write:** `OA_EnrichmentWriter` (per-field policy, USER_MODE FLS, before-snapshot), Change
  Log + Rollback (`OA_ChangeLogService`), Exception Routing (`OA_ExceptionRoutingService`).
- **Execution layer (Sprint 17):** `OA_EnrichmentOrchestrator` (Batch + Stateful) and
  `OA_EnrichmentQueueable` — configurable batches, transient retry, stop-on-unrecoverable, telemetry;
  **safe by default** (`commitWrites = false`). Drives the existing engines; bypasses none.
- **Objects:** `OA_Connector_Run__c` (telemetry), `OA_Enrichment_Change_Log__c` (audit + rollback),
  `OA_Enrichment_Exception__c` (review queue), `OA_Discovered_Organization__c` (net-new + qualification).
- **Config (CMDT):** connector registry, enrichment source, field write policy, qualification rule, pipeline.
- **Lead schema:** 29 enrichment fields. **Runtime FLS:** `OA_Lead_Enrichment_Runtime` permission set.

**Connector inventory (6)** `[Verified from source]`

| Connector | Category | Ingestion | Auth | Live-callout status |
|---|---|---|---|---|
| SAM.gov | Entity/identity + certs | REST GET | data.gov `X-Api-Key` | needs endpoint + EC principal access + key |
| USASpending | Contracts/awards | REST POST | none (public) | **ready** |
| U.S. Census | Market context | REST GET | none | needs `OA_Census` NC |
| IRS Tax-Exempt | Nonprofit/compliance | **bulk CSV** (no callout) | none | **ready** (validated bulk parse) |
| SEC EDGAR | Public company | REST GET | User-Agent | needs `OA_SEC` NC |
| State Registry (template) | State formation | REST GET (extensible) | per-state | template only |

**Governance (ratified — ADR-012).** Enrichment **may** write to Lead, but **only** through the per-field
write policy engine (fill-empty / approved-overwrite / never), with a before-snapshot, change log, and
one-command rollback; conflicts and low-confidence matches route to a human review queue. It is **dormant by
default** (0 connectors enabled, 0 active policies, nothing scheduled) and runs under conservative controls
until a dedicated least-privilege runtime user replaces the temporary `oauser`/MAD exception
([`docs/RUNTIME_USER_EXCEPTION.md`](docs/RUNTIME_USER_EXCEPTION.md)).

**Operating it:** [`docs/OPERATIONS_GUIDE.md`](docs/OPERATIONS_GUIDE.md),
[`docs/GO_LIVE_CHECKLIST.md`](docs/GO_LIVE_CHECKLIST.md),
[`docs/CREDENTIAL_STATUS.md`](docs/CREDENTIAL_STATUS.md),
[`docs/SCHEDULING_PLAN.md`](docs/SCHEDULING_PLAN.md),
[`docs/PERFORMANCE_VALIDATION.md`](docs/PERFORMANCE_VALIDATION.md),
[`docs/MONITORING_DASHBOARDS.md`](docs/MONITORING_DASHBOARDS.md),
[`docs/OPERATIONAL_ALERTS.md`](docs/OPERATIONAL_ALERTS.md).

**Next program:** **Opportunity Intelligence** (a new epic — not yet started). Program-level status for all
future programs (Operational Enablement, Opportunity Intelligence, Procurement, Grant Management, AI Decision
Support, Commercial Enrichment) lives in [`docs/PROGRAM_ROADMAP.md`](docs/PROGRAM_ROADMAP.md).

---

## Repository Structure

```
README.md                     ← this file
sfdx-project.json             ← package directories, API version (67.0), namespace ("")
config/                       ← scratch org definition
docs/                         ← platform documentation (index: docs/README.md)
docs/decisions/               ← Architecture Decision Records (ADR-001 … ADR-005)
force-app/main/default/       ← Layer 1: Core Platform (OA-Core-Platform)
modules/marketing-automation/ ← Layer 2: Marketing module (declared in sfdx-project.json)
clients/pbo/                  ← Layer 3A: PBO client overlay
```

> Note `[Verified from source]`: `sfdx-project.json` declares three package directories
> (`force-app`, `modules/marketing-automation`, `clients/pbo`). Not every directory may contain
> retrieved metadata yet — metadata retrieval is a roadmap phase in progress.

## Package Structure `[Verified from source]`

| Package | Path | Role |
|---------|------|------|
| **OA-Core-Platform** | `force-app` | Shared foundation, utilities, **integrations** (connectors live here). Default package. |
| **OA-Marketing-Automation** | `modules/marketing-automation` | Email campaigns, EAC sync, outreach sequences. Depends on OA-Core-Platform. |
| **PBO client overlay** | `clients/pbo` | One Algorithm internal/PBO-specific configuration. |

Namespace: none (`""`). Source API version: **67.0**. See
[ADR-003](docs/decisions/ADR-003-package-boundary-strategy.md).

---

## Active Workstreams

1. **Production campaign operations** — live EDWOSB outreach (do not disturb). `[Verified from source]`
2. **Communication Preference / Unsubscribe** — completed separately; may be actively maintained.
3. **Lead Enrichment Platform** — **v1.0 complete & commissioned (dormant)**; Sprint 17 added the
   operational execution layer + ops docs. Remaining work is operational enablement (credentials,
   least-privilege runtime user, dashboards, pilots) — see [`docs/PROGRAM_ROADMAP.md`](docs/PROGRAM_ROADMAP.md).
4. **Opportunity Intelligence** — the next program (not yet started). `[Proposed]`

See [Current Sprint Status](#current-sprint-status).

---

## Governance Rules

- **Evidence overrides assumptions.**
- **Repository state overrides memory.**
- **Production state must be verified** before any production claim.
- **No production deployment without validation.**
- **No destructive operation** without verifying branch, `git status`, and a recovery path.
- **Governed enrichment writes only** — Lead enrichment writes go **exclusively** through the per-field
  write policy engine (fill-empty / approved-overwrite / never) with before-snapshot, change log, and
  rollback; conflicts/low-confidence route to human review (ADR-012). No ungoverned or direct-to-Lead writes;
  Contact/Campaign/CampaignMember are never auto-mutated by enrichment.

See [`docs/GOVERNANCE_MODEL.md`](docs/GOVERNANCE_MODEL.md).

## Deployment Safety

- **Check-only validation required** before any deploy (`sf project deploy validate`).
- **Tests required** — Apex coverage ≥ 75%.
- **Rollback plan required** for every production change.
- **Production deployments must be serialized** — one at a time.
- **No parallel production deployments from multiple AI sessions.**

See [`docs/CLIENT_DEPLOYMENT_STRATEGY.md`](docs/CLIENT_DEPLOYMENT_STRATEGY.md) and
[`docs/ENVIRONMENT_STRATEGY.md`](docs/ENVIRONMENT_STRATEGY.md).

## Source-Control Rules

- Work on a **feature branch**; direct commits to `main` are reserved for read-only metadata retrieval (ADR-004).
- **Never** `git push --force` to remove a pushed commit — use `git revert`.
- **Do not commit unrelated or untracked temp files** (e.g. `apex-temp-*.json`, stray flow files).
- Commit small, reversible, single-purpose changes.

## Current Branch Guidance

- **Canonical working copy:** `…/OneDrive - One Algorithm LLC/Documents/GitHub/salesforce-BPO-platform/salesforce-BPO-platform`.
- Current branch at time of writing: `feature/recording-transcript-pipeline`. `[Verified from source]`
- A **second, stale copy** of this repo exists under personal OneDrive — do **not** work in it (see [Current Known Risks](#current-known-risks)).
- Verify you are in the canonical copy and on the intended branch before any work.

---

## Current Known Risks

- **Multiple local working copies** — two divergent copies exist under OneDrive; only the
  canonical business copy is authoritative. Working in the wrong copy risks divergence/conflicts. `[Verified from source]`
- **Untracked temp files must not be committed** — `apex-temp-activate-body.json`,
  `apex-temp-nurture-verify.apex`, and a stray `lead_by_ramesh.flow-meta.xml` are present as
  untracked. `[Verified from source]`
- **USASpending client is not production-grade** — `OA_USASpendingClient` has **zero callers**,
  no test class, no staging persistence, and is at API v61. `[Verified from source]`
- **Remote Site Settings should be reviewed** for migration to Named Credentials
  (`OA_USASpending` remote site vs. the Named Credential standard). `[Verified from source]`
- **Graph credential handling** requires security review if not already remediated
  (`OA_Graph_Credential__c` credential-bearing fields vs. Named/External Credential). `[Verified from source]`
- **`Outreach_Cohort__c` is Text(50), not a picklist** — production values are unconstrained.
  The field description names *Test / Validation, Pilot Batch 1, Pilot Batch 2, Production Ramp*,
  while the code filters only `'Wave 1'`. Query the org before assuming which cohort values exist. `[Verified from source]` / `[Unverified production runtime]`

See [`docs/TECHNICAL_DEBT.md`](docs/TECHNICAL_DEBT.md) and the Open Risks table in
[`docs/STATUS.md`](docs/STATUS.md).

---

## Current Sprint Status

**Lead Enrichment Platform v1.0 — COMPLETE / COMMISSIONED (dormant).** `[Verified from source]`

| Milestone | Scope | State |
|--------|-------|-------|
| Phases 7–11 | Foundation, SAM, generic framework, Wave 1 (USASpending/Census/IRS), Wave 2 (SEC/State) | ✅ Complete |
| Sprints 12–16 | Field deploy, dormant platform deploy, FLS investigation, commissioning, canary + 5-Lead pilot, `RELEASE_1.0.md` | ✅ Complete |
| Release consolidation | `main = 485f7dc`, tag `lead-enrichment-v1.0` (local; push pending approval) | ✅ Complete |
| **Sprint 17** | Operational enablement — async orchestrator + ops docs (credentials, scheduling, dashboards, alerts, performance, ops guide, go-live checklist) | ✅ Complete (validated, dormant) |
| Operational Enablement | least-privilege runtime user, Census/SEC NCs + SAM EC access, dashboards, 25/100 pilots, scheduling | ⏭️ Next |
| Opportunity Intelligence | next development program | 🔭 Future |

Program-level roadmap: [`docs/PROGRAM_ROADMAP.md`](docs/PROGRAM_ROADMAP.md).
Platform (non-connector) roadmap: [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## What Not To Change Without Approval

- **Production campaign automation:** `OA_DripScheduler`, `OA_FollowUpScheduler`,
  `OA_SendGovernor`, `OA_EmailSender`, `OA_EDWOSB_Outreach_Sequence`, and campaign email templates.
- **Data records/automation on:** Campaign, Lead, Contact, CampaignMember, schedulers, Flows.
- **Communication Preference / Unsubscribe** classes and permission sets (owned by a separate workstream).
- **Lead Enrichment Platform v1.0** — the frozen platform classes/engines, connectors, CMDTs, objects, the
  29 Lead fields, and the `OA_Lead_Enrichment_Runtime` permission set (keep it assigned). Change connectors
  only by adding new ones per the developer guide; do not edit the platform engines.
- **No deploy / commit / push** without explicit approval.

---

## Key Architecture Documents

- [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) — overall platform architecture
- [`docs/AI_ARCHITECTURE.md`](docs/AI_ARCHITECTURE.md) — AI summary / processing architecture
- [`docs/DATA_ARCHITECTURE.md`](docs/DATA_ARCHITECTURE.md) — data model & architecture

## Key ADRs

- [ADR-001 — Namespace Strategy](docs/decisions/ADR-001-namespace-strategy.md)
- [ADR-002 — Client Isolation Strategy](docs/decisions/ADR-002-client-isolation-strategy.md)
- [ADR-003 — Package Boundary Strategy](docs/decisions/ADR-003-package-boundary-strategy.md)
- [ADR-004 — Metadata Retrieval Strategy](docs/decisions/ADR-004-metadata-retrieval-strategy.md)
- [ADR-005 — Connector Framework](docs/decisions/ADR-005-connector-framework.md) `[Accepted]`
- [ADR-006 — Canonical Data Model](docs/decisions/ADR-006-canonical-data-model.md) `[Accepted]`
- [ADR-007 — Entity Resolution Framework](docs/decisions/ADR-007-entity-resolution-framework.md) `[Accepted]`
- [ADR-008 — Security & Credential Standard](docs/decisions/ADR-008-security-and-credential-standard.md) `[Accepted]`
- [ADR-009 — Metadata Registry](docs/decisions/ADR-009-metadata-registry.md) `[Accepted]`
- [ADR-010 — Definition of Ready](docs/decisions/ADR-010-definition-of-ready.md) `[Accepted]`

## Finding Documentation by Topic

- **Connector framework docs:** [`docs/CONNECTOR_FRAMEWORK.md`](docs/CONNECTOR_FRAMEWORK.md), [`docs/CONNECTOR_FRAMEWORK_ROADMAP.md`](docs/CONNECTOR_FRAMEWORK_ROADMAP.md), [ADR-005](docs/decisions/ADR-005-connector-framework.md)
- **Unsubscribe / communication-preference docs:** no dedicated design doc yet `[Proposed]`; implemented in `OA_CommPreferenceService`, `OA_UnsubscribeEndpoint`, `OA_UnsubscribeTokenService`, `OA_UnsubscribeEventHandler`. Summarized in the [Communication Preference / Unsubscribe Framework](#communication-preference--unsubscribe-framework) section above.
- **Campaign automation docs:** [`docs/BPO_PILOT_OPERATOR_RUNBOOK.md`](docs/BPO_PILOT_OPERATOR_RUNBOOK.md), [`docs/PLATFORM_ROADMAP.md`](docs/PLATFORM_ROADMAP.md), and the [Campaign Automation Overview](#campaign-automation-overview) above.
- **Microsoft Graph docs:** [`docs/BOOKINGS_INTEGRATION_DESIGN.md`](docs/BOOKINGS_INTEGRATION_DESIGN.md), [`docs/MEETING_CAPTURE_DESIGN.md`](docs/MEETING_CAPTURE_DESIGN.md), [`docs/INTEGRATION_REGISTRY.md`](docs/INTEGRATION_REGISTRY.md) (INT-001).
- **Technical debt / risk docs:** [`docs/TECHNICAL_DEBT.md`](docs/TECHNICAL_DEBT.md), [`docs/STATUS.md`](docs/STATUS.md) (Open Risks), [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md).

## Documentation Index

Full grouped index: **[`docs/README.md`](docs/README.md)**. Frequently referenced:

**Lead Enrichment Platform v1.0 (current baseline)**
- [`docs/RELEASE_1.0.md`](docs/RELEASE_1.0.md) — permanent v1.0 baseline (architecture, connectors, deploy/validation IDs)
- [`docs/PROGRAM_ROADMAP.md`](docs/PROGRAM_ROADMAP.md) — program-level roadmap (current → future)
- [`docs/LEAD_ENRICHMENT_PLATFORM_SPEC.md`](docs/LEAD_ENRICHMENT_PLATFORM_SPEC.md) — connector matrix / spec
- [`docs/CONNECTOR_DEVELOPER_GUIDE.md`](docs/CONNECTOR_DEVELOPER_GUIDE.md) — how to add a connector
- [`docs/OPERATIONS_GUIDE.md`](docs/OPERATIONS_GUIDE.md) · [`docs/GO_LIVE_CHECKLIST.md`](docs/GO_LIVE_CHECKLIST.md)
- [`docs/CREDENTIAL_STATUS.md`](docs/CREDENTIAL_STATUS.md) · [`docs/SCHEDULING_PLAN.md`](docs/SCHEDULING_PLAN.md) · [`docs/PERFORMANCE_VALIDATION.md`](docs/PERFORMANCE_VALIDATION.md)
- [`docs/MONITORING_DASHBOARDS.md`](docs/MONITORING_DASHBOARDS.md) · [`docs/OPERATIONAL_ALERTS.md`](docs/OPERATIONAL_ALERTS.md)
- [`docs/DEPLOYMENT_PACKAGE.md`](docs/DEPLOYMENT_PACKAGE.md) · [`docs/RUNTIME_USER_EXCEPTION.md`](docs/RUNTIME_USER_EXCEPTION.md)

**Design / historical (superseded or pre-v1.0 design — retained for reference)**
- [`docs/CANONICAL_DATA_MODEL.md`](docs/CANONICAL_DATA_MODEL.md), [`docs/ENTITY_RESOLUTION_FRAMEWORK.md`](docs/ENTITY_RESOLUTION_FRAMEWORK.md), [`docs/EVERGREEN_DATA_DICTIONARY.md`](docs/EVERGREEN_DATA_DICTIONARY.md), [`docs/METADATA_REGISTRY.md`](docs/METADATA_REGISTRY.md), [`docs/SECURITY_BASELINE.md`](docs/SECURITY_BASELINE.md) — early "Evergreen" design (v1.0 implementation is the current source of truth)
- [`docs/decisions/`](docs/decisions/) — ADR-001…010 on `main`; the enrichment-governance decisions
  (ADR-011/012) are design docs on the `design/lead-enrichment-platform` branch (see `PROGRAM_ROADMAP.md`)
- [`docs/README.md`](docs/README.md) — full grouped documentation index

---

## USASpending Connector Operations

The USASpending connector is deployed, proven through a controlled production smoke test, and currently dormant/locked by default.

Operational procedures for safely re-enabling, running, reviewing, cleaning up, and re-locking the connector are documented here:

- [USASpending Connector Operations Runbook](docs/USASPENDING_CONNECTOR_OPERATIONS_RUNBOOK.md)

---

## How to Work in This Repo

- **Verify the correct repo root** — the canonical copy under `OneDrive - One Algorithm LLC`, not the personal-OneDrive copy.
- **Run `git status` before work** and confirm the branch.
- **Do not commit unrelated files** (temp `apex-temp-*`, stray flow files).
- **Keep workstreams isolated** — unsubscribe work, campaign work, and Evergreen work should not be mixed in one branch/commit.
- **Prefer small, reversible changes.**
