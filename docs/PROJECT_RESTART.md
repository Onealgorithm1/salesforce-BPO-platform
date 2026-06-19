# Project Restart Guide — One Algorithm BPO Platform

**Purpose:** Allow any future AI coding session to restart immediately with full context.
**Last Updated:** June 19, 2026
**Next Session Should Begin:** Monday, June 23, 2026

---

## STOP — Read This First

This document is the single entry point for any new AI session resuming work on the One Algorithm BPO Platform. Before taking any action, read the documents in the "Read First" list below. Do not make assumptions — the platform state is complex and security-sensitive.

**Standing constraints that never expire:**
- DO NOT retrieve metadata unless the current session task explicitly authorizes it
- DO NOT modify Salesforce (profiles, users, permissions, flows, campaigns, automations)
- DO NOT commit or push unless the current session task explicitly authorizes it
- DO NOT deploy to any Salesforce org
- DO NOT revoke any OAuth tokens or Connected Apps without explicit user approval
- NEVER search for, display, or store user credentials or API keys

---

## Repository

| Field | Value |
|-------|-------|
| **Local path** | `C:\Users\louis\OneDrive\Documents\GitHub\salesforce-BPO-platform` |
| **GitHub URL** | `https://github.com/Onealgorithm1/salesforce-BPO-platform` |
| **Branch** | `main` |
| **Last commit** | See STATUS.md for current hash |
| **Remote alias** | `origin` |

---

## Salesforce Orgs

| Org | Username | Org ID | Purpose |
|-----|----------|--------|---------|
| Production (PBO Edition) | `oauser@pboedition.com` | `00Dbn00000plgUfEAI` | Live operations — use for queries and retrieval |
| DevHub | `sreeni@onealgorithm.com` | `00Dd0000000haZPEAY` | Package creation and scratch orgs only |

**SF CLI aliases:** `oauser@pboedition.com` is the target for all production queries and retrievals.

To verify CLI authentication:
```bash
sf org list
sf org display --target-org oauser@pboedition.com
```

---

## Current Phase

**Phase 0 — Foundation: COMPLETE**
**Phase 1 — Metadata Retrieval: READY TO BEGIN**

The platform foundation is committed and pushed to GitHub. Three metadata retrievals need to be executed (Layer 1, 2, 3 — in that order) to establish the production baseline in source control.

---

## Current Status

All foundation files are committed. Retrieval has been validated and a CONDITIONAL GO has been issued. The only remaining pre-retrieval step is pausing OneDrive sync.

For the complete status, see `docs/STATUS.md`.

---

## Open Tasks (as of June 19, 2026)

### Immediate (Monday morning)

| # | Task | Command / Action |
|---|------|-----------------|
| 1 | Pause OneDrive sync | Right-click OneDrive tray icon → Pause syncing → 2 hours |
| 2 | Retrieve Layer 1 — Core | `sf project retrieve start --manifest manifest/package-core.xml --target-org oauser@pboedition.com` |
| 3 | Validate Layer 1 output | `git status`, check force-app/ for expected files |
| 4 | Commit Layer 1 | `git add force-app/ && git commit -m "feat: retrieve core platform metadata (Layer 1 — Core)"` |
| 5 | Push Layer 1 | `git push origin main` |
| 6 | Retrieve Layer 2 — Marketing | `sf project retrieve start --manifest manifest/package-marketing.xml --target-org oauser@pboedition.com --output-dir modules/marketing-automation` |
| 7 | Validate + commit Layer 2 | `git add modules/ && git commit ...` |
| 8 | Retrieve Layer 3A — PBO | `sf project retrieve start --manifest manifest/package-pbo.xml --target-org oauser@pboedition.com --output-dir clients/pbo` |
| 9 | Validate + commit Layer 3A | `git add clients/pbo/ && git commit ...` |
| 10 | Run post-retrieval audit | Check METADATA_CLASSIFICATION.md checklist |

### High Priority (within 7 days)

| # | Task | Details |
|---|------|---------|
| A | Revoke tbid.digital OAuth tokens | Setup → Connected Apps → OAuth-Connected Apps. 3 tokens, 150 days inactive, no documented purpose (SEC-INT-01) |
| B | Delete OIQ_Integration Connected App | App Manager → OIQ_Integration → Delete. Zero tokens, zero usage, no documented purpose (SEC-INT-02) |
| C | Enroll oauser@pboedition.com in Salesforce Authenticator | Security finding SEC-MFA-01. Louis currently uses email device verification only. |
| D | Verify org-level MFA enforcement | Setup → Identity → Identity Verification (requires UI — cannot query via SOQL) |
| E | Provision Full Sandbox | Setup → Sandboxes → Create Sandbox. Type: Full Copy. Name: OA-Full-Sandbox. Critical infrastructure gap (TD-001). |

---

## Open Risks

Refer to `docs/STATUS.md` for the complete risk register. Summary:

| Risk | Severity | What It Means |
|------|----------|--------------|
| SEC-INT-01 | HIGH | tbid.digital has 3 active OAuth tokens in production with no documented purpose |
| SEC-MFA-01 | HIGH | Louis's admin account uses email verification only, not a strong MFA factor |
| RISK-ENV-01 | HIGH | No sandbox exists — all changes go directly to production |
| SEC-INT-02 | MEDIUM | Undocumented Connected App (OIQ_Integration) with unrestricted user authorization settings |

---

## Read First — Document Priority Order

Before starting any task, read these documents in this order:

| Priority | Document | Why |
|----------|----------|-----|
| 1 | `docs/STATUS.md` | Current phase, open risks, open blockers, next step |
| 2 | `docs/METADATA_CLASSIFICATION.md` | Where every piece of metadata belongs; required before any retrieval |
| 3 | `docs/decisions/ADR-004-metadata-retrieval-strategy.md` | Retrieval order, validation requirements, rollback procedure |
| 4 | `docs/INTEGRATION_REGISTRY.md` | All active integrations; security findings for tbid.digital and OIQ |
| 5 | `docs/SECURITY_MODEL.md` | Role definitions, MFA requirements, service account policy |
| 6 | `manifest/package-core.xml` | What is in Layer 1 retrieval |
| 7 | `manifest/package-marketing.xml` | What is in Layer 2 retrieval |
| 8 | `manifest/package-pbo.xml` | What is in Layer 3A retrieval |

For architecture background (read as needed, not required before Monday's task):
- `docs/decisions/ADR-001-namespace-strategy.md` — Why no namespace
- `docs/decisions/ADR-002-client-isolation-strategy.md` — Why dedicated client orgs
- `docs/decisions/ADR-003-package-boundary-strategy.md` — What goes in each layer
- `docs/PLATFORM_ARCHITECTURE.md` — System design overview
- `docs/GOVERNANCE_MODEL.md` — Change management and approval process

---

## Key Technical Context

### SFDX Project Structure

```
salesforce-BPO-platform/
├── force-app/main/default/          ← Layer 1: OA-Core-Platform package
├── modules/marketing-automation/    ← Layer 2: OA-Marketing-Automation package
├── clients/pbo/                     ← Layer 3A: PBO config overlay (NOT a package)
├── manifest/
│   ├── package-core.xml             ← Layer 1 retrieval manifest
│   ├── package-marketing.xml        ← Layer 2 retrieval manifest
│   ├── package-pbo.xml              ← Layer 3A retrieval manifest
│   └── package-all.xml              ← Bulk retrieval (not used for baseline)
├── config/project-scratch-def.json  ← Scratch org definition
├── docs/                            ← All governance and architecture docs
│   └── decisions/                   ← ADR-001 through ADR-004
├── sfdx-project.json                ← 3-package SFDX project config
└── .forceignore                     ← Excludes 6 managed namespaces + EAC types
```

### Known API Constraints

These Salesforce SOQL limitations were discovered during the security assessment:

| Object | Known Issue |
|--------|------------|
| `OauthToken` | Fields: `Id, AppName, UserId, CreatedDate` only. `UseDate` and `LastModifiedDate` do NOT exist. |
| `SetupAuditTrail` | `Section` and `Display` fields are NOT filterable in WHERE clause |
| `UserLogin` | `User.Username` relationship NOT supported. `IsMfaEnabled`, `LastLoginDate` do NOT exist. Available: `Id, UserId, IsPasswordLocked` |
| `TwoFactorInfo` | NOT supported as SOQL object in this org |
| `AuthSession` | `UserId` does NOT exist as a column |
| `LoginHistory` | `Application` field can be SELECTed but NOT filtered in WHERE clause |
| `ConnectedApplication` (Tooling) | `IsAdminApproved` does NOT exist. Available: `Id, Name, OptionsAllowAdminApprovedUsersOnly` |

### Active Integrations

| ID | Name | Status | Risk |
|----|------|--------|------|
| INT-001 | Microsoft 365 / EAC | Active | High (by design) |
| INT-002 | SfdcSIQActivitySyncEngine | Active | Low (platform) |
| INT-003 | Zendesk | Active | Medium |
| INT-004 | Pipedream | Active | High (scope unknown) |
| INT-005 | tbid.digital | Active — **SECURITY FINDING** | Critical |
| INT-006 | OIQ_Integration | Active (no tokens) — **SECURITY FINDING** | Medium |
| INT-007 | PartnerTrial | Active | Low |
| INT-008 | Environment Hub | Active | Low |

### Users

| Username | Name | Role | UserId |
|----------|------|------|--------|
| oauser@pboedition.com | Louis Rubino | System Administrator | 005bn00000BP9zUAAT |
| onealgorithm@pboedition.com | Sreenivas Amirisetti | System Administrator | 005bn00000BP6GpAAL |
| sreeni@onealgorithm.com | Sreenivas Amirisetti | DevHub admin | — (DevHub org) |
| lrubino@onealgorithm.com | Louis Rubino | M365 mailbox (EAC) | — |

---

## Monday First Command

```bash
# 1. Navigate to project
cd "C:\Users\louis\OneDrive\Documents\GitHub\salesforce-BPO-platform"

# 2. Verify repository state
git status
git log --oneline -5
git remote -v

# 3. Verify Salesforce CLI auth
sf org display --target-org oauser@pboedition.com

# 4. Pause OneDrive (manual — tray icon)

# 5. Execute first retrieval
sf project retrieve start --manifest manifest/package-core.xml --target-org oauser@pboedition.com
```

---

## Escalation

If the Salesforce org is inaccessible, credentials have changed, or a security incident is suspected:

- Contact: Louis Rubino (lrubino@onealgorithm.com)
- DO NOT attempt to reset credentials or modify org access
- DO NOT revoke any tokens without explicit written instruction from Louis Rubino
- Document the anomaly and stop
