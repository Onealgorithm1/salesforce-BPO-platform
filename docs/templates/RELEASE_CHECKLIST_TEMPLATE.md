# Release Checklist — {RELEASE_ID}

**Version:** _fill_
**Date:** _YYYY-MM-DD_
**Owner / Release Manager:** _fill_
**Prepared by:** _fill_
**Status:** ☐ Draft ☐ Ready for approval ☐ Approved ☐ Released
**Governed by:** [GOVERNANCE_MODEL.md §3](../GOVERNANCE_MODEL.md) · [CLAUDE.md §5](../../CLAUDE.md)

> A release is a 🔴 RED event (production deploy + merge to `main`). It proceeds only on explicit
> Louis approval. Fill every item; `[x]` = done, `[ ]` = to do, `N/A — reason` = deliberately skipped.

---

## 1. Release facts
| Field | Value |
|---|---|
| Release ID (`{year}.{quarter}.{seq}`, e.g. `2026.Q3.1`) | _fill_ |
| Package version (if any, `OA-Core@x.y.z`) | _fill_ |
| Production Org ID (must equal `00Dbn00000plgUfEAI`) | _fill_ `[Verified by ID]` |
| Repository / branch | `salesforce-BPO-platform` / `feature/…` |
| Release commit hash | _fill_ |
| Prior release | _fill_ |
| Change category ([Governance §2.1](../GOVERNANCE_MODEL.md): Normal / Major / Security / Emergency) | _fill_ |

## 2. Scope (single workstream only)
- **What ships:** _one-line business description_
- **Metadata in this release:** _list every component; link the deploy manifest_
- **Explicitly out of scope:** _fill — no unrelated work bundled ([CLAUDE.md §5](../../CLAUDE.md))_

## 3. Release artifacts required ([Governance §3.1](../GOVERNANCE_MODEL.md))
- [ ] **Validated deployment result** — `sf project deploy validate` shows 0 errors. Validate ID: _fill_
- [ ] **Test execution report** — all Apex tests pass, **≥75% coverage** on classes in scope. Result: _fill_
- [ ] **Change summary** — every metadata file listed (in PR description).
- [ ] **Rollback plan** — specific undo steps documented (§6 below).
- [ ] **UAT sign-off** — written confirmation (Full Sandbox when available; note `TD-001` if not).
- [ ] **Package manifest** — exact version of everything deploying (`sfdx-project.json` committed).

## 4. Preflight ([CLAUDE.md §3](../../CLAUDE.md))
- [ ] Org ID verified **by ID** = `00Dbn00000plgUfEAI`.
- [ ] Not operating on `main`; release branch matches the workstream.
- [ ] `main == origin/main` (in sync) before merge.
- [ ] Working tree clean; no unrelated staged files.
- [ ] No change to a [protected area](../../CLAUDE.md) without its own explicit approval.

## 5. Change-freeze check ([Governance §2.3](../GOVERNANCE_MODEL.md))
- [ ] Not inside an active email-campaign blast (no schema changes mid-send), quarter-end freeze, external audit, or holiday window — or an exception is documented and approved.

## 6. Rollback plan
- **Reversible?** _yes/no_ — _how_
- **Undo steps:** _fill (e.g., redeploy prior commit `____`; `OA_ChangeLogService.rollback(...)`; revert PR)_
- **Data touched?** _yes/no_ — if yes, before-snapshot / change-log reference: _fill_

## 7. Approval gate 🔴
- [ ] Explicit, specific approval recorded from Louis (e.g., "APPROVED: release {RELEASE_ID}"). Approval text / link: _fill_
- **Release Manager ≠ sole developer?** _note segregation-of-duties compensating control ([Governance §4.2](../GOVERNANCE_MODEL.md))_

## 8. Deploy & verify (do not auto-retry on error — [CLAUDE.md §5](../../CLAUDE.md))
- [ ] Production deploy executed. Deploy ID: _fill_  Result: _Succeeded / Failed_
- [ ] Post-deploy smoke test / acceptance evidence: _fill_
- [ ] **Production changed? yes/no** (state explicitly).

## 9. Release notes ([Governance §3.3](../GOVERNANCE_MODEL.md))
Published to `docs/releases/{RELEASE_ID}.md` with: identifier, date, business-language summary,
known issues / post-deploy monitoring items, who deployed, who approved.
- [ ] Release notes written and committed.

## 10. Post-release
- [ ] 24-hour post-deploy monitoring window observed; findings: _fill_
- [ ] GitHub Issue / workstream closed with production validation evidence.
- [ ] Feature branch preserved (do not delete unless told).
- [ ] Retention records updated where applicable ([Governance §5.3](../GOVERNANCE_MODEL.md)).

---

### Closeout ([CLAUDE.md §4](../../CLAUDE.md))
Files changed · Validation & deploy IDs · Test results + coverage · Production changed (y/n) ·
Branch & HEAD · Working-tree status · Next approval gate.
