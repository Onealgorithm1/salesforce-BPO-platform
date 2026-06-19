# Project Context — One Algorithm BPO Platform

## Organization

**Company:** One Algorithm LLC
**Entity Type:** EDWOSB (Economically Disadvantaged Women-Owned Small Business)
**Salesforce Status:** ISV Partner (AppExchange LMA/FMA infrastructure active)
**Primary Contact:** Louis Rubino (lrubino@onealgorithm.com)
**Platform Admin:** Sreenivas (sreeni@onealgorithm.com)

## Salesforce Orgs

| Org | Username | Org ID | Purpose |
|-----|----------|--------|---------|
| PBO Production | oauser@pboedition.com | 00Dbn00000plgUfEAI | Live operations, campaigns, CRM |
| Developer / DevHub | sreeni@onealgorithm.com | 00Dd0000000haZPEAY | Package development, scratch orgs |

**Instance URL (Production):** https://onealgorithmllc.my.salesforce.com
**Edition:** Salesforce Enterprise Edition
**Microsoft 365 Tenant:** onealgorithm.com (Exchange Online via Microsoft Graph)

## What This Platform Does

One Algorithm operates as a **Salesforce-native BPO and technology platform** delivering:

1. **Internal CRM Operations** — Lead management, email campaigns, partner outreach (EDWOSB)
2. **Client Platform Deployments** — Configuring and deploying Salesforce to client organizations
3. **ISV Products** — Managed packages deployed to client orgs via AppExchange infrastructure
4. **AI-Augmented Processes** — Einstein Activity Capture, Agentforce, OpenAI integrations
5. **Government Contracting Support** — EDWOSB compliance, federal procurement outreach

## Current Production State (as of June 2026)

- **13,286 leads** in the CRM — 100% email/phone/company coverage
- **Active email outreach:** OA EDWOSB Outreach campaign via EAC + Apex scheduler
- **Einstein Activity Capture:** Enabled for lrubino@onealgorithm.com, syncing to OA EDWOSB Outreach config
- **Microsoft 365 connected:** Graph API enabled, contact + event sync bidirectional
- **AI scoring fields exist but unpopulated:** Compatibility_Score__c, Geography_Tier__c on Lead
- **OpenAI integration:** Permission set exists (OpenAI_Access), implementation pending

## Why This Repository Exists

This repository is the **source of truth** for all Salesforce metadata owned by One Algorithm.
Prior to June 2026, zero Salesforce metadata was in version control.
All changes were made directly in the production org with no audit trail in git.

This repository establishes:
- Version-controlled Salesforce metadata
- Repeatable deployment process to client orgs
- Foundation for unlocked package development
- CI/CD pipeline for Salesforce changes
- Audit trail for compliance and governance requirements

## Immediate Priorities (June 2026)

1. Complete metadata baseline retrieval into `force-app/`
2. Retrieve and classify marketing automation metadata into `modules/marketing-automation/`
3. Establish scratch org workflow for development
4. Wire GitHub Actions CI/CD validation
5. Populate AI scoring fields (Compatibility_Score__c, Geography_Tier__c) on 13,286 leads
