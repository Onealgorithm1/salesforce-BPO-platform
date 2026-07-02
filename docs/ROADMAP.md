# Technical Implementation Roadmap — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 19, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Monthly; update as phases complete

This roadmap covers the technical implementation of the One Algorithm Salesforce BPO Platform from source control foundation through AI and automation layer deployment. It is the authoritative sequence for all platform engineering work.

For business roadmap and product vision, see `docs/PLATFORM_ROADMAP.md`.

> **Parallel track (Proposed):** the Evergreen **Connector Framework** runs as a separate
> workstream alongside these phases — see `docs/CONNECTOR_FRAMEWORK_ROADMAP.md` and its governing
> decision `docs/decisions/ADR-005-connector-framework.md`. Supporting governance docs (Proposed):
> `docs/CANONICAL_DATA_MODEL.md`, `docs/EVERGREEN_DATA_DICTIONARY.md`,
> `docs/ENTITY_RESOLUTION_FRAMEWORK.md`, `docs/METADATA_REGISTRY.md`, `docs/SECURITY_BASELINE.md`,
> `docs/DEFINITION_OF_READY.md` (ADR-006 … ADR-010). This does not renumber the phases below.

---

## Phase Summary

| Phase | Name | Status | Target |
|-------|------|--------|--------|
| 0 | Foundation | **COMPLETE** | June 2026 |
| 1 | Metadata Retrieval | **READY — next** | June/July 2026 |
| 2 | Metadata Classification | Pending Phase 1 | July 2026 |
| 3 | Packaging Strategy | Pending Phase 2 | Q3 2026 |
| 4 | CI/CD Pipeline | Pending Phase 3 | Q3 2026 |
| 5 | Client Deployment Framework | Pending Phase 4 | Q4 2026 |
| 6 | AI & Automation Layer | Pending Phase 5 | Q1 2027 |

---

## Phase 0 — Foundation

**Status: COMPLETE (June 19, 2026)**

### Goal
Establish a fully committed, pushed, and documented source control foundation before touching any production metadata.

### Prerequisites
- Salesforce Enterprise Edition org active
- SF CLI installed and authenticated
- Git installed
- GitHub repository created

### Deliverables

| Deliverable | File | Status |
|-------------|------|--------|
| SFDX project config | sfdx-project.json | DONE |
| Metadata exclusion rules | .forceignore | DONE |
| 3-layer directory scaffold | force-app/, modules/, clients/ | DONE |
| Manifest suite (4 manifests) | manifest/*.xml | DONE |
| Scratch org definition | config/project-scratch-def.json | DONE |
| Platform architecture doc | docs/PLATFORM_ARCHITECTURE.md | DONE |
| Security model | docs/SECURITY_MODEL.md | DONE |
| Client deployment strategy | docs/CLIENT_DEPLOYMENT_STRATEGY.md | DONE |
| Integration registry | docs/INTEGRATION_REGISTRY.md | DONE |
| Environment strategy | docs/ENVIRONMENT_STRATEGY.md | DONE |
| Governance model | docs/GOVERNANCE_MODEL.md | DONE |
| Metadata classification | docs/METADATA_CLASSIFICATION.md | DONE |
| Technical debt register | docs/TECHNICAL_DEBT.md | DONE |
| ADR-001 Namespace Strategy | docs/decisions/ADR-001-*.md | DONE |
| ADR-002 Client Isolation Strategy | docs/decisions/ADR-002-*.md | DONE |
| ADR-003 Package Boundary Strategy | docs/decisions/ADR-003-*.md | DONE |
| ADR-004 Metadata Retrieval Strategy | docs/decisions/ADR-004-*.md | DONE |
| Foundation commit on GitHub | 2be29acbb066... | DONE |
| Pre-retrieval gate review | CONDITIONAL GO issued | DONE |

### Exit Criteria
- [x] All foundation files committed and pushed
- [x] Pre-retrieval gate: security findings documented
- [x] Pre-retrieval gate: MFA partially assessed
- [x] Pre-retrieval gate: namespace decision made (ADR-001)
- [x] Pre-retrieval gate: repository risk assessed (ADR-004)
- [x] Retrieval readiness validation: CONDITIONAL GO

---

## Phase 1 — Metadata Retrieval

**Status: READY — begins Monday**

### Goal
Retrieve the complete baseline of all org-owned, unmanaged metadata from the production org into the correct source-controlled directory structure. No metadata should be written by hand — all metadata must come from the org via `sf project retrieve start`.

### Prerequisites
- [x] Phase 0 complete
- [x] Foundation commit on GitHub (rollback point exists)
- [x] Windows Long Paths enabled
- [ ] OneDrive sync paused on project folder during retrieval window
- [ ] Full Sandbox provisioned (STRONGLY RECOMMENDED before retrieval — retrieval itself is read-only, but first deployment needs a sandbox target)

### Deliverables

**Layer 1 — Core Platform** (manifest: `package-core.xml` → target: `force-app/`)

| Expected Metadata | Count | Type |
|------------------|-------|------|
| OA_EmailSender, OA_EmailSender_Test | 4 files | ApexClass |
| Lead.* custom fields | ~22–26 files | CustomField |
| OpenAI_Access | 1 file | PermissionSet |
| OA_Partner_Duplicate_Rule, Standard duplicate rules | 3 files | DuplicateRule |
| OA_Partner_Duplicate_Match, Standard matching rules | 4 files | MatchingRule |
| **Total** | **~34–38 files** | |

**Layer 2 — Marketing Automation** (manifest: `package-marketing.xml` → target: `modules/marketing-automation/`)

| Expected Metadata | Count | Type |
|------------------|-------|------|
| OA_DripScheduler, OA_FollowUpScheduler (+ tests) | 8 files | ApexClass |
| OA_EDWOSB_Outreach_Sequence, OA_Reply_Detection, lead_by_ramesh | 3 files | Flow |
| OA_Campaign_Fields | 1 file | PermissionSet |
| Email folders + templates | ~10–20 files | EmailTemplate |
| **Total** | **~22–32 files** | |

**Layer 3A — PBO Client Overlay** (manifest: `package-pbo.xml` → target: `clients/pbo/`)

| Expected Metadata | Count | Type |
|------------------|-------|------|
| 21 ApexClass (site controllers + LMA test) | 42 files | ApexClass |
| 1 ApexTrigger (linkCOACustomerToLMALicense) | 2 files | ApexTrigger |
| 6 StaticResource | 12 files | StaticResource |
| 7 LightningComponentBundle | ~35–56 files | LWC |
| 4 ApexComponent | 8 files | ApexComponent |
| 24 ApexPage | 48 files | ApexPage |
| **Total** | **~147–168 files** | |

**Total across all three layers: ~200–240 files**

### Retrieval Commands (in order)

```bash
# Step 0 — Pre-flight
# Pause OneDrive, verify git is clean
git status

# Step 1 — Layer 1 (Core)
sf project retrieve start \
  --manifest manifest/package-core.xml \
  --target-org oauser@pboedition.com
git add force-app/
git commit -m "feat: retrieve core platform metadata (Layer 1 — Core)"
git push origin main

# Step 2 — Layer 2 (Marketing)
sf project retrieve start \
  --manifest manifest/package-marketing.xml \
  --target-org oauser@pboedition.com \
  --output-dir modules/marketing-automation
git add modules/
git commit -m "feat: retrieve marketing automation metadata (Layer 2 — Marketing)"
git push origin main

# Step 3 — Layer 3A (PBO)
sf project retrieve start \
  --manifest manifest/package-pbo.xml \
  --target-org oauser@pboedition.com \
  --output-dir clients/pbo
git add clients/
git commit -m "feat: retrieve PBO client overlay metadata (Layer 3A — PBO)"
git push origin main
```

### Exit Criteria
- [ ] Layer 1 retrieved, reviewed, committed, pushed
- [ ] Layer 2 retrieved, reviewed, committed, pushed
- [ ] Layer 3A retrieved, reviewed, committed, pushed
- [ ] No unexpected metadata types in any layer
- [ ] git status clean after all three commits
- [ ] Post-retrieval audit checklist in METADATA_CLASSIFICATION.md initiated

---

## Phase 2 — Metadata Classification

**Status: Pending Phase 1**

### Goal
Audit all retrieved metadata against ADR-003 boundaries. Reclassify any metadata that landed in the wrong layer. Establish the final, clean baseline that will become the foundation for package creation.

### Prerequisites
- Phase 1 complete (all three layers retrieved and committed)

### Deliverables

| Task | Description |
|------|-------------|
| Lead field audit | Review all Lead.* fields from Layer 1; split into Core (AI scoring) vs. Marketing (campaign tracking) |
| Email template audit | Confirm all templates belong in marketing module; check for OA-specific vs. reusable |
| VF page audit | Confirm all 24 pages are OA-site-specific (none are generic utilities) |
| Permission set review | Verify OpenAI_Access grants correct fields; verify OA_Campaign_Fields scope |
| Apex class review | Confirm no cross-layer dependencies (e.g., Site classes importing Core utilities) |
| Update METADATA_CLASSIFICATION.md | Record final classification decisions for every item |
| Reclassification PRs | If any metadata needs to move layers: create feature branch, move file, update manifest, commit |

### Exit Criteria
- [ ] Every metadata item has a confirmed, documented layer assignment
- [ ] Lead field split complete (Core AI fields vs. Marketing campaign fields)
- [ ] METADATA_CLASSIFICATION.md post-retrieval audit section complete
- [ ] No metadata exists in more than one layer
- [ ] All manifests updated to reflect final classification (replace Lead.* with named fields)

---

## Phase 3 — Packaging Strategy

**Status: Pending Phase 2**

### Goal
Create the two unlocked packages (OA-Core-Platform and OA-Marketing-Automation) in the DevHub, establish package version pipelines, and validate that the packages can be installed into a scratch org.

### Prerequisites
- Phase 2 complete (metadata classification finalized)
- Full Sandbox provisioned (required for package installation testing)
- DevHub authenticated: `sreeni@onealgorithm.com` / `00Dd0000000haZPEAY` (alias: dev-org)

### Deliverables

| Task | Command / File |
|------|---------------|
| Create OA-Core-Platform package | `sf package create --name "OA-Core-Platform" --type Unlocked --path force-app --target-dev-hub dev-org` |
| Create OA-Marketing-Automation package | `sf package create --name "OA-Marketing-Automation" --type Unlocked --path modules/marketing-automation --target-dev-hub dev-org` |
| Update sfdx-project.json with packageAliases | Auto-populated by sf package create |
| Create first package versions | `sf package version create --package OA-Core-Platform --installation-key-bypass --wait 20` |
| Validate installation in scratch org | `sf package install --package <version-id> --target-org <scratch>` |
| Document installation keys | Store in secure vault (NOT in repository) |
| Update CLIENT_DEPLOYMENT_STRATEGY.md | Record first version numbers |

### Exit Criteria
- [ ] OA-Core-Platform package created in DevHub with ID
- [ ] OA-Marketing-Automation package created in DevHub with ID
- [ ] packageAliases populated in sfdx-project.json
- [ ] First package versions created (0.1.0.1)
- [ ] Packages install successfully in scratch org
- [ ] Package installation verified with Apex test run

---

## Phase 4 — CI/CD Pipeline

**Status: Pending Phase 3**

### Goal
Implement GitHub Actions pipeline that validates all code changes before they can reach production. No deployment to production without CI gate passing.

### Prerequisites
- Phase 3 complete (packages exist and have version IDs)
- Full Sandbox and Developer Sandbox both provisioned
- GitHub repository has branch protection on main (require PR + CI pass)
- SFDX authentication JWT (server key) stored as GitHub Actions secret

### Deliverables

| Deliverable | Path |
|-------------|------|
| PR validation workflow | `.github/workflows/pr-validate.yml` |
| Develop branch auto-deploy | `.github/workflows/deploy-develop.yml` |
| Release branch auto-deploy | `.github/workflows/deploy-release.yml` |
| Production deployment workflow (manual trigger) | `.github/workflows/deploy-production.yml` |
| Apex test report workflow | `.github/workflows/apex-tests.yml` |
| GitHub Actions secrets setup | `SFDX_AUTH_URL_SANDBOX`, `SFDX_AUTH_URL_PROD` |

### CI Pipeline Behavior

```
PR opened → validate deployment (check-only) + Apex tests → must pass to merge
Merge to develop → auto-deploy to Developer Sandbox
PR to release/* → validate in Full Sandbox
Merge to release/* → auto-deploy to Full Sandbox
PR to main → require Release Manager approval + CI pass
Merge to main → manual production deployment (never auto)
```

### Exit Criteria
- [ ] PR validation runs on every pull request to develop or main
- [ ] Apex test coverage ≥ 75% enforced as CI gate
- [ ] No direct push to main (branch protection active)
- [ ] First full pipeline run completed end-to-end (scratch → developer sandbox → full sandbox → production)

---

## Phase 5 — Client Deployment Framework

**Status: Pending Phase 4**

### Goal
Establish the operational process for onboarding the first external client onto the OA platform. This includes provisioning infrastructure, package installation automation, and client-specific overlay deployment.

### Prerequisites
- Phase 4 complete (CI/CD pipeline operational)
- At least one paying client ready for onboarding
- OA-Core-Platform v1.0.0 released (first production-ready version)
- Service accounts created for client org access (`cicd_deploy@pboedition.com`)

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| Client onboarding runbook | `docs/CLIENT_ONBOARDING_RUNBOOK.md` |
| Client overlay template | `clients/_template/` directory scaffold |
| First client directory | `clients/{code}/` with branded configuration |
| Client version matrix | Live tracking doc (external to repo) |
| Client org CLI alias convention | `sf org login web --alias client-{code}-prod` |
| Post-install validation script | `scripts/apex/verify-core-install.apex` |
| Client offboarding procedure | Documented in CLIENT_DEPLOYMENT_STRATEGY.md |

### Exit Criteria
- [ ] First external client org has OA-Core-Platform installed
- [ ] Client overlay deployed and validated
- [ ] Client admin trained on their org
- [ ] Client version matrix entry created
- [ ] OA service account access to client org logged and time-bounded

---

## Phase 6 — AI & Automation Layer

**Status: Pending Phase 5**

### Goal
Deploy the AI lead scoring, reply detection, and agent infrastructure that differentiates the OA platform. This includes the OpenAI integration, lead compatibility scoring engine, and the agent session logging framework.

### Prerequisites
- Phase 5 complete (at least one client live on platform)
- OpenAI API key procured and stored in Named Credential (`OA_OpenAI_Prod`)
- OA_AI_LeadScorer Apex class developed and tested in scratch org
- OA_AI_AgentSession__c custom object created (Compliance module dependency)
- Legal review of OpenAI data processing terms vs. EDWOSB lead data

### Deliverables

| Deliverable | Package | Description |
|-------------|---------|-------------|
| OA_AI_LeadScorer Apex class | OA-Core-Platform | Callout to OpenAI, returns compatibility score 0–100 |
| OA_AI_AgentSession__c | OA-Compliance or new OA-AI-Agents package | Logs every AI API call for audit |
| Lead.Compatibility_Score__c population trigger | OA-Core-Platform | Auto-score on Lead creation/update |
| Named Credential: OA_OpenAI_Prod | Deployment config | API key, endpoint, PII-stripping pre-processor |
| OA_Reply_Detection flow enhancement | OA-Marketing-Automation | Feed AI-classified replies back to campaign record |
| Agent catalog | docs/AGENT_CATALOG.md | Updated with deployed agents |

### Exit Criteria
- [ ] OA_AI_LeadScorer deployed to production with Named Credential
- [ ] Lead scoring running on at least 100 leads in production
- [ ] All AI callouts logged in OA_AI_AgentSession__c
- [ ] No PII (Lead.Email, Lead.Phone) included in OpenAI payload (verified by Apex test)
- [ ] Compatibility_Score__c field populated across existing lead base
- [ ] AI Architecture document updated with production endpoint configuration

---

## Deferred Phases (Post-Phase 6)

| Phase | Description | Trigger |
|-------|-------------|---------|
| Phase 7 — CLM | Contract lifecycle management (OA_CLM_Contract__c, DocuSign) | First client contract |
| Phase 8 — Compliance Module | OA_COMP_AuditRecord__c, SetupAuditTrail export, EDWOSB reporting | Pre-SOX assessment |
| Phase 9 — Governance Module | Board meeting records, resolutions, disclosure tracking | Pre-IPO |
| Phase 10 — AppExchange | Namespace registration, managed package conversion, Security Review | Commercial ISV launch |
