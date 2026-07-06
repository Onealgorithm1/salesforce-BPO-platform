# Future AI Layer (Deliverable 8)

> ⛔ **DEFERRED (Phase 6 refocus, 2026-07-06).** Out of scope for the current phase, which is **Lead
> Enrichment only** (see [`LEAD_ENRICHMENT_PLATFORM.md`](LEAD_ENRICHMENT_PLATFORM.md)). AI
> recommendations are a **later phase**. Retained for future reference; not part of the active design.

_Status: **DESIGN ONLY — for review** · 2026-07-06. Human approval remains mandatory. AI never writes
to the CRM._

The AI layer turns **reviewed, canonical intelligence** into **recommended actions** that a human
approves before anything touches the CRM. It is the top of the pipeline (stages 10–12), not a
shortcut around the review gates.

---

## 1. Principles (non-negotiable)
1. **AI reads Approved canonical data only** (Layer 3). It never reads raw staging or unreviewed rows.
2. **AI output is a recommendation**, written to `OA_Intelligence_Action__c` — never a direct CRM write.
3. **Human approval is mandatory** (gate #2) before any Action executes.
4. **Grounded + cited:** every recommendation cites the canonical records / runs it used. No ungrounded
   claims; the model is given reviewed data, not free rein.
5. **Least data:** only the fields needed for the task are sent to the model; no secrets, minimal PII.
6. **Credential:** uses the existing `OA_Anthropic` Named Credential (ADR-008). No new secret.

---

## 2. Flow

```
Approved canonical intelligence (Entity/Contract/Opportunity/Compliance/Market)
        │  OA_IntelligenceAI (new service, design) → callout:OA_Anthropic
        ▼
OA_Intelligence_Action__c   (Recommendation + Rationale + Confidence + Citations, Approval=Pending)
        │  HUMAN reviews & Approves/Rejects
        ▼
Governed CRM automation      (only Approved Actions; FLS-enforced; snapshot + rollback)
        ▼
Lead / Account / Opportunity / Task
```

---

## 3. Use cases (each = an `Action_Type__c`)

| Use case | Inputs (canonical) | Recommends | Human approves |
|---|---|---|---|
| **Opportunity recommendations** | Entity capabilities (NAICS/certs) + open `OA_Opportunity_Signal__c` | "Pursue opp X — fit because…" | Create workspace / task |
| **Partner recommendations** | `OA_Relationship_Intelligence__c` (co-awards, subs) + Entity | "Team with org Y for this pursuit" | Add teaming partner |
| **Capture planning** | Contract history + agency ties + opportunity | Draft capture plan / next steps | Accept plan |
| **Proposal suggestions** | Opportunity + entity past performance | Outline/themes/past-perf to cite | Use in proposal |
| **Certification gap analysis** | Entity certs (SAM) vs opportunity set-aside eligibility | "Missing HUBZone for these 6 opps" | Flag / task |
| **Competitive intelligence** | `OA_Contract_Intelligence__c` (who wins these awards) | Incumbents & win patterns | Inform strategy |
| **Risk scoring** | Compliance (registration expiry, exclusions, tax status) | Risk score + reason | Flag compliance |
| **Agency relationship scoring** | Award history by agency | Warm-agency ranking | Prioritize outreach |

---

## 4. `OA_Intelligence_Action__c` contract (recap)
`Action_Type__c`, `Recommendation__c`, `Rationale__c`, `Confidence__c`, `Generated_By__c` (AI/Rule),
`Source_Object__c` + `Source_Record_Id__c`, `Citations__c`, `Approval_Status__c`, `Approved_By__c`,
`CRM_Target__c`, `Executed__c`. A rule engine can populate the same object for non-AI recommendations —
so the **approval + execution path is identical** whether a recommendation came from AI or a rule.

## 5. Guardrails & governance
- **No auto-execution:** no trigger/flow executes an Action; a governed service acts only on
  `Approved` rows, with FLS enforcement, before-snapshot, and rollback (reuse the write-back engine
  pattern already validated dormant).
- **Auditability:** Action → cited canonical records → runs → sources. Every AI recommendation is
  traceable to reviewed inputs.
- **Model hygiene:** prompts are templated and versioned; responses are parsed defensively; a malformed
  or low-confidence response yields a `Needs-Review` Action, never a silent CRM change.
- **Scope creep guard:** AI operates on internal intelligence objects only; it is **not** given
  credentials, callout ability to third parties, or CRM write access.

## 6. Sequencing
The AI layer is the **last** thing built — after the registry, canonical objects, dedupe, and at least
the W1 connectors provide enough reviewed data to reason over. Until then it stays on the roadmap.
