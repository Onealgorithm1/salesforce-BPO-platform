# Environment Strategy — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Semi-annual

---

## 1. Current Environment State

| Environment | Status | Org ID | Notes |
|-------------|--------|--------|-------|
| PBO Production | Active | 00Dbn00000plgUfEAI | Live operations — 13,286 leads, active campaigns |
| DevHub | Active | 00Dd0000000haZPEAY | Package development; scratch org provisioning |
| Full Sandbox | **Does not exist** | — | **Critical gap — TD-001** |
| Developer Sandbox | **Does not exist** | — | All development currently on production |
| Scratch Orgs | Available but unused | — | DevHub connected; no scratch org workflow yet |

**Critical gap:** All development and changes are currently made directly to production. No UAT, no staging, no rollback path. This is the highest-priority infrastructure item in the roadmap.

---

## 2. Target Environment Architecture

```
DEVELOPMENT TRACK
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Scratch Org   │───▶│ Developer Sandbox│───▶│    Full Sandbox     │───▶ Production
│ (feature work,  │    │ (integration QA, │    │ (UAT, staging,      │    (live ops)
│  unit testing)  │    │  develop branch) │    │  release branch)    │
└─────────────────┘    └──────────────────┘    └─────────────────────┘

HOTFIX TRACK (emergency only)
                                                ┌─────────────────────┐
                         [hotfix branch] ───────▶    Full Sandbox     │───▶ Production
                                                │ (expedited UAT)     │
                                                └─────────────────────┘

CLIENT DEPLOYMENT TRACK (future)
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│ Client Scratch  │───▶│ Client Dev/UAT   │───▶│  Client Production  │
│ (client-specific│    │ Sandbox          │    │                     │
│  testing)       │    │                  │    │                     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

---

## 3. Environment Definitions

### 3.1 Production — PBO Edition

| Attribute | Value |
|-----------|-------|
| **Org ID** | 00Dbn00000plgUfEAI |
| **URL** | https://onealgorithmllc.my.salesforce.com |
| **Edition** | Salesforce Enterprise |
| **Purpose** | Live One Algorithm operations: lead management, campaigns, EAC, ISV |
| **Data** | Real production data — 13,286 leads, active email campaigns, LMA licenses |
| **Branch** | `main` (protected) |
| **Who can deploy** | Release Manager only |
| **Deploy trigger** | Manual, gated, after Full Sandbox validation |
| **MFA required** | Yes — all users |
| **Automated changes** | None — no CI auto-deploy to production |

**Production access policy:**
- No developer should make changes directly in production Setup
- All configuration changes go through the source control → sandbox → approval → production pipeline
- Emergency hotfix exceptions require: Release Manager approval + Compliance Officer notification + post-hoc PR within 24 hours

---

### 3.2 Full Sandbox (Provision Required)

| Attribute | Value |
|-----------|-------|
| **Status** | Not yet provisioned — highest infrastructure priority |
| **Type** | Full Sandbox (complete copy of production including data) |
| **Purpose** | UAT, release staging, regression testing, integration testing |
| **Data** | Copy of production data at time of last sandbox refresh |
| **Refresh cadence** | After each major release (Major version), or monthly minimum |
| **Branch** | `release/*` auto-deploys here on branch creation |
| **Who can deploy** | Release Manager, System Admin |
| **Deploy trigger** | Automated on `release/*` branch creation; manual for ad-hoc testing |
| **MFA required** | Recommended (mirrors production policy) |

**Why Full Sandbox:**
- Contains a complete data copy — integration tests run against real data volume and schema
- Required for load testing email campaigns (need real lead volume)
- Required for EAC and M365 integration testing (needs matching data)
- UAT testers can validate against real record structure

**Provisioning steps:**
```
Setup → Sandboxes → Create Sandbox
Type: Full Copy
Name: OA-Full-Sandbox
```

**Note on sandbox cost:** Enterprise Edition typically includes one Full Sandbox. Verify license entitlement before provisioning. If a sandbox is not included, one Partial Sandbox (configurable data size) may be available.

---

### 3.3 Developer Sandbox

| Attribute | Value |
|-----------|-------|
| **Status** | Not yet provisioned |
| **Type** | Developer Sandbox or Developer Pro Sandbox |
| **Purpose** | Integration branch testing; CI/CD pipeline validation |
| **Data** | Minimal — no sensitive production data |
| **Refresh cadence** | As needed; monthly minimum |
| **Branch** | `develop` auto-deploys here on merge |
| **Who can deploy** | Developer, CI/CD pipeline (automated) |
| **Deploy trigger** | Automated via GitHub Actions on merge to `develop` |
| **MFA required** | Optional |

**Why Developer Sandbox (separate from Full):**
- Disposable — refresh frequently without affecting UAT environment
- CI/CD deployment target for every `develop` merge (full sandbox would degrade with frequent deploys)
- Developers can test deployments without affecting UAT stakeholders

---

### 3.4 Partial Sandbox (Future — Compliance and Data Testing)

| Attribute | Value |
|-----------|-------|
| **Status** | Future — Phase 4 (Compliance module) |
| **Type** | Partial Sandbox (configurable data subset) |
| **Purpose** | Compliance testing with realistic data volume, without full data exposure |
| **Data** | Configurable subset — anonymized or reduced lead set |
| **Use case** | Testing audit trail with production-scale data before deploying compliance module |
| **Branch** | `release/compliance-*` |

---

### 3.5 Scratch Orgs (SFDX Development)

| Attribute | Value |
|-----------|-------|
| **Status** | Available via DevHub (00Dd0000000haZPEAY) |
| **Duration** | 1–30 days (configurable, default 7 days) |
| **Purpose** | Feature development, unit testing, package version creation |
| **Data** | Scratch data only — seeded from scripts/apex/ |
| **Branch** | `feature/*` — one scratch org per feature branch |
| **Who creates** | Developer |
| **Deploy trigger** | On demand — developer creates their own scratch org |

**Scratch org workflow:**
```bash
# Create scratch org for a feature
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias feature-lead-scorer \
  --duration-days 14 \
  --target-dev-hub sreeni@onealgorithm.com

# Push source to scratch org
sf project deploy start --target-org feature-lead-scorer

# Run tests
sf apex run test --target-org feature-lead-scorer --code-coverage

# Retrieve any scratch org changes back to source
sf project retrieve start --target-org feature-lead-scorer

# Delete when done (or it expires automatically)
sf org delete scratch --target-org feature-lead-scorer
```

**Scratch org definitions:**
- `config/project-scratch-def.json` — general development (current, has EAC + Agentforce features)
- `config/scratch-def-marketing.json` — future: marketing module with email settings (planned)
- `config/scratch-def-clm.json` — future: CLM module (planned)

---

### 3.6 Future Client Orgs

| Attribute | Value |
|-----------|-------|
| **Purpose** | Live client operations — One Algorithm-delivered Salesforce |
| **Data** | Client's proprietary data — OA has no access by default |
| **Branch** | `client/{code}` — client-specific branch for overlay configuration |
| **Deploy trigger** | Manual, with client sign-off |
| **Access** | Time-limited, logged, only by designated OA personnel with client authorization |

Each client org requires:
- Registered in the Client Version Matrix (CLIENT_DEPLOYMENT_STRATEGY.md)
- Separate Salesforce org (not a sandbox of OA prod)
- OA packages installed in correct order (Core → Module → Overlay)
- Client's own admin contact designated

---

## 4. Promotion Path

### 4.1 Standard Feature Promotion

```
1. Developer creates scratch org from feature/* branch
2. Developer codes, tests locally in scratch org
3. Developer opens PR: feature/* → develop
4. GitHub Actions: validate deployment + run Apex tests (Developer Sandbox)
5. PR reviewed and merged to develop
6. GitHub Actions: auto-deploy to Developer Sandbox
7. Integration testing in Developer Sandbox
8. When ready for release: PR develop → release/*
9. GitHub Actions: auto-deploy to Full Sandbox
10. UAT in Full Sandbox
11. Release Manager approves PR: release/* → main
12. GitHub Actions: validate against production
13. Release Manager manually executes production deployment
14. Monitor 24 hours post-deployment
```

### 4.2 Hotfix Promotion (Emergency Only)

```
1. Identify production issue requiring immediate fix
2. Create hotfix/* branch from main
3. Develop fix (if possible, test in scratch org first)
4. Deploy to Full Sandbox for expedited UAT
5. Get Release Manager approval (verbal + documented)
6. Deploy to production
7. Create retrospective PR: hotfix/* → main AND hotfix/* → develop
   (must backport to both branches within 24 hours)
8. Post-mortem within 5 business days
```

### 4.3 Client Deployment Promotion

```
1. New package version validated in OA Full Sandbox
2. Package version installed in client's sandbox (if they have one)
3. Client UAT and sign-off
4. Install in client production during agreed maintenance window
5. Monitor 24 hours
6. Update Client Version Matrix
```

---

## 5. Testing Requirements by Environment

| Test Type | Scratch Org | Developer Sandbox | Full Sandbox | Production |
|-----------|-------------|------------------|--------------|------------|
| Unit tests (Apex) | Required — 75%+ coverage | Required — CI gate | Required | Validated only |
| Integration tests | Optional | Required | Required | Not run |
| UAT / manual testing | Developer only | Basic smoke test | Full UAT | Never |
| Load testing | Not applicable (no data) | Not applicable | Required before email blast changes | Never |
| Security scan (PMD/Code Analyzer) | Recommended | Required — CI gate | Not run | Validated only |
| Deployment validation (check-only deploy) | Not needed | CI gate | Before each release deploy | Required before every deploy |

---

## 6. Approval Requirements by Deploy Target

| Target | Approver | Required Evidence |
|--------|----------|------------------|
| Scratch org | Self (developer) | None |
| Developer Sandbox | Self or peer | GitHub Actions pass |
| Full Sandbox | Release Manager or peer | PR review + CI pass |
| Production | Release Manager | Full Sandbox UAT sign-off + PR approval + validated deployment |
| Client Sandbox | OA + Client IT | Matching OA Full Sandbox test results |
| Client Production | OA + Client Admin + Release Manager | Client Sandbox UAT + client written approval |

---

## 7. Environment-Specific Configuration

### 7.1 Named Credentials Per Environment

| Service | Scratch/Dev Sandbox | Full Sandbox | Production |
|---------|--------------------|--------------|-----------:|
| OpenAI | `OA_OpenAI_Dev` (test key, low spend limit) | `OA_OpenAI_Dev` (same) | `OA_OpenAI_Prod` (production key) |
| Microsoft 365 | Not configured | `OA_M365_Sandbox` (test mailbox) | Managed by EAC |
| Zendesk | Mock or test instance | Test instance | Production instance |

### 7.2 Data Masking Policy

Full Sandbox contains a copy of production data including PII (Lead email, phone, company).

Minimum required before granting sandbox access:
- All sandbox users are internal OA employees or contractors under NDA
- No sandbox credentials are shared with external parties
- After every sandbox refresh, confirm that lead email data is masked or that access is controlled

Future state: implement data masking profile on Full Sandbox refresh to anonymize Lead.Email and Lead.Phone before the sandbox is accessible.

---

## 8. Sandbox Refresh Policy

| Sandbox | Refresh Trigger | Frequency | Approval |
|---------|----------------|-----------|----------|
| Full Sandbox | After Major release; before Compliance or CLM module go-live | Monthly minimum | Release Manager |
| Developer Sandbox | When schema drifts from production; monthly minimum | As needed | System Admin |
| Scratch orgs | Not refreshed — destroyed and recreated | Per feature | Developer |
