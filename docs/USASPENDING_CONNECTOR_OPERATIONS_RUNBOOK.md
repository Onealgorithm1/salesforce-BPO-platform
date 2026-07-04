# USASpending Connector — Operations Runbook

**Owner:** Louis Rubino (One Algorithm) · **Org:** `oauser@pboedition.com`
**Status:** Sprint 1C-3 CLOSED — connector deployed, proven, **dormant and locked**.
**Last reviewed:** 2026-07-03

> This is an **operations runbook**, not code. It documents how to safely re-enable, run,
> review, clean up, and re-lock the USASpending enrichment connector. Every state-changing
> step is a **human approval gate**. Nothing in this document runs automatically.

---

## 1. Purpose

**What the connector does.** On deliberate, admin-triggered invocation, it searches the public
USASpending.gov award API for a recipient, normalizes the results, and writes them into a
review-staging object (`OA_USASpending_Staging__c`) marked `Review_Status__c = Pending`.

**What it does NOT do.**
- It does **not** run on its own — no trigger, flow, scheduler, or queueable invokes it.
- It does **not** write to `Lead`, `Campaign`, `CampaignMember`, or any unsubscribe records.
- It does **not** promote data to Leads (staging is a human-reviewed holding area).
- It does **not** store or require any secret (USASpending is a public, no-auth API).

**Current production posture.** Deployed · Proven · **Dormant · Locked** — the service is Active
but reachable by **no user** (0 permission assignments) and invoked by **no automation**.

**Why this runbook exists.** The operating procedure and safety gates were established
interactively; this file makes them a durable, shareable asset so any future enrichment run
follows the same controlled, reversible path.

---

## 2. Architecture at a glance

```
 admin (manual)                                            review gate
      │                                                         │
      ▼                                                         ▼
 OA_USASpendingEnrichmentService.enrich(recipient, limit, persist)
      │  (thin admin service — no automation surface)
      ▼
 OA_ConnectorEngine.run(OA_USASpendingConnector, ctx, [recipient])
      │  build → send → parse → map (in memory)
      │        │
      │        └── callout:OA_USASpending  ──►  https://api.usaspending.gov  (public, no auth)
      ▼
 in-memory OA_USASpending_Staging__c rows  ──(persist=true)──►  OA_ConnectorPersistence.upsertStaging(..., Dedupe_Key__c)
                                                                      │ idempotent upsert (no duplicates)
                                                                      ▼
                                                        OA_USASpending_Staging__c  (Review_Status__c = Pending)
```

| Component | Role |
|---|---|
| `OA_USASpendingEnrichmentService` | Admin/manual entry point. `enrich(recipientName, limitResults, persist)`. Plain static — **no** `@InvocableMethod`/`Schedulable`/`Queueable`/trigger. |
| `OA_USASpendingConnector` | Wires the source's request/parser/mapper into the SDK. |
| `OA_ConnectorEngine` | Orchestrates build → send → parse → map (in memory; no DML). |
| `OA_ConnectorPersistence` | The **only** DML path — idempotent upsert on an External Id field. Staging only. |
| `OA_USASpending` (Named Credential) | Callout endpoint `https://api.usaspending.gov`, **no authentication, no secret**. |
| `OA_USASpending_Staging__c` | Review-staging object. Key fields: `Review_Status__c`, `Enrichment_Run_ID__c`, `Dedupe_Key__c` (External Id/Unique), `Award_ID__c`, `Recipient_Name__c`, `Award_Amount__c`, `HTTP_Status__c`, `Query_Date__c`, `Source_Endpoint__c`. |
| `OA_Connector_Staging` (permission set) | Least-privilege grant: staging object + fields only (no delete, no view-all/modify-all, no system powers). **Assign only when running; revoke after.** |

**Deterministic run id:** `enrich` derives `runId = ('USASP-' + recipientName)` (bounded to 36 chars).
The dedupe key is `runId + '|' + Award_ID__c`, so **re-running the same recipient refreshes rows
(upsert), it does not duplicate them.**

---

## 3. Current safe-state baseline

| Check | Baseline value |
|---|---|
| `OA_USASpendingEnrichmentService` / `_Test` | Active |
| `OA_Connector_Staging` assignments | **0** |
| Automation invoking the connector | **0** (triggers, flows, scheduled jobs, queueables) |
| `OA_USASpending_Staging__c` row count | **0** (after cleanup) |
| Lead write-back | none |
| Scheduled jobs referencing connector | 0 |

If any of these differ before a run, investigate before proceeding.

---

## 4. Approval gates (each requires explicit human approval)

| # | Gate | Why it matters |
|---|---|---|
| G1 | Assign `OA_Connector_Staging` | Grants a user the access to run enrichment. |
| G2 | Run a live callout | First/again real call to the external API. |
| G3 | Persist staging rows | Writes records to `OA_USASpending_Staging__c`. |
| G4 | Delete staging rows | Removes review/smoke data. |
| G5 | Revoke permission | Re-locks the connector. |
| G6 | Deploy future changes | Any metadata/code change to production. |
| G7 | Wire automation | Flow/trigger/scheduler/queueable — moves off manual control. |
| G8 | Lead write-back | Promotes reviewed staging data into business `Lead` records. |

**Rule:** never combine gates silently. Each is a separate, logged approval.

---

## 5. Standard controlled run procedure

1. **Pre-check** — confirm org, service Active, and the safe-state baseline (§3).
2. **Verify permission count** — `OA_Connector_Staging` should start at **0** assignments.
3. **[Gate G1] Assign** `OA_Connector_Staging` to exactly **one** approved user.
4. **[Gate G2] Run Step A** (`persist=false`) — dry run; proves the live callout + Named Credential work.
5. **Verify Step A wrote 0 rows** — staging count unchanged; `persisted=0`. If Step A errors, **stop**.
6. **[Gate G2+G3] Run Step B** (`persist=true`) — writes up to `limit` rows as `Pending`.
7. **Capture staging evidence** — query the run-id rows and save the results (§7 evidence query).
8. **Verify no business-record change** — Lead / Campaign / CampaignMember / unsubscribe counts unchanged.
9. **[Gate G4] Clean up** test rows if approved (by exact run id).
10. **[Gate G5] Revoke** the permission assignment.
11. **Verify final safe state** — assignments 0, staging back to baseline, no automation.

Stop after each gate if anything is unexpected. Record evidence before destructive steps.

---

## 6. Example smoke-test parameters (proven 2026-07-03)

| Parameter | Value |
|---|---|
| Recipient | `LOCKHEED MARTIN` |
| `limitResults` | `3` |
| Derived run id | `USASP-LOCKHEED MARTIN` |
| Sequence | Step A `persist=false`, then Step B `persist=true` |
| Result (A) | parsed 3 / mapped 3 / persisted 0 / 0 http / 0 parse errors |
| Result (B) | parsed 3 / mapped 3 / persisted 3 / 0 http / 0 parse errors → 3 `Pending` rows |

Use a well-known prime contractor (e.g. `LOCKHEED MARTIN`, `BOOZ ALLEN HAMILTON`, `LEIDOS`)
with a small `limitResults` (≤ the service cap of 25) to keep runs contained.

---

## 7. Example snippets (EXAMPLES ONLY — do not auto-run; contain no secrets)

> Run via `sf apex run --target-org <org> --file <script.apex>` as the approved assigned user.
> These are illustrative; substitute the approved recipient/limit at run time.

**Step A — dry run (persist=false), writes nothing:**
```apex
// EXAMPLE — proves live callout + Named Credential; NO staging write.
OA_USASpendingEnrichmentService.Result a =
    OA_USASpendingEnrichmentService.enrich('LOCKHEED MARTIN', 3, false);
System.debug('SMOKE_A runId=' + a.runId + ' parsed=' + a.parsed + ' mapped=' + a.mapped +
             ' persisted=' + a.persisted + ' http=' + a.httpErrors + ' parse=' + a.parseErrors);
```

**Step B — persist run (persist=true), writes up to `limit` Pending rows:**
```apex
// EXAMPLE — idempotent upsert into staging as Review_Status__c = Pending.
OA_USASpendingEnrichmentService.Result b =
    OA_USASpendingEnrichmentService.enrich('LOCKHEED MARTIN', 3, true);
System.debug('SMOKE_B runId=' + b.runId + ' parsed=' + b.parsed + ' mapped=' + b.mapped +
             ' persisted=' + b.persisted + ' http=' + b.httpErrors + ' parse=' + b.parseErrors);
```

**Evidence query (SOQL):**
```sql
-- EXAMPLE — capture the rows created by one run.
SELECT Id, Award_ID__c, Recipient_Name__c, Award_Amount__c, Review_Status__c,
       Dedupe_Key__c, Enrichment_Run_ID__c, HTTP_Status__c, Query_Date__c
FROM OA_USASpending_Staging__c
WHERE Enrichment_Run_ID__c = 'USASP-LOCKHEED MARTIN'
```

**Cleanup (delete only that run's rows) — Gate G4:**
```sql
-- EXAMPLE — targets ONLY the run's rows. Verify the SELECT count first, then delete those Ids.
SELECT Id FROM OA_USASpending_Staging__c WHERE Enrichment_Run_ID__c = 'USASP-LOCKHEED MARTIN'
-- then, if approved, delete exactly those returned Ids (e.g. via `sf data delete record` per Id).
```

**Permission assignment verification:**
```sql
-- EXAMPLE — who holds the permset (expect only the approved user during a run).
SELECT Id, Assignee.Username FROM PermissionSetAssignment
WHERE PermissionSet.Name = 'OA_Connector_Staging'
```

**Permission revoke verification (after Gate G5):**
```sql
-- EXAMPLE — after revoke, this count should be 0.
SELECT COUNT(Id) FROM PermissionSetAssignment WHERE PermissionSet.Name = 'OA_Connector_Staging'
```

---

## 8. Verification checklists

**Pre-run**
- [ ] Correct org (`oauser@pboedition.com`).
- [ ] `OA_USASpendingEnrichmentService` Active.
- [ ] `OA_Connector_Staging` assignments = 0 (then G1 assign to one user).
- [ ] Baseline staging row count recorded.
- [ ] No connector-invoking automation.

**Post-Step A (dry run)**
- [ ] `persisted = 0`, `httpErrors = 0`, `parseErrors = 0`.
- [ ] `parsed > 0` (live callout returned data).
- [ ] Staging row count unchanged.

**Post-Step B (persist)**
- [ ] `persisted` between 1 and `limit`.
- [ ] All new rows `Review_Status__c = Pending`.
- [ ] `Enrichment_Run_ID__c` matches the expected run id; `Dedupe_Key__c` populated; `HTTP_Status__c = 200`.
- [ ] Lead / Campaign / CampaignMember / unsubscribe counts unchanged.
- [ ] No automation fired.

**Cleanup**
- [ ] Evidence captured first.
- [ ] Delete count == created count, scoped by run id only.
- [ ] No other staging rows affected.

**Re-lock**
- [ ] `OA_Connector_Staging` assignment deleted (or explicitly retained with reason).
- [ ] Assignments = 0 (if revoked).

**Final closure**
- [ ] Staging back to baseline.
- [ ] No automation, no standing access.
- [ ] Risks/evidence recorded; next step identified.

---

## 9. Rollback and recovery

- **Remove smoke/test rows:** delete by exact `Enrichment_Run_ID__c` (Gate G4). Never a blanket delete.
- **Re-lock access:** delete the `PermissionSetAssignment` for `OA_Connector_Staging` (Gate G5).
- **Leave classes dormant:** the service is inert until invoked; no code rollback needed for a clean run.
- **Destructive rollback (only if a defect requires it):** a destructive deploy removing the connector
  classes / Named Credential / `Dedupe_Key__c` / permission set. Because the components are additive and
  dormant, this is rarely warranted.
- **Recycle Bin note:** deleted `OA_USASpending_Staging__c` rows are recoverable from the org Recycle Bin
  for a limited window (~15 days) if a deletion needs reversing.

---

## 10. Deferred work register (all future, gated, design-first — none started)

| Item | Gate | Notes |
|---|---|---|
| Flow-invocable design | G6/G7 | Expose `enrich` to a screen-flow button; **no** record-triggered auto-fire. |
| Queueable / bulk wrapper design | G6/G7 | Scaled batch enrichment; async chaining + governor limits. |
| **Lead write-back design** | G8 | Promote reviewed `Pending` staging rows into `Lead` — the sensitive business step. Human-approved, field-mapped. |
| Retire legacy `OA_USASpendingClient` | G6 | Confirm no references → deprecate → destructive-deploy; also closes its 0% in-org coverage gap. |
| Retire legacy Remote Site (`OA_USASpending`) | G6 | Only after the old client is removed (it still uses raw `Http`). |
| Dedicated service-user strategy | G1 | Optional: a least-privilege non-admin service user (would need Apex class access) instead of assigning to an admin. |

---

## 11. Risk register

| Risk | Level | Mitigation |
|---|---|---|
| Accidental **standing permission** | 🟡 | Assign only during a run; revoke after (G1/G5); baseline = 0 assignments. |
| Live API **variability** | 🟢 | Small `limit`; well-known recipient; Step A dry run surfaces issues before any write. |
| **Duplicate / idempotency** | 🟢 | Deterministic run id + `Dedupe_Key__c` upsert → re-runs refresh, not duplicate. |
| **Staging cleanup** hitting wrong rows | 🟡 | Always scope deletes by exact `Enrichment_Run_ID__c`; verify SELECT count before delete. |
| Future **Lead write-back** | 🔴 (future) | Separate design + Gate G8; never automatic; field-mapped and reviewed. |
| **Automation wiring** | 🟡 (future) | Gate G7; avoid record-triggered auto-fire; keep manual/controlled first. |
| Legacy **client / Remote Site cleanup** | 🟡 (future) | Confirm no dependencies before destructive deploy; staged plan + rollback. |
| **Local Anthropic key hygiene** (unrelated) | 🟠 | Separate issue — a plaintext key sits in a local **git-ignored** file (NOT in git/GitHub). Precautionary rotation + org-only secret storage recommended; tracked separately. Not part of this connector. |

---

## 12. Definition of Done — a controlled enrichment run

A run is **Done** when:
- [ ] It was **approved** (the relevant gates G1–G5).
- [ ] It **ran** (Step A then Step B as needed).
- [ ] **Evidence captured** (result counts + staging snapshot).
- [ ] Staging rows **reviewed or cleaned up**.
- [ ] **No business-record impact** (Lead/Campaign/CampaignMember/unsubscribe) unless separately approved (G8).
- [ ] Permission **revoked** (or explicitly retained with a documented reason).
- [ ] **Risks recorded** and the **next step identified**.

---

## Related records / references

- Sprint 1C-3 deployment ID: `0AfPn0000022SLdKAM` · fresh validation ID: `0AfPn0000022SIPKA2` · tests 147/0.
- PR #7 merge commit: `43d60f61f0c1bd39bea27d1242cf3bc335d589c7`.
- Connector design: `docs/CONNECTOR_FRAMEWORK.md`, `docs/decisions/ADR-005-connector-framework.md`.
