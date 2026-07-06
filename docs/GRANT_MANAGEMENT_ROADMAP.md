# Grant Management Roadmap (Deliverable 7)

> ⛔ **DEFERRED (Phase 6 refocus, 2026-07-06).** Out of scope for the current phase, which is **Lead
> Enrichment only** (see [`LEAD_ENRICHMENT_PLATFORM.md`](LEAD_ENRICHMENT_PLATFORM.md)). Grants /
> proposal / workspace management is a **later phase**. Retained for future reference.

_Status: **DESIGN ONLY — for review** · 2026-07-06. **Do not implement authenticated Grants.gov
integration.** Architecture only._

Louis has confirmed **active Grants.gov workspaces** and **Expanded AOR** authority. This module
designs how the platform would manage the *grant lifecycle inside Salesforce* — turning the reviewed
opportunity signals (from the dormant Grants.gov connector) into managed pursuits. It is a **future
module**; nothing here is built, and the authenticated Grants.gov System-to-System (S2S) integration
is explicitly out of scope until a separate, gated credential/authority decision.

---

## 1. Where it sits

```
OA_Opportunity_Signal__c  (reviewed, from Grants.gov connector — DORMANT today)
        │  human decides "pursue"
        ▼
OA_Grant_Workspace__c  ──►  OA_Grant_Proposal__c  ──►  OA_Grant_Submission__c
        │                        │                          │
        ├─ OA_Compliance_Checkpoint__c (SAM active? cert current? deadline?)
        └─ Files (ContentDocument: narratives, budgets, attachments)
        ▼
   Account / Opportunity (CRM)   — linkage is human-approved (ADR-007), never automatic
```

The **read** side (finding opportunities) is the External Intelligence Framework. The **write/manage**
side (pursuing and submitting) is this module. They meet where a reviewer promotes an opportunity
signal into a workspace.

---

## 2. Grant lifecycle (states)

```
Identified → Reviewing → Intent-to-Apply → Proposal-Development → Internal-Review →
Submitted → Under-Agency-Review → Awarded / Rejected / Withdrawn → Post-Award → Closeout
```

`OA_Grant_Workspace__c.Stage__c` is a restricted picklist over those states. Every transition is a
human action; no automation advances a stage on its own.

## 3. Objects (design)

**`OA_Grant_Workspace__c`** (parent / pursuit record)
`Opportunity_Signal__c` (lookup — the seed), `Grants_Gov_Workspace_Id__c` (Text — external ref only,
no credential), `Opportunity_Number__c`, `Agency__c`, `Stage__c`, `Close_Date__c`, `Owner`,
`Go_No_Go__c`, `Est_Award_Value__c`, `Account__c` (applicant, reviewed link), `Notes__c`.

**`OA_Grant_Proposal__c`** (one per proposal attempt)
`Workspace__c` (master-detail), `Title__c`, `Status__c` (Drafting/Review/Final), `Version__c`,
`Budget_Total__c`, `Narrative_Ref__c` (ContentDocument), `Internal_Reviewer__c`, `Due_Date__c`.

**`OA_Grant_Submission__c`** (submission event/tracking)
`Proposal__c` (lookup), `Submission_Date__c`, `Method__c` (Manual / Workspace / S2S-future),
`Tracking_Number__c`, `Confirmation_Ref__c`, `Status__c` (Submitted/Received/Validated/Error),
`Agency_Status__c`.

**`OA_Compliance_Checkpoint__c`** (gate log per workspace)
`Workspace__c` (master-detail), `Check_Type__c` (SAM-Registration-Active / Cert-Current /
Deadline-Met / Budget-Complete / Rep-Certs), `Status__c` (Pass/Fail/NA), `Checked_Date__c`,
`Evidence_Ref__c` (link to `OA_Compliance_Intelligence__c` / `OA_Entity_Intelligence__c`).

## 4. Capability areas

| Capability | Design | Notes |
|---|---|---|
| **Workspace synchronization** | Mirror Grants.gov Workspace **status/metadata** into `OA_Grant_Workspace__c` | **Future/S2S only** — needs authenticated API; today store the workspace **id/URL as a reference**, entered by hand. No callout. |
| **Proposal lifecycle** | Version-tracked `OA_Grant_Proposal__c` + Salesforce Files | Internal review = human gate |
| **Submission tracking** | `OA_Grant_Submission__c` records method + tracking number | Manual entry today; S2S auto-status future |
| **Award tracking** | Workspace `Stage__c` → Awarded/Rejected; `Est_Award_Value__c` vs actual | Feeds `OA_Contract_Intelligence__c` once public (USASpending) |
| **Document management** | ContentDocument linked to Workspace/Proposal | Native Files; no external storage |
| **Compliance checkpoints** | `OA_Compliance_Checkpoint__c` gates before submission | Pulls from Compliance/Entity intelligence (SAM active, cert current, deadline) |

## 5. S2S integration — **future only, explicitly deferred**

The Grants.gov **System-to-System / Workspace API** would let the platform push/pull proposal packages
and statuses programmatically. It requires:
- Authenticated Grants.gov org registration, **AOR/EBiz** authority (Louis has Expanded AOR),
- OAuth/credentials + likely MFA, stored as an **External Credential** (ADR-008),
- A dedicated, gated build with its own security review.

**Not designed in detail and not built here.** Until then, the module operates on **manual entry +
reviewed opportunity signals** — full grant *management* value with zero authenticated integration.

## 6. Guardrails
- No authenticated Grants.gov callout is built. No credential provisioned.
- Account/Opportunity linkage is human-approved (ADR-007). No stage auto-advances.
- All objects additive and dormant; delivered as a **future** module after the core framework and
  W1 connectors land.
