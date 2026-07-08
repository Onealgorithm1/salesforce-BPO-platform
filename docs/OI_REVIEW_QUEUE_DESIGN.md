# Opportunity Intelligence — Review Queue Design

**Program 2 · Phase 0 (design only) · 2026-07-08**
Relates to [ADR-018](decisions/ADR-018-opportunity-review-queue-and-human-gates.md).

The review queue is the **human-in-the-loop heart** of OI. Every opportunity the platform ingests
lands here as `Review_Status__c = Pending`. Nothing advances toward a pursuit or a CRM record
without a human acting on it here.

---

## 1. States & transitions

`Review_Status__c` on `OA_Opportunity_Signal__c`:

```
              (ingest, automatic)
   [ source ] ─────────────────────►  Pending
                                         │
        ┌────────────────────────────────┼───────────────────────────────┐
        │ human: not relevant            │ human: relevant                │ human: worth pursuing
        ▼                                ▼                                ▼
    Dismissed                        Reviewed                         Promoted
   (archived, no                (kept, informational)        (Phase 4: becomes a
    further action)                                           Pursuit Candidate)
```

- **Pending** — system default on every new signal. The only state the system sets.
- **Reviewed** — a human looked and kept it (informational / watch).
- **Dismissed** — a human judged it not relevant; stays for audit, drops out of the working queue.
- **Promoted** — a human marked it worth pursuing → seeds an `OA_Pursuit_Candidate__c` (Phase 4).
  **Promotion never auto-creates a CRM `Opportunity`** — that is a further, separate Phase-5 gate.

**Rule:** the system only ever *writes* `Pending`. Every other transition is a recorded human action
(`Reviewed_By__c` / `Reviewed_At__c` / `Review_Notes__c`).

## 2. MVP surface (Phase 1 — no custom UI)

Deliver the queue with **standard Salesforce reporting**, not a Lightning app (UI-first artifacts
are deferred; consistent with prior lessons that reports/dashboards are built in the UI, and custom
report types must exist before the report):

- **Custom Report Type** on `OA_Opportunity_Signal__c`.
- **Report: "Opportunity Review Queue"** — filter `Review_Status__c = Pending`, sort by
  `Response_Deadline__c` ascending; columns: Title, Source, Agency, NAICS, Set-Aside, Est. Value,
  Response Deadline, Confidence, URL.
- **List views** on the object: "Pending Review", "Closing This Week" (`Response_Deadline__c` ≤ 7d),
  "By Source". Reviewers action records inline (edit `Review_Status__c` + notes).

## 3. Later surface (Phase 3–4)

- **Ranked queue** — once `OA_Opportunity_Score__c` exists (Phase 3), the report sorts by
  `Total_Score__c` / `Band__c` and shows per-factor reasons.
- **Go/No-Go review** — `OA_Go_NoGo_Assessment__c` shows the **system draft** `Recommendation__c`;
  the human records the final `Decision__c` (system never sets it).
- **Pursuit board** — `OA_Pursuit_Candidate__c` Kanban (Draft→UnderReview→Approved/Rejected); a
  Lightning page/app is a Phase-4 UI build.

## 4. Human gates enforced at the queue

| Action | Who | Gate |
|---|---|---|
| Ingest signal (Pending) | system | automatic (allowed) |
| Mark Reviewed / Dismissed | reviewer | human |
| Promote to Pursuit Candidate | reviewer | human (Phase 4) |
| Final Go/No-Go `Decision__c` | reviewer | human (Phase 4) |
| Create CRM `Opportunity` | approver | **human + G5** (Phase 5) |
| Assign pursuit owner / proposal tasks | approver | human (Phase 5/6) |
| Any external submission | — | **never automated** |

## 5. SLAs & hygiene (operational, later)

- **Deadline hygiene:** "Closing This Week" list view surfaces time-critical postings; expired
  postings (`Response_Deadline__c < today`) auto-flag `Status__c = Expired` at next ingest (no
  deletion — audit retained).
- **Queue volume control:** dedupe by `Canonical_Key__c` prevents re-run duplication; source filters
  (agency/NAICS/doc-type) keep noisy feeds (Federal Register) from flooding the queue.
- **Metrics (Phase 4 dashboard):** new signals/day, pending backlog, median time-to-review,
  dismiss rate, promote rate, by-source mix.

## 6. What the queue guarantees

- No opportunity ever becomes a commitment without a human touching it here.
- Every state change is attributable and time-stamped.
- The system's only autonomous act is *presenting* opportunities — never *deciding* on them.
