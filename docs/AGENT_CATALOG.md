# Agent Catalog — One Algorithm BPO Platform

**Last updated:** June 2026

---

## Overview

This document catalogs all AI agents — current, planned, and proposed — for the One Algorithm platform.
Agents include Salesforce Agentforce agents, OpenAI-powered Apex automations, and Flow-based intelligent routing.

---

## Active Agents

### AGENT-001 — OA Reply Detection (Flow-based)
**Type:** Salesforce Flow (Record-Triggered)
**Status:** Active (v3)
**Flow name:** OA_Reply_Detection
**Trigger:** New EmailMessage linked to Lead
**Logic:**
- Detects inbound email replies on campaign leads
- Updates Lead.Status to reflect reply received
- Updates OA_ tracking fields
- Triggers human follow-up task creation

**Limitations:**
- Does not classify reply intent (interested / not interested / OOO)
- Binary detection only — reply = yes/no
- No AI scoring of reply sentiment

**Upgrade path:** Replace with Agentforce Reply Classification Agent (AGENT-004)

---

## Planned Agents (Phase 1–2, 2026)

### AGENT-002 — OA Lead Scorer (Apex + OpenAI)
**Type:** Apex Batchable + Trigger
**Status:** Not built
**Class:** OA_AI_LeadScorer (planned)
**Trigger:** Lead create/update, scheduled batch for existing records
**Integration:** OpenAI API via Named Credential (OA_OpenAI_API)

**Input fields:**
- Lead.Company, Lead.Industry, Lead.State, Lead.LeadSource, Lead.Title

**Output fields:**
- Lead.Compatibility_Score__c (0–100)
- Lead.Geography_Tier__c (1–4)

**Scoring criteria:**
- Federal procurement relevance
- EDWOSB service fit
- Geographic proximity to federal hubs
- Company size/industry alignment

**Backfill needed:** 13,286 existing leads with empty scores
**Estimated backfill time:** 4–6 hours at 50 leads/batch

---

### AGENT-003 — OA Geography Tier Classifier (Apex, no AI API)
**Type:** Apex Trigger / Invocable Method
**Status:** Not built
**Class:** OA_AI_GeoClassifier (planned)
**Trigger:** Lead.State or Lead.PostalCode change

**Logic (no external API needed — pure Apex):**
- Tier 1: DC, VA, MD (federal core)
- Tier 2: TX (San Antonio), AL (Huntsville), CA (San Diego/LA), CO (Colorado Springs)
- Tier 3: All other US states
- Tier 4: International / blank

**Output:** Lead.Geography_Tier__c

**Note:** Implement this first (no API cost, immediate value on 13,286 leads)

---

## Planned Agents (Phase 5, 2027)

### AGENT-004 — Reply Classification Agent (Agentforce)
**Type:** Salesforce Agentforce Agent
**Status:** Licensed (2 seats), not configured
**License required:** EinsteinAgentPsl
**Trigger:** EAC captures inbound email reply on a campaign Lead

**Classification outputs:**
| Classification | Action |
|----------------|--------|
| Interested | Create Opportunity, assign to Louis, send acknowledgment |
| Not Interested | Update Lead.Status = Closed - Not Converted, exit sequence |
| Out of Office | Pause sequence 7 days, note OOO contact dates |
| Referral | Create new Lead from referral name, link to original |
| Request Info | Queue for human response, pause automation |
| Bounce/Invalid | Update email to invalid, flag for cleanup |

---

### AGENT-005 — Lead Qualification Agent (Agentforce)
**Type:** Salesforce Agentforce Agent
**Status:** Planned (Phase 5)
**License required:** EinsteinAgentPsl
**Trigger:** New Lead created with Company + Industry populated

**Actions:**
1. Look up company on external data source
2. Score ICP fit
3. Determine outreach sequence assignment
4. Route to appropriate queue or automation

---

### AGENT-006 — Contract Review Assistant (Agentforce + OpenAI)
**Type:** Salesforce Agentforce Agent + OpenAI
**Status:** Planned (Phase 5, dependent on CLM module)
**Trigger:** New OA_CLM_Contract__c record with attachment

**Actions:**
1. Extract text from contract PDF
2. Send to OpenAI for clause analysis
3. Flag non-standard terms
4. Generate review summary
5. Assign to attorney/reviewer with summary

---

## Agent Infrastructure Requirements

| Requirement | Current Status | Action Needed |
|-------------|----------------|---------------|
| Agentforce licenses | 2 EinsteinAgentPsl available | Configure first agent |
| OpenAI Named Credential | Not created | Create in Setup before coding |
| OA_AI_AgentSession__c object | Not built | Build in Phase 5 |
| Agent audit logging | No | Required for compliance |
| PII scrubbing before API calls | No | Required before OpenAI callouts |

---

## Agent Naming Convention

| Pattern | Example | Purpose |
|---------|---------|---------|
| AGENT-{NNN} | AGENT-001 | Catalog reference |
| OA_AI_{Name} | OA_AI_LeadScorer | Apex class name |
| OA_{Name}_Agent | OA_Reply_Agent | Agentforce agent name |
| OA_AI_{Name}__c | OA_AI_Session__c | Custom object |
