# Pull Request — {TITLE}

> Paste into the PR description and fill it out. Opening a PR is 🟢 GREEN; **merging to `main` is
> 🔴 RED** and requires explicit Louis approval. Reviewer ≠ author (self-approval prohibited —
> [Governance §4.1](../GOVERNANCE_MODEL.md)).

**Workstream:** _one workstream only_
**Branch:** `feature/…` → `main`
**Change category:** ☐ Standard ☐ Normal ☐ Major ☐ Security ☐ Emergency ([Governance §2.1](../GOVERNANCE_MODEL.md))
**Tier:** ☐ 🟢 GREEN ☐ 🟡 YELLOW ☐ 🔴 RED-on-merge

---

## What changed
_Business-language summary of what and why._

## Metadata / files changed
_List every file (or link the diff). Confirm all belong to this one workstream._

## Definition of Ready met? ([DEFINITION_OF_READY.md](../DEFINITION_OF_READY.md))
- [ ] Objective maps to a repo artifact (roadmap / ADR / doc), not just a chat instruction.
- [ ] Repository evidence gathered; production/runtime claims labeled `[Verified from source]` or `[Unverified]`.
- [ ] Scope boundaries stated; workstreams kept isolated.
- [ ] Reversibility plan + rollback path identified.

## Test plan & results
- [ ] Apex tests: _N run / 0 fail_ · **coverage ≥75%** on classes in scope: _fill_
- [ ] Check-only validation ID (if metadata): _fill_
- [ ] Evidence of testing attached (IDs / output / screenshots).

## Rollback assessment
- **Can this be undone? How?** _fill_
- **Data touched?** _yes/no_ — before-snapshot / change-log: _fill_

## Safety review
- [ ] No [protected automation](../../CLAUDE.md) (`OA_EDWOSB_Outreach_Sequence`, `OA_Reply_Detection`, `OA_EmailSender`, writeback, Named/External Credentials, M365/Bookings/Teams) changed without explicit approval.
- [ ] No production data DML introduced without approval.
- [ ] New fields ship with FLS permission set; permission sets unassigned by default.
- [ ] No secrets, credentials, or endpoints hardcoded.
- [ ] Single workstream — no unrelated work bundled.

## RED gates this PR will require (if merged/deployed) 🔴
_List each: production deploy / merge to main / permission-set assignment / job scheduling /
backfill / data write / credential change. Each needs its own explicit Louis approval._

## Reviewer sign-off
- **Reviewer (≠ author):** _fill_ · **Date:** _fill_
- [ ] Reviewer confirms metadata list, tests, rollback, and safety review above.

---
_Co-author trailer on commits as configured; end PR body with the standard generated-by line._
