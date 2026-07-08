# Authentication & Connector Evolution Roadmap

**Status:** Proposed (design only)
**Date:** July 7, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Companion to:** [[AUTHENTICATION_FRAMEWORK]], [[CONNECTOR_AUTHENTICATION_MATRIX]],
[[ADR-013-LinkedIn-OAuth-Architecture]]

> How the platform evolves from today's enrichment connectors to a unified enterprise integration
> layer — **architecture only, no implementation**. Each phase is gated; nothing here authorizes a
> build, deploy, or live callout.

---

## The four-phase evolution (Task 7)

```
 PHASE 1                PHASE 2                 PHASE 3                PHASE 4
 Current platform  -->  Unified Auth       -->  Unified Connector -->  Enterprise
 (v1.0 enrichment)      Framework               SDK                    Integration Platform

 6 connectors,          5 auth classes,         OAuth + webhooks       Real-time, multi-domain,
 public/API-key,        one abstraction,        + async orchestrator,  self-service connectors,
 polling, dormant       LinkedIn OAuth first    all connectors onboard middleware where needed
```

### Phase 1 — Current platform (done / operating baseline)
- **What exists:** Lead Enrichment v1.0 (SAM, USASpending, Census, IRS, SEC + State template),
  frozen connector SDK, canonical model, review/write engines, dormant in prod. Auth handled per
  source (public / API-key).
- **Auth posture:** SAM = Ext+Named Cred (compliant); USASpending/Grants = public Named Cred;
  Census/SEC = connector built, Named Credential still to create; legacy Graph = plaintext-secret
  debt.
- **Exit criteria to Phase 2:** ADR-013 accepted; this framework accepted; LinkedIn chosen as the
  first OAuth exercise.

### Phase 2 — Unified Authentication Framework
- **Goal:** Collapse all authentication into the five classes behind one abstraction
  (OA_CredentialProvider) with shared token/retry/log/health components.
- **Architecture delivered:** OA_AuthenticationManager, OA_TokenManager, OA_CredentialProvider,
  OA_CalloutService, OA_RetryManager, OA_ErrorLogger, OA_HealthMonitor (see AUTHENTICATION_FRAMEWORK
  §4).
- **First proof:** LinkedIn OAuth end-to-end (Ext+Named Cred, Named Principal, Auth Code), built
  dormant, gated smoke test with one synthetic record.
- **Exit criteria to Phase 3:** LinkedIn OAuth validated; Census/SEC Named Credentials created;
  legacy Graph secret refactor scheduled.

### Phase 3 — Unified Connector SDK
- **Goal:** Every connector — enrichment *and* the new OAuth/social/finance sources — onboards
  through one SDK path: registry-declared auth class, standard staging/review/write, standard
  retry/log/health.
- **Architecture delivered:** OAuth connectors (Meta, Google, YouTube, GitHub, QuickBooks) reuse the
  ADR-013 template; the **async bulk orchestrator** (the one identified additive gap) lands here to
  cover scheduled polling at volume; connector onboarding becomes "add registry rows + a
  Request/Parser/Mapper," not new platform code.
- **Exit criteria to Phase 4:** ≥2 OAuth connectors live and healthy; async orchestrator proven;
  webhook demand identified (e.g. LinkedIn Lead Sync real-time).

### Phase 4 — Enterprise Integration Platform
- **Goal:** Real-time, multi-domain integration. Webhooks where justified, fronted by a small
  middleware service; self-service connector onboarding; multiple intelligence domains (enrichment,
  opportunity, procurement, marketing) on one authentication + connector spine.
- **Architecture delivered:** webhook middleware (validate signature/challenge, buffer, forward to
  Salesforce via Platform Events); connector marketplace/registry maturity; cross-domain monitoring.
- **Note:** Middleware and webhooks stay **Defer** until volume/latency justify a running server;
  everything before this phase requires no server to operate.

---

## Implementation roadmap — categorized (Build Now / Build Later / Defer)

| Item | Category | Notes |
|---|---|---|
| Accept ADR-013 + this framework as the standard | **Build Now** | Governance decision; no code. |
| Create `OA_LinkedIn` Auth Provider → read generated Redirect URI | **Build Now** *(when approved to build)* | Produces the real Redirect URI (do not guess it). |
| Create LinkedIn Ext+Named Cred (Named Principal, Auth Code); one-time admin consent | **Build Now** *(when approved)* | First OAuth exercise; dormant. |
| LinkedIn staging + log objects; dormant deploy + gated smoke test | **Build Now** *(when approved)* | SAM.gov dormant-deploy precedent. |
| Create `OA_Census` + `OA_SEC` Named Credentials | **Build Now** *(when approved)* | Closes the two Minor Refactors; public, no secret. |
| Shared auth components (OA_AuthenticationManager … OA_HealthMonitor) | **Build Later** | Formalize after LinkedIn proves the path. |
| Scheduled polling + async bulk orchestrator | **Build Later** | The one additive platform gap; covers volume. |
| Token-expiry monitor + ~11-month re-consent reminders | **Build Later** | Prevents the one recurring OAuth failure mode. |
| Retire `OA_Graph_Credential__c` plaintext secret → Ext+Named Cred | **Build Later** | The only Major Refactor; pre-existing ADR-008 debt; needs sandbox (TD-001). |
| Meta / Google / YouTube / GitHub / QuickBooks OAuth connectors | **Build Later** | Reuse ADR-013 template; QuickBooks needs scope-discipline note. |
| Least-privilege runtime user (replace MAD exception) | **Build Later** | Ties to [[runtime-user-exception]]; do before 24/7 OAuth automation. |
| Webhook middleware service (LinkedIn Lead Sync real-time) | **Defer** | Only when volume/latency justify a running server. |
| Full enterprise integration platform (self-service, multi-domain) | **Defer** | Phase 4; revisit after ≥2 OAuth connectors are healthy. |

---

## Governance ratings for the evolution (Task 8)

| Dimension | Rating | Mitigation |
|---|---|---|
| **Technical Risk** | **LOW** | Reuses the frozen, validated SDK; auth reduces to 5 known classes; phase gates prevent big-bang change. |
| **Security Risk** | **MEDIUM** | Stored OAuth secrets + MAD runtime user; QuickBooks write-scope. → Ext Cred encryption, minimal scopes, least-priv user, rotation/revocation runbook, read-only discipline for QBO. |
| **Deployment Risk** | **LOW** | Config-driven, dormant-by-default, canary precedent; CMDT `xmlns:xsd` rule known. |
| **Maintenance Risk** | **MEDIUM** | Annual re-consent per OAuth connector + more moving parts. → OA_HealthMonitor expiry countdown; one shared framework, not N bespoke ones. |
| **Scalability Risk** | **LOW–MEDIUM** | 6+ OAuth connectors + polling + eventual webhooks + governor limits. → async orchestrator, staggered schedules, middleware at volume, linear (not combinatorial) growth via the shared abstraction. |

---

## Single recommendation

**Adopt the OA Authentication Framework as the platform's permanent authentication standard, ratify
it with ADR-013, and prove it once with LinkedIn (Ext+Named Credential, Named Principal,
Authorization Code, polling-first) before onboarding any other OAuth connector.** This gives One
Algorithm a single, reusable, enterprise-grade authentication design that every current connector
already largely conforms to and every future connector inherits for free — with no server to run
today, no secret ever in code or git, and a clear, gated path to real-time integration when volume
justifies it.

---

*Design and governance documentation only. No code, no deployment, no Salesforce or LinkedIn
configuration was performed in producing this roadmap.*
