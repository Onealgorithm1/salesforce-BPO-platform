# Security Model — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026
**Classification:** Internal — Confidential
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Quarterly

---

## 1. Role Model

### 1.1 Role Hierarchy (Target State)

```
System Administrator
    ├── Release Manager
    │       └── Developer
    ├── Compliance Officer
    │       └── Auditor
    └── Integration User (service accounts, one per integration)
            └── AI Agent (scoped service account)

Future (multi-client):
    Client Administrator (per-client org, no access to OA production)
```

### 1.2 Current State vs. Target

| Role | Current | Target |
|------|---------|--------|
| System Administrator | oauser@pboedition.com, sreeni@onealgorithm.com | Unchanged — 2 named admins maximum |
| Release Manager | Louis Rubino (informal) | Formally designated, documented in this file |
| Developer | No separate developer users | Sandbox/scratch org users only — never prod |
| Compliance Officer | None | To be designated when team scales |
| Auditor | None | To be designated before first external audit |
| Integration Users | None — integrations run as admin | One service account per integration |
| AI Agent | None | One service account per AI workload |

---

## 2. Role Definitions and Access Policy

### 2.1 System Administrator

**Who:** Louis Rubino (oauser@pboedition.com), Sreenivas (sreeni@onealgorithm.com)
**Profile:** System Administrator
**Access:** Full org access
**Restrictions:**
- All admin actions are audited via SetupAuditTrail
- MFA mandatory — no exceptions
- Cannot approve their own production deployments (segregation of duties)
- Production login triggers alert notification

**Justification for two admins:** EDWOSB compliance and business continuity require minimum two authorized administrators.

---

### 2.2 Release Manager

**Who:** Louis Rubino (current); must be designated as a named role independent of admin status
**Capabilities:**
- Reviews and approves production deployment PRs
- Executes validated deployments to production
- Reviews rollback plans before deployment
- Signs off on release notes

**Cannot:**
- Be the developer of the change being approved (segregation of duties)
- Approve security policy changes they authored
- Bypass GitHub branch protection rules

---

### 2.3 Developer

**Who:** Future hires, contractors, sreeni@onealgorithm.com for feature work
**Org access:** Sandbox and scratch orgs only — never production directly
**Profile:** Standard User (sandbox) or System Administrator (scratch org only)
**Restrictions:**
- Cannot deploy to production without Release Manager approval
- Cannot access production data (PII on Lead/Contact)
- Cannot create or modify Named Credentials in production
- All code changes must enter via feature branch → PR → review

---

### 2.4 Compliance Officer

**Who:** To be designated — must be independent of development function
**Profile:** Custom — Compliance Officer (read-only, specific objects)
**Access:**
- Read: SetupAuditTrail, OA_COMP_AuditRecord__c, OA_AI_AgentSession__c
- Read: All Permission Sets and Profiles (view only)
- Read: All reports and dashboards
- No create, edit, or delete on any object
- Cannot modify security configuration

**MFA:** Mandatory

---

### 2.5 Auditor

**Who:** External audit firm designees (quarterly/annual audits)
**Profile:** Custom — Auditor (most restrictive read-only)
**Access:**
- Read: OA_COMP_AuditRecord__c (audit trail object only)
- Read: Specific report folders designated for audit
- No access to Lead PII fields (Email, Phone, Company masked)
- No access to financial or contract data
- Session duration: Maximum 2 hours per session
- Login IP: Restricted to known audit firm IP range
- Login window: Restricted to designated audit period only

**MFA:** Mandatory

---

### 2.6 Integration User (Service Account)

One dedicated service account per external integration. No shared credentials.

| Service Account Username | Integration | Objects | Permission |
|--------------------------|-------------|---------|------------|
| `m365_integration@pboedition.com` | Microsoft 365 / EAC | EmailMessage, Event, Contact | R/W — sync fields only |
| `openai_integration@pboedition.com` | OpenAI API callouts | Lead (scoring fields only) | Read + update Compatibility_Score__c, Geography_Tier__c |
| `zendesk_integration@pboedition.com` | Zendesk | Case, Contact | Read only |
| `pipedream_integration@pboedition.com` | Pipedream | To be determined | Scoped after integration audit |
| `cicd_deploy@pboedition.com` | GitHub Actions CI/CD | Metadata deployment | Deploy only — no data access |

**All service accounts:**
- Profile: Minimum Access — API Only (no UI login)
- No interactive login capability
- Password: System-generated, stored in GitHub Secrets or equivalent
- No email forwarding to human mailboxes
- Login IP: Restricted to known integration platform IP ranges where possible
- All sessions logged

**License note:** Each service account requires a Salesforce license. Evaluate Connected App OAuth Client Credentials flow as an alternative for integrations where a user seat would be consumed without justification.

---

### 2.7 AI Agent (Scoped Service Account)

**Who:** Non-human service context for Agentforce and OpenAI Apex classes
**Profile:** Custom — AI Agent (API only)
**Access scoping by agent:**

| Agent | Objects Accessible | Fields Accessible | Can Write |
|-------|-------------------|------------------|-----------|
| OA_AI_LeadScorer | Lead | Company, Industry, State, LeadSource, Title (read) / Compatibility_Score__c, Geography_Tier__c (write) | Yes — scoring fields only |
| OA_AI_GeoClassifier | Lead | State, PostalCode | Yes — Geography_Tier__c only |
| Reply Classification Agent | EmailMessage, Lead | Subject, TextBody (read) / Status (write) | Yes — Status field only |

**All AI agents:**
- Cannot export data
- Cannot access financial or contract objects
- All inputs and outputs logged to OA_AI_AgentSession__c
- PII stripped before any external API call (OpenAI)
- Human-in-the-loop required for high-value decisions (Opportunity creation, contract actions)

---

## 3. Least-Privilege Principles

Applied in this order:

1. **Default deny.** No access unless explicitly granted. All users start from Minimum Access profile.
2. **Permission sets over profile grants.** Profiles set the minimum floor. Permission sets layer specific capabilities.
3. **Object before field.** Grant object-level CRUD first. Add field-level access as a separate, documented grant.
4. **No cross-client access.** No permission set, profile, or sharing rule allows data from one client org to be visible in another.
5. **Time-bound elevated access.** Temporary admin elevation (break-glass access) is logged, requires a documented reason, and expires automatically.
6. **Integration scope is retrieval-only unless write is documented.** Every integration user write permission requires explicit justification.

### 3.1 Object Access Matrix (Target State)

| Object | Sys Admin | Developer | Release Manager | Compliance | Auditor | Integration User | AI Agent |
|--------|-----------|-----------|----------------|------------|---------|-----------------|----------|
| Lead | CRUD | CRUD (sandbox) | Read | Read | Read (no PII) | Varies | Read + score fields |
| Contact | CRUD | CRUD (sandbox) | Read | Read | None | Read (M365) | None |
| Campaign | CRUD | CRUD (sandbox) | Read | Read | None | None | None |
| EmailMessage | CRUD | Read | Read | Read | None | R/W (M365) | Read |
| OA_COMP_AuditRecord__c | CRUD | Read | Read | Read | Read | None | Create |
| OA_AI_AgentSession__c | CRUD | Read | Read | Read | None | None | CRUD |
| OA_CLM_Contract__c (planned) | CRUD | CRUD (sandbox) | Read | Read | Read | None | Read |
| Permission Sets | CRUD | None | None | Read | None | None | None |
| Named Credentials | View/Edit | None | None | None | None | None | None |
| SetupAuditTrail | Read | None | None | Read | Read | None | None |

---

## 4. Secrets Management Policy

### 4.1 Approved Storage Locations

| Location | Approved | Condition |
|----------|----------|-----------|
| Salesforce Named Credential | YES | For org-wide service-to-service auth |
| Salesforce External Credential | YES | For per-user OAuth flows |
| GitHub Secrets (repo secrets) | YES | CI/CD deployment credentials only |
| Salesforce Certificate Keystore | YES | JWT bearer flow for Connected Apps |
| Custom Setting (cleartext) | NO | Queryable via SOQL — never use for secrets |
| Custom Metadata | NO | Deployable and visible — not for secrets |
| Apex code (hardcoded) | NEVER | Enters git history; permanent exposure |
| This repository (any file) | NEVER | `.env` is gitignored but file exclusion is not a security control |
| `.env` file | NO | Local only; CI/CD systems cannot use it safely at scale |

### 4.2 Rotation Schedule

| Secret | Rotation Frequency | Who Rotates | How |
|--------|-------------------|-------------|-----|
| OpenAI API key | 90 days | Louis Rubino | Delete in OpenAI → update Named Credential |
| GitHub Actions deployment credentials | 6 months | Louis Rubino | Rotate in GitHub Secrets → update Connected App |
| Salesforce Connected App secrets | Annual | System Admin | Rotate in Setup → update dependent integrations |
| OAuth tokens (M365, Zendesk, Pipedream) | Auto-refresh | Platform | Reviewed annually; revoke and reconnect if relationship ends |
| Audit firm Auditor login | Per audit engagement | System Admin | Create before audit, deactivate immediately after |

### 4.3 Incident Response — Compromised Secret

1. Revoke immediately — do not wait for rotation cycle
2. Log incident: date, credential type, suspected exposure window
3. Query SetupAuditTrail for all actions by the compromised credential in the prior 30 days
4. Assess data exposure: what objects did the credential have access to?
5. Issue replacement credential and update all dependent systems
6. Post-incident review within 5 business days
7. If PII was accessible: assess notification obligations

---

## 5. Named Credentials and External Credentials Strategy

### 5.1 When to Use Each

| Scenario | Use |
|----------|-----|
| Org-wide API call (one shared key, not user-specific) | Named Credential |
| Per-user OAuth (each Salesforce user authenticates to the external service individually) | External Credential |
| EAC Microsoft 365 mailbox connections | External Credential (managed by Salesforce EAC internally) |
| OpenAI API (one org-level key, used by Apex batch jobs) | Named Credential |
| DocuSign per-user signing (future) | External Credential |
| GitHub Actions deployment (CI/CD, non-interactive) | Connected App + certificate, not Named Credential |

### 5.2 Naming Convention

`OA_{Service}_{Environment}`

| Named Credential Name | Service | Target | Auth Protocol |
|----------------------|---------|--------|--------------|
| `OA_OpenAI_Prod` | OpenAI | api.openai.com | Custom header (Authorization: Bearer {key}) |
| `OA_OpenAI_Dev` | OpenAI | api.openai.com | Same — separate key for non-production usage |
| `OA_Zendesk_Prod` | Zendesk | {subdomain}.zendesk.com | OAuth 2.0 |
| `OA_Pipedream_Prod` | Pipedream | api.pipedream.com | OAuth 2.0 |

**Rule:** Production and non-production environments must use separate Named Credentials with separate keys. A sandbox must never use a production API key.

### 5.3 Access Control on Named Credentials

- Named Credentials are callable from Apex only via `Http.send()` using the credential name
- Access to invoke a Named Credential is controlled by the executing Apex class's permission requirements
- No Named Credential should be exposed to Flow, formula fields, or any citizen-developer-accessible tool
- All Apex classes that call Named Credentials must have explicit test coverage verifying the callout is not made in test context (`Test.isRunningTest()` check)

---

## 6. Multi-Factor Authentication Requirements

| User Type | Production | Sandbox | Scratch Org |
|-----------|-----------|---------|-------------|
| System Administrator | Mandatory | Required | Not required |
| Release Manager | Mandatory | Required | Not required |
| Developer | Mandatory (if prod access) | Recommended | Not required |
| Compliance Officer | Mandatory | Not applicable | Not applicable |
| Auditor | Mandatory (time-limited) | Not applicable | Not applicable |
| Service accounts | N/A (no interactive login) | N/A | N/A |

**Verification action (pre-retrieval):**
Navigate to Setup → Identity → Identity Verification in production org and confirm:
- "Require MFA for All Direct UI Logins" is ON
- All active human users (oauser, sreeni) have enrolled in MFA
- No exemptions are active

---

## 7. Logging and Monitoring Requirements

### 7.1 Audit Sources

| Source | What It Captures | Retention | Who Can Access |
|--------|-----------------|-----------|----------------|
| SetupAuditTrail | All configuration and admin changes | 180 days (platform limit; export to retain longer) | System Admin, Compliance Officer |
| Salesforce Login History | All login attempts, IP, method, result | 6 months | System Admin |
| Salesforce API Usage Logs | API call volume, error rates | 30 days (platform) | System Admin |
| Apex Debug Logs | Code-level execution (on-demand capture) | 24 hours per log | Developer, System Admin |
| OA_COMP_AuditRecord__c (Phase 4) | Business-event audit trail (contract actions, compliance decisions, AI scoring) | Indefinite | Compliance Officer, Auditor |
| OA_AI_AgentSession__c (Phase 5) | All AI agent inputs, outputs, classifications, confidence scores | 12 months | System Admin, Compliance Officer |
| GitHub Actions logs | All CI/CD runs: validation, deployment, test results | 90 days (GitHub default) | Developer, Release Manager |

### 7.2 Required Alerts

| Trigger Event | Response | Who Is Notified |
|---------------|----------|-----------------|
| Login from new IP or country | Email alert | System Admin |
| 3+ failed login attempts | Account review flag | System Admin |
| Production data export > 500 records | Immediate notification | System Admin, Compliance Officer |
| New Connected App authorized | Alert | System Admin |
| Permission set assigned to any user | Log entry in SetupAuditTrail | Review monthly |
| Production deployment | Success/failure notification | Release Manager, Louis Rubino |
| Service account interactive login attempt | Immediate block + alert | System Admin |
| Managed package installed or upgraded | Alert | System Admin |

### 7.3 SetupAuditTrail Export Policy

SetupAuditTrail retains only 180 days in the platform. For compliance and SOX readiness:
- Export SetupAuditTrail to external storage monthly
- Retain exports for a minimum of 7 years (federal government contractor standard)
- Storage: encrypted at rest, access-controlled (not in this git repository)

---

## 8. Security Review Schedule

| Review | Frequency | Owner |
|--------|-----------|-------|
| User access review (active users, permission sets) | Quarterly | System Admin |
| Service account audit (active integrations, scope) | Quarterly | System Admin |
| Named Credential rotation check | Per rotation schedule | Louis Rubino |
| Unknown/unidentified Connected App review | Immediately (tbid.digital, OIQ are open items) | Louis Rubino |
| MFA enrollment verification | Quarterly | System Admin |
| SetupAuditTrail export | Monthly | System Admin |
| Full security model review | Annual | Louis Rubino |
