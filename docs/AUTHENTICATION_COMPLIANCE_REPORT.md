# Authentication Compliance Report

**Status:** Evidence-based review (design/governance only)
**Date:** July 7, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Standard applied:** [[ADR-014-Enterprise-Authentication-Standard]] (with [[ADR-008-security-and-credential-standard]], [[ADR-013-LinkedIn-OAuth-Architecture]])
**Evidence basis:** repository state on branch `main` @ `15d1e2a`, verified 2026-07-07 via `git ls-files` / `git grep`

> Every conclusion is tagged **`[Verified from source]`** (confirmed from tracked repo files) or
> **`[Needs Verification]`** (an org-runtime fact not determinable from the repo — not assumed).

---

## 1. Evidence collected (verbatim provenance)

- **Named Credentials on main `[Verified from source]`:** `OA_Anthropic`, `OA_Census`, `OA_SAM`,
  `OA_SEC`, `OA_USASpending` (under `force-app/.../namedCredentials/`).
- **External Credentials on main `[Verified from source]`:** **none** — zero files under
  `externalCredentials/`. ⇒ `OA_SAM` / `OA_Anthropic` reference org-only ECs not in version control.
- **Remote Site Settings on main `[Verified from source]`:** `MicrosoftGraph`, `MicrosoftLogin`,
  `OA_USASpending` (deprecated-for-connector-use per ADR-008 rule #1).
- **`OA_Graph_Credential__c` `[Verified from source]`:** object + fields `Client_Id__c`,
  `Client_Secret__c`, `Tenant_Id__c` tracked under `force-app/.../objects/OA_Graph_Credential__c/`.
- **References `[Verified from source]`:** `OA_BookingPoller.cls` (force-app **and** modules copies),
  `OA_ArtifactPoller.cls` (modules), their `_Test` classes, and docs (README, SECURITY_BASELINE,
  METADATA_REGISTRY, TECHNICAL_DEBT, ADR-008).
- **Execution wiring `[Verified from source]`:** `OA_BookingPoller implements Schedulable` with
  `execute(SchedulableContext)` → `OA_Graph_Credential__c.getOrgDefaults()` →
  `getAccessToken(cred)`; `OA_ArtifactPoller implements Schedulable` likewise; callers
  `OA_AISummaryService`, `OA_AISummaryQueueable`, `OA_ReplayBookingService`.
- **Grants.gov `[Verified from source]`:** **not on main** (no `OA_Grants` NC under main); lives on
  `feature/grantsgov-lead-enrichment-staging`.

---

## 2. Existing connector classification (Task 2)

| Connector / component | Evidence | Classification |
|---|---|---|
| **SAM.gov** | `OA_SAM` NC on main `[Verified from source]`; External Credential **not** in repo (org-only) `[Verified from source]`; live EC principal-access grant `[Needs Verification — org]` | **COMPLIANT** (minor: commit/document the EC) |
| **USASpending** | `OA_USASpending` NC on main `[Verified from source]`; redundant `OA_USASpending` **Remote Site** still present `[Verified from source]` | **COMPLIANT** (minor: remove redundant Remote Site) |
| **Census** | `OA_Census` NC now on main `[Verified from source]` (added by Sprint 19); connector-to-NC wiring `[Needs Verification]` | **COMPLIANT** (was "future" — evidence updates prior docs) |
| **SEC (EDGAR)** | `OA_SEC` NC now on main `[Verified from source]`; User-Agent policy compliance `[Needs Verification — runtime]` | **COMPLIANT** |
| **IRS (EO BMF)** | bulk CSV, no callout / no auth `[Verified from source — no NC needed]`; async bulk scheduler deferred | **COMPLIANT** (ops gap, not auth) |
| **Anthropic (AI)** | `OA_Anthropic` NC on main `[Verified from source]`; EC **not** in repo `[Verified from source]` | **COMPLIANT** (minor: commit/document the EC) |
| **Grants.gov** | not on main; public keyless NC on feature branch `[Verified from source]` | **FUTURE** (branch, not merged) |
| **Microsoft Graph** (`OA_BookingPoller` + `OA_ArtifactPoller` + `OA_Graph_Credential__c`) | plaintext secret in custom object + hand-rolled `getAccessToken` + Remote Sites + duplicate class `[Verified from source]` | **MAJOR REFACTOR** |
| **LinkedIn** | design only (ADR-013); no metadata `[Verified from source]` | **FUTURE** |
| **Meta / Google / YouTube / GitHub / QuickBooks** | not built `[Verified from source]` | **FUTURE** |

### 2a. `OA_Graph_Credential__c` — direct answers with evidence (Task 2 focus)

| Question | Answer | Evidence |
|---|---|---|
| Still deployed (as source)? | **YES** | Object + 3 fields tracked in `force-app` `[Verified from source]`. Live-org presence `[Needs Verification — org]`. |
| Still referenced? | **YES** | `OA_BookingPoller` (×2), `OA_ArtifactPoller`, test classes, 6 docs `[Verified from source]`. |
| Still executed? | **Code path is live & schedulable** | Both pollers `implements Schedulable` and read the credential `[Verified from source]`. Whether an **active CronTrigger currently runs them in prod** = `[Needs Verification — org]` (scheduled jobs are not repo metadata). |
| Dormant? | **NO (at code level)** | It backs the active bookings / artifact / AI-summary pipeline, not a dormant enrichment connector `[Verified from source]`. Live schedule state `[Needs Verification — org]`. |
| Already replaced? | **NO** | No Named/External Credential for Graph exists in repo; only `OA_Anthropic` uses the correct pattern `[Verified from source]`. |
| Safe to retire? | **NO — not yet** | Retiring it breaks `OA_BookingPoller` + `OA_ArtifactPoller` (both reference the object and its fields) `[Verified from source]`. Safe **only after** Graph auth is migrated to Named/External Credential **and** both pollers (and their duplicate copies) are refactored. |

---

## 3. Authentication compliance table (Task 3)

Legend: ✅ present/compliant · ➖ n/a · ⚠️ gap · **NV** = `[Needs Verification]`

| Connector | Auth Method | Cred Storage | Secret Storage | OAuth | API Key | Named Cred | Ext Cred | Encryption | Logging | Retry | Monitoring | Governance | Overall |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **SAM.gov** | API Key header | EC (org-only) | EC | ➖ | ✅ | ✅ | ⚠️ not in repo | ✅ (EC) | ✅ SDK | ✅ SDK | ✅ Run obj | dormant-by-default | **COMPLIANT** (commit EC) |
| **USASpending** | Public | NC | none | ➖ | ➖ | ✅ | ➖ | ➖ | ✅ SDK | ✅ SDK | ✅ | ⚠️ redundant Remote Site | **COMPLIANT** (rm Remote Site) |
| **Census** | Public | NC | none | ➖ | ➖ | ✅ | ➖ | ➖ | ✅ SDK | ✅ SDK | NV wiring | dormant | **COMPLIANT** |
| **SEC** | Public + User-Agent | NC | none | ➖ | ➖ | ✅ | ➖ | ➖ | ✅ SDK | ✅ SDK | NV UA runtime | dormant | **COMPLIANT** |
| **IRS** | Bulk CSV (no auth) | none | none | ➖ | ➖ | ➖ (n/a) | ➖ | ➖ | ✅ SDK | ✅ SDK | ✅ | dormant | **COMPLIANT** |
| **Anthropic** | API Key | EC (org-only) | EC | ➖ | ✅ | ✅ | ⚠️ not in repo | ✅ (EC) | NV | NV | NV | live-ish | **COMPLIANT** (commit EC) |
| **Microsoft Graph** | Hand-rolled OAuth | **custom object** | **plaintext Text(255)** | ⚠️ manual | ➖ | ➖ (Remote Site) | ⚠️ none | ❌ none | System.debug | ⚠️ none | ⚠️ none | **non-compliant** | **MAJOR REFACTOR** |
| **Grants.gov** | Public | NC (branch) | none | ➖ | ➖ | ✅ (branch) | ➖ | ➖ | ✅ SDK | ✅ SDK | dormant | not on main | **FUTURE** |
| **LinkedIn** | OAuth 3-legged | EC (planned) | EC | ✅ (planned) | ➖ | planned | planned | planned | planned | planned | planned | ADR-013 | **FUTURE** |
| **Meta/Google/YouTube/GitHub/QuickBooks** | OAuth 3-legged | EC (planned) | EC | ✅ (planned) | ➖ | planned | planned | planned | planned | planned | planned | ADR-014 | **FUTURE** |

---

## 4. Migration plan for legacy authentication (Task 4)

**Principle: reuse before rebuild. Only one component requires a real migration — Microsoft Graph.**
Everything else is a minor, low-risk cleanup, not a rewrite.

Prioritized by **Security Risk × Maintenance Cost × Business Value ÷ Implementation Complexity**:

| # | Item | Sec Risk | Maint Cost | Biz Value | Complexity | Priority | Action (smallest reversible) |
|---|---|---|---|---|---|---|---|
| 1 | **Migrate Microsoft Graph auth off `OA_Graph_Credential__c`** → Named/External Credential; refactor `OA_BookingPoller` + `OA_ArtifactPoller` to drop `getAccessToken`; then retire the object + Remote Sites | **HIGH** (plaintext secret) | HIGH (duplicate class, hand-rolled) | HIGH (live meeting/AI pipeline) | MED–HIGH (needs sandbox; live pipeline) | **P1** | Design the Graph EC/NC in a sandbox first (blocked by TD-001 sandbox availability `[Needs Verification]`); do **not** retire the object until pollers are cut over and verified. |
| 2 | **Commit the org-only External Credentials** (`OA_SAM`, `OA_Anthropic`) or document them as intentionally org-only | MED (reproducibility) | LOW | MED | LOW | **P2** | Add EC metadata to repo (secretless — SF exports EC without secret values) or add a documented exception in SECURITY_BASELINE. |
| 3 | **De-duplicate `OA_BookingPoller`** (force-app vs modules layer-boundary violation) | LOW | MED | MED | LOW | **P3** | Fold into one owning package; done alongside item 1 to avoid double work. |
| 4 | **Remove redundant `OA_USASpending` Remote Site** (NC already exists) | LOW | LOW | LOW | LOW | **P4** | Delete the Remote Site after confirming no caller depends on it `[Needs Verification]`. |
| 5 | **Confirm Census/SEC connector→NC wiring** (NCs now exist; wiring unverified) | LOW | LOW | MED | LOW | **P4** | Verify the connector classes call `callout:OA_Census` / `callout:OA_SEC`; add if missing. |

**Explicitly NOT recommended:** rewriting SAM/USASpending/Census/SEC/IRS connectors — they are
compliant; touching them would be an unnecessary rewrite. The Graph migration is the only true
refactor, and even it is *cutover*, not a from-scratch rebuild (reuse the existing poller logic;
swap only the auth mechanism).

---

## 5. Result

**Overall platform authentication posture: WARN.**

- **Why not PASS:** one **MAJOR REFACTOR** remains (Microsoft Graph plaintext secret, live &
  scheduled at code level) `[Verified from source]`, and the External Credentials for the compliant
  API-key connectors are **not version-controlled** `[Verified from source]` — a reproducibility
  gap. Several runtime facts are `[Needs Verification]` and were **not** assumed.
- **Why not FAIL:** the standard is defined (ADR-014); the enrichment connectors are COMPLIANT or a
  minor cleanup away; the one debt item is contained, documented, and has a non-destructive
  migration path. No secret is newly exposed by this review.

### Next smallest reversible step

**Verify the org-runtime facts before any migration is planned** — specifically: (a) is an active
CronTrigger currently executing `OA_BookingPoller` / `OA_ArtifactPoller` in production, and (b) does
`OA_Graph_Credential__c` hold live secret values in the org. This is a **read-only** org query
(no deploy, no config, no secret exposure) that converts the three `[Needs Verification]` Graph
facts into `[Verified]`, so the P1 migration can be scoped accurately. It changes nothing and is
fully reversible (it makes no changes at all).

*Design and governance documentation only. No deployment, no Salesforce/LinkedIn change, no metadata
change, no OAuth configuration, no commit, no push was performed.*
