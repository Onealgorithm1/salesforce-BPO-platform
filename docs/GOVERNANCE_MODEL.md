# Governance Model — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Quarterly; mandatory review before any SOX or public-company readiness milestone

---

## 1. Governance Philosophy

One Algorithm is currently an EDWOSB with ISV ambitions. The governance model must be designed for where the company is going — not only where it is today. A company that builds governance controls in the start-up phase avoids the painful retrofit that derails most pre-IPO technology companies.

Every governance control in this document is proportionate to current scale but designed to be hardened, not replaced, as the company grows.

**Current scale:** 2 admins, 1 live Salesforce org, no external audit obligation
**Target scale:** Multi-client ISV, public company, federal contractor, EDWOSB certification maintained

---

## 2. Change Management

### 2.1 Change Categories

| Category | Definition | Examples | Approval Required |
|----------|-----------|---------|-------------------|
| **Standard** | Low-risk, reversible, pre-approved change type | Scratch org development, sandbox deploys, documentation updates | Developer self-approval |
| **Normal** | Planned change with defined scope and tested rollback path | Feature deployment to production, package version release | Release Manager |
| **Emergency (Hotfix)** | Unplanned, must fix production issue immediately | Critical bug causing campaign failure, security patch | Release Manager (verbal) + post-hoc documentation |
| **Major** | Breaking change, data migration, schema change affecting all client orgs | Major version bump, Lead object field deletion, namespace change | Release Manager + Louis Rubino |
| **Security** | Any change to permission sets, profiles, sharing rules, Named Credentials, Connected Apps | New integration authorization, profile change | System Admin + Louis Rubino |

### 2.2 Change Request Process

**For Normal and Major changes:**

1. **Initiate:** Developer opens GitHub Issue describing the change, impacted metadata, and business justification
2. **Branch:** Create `feature/{issue-number}-{description}` branch from `develop`
3. **Develop:** Build in scratch org; retrieve to branch
4. **PR to develop:** PR must include:
   - Description of what changed
   - List of all metadata files modified
   - Test plan and results
   - Rollback assessment (can this be undone? How?)
   - Screenshots or evidence of sandbox testing
5. **CI validation:** GitHub Actions runs automatically — must pass
6. **Peer review:** At least one reviewer (Louis Rubino currently serves dual roles until team scales)
7. **Merge to develop** → auto-deploy to Developer Sandbox
8. **Integration test** in Developer Sandbox
9. **PR to release branch** → auto-deploy to Full Sandbox
10. **UAT** in Full Sandbox
11. **Release Manager sign-off** on PR to main
12. **Production deployment** by Release Manager
13. **Post-deploy monitoring** — 24 hours
14. **Close GitHub Issue** with deployment date and production validation evidence

### 2.3 Change Freeze Windows

| Period | Change Type Allowed | Reason |
|--------|--------------------|---------
| During active email campaign blast | Standard only — no schema changes | Active send operations; schema changes risk mid-send failures |
| Final 2 weeks of each quarter | Standard and Normal only — no Major | Data integrity for quarterly reporting |
| During external audit | Standard only — no configuration changes | Audit requires stable environment |
| Public holiday | Emergency only | Reduced monitoring capacity |

### 2.4 Emergency Change Protocol

When a production issue requires an immediate fix:

1. Release Manager declares emergency — documented in Slack/email with timestamp
2. Developer creates `hotfix/{description}` branch from `main`
3. Fix developed in scratch org if time permits; otherwise directly on hotfix branch
4. Minimum testing: deploy validation + critical path smoke test
5. Release Manager approves deployment verbally, with written confirmation within 4 hours
6. Deploy to production
7. Create retroactive PR to `main` AND `develop` within 24 hours
8. Post-mortem within 5 business days documenting: root cause, fix, prevention measure

---

## 3. Release Approval Process

### 3.1 Release Artifacts Required for Production Deployment

Before any production deployment, the Release Manager must have in hand:

| Artifact | Description | Where It Lives |
|----------|-------------|---------------|
| Validated deployment result | `sf project deploy validate` output showing 0 errors | CI/CD log |
| Test execution report | Apex test results — all pass, 75%+ code coverage | CI/CD log |
| Change summary | List of every metadata file in the deployment | PR description |
| Rollback plan | Specific steps to undo if deployment fails | PR description |
| Full Sandbox UAT sign-off | Written confirmation that UAT passed | PR comment or email |
| Package manifest | Exact version of every package being deployed | sfdx-project.json commit |

### 3.2 Release Naming Convention

`{year}.{quarter}.{sequence}` — e.g., `2026.Q3.1`

For package releases: semantic versioning — `OA-Core-Platform@1.2.0`

### 3.3 Release Notes

Every production release requires published release notes containing:
- Release identifier
- Date deployed
- Summary of changes (business language, not technical)
- Known issues or post-deploy monitoring items
- Who deployed and who approved

Release notes are stored in `docs/releases/` (directory to be created when first release occurs).

---

## 4. Segregation of Duties

### 4.1 Core Segregation Rules

| Rule | Who Can Do It | Who Cannot Do It |
|------|--------------|-----------------|
| Develop a change | Developer | Release Manager in their Release Manager capacity |
| Approve their own PR | Anyone | Anyone (self-approval is prohibited) |
| Deploy to production | Release Manager | The developer who wrote the code |
| Approve a security change they authored | System Admin | The person who proposed the change |
| Create a user account and assign admin profile | System Admin A | The new admin themselves |
| Authorize a new Connected App | System Admin | The integration developer requesting it |
| Review AI agent outputs | Compliance Officer | The AI agent itself (human-in-loop required) |
| Sign their own contract (future CLM) | Authorized signatory | The contract author |

### 4.2 Current Segregation Gaps (Small Team Acknowledgment)

With 2 administrators, full segregation is not always achievable. The following compensating controls apply until the team scales:

| Gap | Compensating Control |
|-----|---------------------|
| Louis Rubino often serves as both developer and release manager | All changes documented in GitHub PR with explicit written sign-off; post-hoc review of SetupAuditTrail |
| Only 2 admins — one must approve emergency changes by the other | Emergency changes require a secondary written notification to sreeni@onealgorithm.com within 4 hours |
| No dedicated compliance officer | Louis Rubino reviews SetupAuditTrail monthly; external audit firm engaged for annual review |

**Maturity target:** When the first non-admin team member is hired, immediately separate the Developer role from the Release Manager role. When the company reaches 5+ employees, designate a Compliance Officer.

---

## 5. Audit Requirements

### 5.1 Internal Audit Schedule

| Audit | Frequency | What Is Reviewed | Output |
|-------|-----------|-----------------|--------|
| User access review | Quarterly | All active users, their profiles, and permission set assignments | Written confirmation or change list |
| Service account audit | Quarterly | All Connected Apps, integration users, OAuth authorizations | Registry update |
| SetupAuditTrail review | Monthly | All admin actions in the prior 30 days | Flag any unauthorized changes |
| Permission set changes | Monthly | Review SetupAuditTrail entries for PermissionSet assignments/revocations | Confirm all changes were authorized |
| Integration registry review | Quarterly | All INT-xxx entries current; no unknown Connected Apps | Updated registry committed |
| Code coverage report | Per release | Apex test coverage ≥ 75% on all classes in scope | CI report attached to PR |
| Named Credential audit | Semi-annual | All Named Credentials exist, are current, using correct auth method | Rotation triggered if overdue |

### 5.2 External Audit Preparation

Before engaging an external auditor:

1. Export SetupAuditTrail for the audit period to CSV
2. Export user access report (all users, profiles, permission sets)
3. Export all Connected App authorizations
4. Prepare OA_COMP_AuditRecord__c report (when built)
5. Provide GitHub commit history for all production changes in the audit period
6. Prepare evidence that all production deployments had prior validation and approval

### 5.3 Federal Contractor Compliance (EDWOSB)

As an EDWOSB, One Algorithm is subject to federal contractor requirements. The following records must be maintained:

| Record Type | Retention Period | Storage |
|-------------|-----------------|---------|
| SetupAuditTrail exports | 7 years | Encrypted external storage |
| Email campaign records (CAN-SPAM compliance) | 3 years | Salesforce + backup |
| Lead data consent records | 3 years (or longer if state law requires) | OA_COMP_AuditRecord__c (planned) |
| Deployment records (what was deployed, when, by whom) | 7 years | GitHub commit history + release notes |
| Contract records (when CLM is built) | Term of contract + 7 years | OA_CLM_Contract__c + archive |

---

## 6. Documentation Requirements

### 6.1 What Must Be Documented

| Document | Where | Required Before |
|----------|-------|----------------|
| This governance model | docs/GOVERNANCE_MODEL.md | First production deployment from this repo |
| Every integration | docs/INTEGRATION_REGISTRY.md | Authorizing any new Connected App |
| Every metadata classification decision | docs/METADATA_CLASSIFICATION.md | Metadata retrieval |
| Security model and role assignments | docs/SECURITY_MODEL.md | Any permission or user change |
| Environment strategy | docs/ENVIRONMENT_STRATEGY.md | Sandbox provisioning |
| Client deployment process | docs/CLIENT_DEPLOYMENT_STRATEGY.md | First client onboarding |
| Release notes | docs/releases/{release-id}.md | Every production deployment |
| Post-mortems | docs/post-mortems/{date}-{incident}.md | Within 5 business days of any emergency |
| Architecture decisions | docs/PLATFORM_ARCHITECTURE.md | Changes to layer boundaries or package structure |

### 6.2 Documentation Standards

- All docs in Markdown, committed to this repository under `docs/`
- Every doc must have: Version, Date, Owner, Review cadence in the header
- Architectural decision records (ADRs) for major decisions that are hard to reverse (namespace choice, package type, client isolation model)
- No undocumented exceptions to governance rules — document it or don't do it

---

## 7. Future SOX / Public-Company Readiness Controls

These controls are not required today but should be designed in now to avoid painful retrofits.

### 7.1 SOX-Relevant Salesforce Controls

| Control | SOX Relevance | Current State | Target State |
|---------|-------------|--------------|-------------|
| **IT General Controls: Access Management** | Who has access to financial data | All admins have full access | Role-based, least-privilege model (defined in SECURITY_MODEL.md) |
| **Change Management Controls** | All production changes are documented, tested, and approved | No formal process | Defined in this document — implement now |
| **Segregation of Duties** | Developer ≠ Approver ≠ Deployer | Same person (Louis) currently | Separate roles enforced via PR rules as team scales |
| **Audit Trail** | All significant changes are logged and retained | SetupAuditTrail (180 days) | Export monthly; 7-year retention in external storage |
| **Automated Controls Testing** | CI/CD validates all changes before production | Not yet built | GitHub Actions pipeline (Phase 0 deliverable) |
| **User Provisioning Controls** | New user access follows a documented process | Ad hoc | Documented in SECURITY_MODEL.md; implement formal request process |
| **Periodic Access Reviews** | Regular review that access is appropriate | Not done | Quarterly (defined in Section 5.1) |
| **Backup and Recovery** | Data can be recovered in case of loss | Salesforce built-in only | Plan for Salesforce Backup and Recovery or third-party solution |

### 7.2 Controls That Must Be In Place Before Any IPO/Public-Company Process

These are typically required by auditors (Big 4 or equivalent) performing an SOX readiness assessment:

1. **Documented change management process** — this document satisfies that requirement
2. **Formal access reviews** — must be performed and documented quarterly before audit period
3. **Production = immutable without documented approval** — enforced via branch protection and Release Manager process
4. **MFA on all privileged accounts** — must be verified and documented
5. **Segregation of developer/deployer roles** — must be enforced via tooling (GitHub branch protection, not just policy)
6. **No shared credentials** — every admin has unique login; no shared admin accounts
7. **Service account inventory** — all non-human accounts documented (Integration Registry)
8. **Audit log retention** — 7-year minimum for production change history
9. **Backup and recovery tested** — annual DR test documented
10. **Third-party integration inventory** — all external data flows documented (Integration Registry)

### 7.3 SOX Readiness Roadmap

| Phase | Milestone | Target |
|-------|-----------|--------|
| Now | Implement change management process documented here | Q3 2026 |
| Phase 0 | GitHub Actions CI/CD gate (no unvalidated deploys to production) | Q3 2026 |
| Phase 1 | Provision sandbox; separate dev from production | Q3 2026 |
| Phase 1 | Create service accounts; remove integrations from admin credentials | Q3 2026 |
| Phase 2 | First formal quarterly access review documented | Q4 2026 |
| Phase 3 | External security review (pre-AppExchange listing) | Q4 2026 |
| Phase 4 | Compliance module + OA_COMP_AuditRecord__c operational | Q1 2027 |
| Phase 4 | SetupAuditTrail export to external storage automated | Q1 2027 |
| Phase 5 | SOX readiness assessment by external auditor | Q2 2027 |
| Long-term | Engage SOX compliance firm 18 months before anticipated IPO | TBD |

### 7.4 Board and Governance Infrastructure (Phase 6)

When public-company governance is required:

| Object | Purpose |
|--------|---------|
| `OA_GOV_BoardMeeting__c` | Board meeting records, agenda, resolutions |
| `OA_GOV_Resolution__c` | Corporate resolutions tied to board meetings |
| `OA_GOV_Approval__c` | Approval workflow for governance items |
| `OA_GOV_DisclosureItem__c` | Material disclosure tracking for SEC reporting |
| `OA_GOV_CommitteeAssignment__c` | Audit, compensation, nominating committee structure |

These objects are scaffolded for Phase 6 deployment into the Governance module (`modules/governance/`).

---

## 8. Package Governance

### 8.1 Package Change Control

| Change Type | Who Approves | Required Evidence |
|------------|-------------|-------------------|
| New package version (patch) | Release Manager | CI pass, sandbox validation |
| New package version (minor) | Release Manager | CI pass, Full Sandbox UAT, release notes |
| New package version (major) | Louis Rubino + Release Manager | All minor requirements + client impact assessment |
| New package created | Louis Rubino | Architecture review, naming standards compliance |
| Package deprecated | Louis Rubino | Client notification, migration path documented |
| Namespace registration | Louis Rubino | Irreversible — requires board-level sign-off when company is larger |

### 8.2 Package Dependency Governance

- No package may introduce a circular dependency
- All dependencies must be explicitly declared in `sfdx-project.json`
- A package may only depend on packages in the same or lower layer (Client → Module → Core; never Core → Module)
- External managed package dependencies (third-party) must be approved before introduction

### 8.3 Breaking Change Policy

Before introducing any breaking change (major version bump):
1. Document exactly what breaks
2. Provide a migration guide
3. Notify all affected client admins in writing (email + written acknowledgment)
4. Provide minimum 60-day deprecation window before removing deprecated functionality
5. Support the old version for one additional minor release cycle after the breaking change ships
