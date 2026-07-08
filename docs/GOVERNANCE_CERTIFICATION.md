# Governance Certification — Lead Enrichment Platform

**Date:** 2026-07-08 · **Branch:** `feature/lead-enrichment-repo-certification` · **Mode:** read-only
**Governed by:** [../CLAUDE.md](../CLAUDE.md) · [GOVERNANCE_MODEL.md](GOVERNANCE_MODEL.md) · **Companion:** [REPOSITORY_CERTIFICATION.md](REPOSITORY_CERTIFICATION.md)

> Phase 3: verification that the repository follows One Algorithm governance. Each principle is checked against
> concrete evidence in the tree and the prior audit findings (hardening + readiness sprints).

---

## 1. Governance principle verification

| Principle | Evidence | Verdict |
|---|---|---|
| **Reuse-before-build** | CLAUDE.md §7 codifies it; the hardening/readiness sprints indexed existing runbooks/monitoring/deployment docs instead of duplicating; connector SDK reused across 6 connectors; OI reuses the connector framework. Overlapping docs are dated artifacts, not rebuilds. | 🟢 PASS |
| **Dormant-first deployment** | All 8 registry connectors `Enabled__c=false`; 22 field-write policies `Active__c=false` (9 Overwrite, none active); 11 pipeline stages + 6 sources inactive; 0 enrichment cron/jobs/triggers; `commitWrites` null-safe **false**. Documented in MAINTENANCE.md (kill-switch model) and DEPLOYMENT_PACKAGE.md ("all records ship Enabled/Active=false"). | 🟢 PASS |
| **Rollback documented** | Dedicated [ROLLBACK_CHECKLIST.md](ROLLBACK_CHECKLIST.md) (step-by-step, per-field verify) + [ROLLBACK_DEFECT_FIX.md](ROLLBACK_DEFECT_FIX.md) (multi-field fix, proven 30/30) + MAINTENANCE §Recovery + DEPLOYMENT_PACKAGE §3. Metadata rollback = redeploy prior tag; data rollback = `OA_ChangeLogService.rollback`. | 🟢 PASS |
| **Security gates documented** | CLAUDE.md §2 RED tier + §9 protected areas; SECURITY_BASELINE.md / SECURITY_MODEL.md; no secrets in git (`externalCredentials/`+`authproviders/` gitignored & untracked, verified); least-privilege runtime permset (no Delete/ViewAll/ModifyAll); write-back permset "keep UNASSIGNED". | 🟢 PASS |
| **Approval gates documented** | CLAUDE.md §2 (GREEN/YELLOW/RED) + §5 deployment policy; every certification/readiness doc marks deploy, merge, enablement, permset-assign, credential, destructive, data-write as 🔴 requiring explicit Louis approval. Approval-for-one ≠ approval-for-next stated. | 🟢 PASS |
| **No production assumptions** | Audits verify org by **ID** `00Dbn00000plgUfEAI` (never name); DevHub `00Dd…` kept distinct; SAM endpoint reported as the actual metadata value (alpha), not an assumed prod value; evidence-over-memory applied (SAM prod-move treated as pending, matching the repo). | 🟢 PASS |
| **No undocumented runtime dependencies** | Runtime user (MAD `oauser`) documented as a tracked exception (RUNTIME_USER_EXCEPTION.md, R1); NC/EC dependencies enumerated (secret-free NCs tracked, ECs gitignored); the live write-back's dependency on `OA_USASpending_Staging__c`/`OA_USASpendingClient` is now documented (Cleanup C-7 / TD-LE-08); registry↔interface latent mismatch documented (Registry Review). | 🟢 PASS |

## 2. Governance artifacts present
CLAUDE.md (governed-autonomy operating guide), GOVERNANCE_MODEL.md, GOVERNANCE_RECOMMENDATIONS.md, DEFINITION_OF_READY.md
(ADR-010), SECURITY_BASELINE.md (ADR-008), plus reusable templates (PRODUCTION_READINESS_REVIEW, DEPLOYMENT_CHECKLIST,
RELEASE_CHECKLIST, OPERATIONS_REVIEW, PR_CHECKLIST, ADR_TEMPLATE). ADR chain ADR-001…010 + 015…019 Accepted.

## 3. Standing governance risks (documented, accepted)
- **R1 — runtime user is MAD `oauser`** (weakens FLS least-privilege): documented exception; replace with least-priv user (license). Top standing risk.
- **R2 — SAM data.gov key** unconfirmed/previously exposed: documented; rotate + JIT EC principal grant before any SAM run.
These are governance-visible, owner-assigned, and gate 24×7 automation — consistent with the governance model (not violations).

## 4. Verdict
| Dimension | Verdict |
|---|---|
| Reuse-before-build | 🟢 PASS |
| Dormant-first | 🟢 PASS |
| Rollback documented | 🟢 PASS |
| Security gates | 🟢 PASS |
| Approval gates | 🟢 PASS |
| No production assumptions | 🟢 PASS |
| No undocumented runtime deps | 🟢 PASS |

**Overall Phase-3 verdict: 🟢 PASS.** The repository is governance-compliant. All RED actions are gated, dormancy is
enforced and documented, rollback and security are proven and written down, and the one standing runtime exception is
explicitly tracked rather than hidden.
