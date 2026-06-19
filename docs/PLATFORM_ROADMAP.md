# Platform Roadmap — One Algorithm BPO Platform

**Last updated:** June 2026

---

## Phase 0 — Foundation (June 2026) ← CURRENT

**Goal:** Establish source control, project structure, and baseline metadata.

- [x] Einstein Activity Capture enrolled for oauser@pboedition.com
- [x] Microsoft 365 connected (lrubino@onealgorithm.com)
- [x] Repository initialized with SFDX project structure
- [ ] Baseline metadata retrieval (Core — 27 classes, 1 trigger, flows, fields, LWC)
- [ ] Marketing automation metadata classified and retrieved
- [ ] GitHub Actions CI/CD validation pipeline
- [ ] Developer Sandbox provisioned
- [ ] First successful scratch org spin-up from this repo

---

## Phase 1 — Operational Stability (Q3 2026)

**Goal:** Close all critical gaps in the live email campaign system.

- [ ] Reactivate OA_EDWOSB_Outreach_Sequence flow (currently deactivated)
- [ ] Resolve 2 paused FlowInterviews from lead_by_ramesh
- [ ] Build AI lead scoring logic for Compatibility_Score__c and Geography_Tier__c
- [ ] Populate scoring on all 13,286 existing leads
- [ ] Deduplicate email templates (Day 3, 5, 10 exist in two versions each)
- [ ] Upgrade Apex API versions from v61 → v67
- [ ] Investigate and document tbid.digital.salesforce.com OAuth app
- [ ] Investigate and document OIQ_Integration connected app
- [ ] Provision Full Sandbox (clone of production)

---

## Phase 2 — Marketing Automation Module (Q3–Q4 2026)

**Goal:** Formalize the marketing module as a deployable unlocked package.

- [ ] Extract all OA_MKT_ classes and flows into modules/marketing-automation/
- [ ] Build OA_MKT_LeadScorer with OpenAI Named Credential callout
- [ ] Build multi-step EAC reply detection pipeline
- [ ] Implement Geography_Tier__c scoring from Lead.State/Country
- [ ] Build campaign analytics dashboard
- [ ] First package version: OA-Marketing-Automation@1.0.0
- [ ] Deploy marketing module to first client org

---

## Phase 3 — Contract Lifecycle Management (Q4 2026)

**Goal:** Build CLM module for government contract tracking.

- [ ] Design OA_CLM_Contract__c custom object
- [ ] Build contract approval flow
- [ ] EDWOSB certification tracking
- [ ] Contract renewal automation
- [ ] Integration with DocuSign or similar e-signature
- [ ] First package version: OA-Contract-Lifecycle@1.0.0

---

## Phase 4 — Compliance Automation (Q1 2027)

**Goal:** Automate EDWOSB and public-company compliance requirements.

- [ ] Audit trail object (OA_COMP_AuditRecord__c)
- [ ] Automated compliance reporting flows
- [ ] EDWOSB certification renewal reminders
- [ ] Federal reporting data exports
- [ ] First package version: OA-Compliance-Automation@1.0.0

---

## Phase 5 — AI Agents (Q1–Q2 2027)

**Goal:** Deploy Agentforce agents and OpenAI-powered automation.

- [ ] Lead qualification Agentforce agent
- [ ] Email reply classification agent
- [ ] Contract review AI assistant
- [ ] OpenAI Named Credential implementation
- [ ] OA_AI_AgentSession__c tracking object
- [ ] First package version: OA-AI-Agents@1.0.0

---

## Phase 6 — Governance Module (Q2 2027)

**Goal:** Public-company governance requirements support.

- [ ] Board meeting tracking object
- [ ] Approval workflow automation
- [ ] Audit committee reporting dashboard
- [ ] SOX-aligned change management flows
- [ ] First package version: OA-Governance@1.0.0

---

## Long-Term — AppExchange (2027+)

- [ ] Namespace registration for OA packages
- [ ] Security review submission for first module
- [ ] AppExchange listing for OA Marketing Automation
- [ ] Transition from unlocked → managed packages for listed products
