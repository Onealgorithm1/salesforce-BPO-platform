# Deployment Checklist — {WORKSTREAM} → {TARGET}

**Date:** _YYYY-MM-DD_
**Operator:** _fill_
**Deploy type:** ☐ Check-only (validate) ☐ Production deploy ☐ Dormant/observe-only
**Status:** ☐ Prepared ☐ Approved ☐ Deployed ☐ Verified
**Governed by:** [CLAUDE.md §5 Deployment Policy](../../CLAUDE.md) · [GOVERNANCE_MODEL.md §3](../GOVERNANCE_MODEL.md)

> A non-`--dry-run` production deploy is 🔴 RED — stop for explicit Louis approval. A check-only
> validation is 🟢 GREEN. A dormant/observe-only component (no active trigger/flow/schedule) is 🟡.

---

## 1. Preflight ([CLAUDE.md §3](../../CLAUDE.md))
- [ ] Org ID verified **by ID** = `00Dbn00000plgUfEAI` (never by name/alias).
- [ ] Current branch is the workstream feature branch (not `main`).
- [ ] Working tree clean; only this workstream's files in scope.
- [ ] `main == origin/main`.
- [ ] Deploy manifest / package path reviewed — no unrelated components bundled.

## 2. Content review
- [ ] Every component to deploy is listed: _fill / link manifest_
- [ ] **Reuse-before-build** confirmed — extends existing metadata rather than duplicating ([CLAUDE.md §7](../../CLAUDE.md)).
- [ ] Changes are **additive / reversible** where possible; in-place edits to shared assets justified.
- [ ] **FLS bundled:** any new reportable custom field ships with a permission set granting FLS (Metadata-API field deploys omit FLS — [CLAUDE.md §7 lesson](../../CLAUDE.md)).
- [ ] Permission sets are **least-privilege** and **unassigned by default** (assignment is a separate 🔴 gate).
- [ ] No [protected automation/data](../../CLAUDE.md) touched without its own approval.

## 3. Validation (check-only first — always)
- [ ] `sf project deploy validate` run. **Validate ID:** _fill_  **Errors:** _0 / list_
- [ ] Apex tests run in validation. **Result:** _N run / 0 fail_  **Coverage:** _≥75% on classes in scope_
- [ ] Two-phase clarity assessed: dependencies ordered if needed (note: correct custom-report-type syntax deploys in one transaction — [CLAUDE.md §7](../../CLAUDE.md)).

## 4. Rollback readiness
- **Reversible?** _yes/no_ — **how:** _redeploy prior commit `____` / revert / `OA_ChangeLogService.rollback` / disable dormant component_
- [ ] Rollback path identified **before** deploy.
- [ ] If data is written: before-snapshot / change-log in place.

## 5. Approval gate 🔴 (production deploy only)
- [ ] Explicit Louis approval recorded (e.g., "APPROVED: deploy {WORKSTREAM}"). Reference: _fill_
- [ ] Not inside a [change-freeze window](../GOVERNANCE_MODEL.md) (or exception approved).

## 6. Deploy
- [ ] Deploy executed. **Deploy ID:** _fill_  **checkOnly:** _false_  **Result:** _Succeeded/Failed_
- [ ] **On any error: STOP. Do not auto-retry.** Diagnose root cause; retry only after a confirmed fix ([CLAUDE.md §5](../../CLAUDE.md)).

## 7. Post-deploy verification
- [ ] Smoke test / acceptance evidence captured: _fill_
- [ ] Component counts in org match intent (e.g., dormant component present, 0 active triggers/jobs).
- [ ] **Production changed? yes/no** — stated explicitly.
- [ ] Monitoring window started (duration: _fill_).

---

### Closeout ([CLAUDE.md §4](../../CLAUDE.md))
Files changed · Validate + deploy IDs · Tests + coverage · Production changed (y/n) ·
Branch & HEAD · Working-tree status · Next approval gate.
