# AI Architecture — One Algorithm BPO Platform

**Last updated:** June 2026

---

## Current AI State (June 2026)

| Capability | Status | Notes |
|------------|--------|-------|
| Einstein Activity Capture | Active | Email + calendar sync, lrubino@onealgorithm.com connected |
| Microsoft Graph API | Active | Enabled June 17, 2026 |
| Agentforce (Einstein Agent) | Licensed | 2 seats available, 0 deployed |
| OpenAI Integration | Partial | Permission set exists, Named Credential not built |
| Lead Scoring (AI) | Not built | Fields exist, logic absent |
| Reply Detection | Active | OA_Reply_Detection flow v3 running |

---

## Layer 1 — Einstein Activity Capture (Active)

### Configuration
- **Config name:** OA EDWOSB Outreach
- **Config ID:** 063Pn0000043irpIAA
- **Enrolled user:** Louis Rubino (oauser@pboedition.com)
- **Connected mailbox:** lrubino@onealgorithm.com
- **OAuth accepted:** June 19, 2026

### What EAC Does
1. Captures inbound and outbound emails from lrubino@onealgorithm.com
2. Creates `EmailMessage` records in Salesforce, linked to matching Leads/Contacts by email address
3. Syncs calendar events bidirectionally (Salesforce ↔ Outlook)
4. Syncs contacts bidirectionally (Salesforce ↔ Outlook Contacts)

### Email → Lead Matching Logic
EAC matches emails to Salesforce records by the `To`, `From`, and `CC` email addresses.
If a Lead or Contact has the same email address as the sender/recipient, the EmailMessage
is linked to that record and appears in the activity timeline.

### Reply Detection Integration
When a lead replies to a campaign email:
1. EAC captures the reply as an EmailMessage linked to the Lead
2. OA_Reply_Detection flow (v3) is triggered by the new EmailMessage
3. Flow updates Lead.Status and OA_ tracking fields
4. Lead exits the outreach sequence

---

## Layer 2 — OpenAI Integration (Planned)

### Architecture
```
Apex Class (OA_AI_LeadScorer)
    ↓ callout via
Named Credential (OpenAI_API)
    ↓ HTTP POST to
api.openai.com/v1/chat/completions
    ↓ returns
Score + rationale JSON
    ↓ parsed and written to
Lead.Compatibility_Score__c
Lead.Geography_Tier__c
```

### Credential Management
- **Current:** OpenAI_Access permission set exists, no Named Credential built
- **Required:** Create Named Credential "OpenAI_API" in Salesforce Setup
- **Never:** Store API key in Apex code, custom settings, or this repository

### Planned Prompt Design (Compatibility Scoring)
System prompt will include:
- One Algorithm's EDWOSB service description
- Target customer profile (government contractor, federal procurement)
- Scoring criteria (0–100)

User prompt will include sanitized Lead fields:
- Company, Industry, State, LeadSource, Title
- No PII beyond what's needed for scoring

### Batch Processing Plan
1. Build `OA_AI_LeadScorer` as a `Database.Batchable` class
2. Process existing 13,286 leads in batches of 50 (API rate limit consideration)
3. Estimated runtime: ~4–6 hours for full backfill
4. On-create trigger for new leads going forward

---

## Layer 3 — Agentforce (Planned)

### License Status
- **EinsteinAgentPsl:** 2 seats available, 0 used
- **EinsteinAgentCWUPsl:** 2 seats available, 0 used

### Planned Agents

#### Agent 1 — Lead Qualification Agent
**Purpose:** Automatically qualify and score inbound leads
**Triggers:** New Lead created
**Actions:**
- Retrieve company data from external sources
- Score against ICP (Ideal Customer Profile)
- Update Compatibility_Score__c
- Route to appropriate sequence

#### Agent 2 — Reply Classification Agent
**Purpose:** Classify email replies (interested / not interested / referral / out of office)
**Triggers:** New EmailMessage captured by EAC
**Actions:**
- Read email content
- Classify intent
- Update Lead.Status accordingly
- If interested: create Task for human follow-up

#### Agent 3 — Contract Review Assistant (Phase 5)
**Purpose:** AI-assisted contract clause review
**Triggers:** New OA_CLM_Contract__c uploaded
**Actions:**
- Extract key clauses
- Flag non-standard terms
- Recommend approval/revision

---

## Layer 4 — Einstein Email Insights

**Status:** Listed in Setup navigation (Einstein Email Insights)
**Current use:** Unknown — not assessed in June 2026 baseline
**Planned:** Review and integrate with marketing module

---

## AI Data Flow (Target State)

```
New Lead Created
    ↓
OA_AI_LeadScorer (Apex, async)
    ↓ OpenAI API
Compatibility_Score__c updated (0-100)
Geography_Tier__c updated (1-4)
    ↓
Lead Assignment Flow
    ↓ routes by score
Score ≥ 70  → High Priority Queue → Human follow-up Task
Score 40-69 → OA_MKT_EDWOSB_Outreach_Sequence (Flow)
Score < 40  → Nurture sequence or disqualify

    ↓ (during outreach)
EAC captures reply
    ↓
OA_Reply_Detection (Flow)
    ↓
Reply Classification Agent (Agentforce)
    ↓
Interested → Create Opportunity, assign to Louis
Not Interested → Update Status = Closed, exit sequence
OOO → Pause sequence 7 days, retry
```

---

## Security and Compliance for AI

1. **No PII in API calls beyond what's necessary** — strip sensitive fields before OpenAI callout
2. **Log all AI scoring calls** in `OA_AI_AgentSession__c` (when built) for audit trail
3. **Human-in-the-loop for high-value decisions** — AI scores, humans close
4. **Named Credential rotation policy** — OpenAI keys rotated every 90 days
5. **No AI-generated content sent to leads without human review** — AI classifies, humans send
