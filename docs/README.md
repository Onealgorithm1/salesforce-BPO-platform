# Documentation Index — One Algorithm Salesforce BPO Platform

Grouped index of all documentation in this repository. Repository entry point:
[`../README.md`](../README.md).

**Status legend**
- **Current** — committed and believed accurate.
- **Proposed** — design-stage or not yet ratified (includes files not yet created).
- **Needs Review** — committed but known to be stale, incomplete, or contradicted by source.
- **Deprecated** — superseded; retained for history.

**Owner:** where a document explicitly names an owner it is listed; `—` means unlisted.
Default platform owner is Louis Rubino (lrubino@onealgorithm.com).

> Rows marked **Proposed** are design/governance documents that exist but are not yet ratified
> (ADRs) or not yet implemented in code. No index row points to a missing file.

---

## 1. Architecture

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | Overall platform architecture and layering. | Current | — |
| [`AI_ARCHITECTURE.md`](AI_ARCHITECTURE.md) | AI summary / transcript-processing architecture. | Current | — |
| [`AGENT_CATALOG.md`](AGENT_CATALOG.md) | Catalog of AI agents / automation components. | Current | — |
| [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) | Background context and project framing. | Current | — |

## 2. ADRs (Architecture Decision Records)

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`decisions/ADR-001-namespace-strategy.md`](decisions/ADR-001-namespace-strategy.md) | Namespace decision (no namespace; `OA_` prefix). | Current | Louis Rubino |
| [`decisions/ADR-002-client-isolation-strategy.md`](decisions/ADR-002-client-isolation-strategy.md) | Client isolation via layer/overlay separation. | Current | Louis Rubino |
| [`decisions/ADR-003-package-boundary-strategy.md`](decisions/ADR-003-package-boundary-strategy.md) | Three-layer package boundaries. | Current | Louis Rubino |
| [`decisions/ADR-004-metadata-retrieval-strategy.md`](decisions/ADR-004-metadata-retrieval-strategy.md) | Layer-by-layer metadata retrieval discipline. | Current | Louis Rubino |
| [`decisions/ADR-005-connector-framework.md`](decisions/ADR-005-connector-framework.md) | Connector Framework existence, placement, standards. | **Accepted** | Louis Rubino |
| [`decisions/ADR-006-canonical-data-model.md`](decisions/ADR-006-canonical-data-model.md) | Source-neutral canonical entities for enrichment. | **Accepted** | Louis Rubino |
| [`decisions/ADR-007-entity-resolution-framework.md`](decisions/ADR-007-entity-resolution-framework.md) | Deterministic-first matching + mandatory review gate. | **Accepted** | Louis Rubino |
| [`decisions/ADR-008-security-and-credential-standard.md`](decisions/ADR-008-security-and-credential-standard.md) | Named/External Credential standard; no secrets in objects. | **Accepted** | Louis Rubino |
| [`decisions/ADR-009-metadata-registry.md`](decisions/ADR-009-metadata-registry.md) | Authoritative committed-metadata inventory. | **Accepted** | Louis Rubino |
| [`decisions/ADR-010-definition-of-ready.md`](decisions/ADR-010-definition-of-ready.md) | Readiness gate before implementation. | **Accepted** | Louis Rubino |

## 3. Governance

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`GOVERNANCE_MODEL.md`](GOVERNANCE_MODEL.md) | Governance model and decision rules. | Current | — |
| [`METADATA_CLASSIFICATION.md`](METADATA_CLASSIFICATION.md) | Classification of metadata into layers; post-retrieval audit checklist. | Current | — |
| [`PROJECT_RESTART.md`](PROJECT_RESTART.md) | Restart/handoff guidance for resuming work. | Current | — |
| [`DEFINITION_OF_READY.md`](DEFINITION_OF_READY.md) | Definition-of-Ready gate for sprint work. | **Proposed** | Louis Rubino |

## 4. Security

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`SECURITY_MODEL.md`](SECURITY_MODEL.md) | Platform security model. | Current | — |
| [`SECURITY_BASELINE.md`](SECURITY_BASELINE.md) | Evergreen security baseline (Named Credentials, guest access, staging). | **Proposed** | Louis Rubino |
| [`INTEGRATION_REGISTRY.md`](INTEGRATION_REGISTRY.md) | Authoritative registry of every external integration; also records security findings (see §12). | Current | Louis Rubino |

## 5. Campaign Automation

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`BPO_PILOT_OPERATOR_RUNBOOK.md`](BPO_PILOT_OPERATOR_RUNBOOK.md) | Operator runbook for the pilot campaign. | Current | — |
| [`PLATFORM_ROADMAP.md`](PLATFORM_ROADMAP.md) | Business roadmap (includes campaign/operational-stability phases). | Current | — |
| [`../README.md`](../README.md) | Verified enrollment gate, safeguards, and component roles (Campaign Automation Overview). | Current | — |

> No dedicated campaign-automation *design* doc exists; the verified behavior lives in the
> root README plus the Apex source (`OA_DripScheduler`, `OA_FollowUpScheduler`,
> `OA_SendGovernor`, `OA_EmailSender`) and the `OA_EDWOSB_Outreach_Sequence` flow.
> Note: `TECHNICAL_DEBT.md` TD-003 (flow "deactivated") is contradicted by the committed flow
> metadata — see §12.

## 6. Communication Preferences

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`../README.md`](../README.md) | Communication Preference / Unsubscribe framework rules (GET-never-unsubscribe, POST token unsubscribe, minimal guest access). | Current | — |

> No dedicated communication-preference/unsubscribe *design* doc exists yet `[Proposed]`.
> Implementation: `OA_CommPreferenceService`, `OA_UnsubscribeEndpoint`,
> `OA_UnsubscribeTokenService`, `OA_UnsubscribeEventHandler`, objects
> `OA_Communication_Preference__c` / `_Audit__c` / `_Token__c`, event `OA_Unsubscribe_Request__e`,
> permission set `OA_Unsubscribe_Guest_Access`.

## 7. Microsoft Graph / Teams / Bookings

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`BOOKINGS_INTEGRATION_DESIGN.md`](BOOKINGS_INTEGRATION_DESIGN.md) | Microsoft Bookings polling integration design. | Current | — |
| [`MEETING_CAPTURE_DESIGN.md`](MEETING_CAPTURE_DESIGN.md) | Teams meeting / recording / transcript capture design. | Current | — |
| [`INTEGRATION_REGISTRY.md`](INTEGRATION_REGISTRY.md) | INT-001 Microsoft 365 / Graph and related integrations. | Current | Louis Rubino |

> Security debt: `OA_Graph_Credential__c` credential handling should be reviewed for migration
> to Named/External Credentials — see §12.

## 8. Evergreen Connector Framework

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`CONNECTOR_FRAMEWORK.md`](CONNECTOR_FRAMEWORK.md) | Connector SDK design (interfaces, engine, staging contract, test harness). | **Proposed** | Louis Rubino |
| [`CONNECTOR_FRAMEWORK_ROADMAP.md`](CONNECTOR_FRAMEWORK_ROADMAP.md) | Sprint 1A→1D→Sprint 2 sequencing for the connector track. | **Proposed** | Louis Rubino |
| [`decisions/ADR-005-connector-framework.md`](decisions/ADR-005-connector-framework.md) | Governing decision for the framework (see §2). | **Proposed** | Louis Rubino |

## 9. Data Model / Data Dictionary

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`DATA_ARCHITECTURE.md`](DATA_ARCHITECTURE.md) | Data model and data architecture. | Needs Review | — |
| [`CANONICAL_DATA_MODEL.md`](CANONICAL_DATA_MODEL.md) | Evergreen canonical data model. | **Proposed** | Louis Rubino |
| [`EVERGREEN_DATA_DICTIONARY.md`](EVERGREEN_DATA_DICTIONARY.md) | Field-level data dictionary for Evergreen entities. | **Proposed** | Louis Rubino |
| [`METADATA_REGISTRY.md`](METADATA_REGISTRY.md) | Registry of platform metadata (objects, fields, automation). | **Proposed** | Louis Rubino |

> `DATA_ARCHITECTURE.md` is marked **Needs Review**: prior notes indicate it may reference
> metadata (e.g. a partner duplicate rule) not present in the repository. Re-verify against
> source before relying on it.

## 10. Entity Resolution

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`ENTITY_RESOLUTION_FRAMEWORK.md`](ENTITY_RESOLUTION_FRAMEWORK.md) | Entity resolution / match-and-merge framework for enrichment. | **Proposed** | Louis Rubino |

> Design doc exists (Proposed); **no implementation yet.** The USASpending staging object carries
> `Match_Confidence__c` / `Name_Match_Score__c` fields anticipating this work.

## 11. Deployment / Operations

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`ROADMAP.md`](ROADMAP.md) | Technical implementation roadmap (Phase 0–6; Phase 1 = Metadata Retrieval). | Current | Louis Rubino |
| [`STATUS.md`](STATUS.md) | Project status, milestones, open risks/blockers. | Current | Louis Rubino |
| [`CLIENT_DEPLOYMENT_STRATEGY.md`](CLIENT_DEPLOYMENT_STRATEGY.md) | Client onboarding / deployment strategy. | Current | — |
| [`ENVIRONMENT_STRATEGY.md`](ENVIRONMENT_STRATEGY.md) | Environment/sandbox strategy. | Current | — |
| [`SALESFORCE_ORG_STATUS.md`](SALESFORCE_ORG_STATUS.md) | Snapshot of the Salesforce org state. | Needs Review | — |
| [`SESSION_SUMMARIES/2026-06-19.md`](SESSION_SUMMARIES/2026-06-19.md) | Working-session summary (2026-06-19). | Current | — |
| [`DEFINITION_OF_READY.md`](DEFINITION_OF_READY.md) | Sprint readiness gate (also §3). | **Proposed** | Louis Rubino |

> `SALESFORCE_ORG_STATUS.md` is marked **Needs Review**: org snapshots go stale; confirm against
> the live org before use.

## 12. Technical Debt / Risks

| Document | Purpose | Status | Owner |
|----------|---------|--------|-------|
| [`TECHNICAL_DEBT.md`](TECHNICAL_DEBT.md) | Technical debt register (TD-001 … TD-015). | Needs Review | — |
| [`STATUS.md`](STATUS.md) | Open Risks / Open Blockers tables (see §11). | Current | Louis Rubino |
| [`INTEGRATION_REGISTRY.md`](INTEGRATION_REGISTRY.md) | Security findings for unidentified integrations (see §4, §7). | Current | Louis Rubino |

> `TECHNICAL_DEBT.md` is marked **Needs Review**: TD-003 states `OA_EDWOSB_Outreach_Sequence` is
> deactivated and missing enrollment logic, but the committed flow is `Active` and already passes
> `campaignId`/`campaignMemberId`. Reconcile the register against the current source (and confirm
> the org's runtime flow state).

---

## Repository-verification notes (2026-07-02)

Findings established while assembling this index, for reviewer awareness:

- **"Evergreen"/"Connector Framework" are new to the repo** — before ADR-005 and the connector
  docs, neither term appeared anywhere in code or the roadmap. The platform `ROADMAP.md` Phase 1
  is "Metadata Retrieval"; the historical `Sprint 1 Production Launch Ready` commit was the email
  campaign launch, unrelated to connectors.
- **Two roadmaps coexist** — `ROADMAP.md` (technical) and `PLATFORM_ROADMAP.md` (business) use
  different phase numbering. Not a conflict, but read both.
- **TD-003 vs. flow metadata** — contradiction noted above (§5, §12).
- **`Outreach_Cohort__c`** — free Text(50); code filters only `'Wave 1'` while the field
  description names a different four-value set. Actual org values must be queried.

New/changed docs in this Sprint 1A pass (all uncommitted):
- **Rewritten:** root `README.md`.
- **New index:** this `docs/README.md`.
- **Connector framework (prior 1A step):** `CONNECTOR_FRAMEWORK.md`, `CONNECTOR_FRAMEWORK_ROADMAP.md`, `decisions/ADR-005-connector-framework.md`.
- **Governance docs (this step):** `CANONICAL_DATA_MODEL.md`, `EVERGREEN_DATA_DICTIONARY.md`, `ENTITY_RESOLUTION_FRAMEWORK.md`, `METADATA_REGISTRY.md`, `SECURITY_BASELINE.md`, `DEFINITION_OF_READY.md`.
- **Proposed ADRs (this step):** `decisions/ADR-006-canonical-data-model.md` … `ADR-010-definition-of-ready.md`.

ADR-005 … ADR-010 are now **Status: Accepted** (Sprint 1A closure); the design/governance docs
they govern remain **Proposed** until implemented. Nothing committed.
