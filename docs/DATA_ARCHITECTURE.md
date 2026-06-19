# Data Architecture — One Algorithm BPO Platform

**Last updated:** June 2026

---

## Core Data Model

### Lead Object (Primary — 13,286 records)

The Lead object is the central entity for the EDWOSB outreach campaign.

#### Standard Fields in Active Use
| Field | Usage |
|-------|-------|
| Email | 100% coverage — primary campaign channel |
| Phone | 100% coverage |
| Company | 100% coverage |
| LeadSource | Segmentation |
| Status | Campaign stage tracking |

#### Org-Owned Custom Fields (22 fields)

**AI Scoring (not yet implemented)**
| Field | API Name | Type | Status |
|-------|----------|------|--------|
| Compatibility Score | Compatibility_Score__c | Number | 0% populated — priority build |
| Geography Tier | Geography_Tier__c | Picklist/Number | 0% populated — priority build |

**Campaign Tracking**
| Field | API Name | Purpose |
|-------|----------|---------|
| OA_ fields (×20) | OA_* | Outreach sequence tracking, reply flags, stage dates |

#### Data Quality (as of June 2026)
- **13,286 total leads**
- Email coverage: 100%
- Phone coverage: 100%
- Company coverage: 100%
- AI score coverage: 0% (unbuilt)
- Duplicate exposure: Active duplicate rules in place (OA_Partner_Duplicate_Rule)

---

## Object Inventory

### Standard Objects (in use)
| Object | Records (approx) | Primary Use |
|--------|------------------|-------------|
| Lead | 13,286 | EDWOSB outreach, partner pipeline |
| Campaign | Active | Email campaign management |
| CampaignMember | Active | Lead-to-campaign associations |
| Task | Active | EAC-captured email activities |
| EmailMessage | Active | EAC email capture (post June 19, 2026) |
| Event | Active | EAC calendar sync |
| Contact | Low | Business contacts |
| Account | Low | Partner organizations |

### Custom Objects
**Currently:** 0 unmanaged custom objects (managed packages own all custom objects in the org)
**Planned:**
- `OA_CLM_Contract__c` — Contract lifecycle (Phase 3)
- `OA_COMP_AuditRecord__c` — Compliance audit trail (Phase 4)
- `OA_AI_AgentSession__c` — AI agent interaction tracking (Phase 5)
- `OA_GOV_BoardMeeting__c` — Board meeting governance (Phase 6)

---

## Data Flow — Email Campaign

```
Lead (13,286)
    ↓ triggers
OA_FollowUpScheduler (Apex)         ← currently driving email
    ↓ calls
OA_EmailSender (Apex)
    ↓ sends via
Salesforce Email Action
    ↓ captured by
Einstein Activity Capture
    ↓ creates
EmailMessage (linked to Lead)
    ↓ detected by
OA_Reply_Detection (Flow)
    ↓ updates
Lead.Status / OA_ tracking fields
```

**Planned — when OA_EDWOSB_Outreach_Sequence is reactivated:**
```
Lead (Status = New/Contacted)
    ↓ triggers
OA_EDWOSB_Outreach_Sequence (Flow)  ← multi-step sequence
    ↓ calls
OA_EmailSender via Flow Action
    ↓ captured by EAC → reply detection loop
```

---

## Data Flow — EAC Sync

```
lrubino@onealgorithm.com (Exchange Online)
    ↓ Microsoft Graph API
Einstein Activity Capture (OA EDWOSB Outreach config)
    ↓ email capture
EmailMessage records (linked to matching Lead/Contact by email address)
    ↓ event sync (bidirectional)
Event records (Salesforce Calendar ↔ Outlook Calendar)
    ↓ contact sync (bidirectional)
Contact records ↔ Outlook Contacts
```

---

## Duplicate Management

| Rule | Object | Type | Status |
|------|--------|------|--------|
| OA_Partner_Duplicate_Rule | Lead | Custom | Active |
| Standard_Rule_for_Leads_with_Duplicate_Contacts | Lead | Standard | Active |
| Standard_Rule_for_Contacts_with_Duplicate_Leads | Contact | Standard | Active |

Matching rules:
- OA_Partner_Duplicate_Match (Lead — custom)
- Standard_Lead_Match_Rule_v1_0 (Lead)
- Standard_Contact_Match_Rule_v1_1 (Contact)
- Standard_Account_Match_Rule_v1_0 (Account)

---

## AI Scoring Model (Planned)

### Compatibility_Score__c
**Purpose:** Score a lead's fit with One Algorithm's EDWOSB service offering
**Input signals (planned):**
- Company size / revenue range
- Industry (government contractor adjacent)
- Geography (federal procurement hubs)
- Engagement history (emails opened, replied)
- Lead source

**Scoring method:** OpenAI API callout via Named Credential
**Trigger:** On Lead create/update, batch for existing records
**Output:** 0–100 numeric score

### Geography_Tier__c
**Purpose:** Tier leads by proximity to federal contracting activity
**Input:** Lead.State, Lead.Country, company ZIP
**Tier definitions (proposed):**
- Tier 1: DC Metro, Northern Virginia, Maryland
- Tier 2: Major federal hub cities (San Antonio, Huntsville, San Diego)
- Tier 3: All other US locations
- Tier 4: International

**Scoring method:** Apex lookup against ZIP/state mapping (no API call needed)

---

## Data Retention and Compliance

**EDWOSB requirements:**
- Lead data must be auditable for federal compliance purposes
- Email campaign records should be retained per CAN-SPAM / federal requirements
- Contact data should have consent tracking (ContactPointTypeConsent object exists in org)

**Planned:**
- Implement consent tracking on Lead and Contact
- Build data retention policy enforcement in OA Compliance module
- Audit trail via OA_COMP_AuditRecord__c (Phase 4)
