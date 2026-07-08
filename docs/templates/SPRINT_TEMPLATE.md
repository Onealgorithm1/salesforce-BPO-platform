# Sprint {NN} — {NAME}

**Dates:** _start_ → _end_
**Owner:** _fill_
**Status:** ☐ Planned ☐ In progress ☐ Closed
**Workstream(s):** _keep isolated — one primary workstream per branch_
**Governed by:** [DEFINITION_OF_READY.md](../DEFINITION_OF_READY.md) · [CLAUDE.md](../../CLAUDE.md)

> Default posture is 🟢 GREEN (branch work, source edits, docs, check-only validation). Each task
> that reaches a 🔴 action (deploy, merge, data write, assignment, scheduling) stops for Louis.

---

## 1. Objective
_What this sprint delivers, mapped to a repo artifact ([ROADMAP.md](../ROADMAP.md) / ADR / spec).
One sentence of business value._

## 2. Definition of Ready check (before starting)
- [ ] Objective written and mapped to an artifact.
- [ ] Repository evidence gathered; assumptions labeled `[Unverified]` until command-verified.
- [ ] Scope boundaries stated (§3); workstreams isolated.
- [ ] Reversibility plan (branch, clean baseline, rollback path).
- [ ] Approvals identified for any hard-to-reverse step.

## 3. Scope
**In scope:** _fill_
**Out of scope (explicit):** _fill_
**Branch:** `feature/…`

## 4. Tasks
| # | Task | Tier 🟢🟡🔴 | Evidence / IDs | Status |
|---|------|-----------|----------------|--------|
| 1 | _fill_ | 🟢 | _validate ID / test result_ | ☐ |
| 2 | _fill_ | 🟡 | _fill_ | ☐ |
| 3 | _fill_ | 🔴 (awaits approval) | _fill_ | ☐ |

## 5. RED gates encountered
_List each RED action and its approval status (requested / approved by Louis / deferred)._

## 6. Evidence & validation
- Validate / deploy IDs: _fill_
- Tests: _N run / 0 fail_ · coverage: _≥75%_
- **Production changed? yes/no** (explicit).

## 7. Definition of Done ([DoR §4](../DEFINITION_OF_READY.md))
- [ ] Code + tests committed on the feature branch; ≥75% coverage.
- [ ] Check-only validation passed (if metadata).
- [ ] Docs / registries updated.
- [ ] Reversibility confirmed.
- [ ] For production: serialized, approved deploy with rollback plan.

## 8. Closeout ([CLAUDE.md §4](../../CLAUDE.md))
Files changed · Validation/deploy IDs · Test results + coverage · Production changed (y/n) ·
Branch & HEAD · Working-tree status · **Next approval gate.**

## 9. Carry-over / next sprint
_Unfinished items, newly discovered work, risks to log in
[OPERATIONAL_RISK_REGISTER.md](../OPERATIONAL_RISK_REGISTER.md) or [TECHNICAL_DEBT.md](../TECHNICAL_DEBT.md)._
