# Governance Improvement Recommendations

**Version:** 1.0
**Date:** July 8, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Review cadence:** Quarterly, with [GOVERNANCE_MODEL.md](GOVERNANCE_MODEL.md)
**Status:** Proposed — for Louis's review. Nothing here is adopted until approved.

Observations from reviewing `CLAUDE.md`, the Claude Code permission rules, `GOVERNANCE_MODEL.md`,
the `docs/decisions/` ADRs, and the repository structure. Each item is a **proposal**, tiered and
sized; none is a decision. Findings are labeled `[Verified from source]` where confirmed by reading
the repo.

---

## Summary

The repository already has strong governance bones: a tiered `CLAUDE.md`, a full governance model,
a Definition of Ready backed by ADR-010, ten ADRs, a risk register, and rich operational runbooks.
The gaps below are mostly about **making existing intent executable and consistent** — templates,
wiring, and reconciling two branching descriptions — not about inventing new controls.

---

## Recommendations (prioritized)

### R1 — Adopt the reusable template set 🟡 *(this PR)*
`docs/templates/` now holds Release, Deployment, PR, ADR, Sprint, Production-Readiness, Operations,
Daily-Monitoring, and Weekly-Health templates. **Proposal:** treat them as the canonical starting
point for those artifacts and link them from `CLAUDE.md` and `GOVERNANCE_MODEL.md`.
**Effort:** done (adoption is a decision). **Reversible:** yes.

### R2 — Wire the PR checklist into GitHub 🟡
`GOVERNANCE_MODEL.md §2.2` requires each PR to carry a metadata list, test plan, rollback
assessment, and evidence — but there is **no `.github/pull_request_template.md`** `[Verified from source]`.
**Proposal:** add `.github/pull_request_template.md` (source it from
[`PR_CHECKLIST_TEMPLATE.md`](templates/PR_CHECKLIST_TEMPLATE.md)) so every PR is pre-populated, and
optional issue templates for change requests. **Effort:** S. **Reversible:** yes.

### R3 — Create the referenced-but-missing directories 🟢
`GOVERNANCE_MODEL.md §3.3 / §6.1` point release notes at `docs/releases/` and post-mortems at
`docs/post-mortems/`, but **neither directory exists yet** `[Verified from source]`.
**Proposal:** create both with a short `README.md` each (naming convention + which template feeds
them) so the first release/incident has a home instead of improvising. **Effort:** S. **Reversible:** yes.

### R4 — Add an ADR index 🟢
`docs/decisions/` has ADR-001…010 but **no index** `[Verified from source]`.
**Proposal:** add `docs/decisions/README.md` listing each ADR with status (Accepted/Superseded) and
one-line summary, and adopt [`ADR_TEMPLATE.md`](templates/ADR_TEMPLATE.md) for ADR-011+. Keeps the
"hard-to-reverse decisions are discoverable" promise of `GOVERNANCE_MODEL.md §6.2`. **Effort:** S.

### R5 — Reconcile the two branching models 🟡 *(needs a decision)*
`CLAUDE.md §6` describes **trunk-based** flow: `feature/<workstream>` → `main` (which mirrors
production), no `develop`. `GOVERNANCE_MODEL.md §2.2` describes a **GitFlow** path:
`feature` → `develop` → release branch → Full Sandbox UAT → `main` `[Verified from source]`. These
are two different models, and `TD-001` records that **no Full Sandbox exists yet**. The lived
practice (per the repo's own release history) is the trunk-based one.
**Proposal:** pick one as current-state and mark the other as target-state. Recommended: update
`GOVERNANCE_MODEL.md §2.2` to document trunk-based-with-check-only-validation as **today**, and keep
the `develop`/sandbox/UAT flow explicitly labeled as the **maturity target** (tie to the SOX roadmap
§7.3). Prevents contributors following a process the environment can't support. **Effort:** M.
**Reversible:** yes (doc change).

### R6 — Make governance travel with the repo via committed permission rules 🟡
Claude Code permission governance currently lives in **user-level** settings
(`~/.claude/settings.local.json`) — it protects this operator but does not travel with the repo to
any other machine or contributor.
**Proposal:** add a committed **repo-level** `.claude/settings.json` encoding the RED gates as
`ask` rules (production deploys, merges, `sf data` writes, anonymous Apex, permission-set
assignments, credential reads, destructive git) mirroring `CLAUDE.md §2`. Deny/ask rules layer
additively across sources, so this raises the floor for everyone without weakening any operator's
own stricter setup. **Effort:** S. **Reversible:** yes. *(Recommend reviewing the exact rule list
before committing, since it applies to every contributor.)*

### R7 — Stand up the CI/CD validation gate (Phase 0) 🟡
`GOVERNANCE_MODEL.md §7.3` lists a **GitHub Actions CI/CD gate** as a Phase 0 / Q3-2026 deliverable;
it is **not yet built** `[Verified from source]`. It is the single control that turns "no unvalidated
deploy to production" from policy into enforcement, and it directly supports SOX readiness item #5
(separate developer/deployer via tooling).
**Proposal:** add a check-only workflow (`sf project deploy validate` + `RunLocalTests`, coverage
gate ≥75%) that runs on every PR to `main`. Keep it **validate-only** — no auto-deploy — so it never
crosses a 🔴 line by itself. **Effort:** M. **Reversible:** yes.

### R8 — Promote the Definition of Done 🟢
The Definition of Done exists only inside `DEFINITION_OF_READY.md §4`. **Proposal:** surface it in
the PR template (R2) and Sprint template so "Done" is checked at closeout, not just described.
**Effort:** S (largely covered by R1/R2).

---

## Suggested sequencing

1. **This PR:** R1 (templates) + this recommendations doc — additive, reversible, no production impact.
2. **Fast follow (decisions needed):** R5 branching reconciliation, R6 repo-level permission rules.
3. **Next:** R2/R3/R4/R8 wiring (small, mechanical).
4. **Scheduled:** R7 CI gate (aligns with the Phase 0 milestone already on the SOX roadmap).

None of these require a production deployment. R5 and R6 are the two that warrant an explicit
decision from Louis before implementing.
