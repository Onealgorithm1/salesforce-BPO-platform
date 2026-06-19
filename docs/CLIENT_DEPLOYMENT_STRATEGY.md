# Client Deployment Strategy — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** With each new client engagement

---

## 1. Deployment Philosophy

One Algorithm operates as a Salesforce ISV and BPO platform provider. The deployment model must support:

1. **Internal use:** OA's own CRM and operations (PBO Edition org)
2. **Client deployments:** Configuring and deploying Salesforce capabilities to client organizations
3. **Commercial ISV:** Distributing packaged products via AppExchange to multiple orgs at scale

These three modes are distinct and require strict architectural separation. Code and configuration from one mode must never inadvertently enter another.

---

## 2. Client Isolation Model

### 2.1 One Org Per Client (Adopted Standard)

Each client receives a **dedicated Salesforce org**. This is not negotiable for the following reasons:

| Requirement | Why One Org Per Client |
|-------------|----------------------|
| Data isolation | No SOQL query from one client can access another client's data |
| Security | Breach of one client org does not expose other clients |
| Customization | Client-specific configuration cannot conflict with other clients' configuration |
| Compliance | Federal contractor data isolation requirements |
| License management | Client pays for their own Salesforce licenses; OA licenses are separate |
| Upgrade independence | Client can choose their upgrade cadence independently |

**Rejected alternatives:**
- **Shared org with namespacing:** Insufficient isolation; org-wide admin actions affect all clients; SOQL can query across "namespaces" if sharing rules are misconfigured.
- **Communities portal on OA org:** Data residency and isolation violations; client data would sit in OA's org.

### 2.2 Client Org Registry

Every client org must be registered in the integration registry before any deployment. Required information per client:

| Field | Description |
|-------|-------------|
| Client Code | Short identifier used in `clients/{code}/` directory (e.g., `acme`) |
| Org ID | 18-character Salesforce Org ID |
| Org Type | Production / Sandbox |
| Primary Admin | Client's designated Salesforce admin |
| OA Contact | One Algorithm account manager |
| Installed Packages | Which OA packages are installed, at which version |
| Sandbox Available | Yes/No |
| Date Onboarded | ISO date |

---

## 3. Package Deployment Model

### 3.1 Deployment Layers

All deployments follow the same dependency order. No exceptions.

```
LAYER 0 — Prerequisites (installed before OA packages)
    └── Any prerequisite managed packages (Salesforce-provided or third-party)

LAYER 1 — OA Core Platform
    Package: OA-Core-Platform
    Contains: Base utilities, shared fields, data quality rules, core permission sets
    Install command: sf package install --package <OA-Core-Platform@version>

LAYER 2 — OA Feature Modules (install only what the client needs)
    Package: OA-Marketing-Automation  (depends on: OA-Core-Platform)
    Package: OA-Contract-Lifecycle    (depends on: OA-Core-Platform)
    Package: OA-Compliance-Automation (depends on: OA-Core-Platform)
    Package: OA-AI-Agents             (depends on: OA-Core-Platform)
    Package: OA-Governance            (depends on: OA-Core-Platform)

LAYER 3 — Client Configuration Overlay
    Source: clients/{client-code}/
    Deployed via: sf project deploy start --source-dir clients/{client-code}
    Contains: Client-specific permission sets, settings, custom labels, branding
    NOT a package — deployed as source, specific to one org
```

### 3.2 Package Strategy

#### Near-Term (Current through 2026): Unlocked Packages

- **Why:** Unlocked packages support iterative development without namespace locks
- **Trade-off:** Cannot be listed on AppExchange; must be installed with installation keys
- **Suitable for:** Internal use + direct client deployments with contractual relationships

#### Medium-Term (2027): Managed Packages for AppExchange Listings

- **Why:** Required for AppExchange listing; provides IP protection; supports push upgrades
- **Trade-off:** Namespace is locked permanently; migration from unlocked to managed requires rebuild
- **Decision point:** Namespace must be registered and committed to BEFORE creating the first managed package version
- **Current status:** Namespace not yet registered — this decision must be made before AppExchange listing work begins

#### Package Versioning

All packages use semantic versioning: `MAJOR.MINOR.PATCH.BUILD`

| Version Type | Meaning | Upgrade Behavior |
|-------------|---------|-----------------|
| PATCH (1.0.x) | Bug fix, no API or schema change | Push upgrade compatible |
| MINOR (1.x.0) | New feature, backward compatible | Client opt-in, recommended |
| MAJOR (x.0.0) | Breaking change | Client coordination required; deprecation notice minimum 60 days |

---

## 4. Core Platform Deployment Model

### 4.1 What the Core Package Contains

`OA-Core-Platform` (force-app/) is the foundation that every client org receives. It contains only metadata that is:
- Object-model agnostic (works for any Salesforce org)
- Not OA-brand specific
- Not module-specific

Contents:
- `OA_EmailSender` Apex class (generic email utility)
- AI scoring custom fields on Lead (`Compatibility_Score__c`, `Geography_Tier__c`)
- Core data quality rules (duplicate and matching rules)
- `OpenAI_Access` permission set (for orgs using AI features)

### 4.2 Core Package Deployment Steps

For a new client org:
```bash
# 1. Authenticate to client org
sf org login web --alias client-acme

# 2. Install Core package
sf package install \
  --package OA-Core-Platform@1.0.0-1 \
  --target-org client-acme \
  --installation-key <key>

# 3. Verify installation
sf package installed list --target-org client-acme

# 4. Run post-install validation
sf apex run --target-org client-acme \
  --file scripts/apex/verify-core-install.apex
```

### 4.3 Core Package Upgrade Path

- Patch and minor upgrades: automated push (once managed package model is adopted)
- Clients on unlocked package model: manual install of new version
- Upgrade window: notified 14 days in advance; executed during agreed maintenance window
- Rollback: not possible once installed; forward-fix only (this is why sandbox testing is mandatory)

---

## 5. Marketing Automation Module Deployment

### 5.1 Prerequisites

- OA-Core-Platform installed at compatible version
- Client org has Campaign object enabled
- Client has designated email sender (OA Org-Wide Email Address configured)
- Einstein Activity Capture enabled and licensed (if email capture is included)

### 5.2 Marketing Module Contents

`OA-Marketing-Automation` (modules/marketing-automation/) contains:
- `OA_DripScheduler`, `OA_FollowUpScheduler` Apex classes
- `OA_EDWOSB_Outreach_Sequence`, `OA_Reply_Detection` flows
- `OA_Campaign_Fields` permission set
- Email templates (client-branded versions live in client overlay)

### 5.3 Client Branding in Marketing Module

Email template content and branding are NOT in the marketing module package. They live in `clients/{code}/` and are deployed as a client overlay. This ensures:
- OA's email templates are never accidentally sent from a client org
- Client's branding is entirely self-contained
- Module upgrades do not overwrite client email customizations

---

## 6. Client Overlay Model

### 6.1 What Goes in `clients/{code}/`

The client overlay is NOT a package. It is org-specific source code deployed to exactly one org.

| Metadata Type | In Client Overlay? | Reason |
|--------------|-------------------|--------|
| Custom permission sets (client-specific roles) | Yes | Roles are unique to client org structure |
| Custom labels (client brand name, legal entity) | Yes | Brand-specific text |
| Custom metadata records (client config values) | Yes | Runtime configuration |
| Email templates (client-branded) | Yes | Never cross-pollinate email branding |
| Profiles (client-specific tweaks) | Yes | Profiles are org-specific |
| Remote Site Settings (client's endpoints) | Yes | Client-specific endpoints |
| Client-specific Apex classes | Yes | Only if client paid for custom development |
| Shared OA platform classes | No | These are in the package |
| Shared OA flows | No | These are in the package |

### 6.2 Directory Structure for a New Client

```
clients/
└── {client-code}/
    └── main/default/
        ├── permissionsets/       Client-specific permission sets
        ├── settings/             Org-wide settings
        ├── customMetadata/       Runtime configuration values
        ├── labels/               Custom labels (client brand)
        ├── email/                Client-branded email templates
        ├── profiles/             Profile overrides
        └── remoteSiteSettings/   Client-specific endpoint approvals
```

### 6.3 Creating a New Client Overlay

When onboarding a new client:

```bash
# 1. Create client directory scaffold
mkdir -p clients/{code}/main/default/{permissionsets,settings,customMetadata,labels,email,profiles}

# 2. Copy from template (if a client template exists)
cp -r clients/_template/* clients/{code}/

# 3. Customize for this client
# Edit labels, templates, permission sets

# 4. Commit to a new branch
git checkout -b client/{code}-onboarding

# 5. Deploy (never via package install — this is direct source deploy)
sf project deploy start \
  --source-dir clients/{code} \
  --target-org client-{code}-prod
```

---

## 7. Branding Isolation

### 7.1 OA Branding vs. Client Branding

| Asset | Lives In | Deployed To |
|-------|---------|-------------|
| One Algorithm logo | `clients/pbo/main/default/staticresources/` | PBO org only |
| Client X logo | `clients/{x}/main/default/staticresources/` | Client X org only |
| OA email template copy | `modules/marketing-automation/main/default/email/` (base) | Not deployed to clients directly |
| Client X email templates | `clients/{x}/main/default/email/` | Client X org only |
| OA website LWC | `clients/pbo/main/default/lwc/` | PBO org only |
| Client X website LWC | `clients/{x}/main/default/lwc/` (if applicable) | Client X org only |

**Critical rule:** No OA brand asset ever enters a client overlay. No client brand asset ever enters a package or the core/module directories.

---

## 8. Client Data Isolation

### 8.1 Data Residency

All client data resides in the client's dedicated Salesforce org. One Algorithm has no direct access to client record data except:
- As documented in the service agreement
- Via authorized integration user credentials (logged and audited)
- Via temporary admin access granted by the client (logged and time-limited)

### 8.2 No Cross-Client Data Flow

- OA production org (`00Dbn00000plgUfEAI`) contains ONLY One Algorithm's internal data
- Client orgs contain ONLY that client's data
- No integration, Named Credential, or automation should ever move data between client orgs
- Any cross-org data movement must be: approved in writing, logged, and limited to the minimum data necessary

### 8.3 Data Classification Applied to Client Deployments

Before any metadata deployment to a client org, verify:
- No OA customer data is embedded in metadata (e.g., hardcoded email addresses in flows)
- No OA-internal API keys are present in deployed metadata
- No OA-internal Named Credentials or Remote Site Settings are included

---

## 9. Multi-Client Governance

### 9.1 Client Version Matrix

Maintain a live document (separate from this repository) tracking:

| Client Code | Org ID | Core Version | Marketing Version | CLM Version | Last Deployed | Sandbox Available |
|-------------|--------|-------------|-------------------|-------------|--------------|-------------------|
| pbo | 00Dbn00000plgUfEAI | N/A (source) | N/A (source) | — | 2026-06-19 | No |
| (future clients) | | | | | | |

### 9.2 Upgrade Governance

For each installed client:
1. Test new package version in OA Developer Sandbox first
2. Test in client's sandbox (if they have one) before production
3. Provide written upgrade notes: what changed, what the client should test, rollback assessment
4. Get client sign-off before production upgrade
5. Upgrade outside business hours
6. Monitor for 24 hours post-upgrade

### 9.3 Client Offboarding

When a client relationship ends:
1. Export client overlay (`clients/{code}/`) to a separate archive branch: `archive/client/{code}`
2. Remove client directory from active `clients/` directory
3. Revoke all OA service account access to client org
4. Confirm client has revoked OA Connected App authorization
5. Document decommission date and reason in client registry

---

## 10. Future AppExchange Model

When OA transitions to managed packages for AppExchange:

| Decision | Action Required |
|----------|----------------|
| Namespace registration | Register namespace in DevHub before creating first managed package version — permanent, irreversible |
| Package migration | Managed package is NOT an upgrade of unlocked package — it is a parallel deployment until all clients migrate |
| Push upgrades | With managed packages, OA can push minor/patch upgrades to all installed orgs simultaneously |
| Security review | Required before any AppExchange listing — budget 6–12 weeks for Salesforce Security Review |
| IP protection | Managed packages obfuscate Apex code — provides IP protection unlocked packages do not |
| License management | LMA (sfLma) already installed in OA org — connect new managed packages to LMA for license tracking |
