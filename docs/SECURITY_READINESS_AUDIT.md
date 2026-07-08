# Security Readiness Audit — Lead Enrichment (Production)

**Date:** 2026-07-08 · **Mode:** READ-ONLY live-org audit · **Org:** `00Dbn00000plgUfEAI` (verified by ID)
**Method:** live `sf` queries (NamedCredential / ExternalCredential / PermissionSetAssignment / SetupEntityAccess / ConnectedApplication / AuthProvider)

> Phase 2. Every row is a live production result.

---

## 1. Named Credentials (live, 8)
| NC | For | In repo? |
|---|---|---|
| `OA_USASpending` | USASpending connector (NoAuth, public) | ✅ |
| `OA_Census` | Census connector (NoAuth, public) | ✅ |
| `OA_SEC` | SEC connector (NoAuth, public) | ✅ |
| `OA_SAM` | SAM Entity connector (SecuredEndpoint → EC `OA_SAM`; endpoint `api-alpha.sam.gov`) | ✅ |
| `OA_Anthropic` | AI summaries (SecuredEndpoint) | ✅ |
| `OA_LinkedIn` | Social (SecuredEndpoint) | ✅ |
| `OA_Meta` | Social (SecuredEndpoint) | ✅ |
| `OpenAI` | AI (SecuredEndpoint) | **❌ not in repo — drift** |

**Not in prod (repo-only):** `OA_GrantsGov`, `OA_SAM_Opportunities` (OI, not deployed).
All Lead-Enrichment NCs required for the certified connectors are present.

## 2. External Credentials (live, 5)
`OA_SAM`, `OA_Anthropic`, `OA_LinkedIn`, `OA_Meta`, `OpenAI`. (Public connectors need none.)
Repo tracks EC files as **gitignored** (secrets never in git) — confirmed no EC tracked.
**Drift:** `OpenAI` EC exists in org, not in repo.

## 3. External Credential principal access — ⚠️ 0 grants (live)
`SELECT Parent.Name FROM SetupEntityAccess WHERE SetupEntityType='ExternalCredential'` → **0 rows.**
No permission set grants EC principal access to any user. Consequence for Lead Enrichment: **the SAM connector
cannot authenticate** (its `OA_SAM` EC has no principal-access grant) — the documented R2 blocker, now **confirmed
live**. A JIT permission-set grant is required before any SAM run. (Meta/LinkedIn/Anthropic/OpenAI use named-principal
EC config, not permset grants; they are out of Lead-Enrichment scope.)

## 4. Permission set assignments (live)
| Permission set | Assigned to | Assessment |
|---|---|---|
| `OA_Lead_Enrichment_Runtime` | `oauser@pboedition.com` | ✅ correct — must stay assigned (FLS on enrichment fields; revoking = "No such column" bug) |
| `OA_Lead_Writeback_Reviewer` | `oauser@pboedition.com` | ✅ read/review permset — acceptable |
| `OA_Lead_Writeback_Automation` | **unassigned** | ✅ correct — the sensitive Lead-write permset is NOT assigned |
| `OA_SAM_Connector` | **unassigned** | ✅ (carries SAM EC principal access; JIT only) |
| `OA_Connector_Staging` | **unassigned** | ✅ |
| `OA_Opportunity_Intelligence_Runtime` | **unassigned** | ✅ |

## 5. Runtime user — 🔴 least-privilege violation (documented exception R1)
The enrichment runtime identity is **`oauser@pboedition.com`**, a **Modify-All-Data (MAD) admin**. MAD bypasses FLS,
weakening the field-level guardrail that the least-privilege permset design depends on. This is the documented,
accepted temporary exception (`RUNTIME_USER_EXCEPTION.md`) — **top standing security risk**. Fix: a dedicated
least-privilege integration user (needs a Salesforce license). Not blocking a dormant deploy; **blocks unattended 24×7 writes.**

## 6. Connected Apps (live, 10) & Auth Providers (live, 1)
Connected apps: standard Salesforce/Chatter apps + `Environment Hub` + `PartnerTrial` + **`OIQ_Integration`**.
- **`OIQ_Integration`** = unidentified connected app (TECHNICAL_DEBT **TD-009**, purpose undocumented). Not related to
  Lead Enrichment, but a standing security-hygiene item — recommend identify/document or revoke. (TD-008 `tbid.digital`
  app was **not** present in this ConnectedApplication query — appears resolved or was never a ConnectedApplication.)
Auth Providers: **`OA_LinkedIn`** only (social OAuth). No enrichment auth provider (correct — enrichment NCs are NoAuth/SecuredEndpoint).

## 7. Secrets posture
No secrets in git (verified prior sprints: `externalCredentials/` + `authproviders/` gitignored and untracked; NCs
secret-free). Live ECs hold the secrets in-org. ✅

## 8. Phase-2 findings summary
| Category | Finding | Severity |
|---|---|---|
| Missing | none blocking (all LE NCs present) | — |
| Dormant | write-back Automation + connector permsets **unassigned**; 0 EC principal grants | 🟢 by design |
| Unsafe | **runtime user = MAD `oauser`** | 🔴 R1 |
| Temporary | SAM EC principal grant to be JIT; MAD user until license | 🔴 R1/R2 |
| Least-privilege violation | MAD runtime user (documented) | 🔴 R1 |
| Hygiene | `OpenAI` NC/EC in org not in repo (drift); `OIQ_Integration` app unidentified (TD-009) | 🟡 |

**Phase-2 verdict: 🟡 WARN.** Dormant security posture is sound (unassigned write/connector permsets, no EC grants,
no secrets in git). Two 🔴 items gate *active* operation only: the MAD runtime user (R1) and SAM credential/JIT grant
(R2). Neither blocks the already-live dormant state.
