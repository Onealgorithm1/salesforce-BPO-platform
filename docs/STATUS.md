# Project Status — One Algorithm BPO Platform

**Last Updated:** June 19, 2026
**Updated By:** Louis Rubino (lrubino@onealgorithm.com)
**Branch:** main
**Commit:** 2be29acbb06662872c67492303a9269a60cfbb8a

---

## Current Phase

**Phase 0 — Foundation: COMPLETE**
**Phase 1 — Metadata Retrieval: READY TO BEGIN**

All Phase 0 deliverables are committed and pushed to GitHub. The first retrieval (package-core.xml → force-app/) has been validated and is authorized pending one manual pre-flight step (OneDrive sync pause).

---

## Completed Milestones

| Milestone | Completed | Evidence |
|-----------|-----------|---------|
| EAC Enrollment Phase 1 — oauser@pboedition.com PSL + PS assigned | June 19, 2026 | SetupAuditTrail |
| EAC Enrollment Phase 2 — OA EDWOSB Outreach config updated | June 19, 2026 | Config shows Louis Rubino in Selected |
| EAC Enrollment Phase 3 — M365 OAuth connected (lrubino@onealgorithm.com) | June 19, 2026 | INT-001 active in INTEGRATION_REGISTRY.md |
| SFDX project structure created | June 19, 2026 | sfdx-project.json, .forceignore committed |
| Directory scaffolding (all .gitkeep) | June 19, 2026 | force-app/, modules/, clients/ all scaffolded |
| Manifest suite created (4 manifests) | June 19, 2026 | manifest/ directory committed |
| Metadata classification documented | June 19, 2026 | docs/METADATA_CLASSIFICATION.md |
| Architecture cleanup (MHolt removed) | June 19, 2026 | grep confirms zero references |
| Governance documentation suite (5 docs) | June 19, 2026 | docs/ committed |
| Architecture Decision Records (ADR-001 through ADR-004) | June 19, 2026 | docs/decisions/ committed |
| Pre-retrieval gate review completed | June 19, 2026 | CONDITIONAL GO issued |
| Git repository initialized | June 19, 2026 | git init (already existed) |
| Foundation commit created | June 19, 2026 | 2be29ac — 50 files, 4,047 insertions |
| Pushed to GitHub | June 19, 2026 | github.com/Onealgorithm1/salesforce-BPO-platform |
| Retrieval readiness validation (package-core.xml) | June 19, 2026 | All 6 checks PASS |
| STATUS.md, ROADMAP.md, PROJECT_RESTART.md created | June 19, 2026 | docs/ committed |

---

## Open Risks

| Risk ID | Severity | Description | Owner | Status |
|---------|----------|-------------|-------|--------|
| SEC-INT-01 | HIGH | tbid.digital: 3 active OAuth tokens, unknown purpose, 150 days inactive | Louis Rubino | Open — revocation pending authorization decision |
| SEC-INT-02 | MEDIUM | OIQ_Integration: undocumented Connected App in org, no tokens, `OptionsAllowAdminApprovedUsersOnly=false` | Louis Rubino | Open — deletion pending |
| SEC-MFA-01 | HIGH | oauser@pboedition.com protected by email device verification only; no Salesforce Authenticator | Louis Rubino | Open — enrollment pending |
| SEC-MFA-02 | MEDIUM | Org-level MFA enforcement status not verified (requires Setup UI, not queryable via SOQL) | Louis Rubino | Open — manual verification pending |
| SEC-INT-03 | LOW | Pipedream (INT-004): active OAuth token, exact workflow scope undocumented | Louis Rubino | Open — audit pending |
| RISK-ENV-01 | HIGH | No Full Sandbox provisioned — all changes go directly to production | Louis Rubino | Open — TD-001 in TECHNICAL_DEBT.md |
| RISK-REPO-01 | MEDIUM | Repository sits inside OneDrive sync tree — file collision risk during retrieval | Louis Rubino | Mitigated per session; re-evaluate post-retrieval |

---

## Open Blockers

| Blocker | Blocking What | Resolution |
|---------|--------------|-----------|
| OneDrive sync not yet paused | package-core.xml retrieval | Right-click OneDrive tray icon → Pause syncing → 2 hours |

No other blockers. After OneDrive is paused, retrieval can proceed immediately.

---

## Open Decisions

| Decision | Context | Urgency |
|----------|---------|---------|
| tbid.digital OAuth revocation | 3 tokens, 150 days inactive, unknown purpose — revoke or document justification | High — do before next client onboarding |
| OIQ_Integration deletion | Dead Connected App, no tokens, no activity — delete or document purpose | Medium |
| oauser MFA upgrade | Enroll Louis in Salesforce Authenticator or hardware key | High — required before SOX readiness |
| Full Sandbox provisioning | Required before any production deployment from source control | High — Phase 1 prerequisite |
| GitHub branch protection rules | Protect main branch: require PR, require CI pass | Medium — set up with CI/CD in Phase 4 |

---

## Next Recommended Step

**Monday Morning: Execute package-core.xml retrieval**

Pre-flight (2 minutes):
1. Right-click OneDrive → Pause syncing → 2 hours
2. Open terminal in `C:\Users\louis\OneDrive\Documents\GitHub\salesforce-BPO-platform`

Retrieval command:
```bash
sf project retrieve start \
  --manifest manifest/package-core.xml \
  --target-org oauser@pboedition.com
```

Post-retrieval:
1. `git status` — confirm expected files written
2. Review `force-app/main/default/objects/Lead/fields/` — audit field list against METADATA_CLASSIFICATION.md
3. `git add force-app/ && git commit -m "feat: retrieve core platform metadata (Layer 1)"`
4. `git push origin main`
5. Then proceed to package-marketing.xml retrieval

Full retrieval sequence (Layer 1 → 2 → 3):
```bash
# Layer 1 — Core
sf project retrieve start --manifest manifest/package-core.xml --target-org oauser@pboedition.com

# Layer 2 — Marketing
sf project retrieve start --manifest manifest/package-marketing.xml --target-org oauser@pboedition.com --output-dir modules/marketing-automation

# Layer 3 — PBO
sf project retrieve start --manifest manifest/package-pbo.xml --target-org oauser@pboedition.com --output-dir clients/pbo
```

---

## Last Successful Validation

**Retrieval Readiness Validation — package-core.xml** (June 19, 2026)

| Check | Result |
|-------|--------|
| Windows Long Paths | PASS (enabled, value=1) |
| Path length risk | PASS (64-char base, 196-char budget) |
| OneDrive sync | CAUTION (running, pause required before retrieval) |
| package-core.xml XML validation | PASS (well-formed, version 67.0) |
| Metadata count estimate | PASS (~34–38 files, 80–250 KB) |
| Target directory (force-app/main/default) | PASS (exists, clean, committed) |

**Decision: CONDITIONAL GO** — authorized pending OneDrive pause.

---

## Repository Health

```
Branch:  main
Remote:  https://github.com/Onealgorithm1/salesforce-BPO-platform.git
Commit:  2be29acbb06662872c67492303a9269a60cfbb8a
Status:  Clean — nothing to commit, working tree clean
Files:   52 committed (2 from initial commit + 50 from foundation commit)
```
