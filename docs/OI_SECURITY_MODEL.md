# Opportunity Intelligence — Security & Governance Model

**Program 2 · Phase 0 (design only) · 2026-07-08**
Extends ADR-008 (security & credential standard). Relates to
[ADR-019](decisions/ADR-019-opportunity-intelligence-security-model.md).

---

## 1. Principles

1. **Read-only sources.** Every external API is GET-only. OI submits, posts, or writes back to
   **no** external system — ever.
2. **Secrets only in External Credentials.** No API key, token, or secret in git, Apex, CMDT, or a
   custom-setting text field. (Avoids the pre-existing `OA_Graph_Credential__c` plaintext
   anti-pattern, which is Program-1 tech debt, not OI's to fix or copy.)
3. **Least privilege.** A dedicated permset scoped to the new object only; a least-privilege
   runtime user is the target.
4. **Dormant by default.** Connectors `Enabled__c=false`, permset unassigned, object empty, no jobs.
5. **Human-gated writes.** No CRM `Opportunity`, outreach, pursuit assignment, or submission
   without an explicit human action.
6. **Auditable & reversible.** Every run stamped in `OA_Connector_Run__c`; MVP is insert-only and
   delete-by-run reversible; Phase-5 writeback reuses `OA_ChangeLogService` snapshot/rollback.

## 2. Credentials

| Source | Credential | Secret? | Phase |
|---|---|---|---|
| Grants.gov | Named Credential `OA_GrantsGov` (public endpoint, **no secret**) | none | 1 |
| SAM.gov Opportunities | Named + **External** Credential `OA_SAM_Opportunities` (data.gov `api_key` header) | **in EC only, provisioned in Setup by Louis** | 2 |
| SBIR / Federal Register | public Named Credentials (endpoint only) | none | 3 |

**Do not** reuse or repoint the existing `OA_SAM` (Entity API) credential — SAM Opportunities is a
distinct endpoint and key. **Do not** reuse `OA_USASpending` for opportunity fetches (it is the
past-performance/scoring input, reused read-only in Phase 3).

## 3. Access control

- **Permission set `OA_Opportunity_Intelligence_Runtime`** — CRUD/FLS on `OA_Opportunity_Signal__c`
  (and later Score/Assessment/Pursuit). **Unassigned by default.** Assigned only to the runtime
  user + reviewers when a run is authorized.
- **Runtime user** — target is a dedicated least-privilege user. **Standing exception:** OI
  inherits the Program-1 MAD-`oauser` carryover (over-privileged admin, driven by a licensing
  constraint — 0 spare licenses). This is the **top standing operational risk**; it bounds the
  safety of *unattended* automation. The MVP is **manual**, so exposure is bounded; 24×7 OI
  automation is gated (G5) on replacing the runtime user. See `RUNTIME_USER_EXCEPTION.md`.
- **Reviewers** — a review permset/profile grants read + `Review_Status__c`/notes edit on signals;
  reviewers cannot enable connectors or create CRM records.

## 4. Writeback guardrails

- **MVP (Phase 1–2):** the only DML is `insert OA_Opportunity_Signal__c` (+ reused run/exception
  rows). There is **no code path** that writes to Lead, Account, Campaign, ERE, Analytics, or any
  Lead-Enrichment object.
- **Phase 5 (CRM Opportunity):** created **only** on an explicit human approval action, one record
  at a time, audited via `OA_ChangeLogService`, reversible. Read-only Account association only
  (ADR-007). This is a separate approval (G5), not implied by any earlier gate.

## 5. Threats & mitigations

| Threat | Mitigation |
|---|---|
| Secret leakage | secrets only in External Credentials; nothing sensitive in git/CMDT/Apex; repo scan before commit |
| Over-privileged runtime user (MAD `oauser`) | documented standing exception; MVP manual/bounded; gate 24×7 on least-priv user (G5) |
| Accidental write outside OI | new-object-only DML; proposal/writeback engines left alone; explicit no-touch list; code review |
| Unauthorized connector enablement | `Enabled__c=false` default; enabling is a reviewed metadata change; kill switch = disable row |
| Runaway volume / rate-limit lockout | callout-before-DML, ≤50/txn, paging + backoff; keyless sources first |
| Review-queue poisoning / noise | source-scoped `Canonical_Key__c` dedupe; tight agency/doc-type filters; confidence banding |
| Data exfiltration via outbound | sources are GET-only; no outbound writes exist in the design |
| Parallel-session collision (shared org/tree) | build in isolated worktree/branch; quiet-org check before any deploy; no push/merge without approval |

## 6. Audit trail

- **Provenance:** `OA_Connector_Run__c` per fetch — endpoint, counts (requested/parsed/mapped/
  persisted), HTTP/parse errors, status, initiated-by, timestamps.
- **Lineage:** `Canonical_Key__c` + `Raw_Payload_Ref__c` (hash/pointer, no PII) tie a signal to its
  source payload and run.
- **Human actions:** `Reviewed_By__c` / `Reviewed_At__c` / `Review_Notes__c` on the signal.
- **Reversibility:** MVP delete-by-run; Phase-5 writeback change-log rollback.

## 7. Compliance posture

- No PII beyond what public procurement postings already publish.
- No storage of credentials or secrets in the repository.
- All decisions rule-based and explainable (no AI in v1) — auditable for a government-adjacent buyer.
