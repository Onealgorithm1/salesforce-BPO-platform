# Integration Registry — One Algorithm BPO Platform

**Version:** 1.0
**Date:** June 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Quarterly — every integration must be reviewed and re-confirmed

---

## Purpose

This registry is the authoritative record of every external system that the One Algorithm Salesforce platform connects to. No integration should exist in the org that is not documented here. Any connected app, Named Credential, Remote Site Setting, or OAuth authorization that is NOT in this registry is a security finding requiring immediate investigation.

---

## Integration Risk Classification

| Risk Level | Definition |
|------------|-----------|
| **Critical** | Breach exposes PII, financial data, or enables org-wide access |
| **High** | Breach exposes operational data or enables write access to production systems |
| **Medium** | Breach disrupts operations or exposes non-sensitive business data |
| **Low** | Read-only, non-PII, easily revocable |

## Data Classification

| Classification | Definition |
|---------------|-----------|
| **Restricted** | PII, financial data, federal compliance data, authentication credentials |
| **Confidential** | Internal business data, client lists, contract terms, lead data |
| **Internal** | Non-sensitive operational data, aggregate statistics, configuration |
| **Public** | Data intended for external publication |

---

## Current Integrations (Active)

---

### INT-001 — Microsoft 365 / Exchange Online

| Field | Value |
|-------|-------|
| **Integration ID** | INT-001 |
| **Name** | Microsoft 365 / Exchange Online |
| **Status** | Active |
| **Connected Since** | June 19, 2026 |
| **Owner** | Louis Rubino (lrubino@onealgorithm.com) |
| **Business Owner** | Louis Rubino |
| **Purpose** | Einstein Activity Capture — email sync, calendar sync, contact sync for EDWOSB outreach campaign |
| **Protocol** | Microsoft Graph API (OAuth 2.0 — Authorization Code flow) |
| **Auth Method** | OAuth 2.0, per-user token (External Credential, managed by EAC platform) |
| **Salesforce Mechanism** | Einstein Activity Capture config: OA EDWOSB Outreach (063Pn0000043irpIAA) |
| **Connected Account** | lrubino@onealgorithm.com (M365 mailbox) |
| **Data Flow: Inbound to SF** | EmailMessage records, Event records, Contact sync |
| **Data Flow: Outbound to M365** | Calendar events, Contacts |
| **Data Classification** | Restricted — emails contain business communications, potential PII |
| **PII Exposure** | Yes — email content, contact names, calendar event details |
| **Risk Level** | High — access to all email in connected mailbox |
| **Business Criticality** | Critical — drives live EDWOSB outreach campaign |
| **Sandbox Equivalent** | No — EAC not configurable in sandbox without separate M365 account |
| **Token Rotation** | Auto-refresh (OAuth); manual reconnect if token expires or permission changes |
| **Review Date** | September 2026 |
| **Notes** | Graph API (`inboxUseGraphApiOffOn`) enabled June 17, 2026. OAuth consent granted June 19, 2026 17:12 UTC. Bidirectional sync for email, calendar, contacts. |

---

### INT-002 — Salesforce EAC Backend (SfdcSIQActivitySyncEngine)

| Field | Value |
|-------|-------|
| **Integration ID** | INT-002 |
| **Name** | SfdcSIQActivitySyncEngine |
| **Status** | Active |
| **Owner** | Salesforce Platform (internal) |
| **Purpose** | Einstein Activity Capture internal sync engine — platform-managed |
| **Auth Method** | Platform OAuth (managed by Salesforce, not configurable) |
| **Data Classification** | Internal |
| **Risk Level** | Low — Salesforce platform component, not a third-party integration |
| **Business Criticality** | Critical — required for EAC to function |
| **Review Date** | N/A — platform managed |
| **Notes** | This is the internal Salesforce SIQ (Sales Insights) sync service. Not a third-party integration. Do not revoke. |

---

### INT-003 — Zendesk

| Field | Value |
|-------|-------|
| **Integration ID** | INT-003 |
| **Name** | Salesforce Integration for Zendesk |
| **Status** | Active |
| **Owner** | Louis Rubino |
| **Purpose** | Support ticket sync between Zendesk and Salesforce (Case/Contact) |
| **Auth Method** | OAuth 2.0 |
| **Salesforce Mechanism** | Connected App (Salesforce Integration for Zendesk) |
| **Data Flow: Inbound to SF** | Cases, Contact updates |
| **Data Flow: Outbound to Zendesk** | Contact information |
| **Data Classification** | Confidential — customer support data, contact PII |
| **PII Exposure** | Yes — contact names, email addresses in support tickets |
| **Risk Level** | Medium — bidirectional contact data sync |
| **Business Criticality** | Medium — support operations depend on this |
| **Sandbox Equivalent** | Not configured |
| **Token Rotation** | Annual review |
| **Review Date** | September 2026 |
| **Notes** | Confirm which Zendesk instance (subdomain) this connects to. Confirm what Case fields are synced. |

---

### INT-004 — Pipedream

| Field | Value |
|-------|-------|
| **Integration ID** | INT-004 |
| **Name** | Pipedream |
| **Status** | Active |
| **Owner** | Unknown — requires investigation |
| **Purpose** | Workflow automation bridge — exact workflows unknown |
| **Auth Method** | OAuth 2.0 |
| **Data Flow: Inbound to SF** | Unknown |
| **Data Flow: Outbound to Pipedream** | Unknown |
| **Data Classification** | Unknown — requires audit |
| **PII Exposure** | Unknown — potentially yes depending on workflows |
| **Risk Level** | High (unknown scope) |
| **Business Criticality** | Unknown |
| **Sandbox Equivalent** | Not configured |
| **Review Date** | Immediate — open investigation item |
| **Notes** | **ACTION REQUIRED:** Audit all active Pipedream workflows that connect to this Salesforce org. Document what data flows through Pipedream, to what destination. If no active business purpose is identified, revoke the authorization. |

---

### INT-005 — tbid.digital (UNIDENTIFIED)

| Field | Value |
|-------|-------|
| **Integration ID** | INT-005 |
| **Name** | tbid.digital.salesforce.com |
| **Status** | Active — **UNDER INVESTIGATION** |
| **Owner** | Unknown |
| **Purpose** | Unknown |
| **Auth Method** | OAuth — Connected App |
| **Data Classification** | Unknown |
| **PII Exposure** | Unknown |
| **Risk Level** | **Critical** — unknown access scope in production org |
| **Business Criticality** | Unknown |
| **Review Date** | Immediate |
| **Notes** | **SECURITY FINDING — TD-008.** This OAuth connected app was present in the June 2026 baseline assessment but has no known business justification. The domain `tbid.digital` is unrecognized. IMMEDIATE ACTION: Determine if this was authorized by OA personnel. If origin is unknown, revoke immediately. A revocation can be reversed if the app is found to be legitimate. An unknown app with org access cannot remain without documented justification. |

---

### INT-006 — OIQ Integration (UNIDENTIFIED)

| Field | Value |
|-------|-------|
| **Integration ID** | INT-006 |
| **Name** | OIQ_Integration |
| **Status** | Active — **UNDER INVESTIGATION** |
| **Owner** | Unknown |
| **Purpose** | Unknown — "OIQ" may refer to an analytics or intelligence tool |
| **Auth Method** | Connected App (OAuth or API) |
| **Data Classification** | Unknown |
| **PII Exposure** | Unknown |
| **Risk Level** | **High** — undocumented access to production org |
| **Business Criticality** | Unknown |
| **Review Date** | Immediate |
| **Notes** | **SECURITY FINDING — TD-009.** OIQ_Integration exists as a Connected App but has no documentation. Possible interpretations: Oracle IQ, Outreach IQ, internal test app. ACTION: Query SetupAuditTrail for most recent access events from OIQ_Integration. If last access was more than 90 days ago with no documented purpose, revoke. |

---

### INT-007 — PartnerTrial

| Field | Value |
|-------|-------|
| **Integration ID** | INT-007 |
| **Name** | PartnerTrial |
| **Status** | Active |
| **Owner** | Salesforce (ISV Partner infrastructure) |
| **Purpose** | Salesforce ISV Partner Program — trial org provisioning |
| **Auth Method** | Connected App (Salesforce-managed) |
| **Data Classification** | Internal |
| **Risk Level** | Low — platform ISV infrastructure |
| **Business Criticality** | Medium — required for trial org provisioning for clients |
| **Review Date** | Annual |
| **Notes** | Standard Salesforce ISV Partner connected app. Do not revoke. |

---

### INT-008 — Environment Hub

| Field | Value |
|-------|-------|
| **Integration ID** | INT-008 |
| **Name** | Environment Hub |
| **Status** | Active |
| **Owner** | Salesforce (DevHub infrastructure) |
| **Purpose** | Connects PBO org to DevHub for scratch org and package management |
| **Auth Method** | Salesforce platform (hub connection) |
| **Data Classification** | Internal |
| **Risk Level** | Low — Salesforce platform infrastructure |
| **Business Criticality** | High — required for scratch org and package development workflows |
| **Review Date** | Annual |
| **Notes** | This connection links PBO Edition to DevHub (sreeni@onealgorithm.com / 00Dd0000000haZPEAY). Required for SFDX package operations. Do not revoke. |

---

## Planned Integrations (Not Yet Active)

---

### INT-P01 — OpenAI API

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P01 |
| **Name** | OpenAI API |
| **Status** | Planned — Phase 1–2 |
| **Owner** | Louis Rubino |
| **Purpose** | Lead compatibility scoring (Compatibility_Score__c), reply classification |
| **Protocol** | HTTPS REST API |
| **Auth Method** | API Key via Salesforce Named Credential (`OA_OpenAI_Prod`) |
| **Salesforce Mechanism** | Named Credential + Apex callout (OA_AI_LeadScorer class) |
| **Data Flow: Outbound to OpenAI** | Lead.Company, Lead.Industry, Lead.State, Lead.LeadSource, Lead.Title (sanitized — no PII email/phone) |
| **Data Flow: Inbound to SF** | Score (0–100), optional rationale text |
| **Data Classification** | Confidential — business data about leads sent externally |
| **PII Exposure** | Low — sanitized before callout. Names and contact info stripped. |
| **Risk Level** | Medium — external AI processing of business data |
| **Business Criticality** | High (once built) — drives lead prioritization |
| **Key Requirements Before Activation** | (1) Create Named Credential OA_OpenAI_Prod in Setup. (2) Confirm OpenAI data processing terms are acceptable for EDWOSB lead data. (3) Implement PII stripping in Apex before callout. (4) Log all callouts in OA_AI_AgentSession__c. |
| **Review Date** | Before implementation |

---

### INT-P02 — Google Ads

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P02 |
| **Name** | Google Ads API |
| **Status** | Planned — future phase |
| **Purpose** | Lead attribution, campaign performance correlation |
| **Auth Method** | OAuth 2.0 |
| **Data Flow: Outbound** | Campaign IDs, conversion events |
| **Data Flow: Inbound** | Ad performance metrics, audience data |
| **Data Classification** | Confidential |
| **PII Exposure** | Medium — conversion events tied to email/phone hashes |
| **Risk Level** | Medium |
| **Notes** | Requires review of Google Ads customer match policies. Cannot share raw email/phone — must use hashed identifiers. |

---

### INT-P03 — LinkedIn Campaign Manager

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P03 |
| **Name** | LinkedIn Campaign Manager API |
| **Status** | Planned — future phase |
| **Purpose** | Lead attribution, audience matching for EDWOSB outreach |
| **Auth Method** | OAuth 2.0 (LinkedIn Marketing Developer Platform) |
| **Data Classification** | Confidential |
| **PII Exposure** | Medium — email matching for LinkedIn audience targeting |
| **Risk Level** | Medium |
| **Notes** | LinkedIn's Matched Audiences API allows email-based targeting. Hash emails before transmission. Requires LinkedIn Marketing API access application. |

---

### INT-P04 — Financial System (QuickBooks / Future ERP)

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P04 |
| **Name** | Financial System Integration |
| **Status** | Planned — Phase 3+ |
| **Purpose** | Contract value sync, revenue recognition, EDWOSB contract reporting |
| **Auth Method** | To be determined by financial system selected |
| **Data Classification** | **Restricted** — financial data |
| **PII Exposure** | High — contract parties, payment terms |
| **Risk Level** | High — financial data integration |
| **Notes** | Requires formal data processing agreement. Finance system credentials must be separate Named Credential from all other integrations. Segregation of duties: finance integration not accessible to marketing users. |

---

### INT-P05 — Compliance/Regulatory System

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P05 |
| **Name** | Compliance / Regulatory Reporting System |
| **Status** | Planned — Phase 4 |
| **Purpose** | EDWOSB certification status, federal reporting data exchange, audit log export |
| **Auth Method** | To be determined |
| **Data Classification** | Restricted — federal compliance data |
| **Risk Level** | Critical — federal regulatory exposure |
| **Notes** | Must be reviewed by legal counsel before implementation. Any connection to a federal system requires security assessment and potentially FedRAMP-compliant infrastructure. |

---

### INT-P06 — Contract Management / E-Signature System

| Field | Value |
|-------|-------|
| **Integration ID** | INT-P06 |
| **Name** | DocuSign (or equivalent) |
| **Status** | Planned — Phase 3 (CLM module) |
| **Purpose** | Contract execution, e-signature workflow for OA_CLM_Contract__c |
| **Auth Method** | OAuth 2.0 per-user (External Credential) |
| **Data Classification** | Restricted — contract terms, party signatures |
| **PII Exposure** | High — signatory names, emails, legal entity data |
| **Risk Level** | High — legal document signing |
| **Notes** | Use External Credential (per-user OAuth), not Named Credential. Each signer authenticates independently. Audit trail from DocuSign must be preserved alongside OA_COMP_AuditRecord__c. |

---

## Integration Review Process

### Quarterly Review Checklist

For each active integration:
- [ ] Is the integration still serving an active business purpose?
- [ ] Has the owner changed? Update registry if so.
- [ ] Are all OAuth tokens and credentials current?
- [ ] Have there been any unauthorized access events in SetupAuditTrail?
- [ ] Is the integration's data classification still accurate?
- [ ] Are there any new data flows not previously documented?
- [ ] Is the sandbox equivalent still configured and working?

### Adding a New Integration

Before authorizing any new Connected App or OAuth integration:
1. Assign an INT-xxx ID
2. Complete all fields in this registry
3. Get sign-off from Louis Rubino (Risk Level: Medium) or Legal (Risk Level: High/Critical)
4. Create service account for the integration (not using admin account)
5. Create Named Credential or External Credential in Setup
6. Test in sandbox before authorizing in production
7. Commit updated registry to this repository
