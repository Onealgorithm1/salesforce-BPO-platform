# Platform Architecture — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026

---

## Architecture Philosophy

Three-layer separation. Every piece of metadata belongs to exactly one layer.
No layer references anything above it. Communication between modules uses Platform Events.

```
CLIENT LAYER     — org-specific config, permission sets, profiles
      ↓ depends on
MODULE LAYER     — reusable feature packages (Marketing, CLM, Compliance, AI, Governance)
      ↓ depends on
CORE LAYER       — shared foundation, utilities, base objects, integrations
```

---

## Package Structure

### Package 1 — OA Core Platform (`force-app/`)
**Type:** Salesforce DX Unlocked Package
**Namespace:** None (until AppExchange listing)
**Dependencies:** None

Contains:
- Base utility Apex classes (OA_ prefix)
- Shared LWC components
- Integration framework (Named Credentials, Remote Site Settings)
- Core custom fields on standard objects
- Duplicate/matching rules
- Foundational permission sets

### Package 2 — OA Marketing Automation (`modules/marketing-automation/`)
**Type:** Salesforce DX Unlocked Package
**Dependencies:** OA Core Platform 1.0.0+

Contains:
- Email campaign classes (OA_MKT_ prefix)
- Outreach sequences (Flows)
- EAC configuration metadata
- Email templates (OA_Marketing folder)
- Lead scoring logic (when implemented)
- Campaign permission sets

### Future Packages (not yet created)
- OA Contract Lifecycle (`modules/contract-lifecycle/`)
- OA Compliance Automation (`modules/compliance-automation/`)
- OA AI Agents (`modules/ai-agents/`)
- OA Governance (`modules/governance/`)

---

## Naming Standards

### Apex Classes
| Pattern | Example | Layer |
|---------|---------|-------|
| `OA_{Noun}` | `OA_LeadScorer` | Core |
| `OA_MKT_{Noun}` | `OA_MKT_CampaignSender` | Marketing |
| `OA_CLM_{Noun}` | `OA_CLM_ContractApprover` | CLM |
| `OA_COMP_{Noun}` | `OA_COMP_AuditLogger` | Compliance |
| `OA_AI_{Noun}` | `OA_AI_AgentRouter` | AI |
| `OA_GOV_{Noun}` | `OA_GOV_BoardReporter` | Governance |
| `{Class}_Test` | `OA_LeadScorer_Test` | Same layer as class |
| `{ClientCode}_{Noun}` | `PBO_LeadRouter` | Client only |

### Custom Objects
`OA_{Object}__c` (core), `OA_MKT_{Object}__c` (marketing), etc.

### Custom Fields
`OA_{FieldName}__c` on standard objects. `OA_MKT_{FieldName}__c` for module-specific fields.

### Flows
`OA_{Function}_{Trigger}` — e.g., `OA_MKT_EDWOSB_Outreach_Sequence`

### Permission Sets
`OA_{Module}_{Role}` — e.g., `OA_MKT_Campaign_Manager`

---

## Repository Structure

```
salesforce-BPO-platform/
├── .gitignore
├── .forceignore
├── sfdx-project.json
├── config/              — scratch org definitions
├── docs/                — this directory
├── manifest/            — package.xml retrieval manifests
├── scripts/             — deployment and ops scripts
├── force-app/           — Core Platform package
├── modules/
│   └── marketing-automation/   — Marketing package
└── clients/
    └── pbo/             — PBO org-specific config
```

---

## Integration Architecture

### Microsoft 365 / Exchange Online
- **Protocol:** Microsoft Graph API (OAuth 2.0)
- **Connected account:** lrubino@onealgorithm.com
- **Sync:** Email (capture) + Events (bidirectional) + Contacts (bidirectional)
- **Config:** OA EDWOSB Outreach EAC configuration

### OpenAI
- **Status:** Permission set created (OpenAI_Access), implementation pending
- **Planned use:** Lead scoring (Compatibility_Score__c, Geography_Tier__c), reply classification
- **Pattern:** Named Credential → Apex callout → Lead field update

### Zendesk
- **Status:** OAuth integration active (Salesforce Integration for Zendesk)
- **Purpose:** Support ticket sync

### Pipedream
- **Status:** OAuth active
- **Purpose:** Workflow automation bridge

---

## Branching Strategy

```
main        → Production baseline (protected, PR required, validation required)
develop     → Integration (auto-deploy to Developer Sandbox)
feature/*   → All development work
release/*   → Release candidates (auto-deploy to Full Sandbox)
hotfix/*    → Emergency production fixes
client/*    → Client-specific development
```

**Commit convention:** `{type}({module}): {description}`
Types: feat, fix, chore, refactor, test, docs

---

## Environment Strategy

| Environment | Purpose | Source Branch | Deploy Trigger |
|-------------|---------|---------------|----------------|
| Production (PBO) | Live operations | main | Manual, gated |
| Full Sandbox | UAT / staging | release/* | Auto on PR merge |
| Developer Sandbox | Integration QA | develop | Auto on merge |
| Scratch Orgs | Feature dev, testing | feature/* | On demand |
| Client Orgs | Client deployments | client/* | Manual per client |
