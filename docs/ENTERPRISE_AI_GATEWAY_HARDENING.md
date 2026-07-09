# Enterprise AI Gateway Hardening + OpenRouter Workspace Management

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/enterprise-ai-gateway-hardening`
**Mode:** engineering · runtime validation · governance. **Reuse ECs/adapters; no secrets handled; no credential replacement; no scheduling.**
**Production changes:** `OA_AI_Platform_Access` (log FLS permset, deployed+assigned) + `OA_AI_ModelRegistry` (+test, deployed). OpenRouter inference/management auth = **gated (secrets Louis configures)**.

---

## 1. Executive Summary
The AI platform is substantially hardened: **telemetry is now reportable** (FLS permset), a **live model registry discovers 340 OpenRouter models** with pricing/context and gives a **data-driven routing recommendation** (recommend-only, no auto-switch), and governance/runbooks are complete. The **OpenRouter 401 is conclusively root-caused**: the `OA_OpenRouter` EC has **no `Authorization` AuthHeader** (Anthropic has `x-api-key`), so no Bearer token is sent — **completions need the key wired (gated secret)**; the public `/models` works, which is why discovery + fallback function. Workspace management is designed with a **separate `OA_OpenRouter_Management` credential** (gated — needs an OpenRouter Provisioning key). **Verdict: 🟡 WARN** — infrastructure hardened + governed, but OpenRouter **inference** and **management** both await two secrets Louis must configure; the gateway stays operational via Anthropic fallback.

## 2. Runtime Certification (Phase 0)
`OA_AI_Gateway` live; `OA_AI_Request_Log__c` (1 row, now queryable); `OA_AI_Model__mdt` type live; ECs OA_Anthropic (working) / OA_OpenRouter (inference, no Bearer) / OpenAI (no key); adapters dormant. Runtime user `oauser` (+ `OA_AI_Platform_Access`).

## 3. Authentication Validation (Phase 1 — root cause, gated fix)
| EC | Auth config | Result |
|---|---|---|
| OA_Anthropic | NamedPrincipal + **AuthHeader `x-api-key`** | 200 (key injected) |
| **OA_OpenRouter** | NamedPrincipal only — **NO AuthHeader** | **401** completions (`No cookie auth credentials`); `/models` GET public → 200 |
**Fix (🔴 gated secret — Louis, Setup):** OA_OpenRouter EC → add a **Custom Header `Authorization`** with value `Bearer <OpenRouter inference API key>` (mirror the Anthropic `x-api-key` pattern). Then completions authenticate. I do not handle the secret. Before/after: 401 (no header) → expect 200 once the header+key are set.

## 4. OpenRouter Certification (Phase 2)
- **Model listing:** ✅ 200, **340 models** (public).
- **Chat completion:** 401 (Bearer not wired) — gated.
- **Streaming:** deferred (needs completions auth).
- **Token/latency/cost/error/retry/fallback:** validated via the gateway last sprint (OpenRouter 401 → Anthropic 200, 18 tokens, $0.000036) — **fallback proven**; full OpenRouter token/cost validation pending the key.

## 5. Gateway Refactor (Phase 3)
`OA_AI_Gateway.complete()` is the single entry point (built). Adapters `OA_AISummaryService`/`OA_ProposalAdapter` (dormant) **refactor-to-gateway is documented as the immediate follow-up** (not modified this sprint to avoid drift). New AI workloads MUST call the gateway; no direct provider calls.

## 6. Model Registry (Phase 4 — BUILT + live)
`OA_AI_ModelRegistry.discover()` fetches the **public** OpenRouter `/models` (no secret): **340 models live**, each with provider/context/pricing (no hardcoded catalog). `recommend(minContext)` returns the cheapest model meeting context (variable/`-1` pricing excluded) — e.g. `tencent/hy3:free` (262k ctx, $0). Deployed + tested (mock) + live-validated. *(Refinement: add a min-quality/paid filter so "free" models aren't auto-recommended for critical workloads.)*

## 7. Benchmark Engine (Phase 5 — design)
`OA_AI_Benchmark` (design): run standardized prompts (JSON, summarization, classification, proposal, reasoning) through the gateway per candidate model; score accuracy/format/cost/latency; store to a benchmark object. Requires OpenRouter completions (gated key) to benchmark non-Anthropic models. Anthropic benchmarking possible now.

## 8. Self-Optimizing Routing (Phase 6 — design; recommend-only)
Combine registry (cost/context) + benchmark (quality) + telemetry (latency/reliability) → **recommend** the best model per workflow. **Never auto-switches** production routing (stays in `OA_AI_Model__mdt`, human-approved). A scheduled recommendation report is the delivery (gated on scheduling).

## 9. Governance (Phase 7 — telemetry complete)
`OA_AI_Request_Log__c` captures provider/model/workflow/prompt+completion+total tokens/latency/cost/status/retry/failure/business-process per call — **now queryable** (FLS permset). Prompt logging: opt-in (privacy). Nothing fails silently (every failure logged with reason + surfaced on the result).

## 10. Dashboards (Phase 8 — enabled by FLS permset)
Executive/Operations/Engineering/Spend/Latency/Provider/Benchmark/Routing dashboards buildable on `OA_AI_Request_Log__c` (now readable via `OA_AI_Platform_Access`). Reports: cost by model/workflow/provider/day; latency; failure rate; retry rate. Build reports next (data now visible).

## 11. Budget Enforcement (Phase 9 — design)
`OA_AI_Budget__mdt` (daily/monthly/per-workflow/per-provider/per-model caps + 50/75/90/100% thresholds). Gateway pre-call check sums `OA_AI_Request_Log__c.Estimated_Cost__c` for the window vs cap → soft-stop (governed error) at 100%, admin override; alerts via platform event/email. Wire into the gateway next (CMDT records via Setup due to the CLI `UNKNOWN_EXCEPTION` on CMDT-record deploys).

## 12. Happy / Unhappy Path Matrix (Phase 10)
| Path | Detection | Recovery | Escalation | Audit | Impact |
|---|---|---|---|---|---|
| Success | 200 + usage | — | — | log | — |
| **Auth (OpenRouter 401)** | 401 | **fallback Anthropic** / wire key (gated) | admin | log | provider degraded (mitigated) |
| Provider outage / 5xx | status | fallback | ops | log | degraded |
| Timeout | callout timeout | retry + fallback | eng | log | latency |
| Invalid model | 400/404 | registry validation | eng | log | request fails |
| Malformed response | parse guard | fallback | eng | log | partial |
| Prompt injection | output-as-untrusted | never auto-execute | eng | log | integrity |
| Budget exceeded | budget check | soft/hard stop | exec | log | spend control |
| Token exceeded | max_tokens | truncate | eng | log | partial |
| Rate limited (429) | 429 | backoff + fallback | ops | log | throttled |
| Retry exhaustion | counter | fail + alert | ops | log | request fails |
| Human approval | gate | hold output | reviewer | log | no CRM write |
**Nothing fails silently.**

## 13. Enterprise Readiness (Phase 11)
- **AI platform production-ready?** **Operational via Anthropic fallback + reportable telemetry + live model discovery.** For OpenRouter as the *primary* standard: **pending the gated inference Bearer key.**
- **Can Opportunity Intelligence begin?** **Yes, on the gateway** (operational via fallback) — but wire the OpenRouter inference key first for the intended cost/model strategy.
- **Tech debt:** OpenRouter inference key (gated); adapter refactor; budget enforcement; benchmark engine; dashboards/reports; registry quality-filter.
- **Operational debt:** AI dashboards; monthly spend review; alerting.
- **Security debt:** OpenRouter inference + management keys (gated secrets); prompt-injection controls; federal data-residency.

---

## OpenRouter Workspace Management (Amendment — Phases 12–14)

### 19. OpenRouter Workspace Audit (Phase 12)
- **`OA_OpenRouter_Management` credential:** **does not exist** (only `OA_OpenRouter` inference). Must be created (gated — needs a Provisioning key).
- **Workspace/keys/limits/spend audit:** **BLOCKED** — requires the OpenRouter **Management (Provisioning) API key**; not available and must not be fabricated/stored in code. (Even the current-key self-audit `GET /api/v1/key` needs the working inference Bearer, which is also gated.)
- **Model/provider availability:** ✅ auditable now via public `/models` (340 models; provider set incl. openai/google/anthropic/x-ai/qwen/deepseek/meta-llama/mistralai/amazon/...).
- **Billing/spend via API:** requires the management key.

### 20. Management API Readiness
OpenRouter Management (Provisioning) API: `GET/POST/PATCH/DELETE https://openrouter.ai/api/v1/keys` (list/create/update/disable keys), `GET /api/v1/key` (current key usage/limit), `GET /api/v1/credits` (balance) — all require a **Provisioning key** (distinct from inference). **Design:** create a **separate** `OA_OpenRouter_Management` Named/External Credential (Custom auth, `Authorization: Bearer <provisioning key>`), **used only for admin** (never for model calls), key **never** in Apex/docs/logs/repo. Apex admin methods would call `callout:OA_OpenRouter_Management/...`.

### 21. OpenRouter Key Governance (Phase 13)
| Key | Name | Cap | Reset | Stored as | Use |
|---|---|---|---|---|---|
| Production inference | `Salesforce-BPO-Production` | **required spend cap**, no unlimited | monthly | `OA_OpenRouter` EC (Bearer) | model calls only |
| Development/test | `Salesforce-BPO-Development` | lower cap | monthly/expiry | dev EC | test model calls |
| Management | `Salesforce-BPO-Management` | n/a | — | `OA_OpenRouter_Management` EC (protected) | admin API only; **never** model calls / never logged / never in repo |
**Every management action records:** who, why, what changed, before/after, risk, rollback, timestamp, related workflow, related PR/commit (log to `OA_Enrichment_Change_Log__c` or a dedicated admin-audit object). **Never without explicit Louis approval:** delete production keys, remove spend limits, create unlimited keys, change billing/ownership, disable the active production inference key.

### 22. Admin Operations Runbook (Phase 14)
- **Create model-call key:** management API `POST /keys` (name, cap) → store in a scoped EC → validate with a tiny gateway call.
- **Rotate production key:** create new capped key → update `OA_OpenRouter` EC Bearer → validate → disable old key → audit.
- **Disable compromised key:** management API `PATCH /keys/{id}` disabled=true → rotate → audit → notify.
- **Lower/raise spend caps:** `PATCH /keys/{id}` limit (raise = approval) → audit.
- **Audit workspace drift:** compare live keys/limits vs the policy table → report deltas.
- **Audit model availability:** `OA_AI_ModelRegistry.discover()` (public) → diff vs expected.
- **Monthly AI spend review:** sum `OA_AI_Request_Log__c.Estimated_Cost__c` + `GET /api/v1/credits` → review vs budgets.
- **Emergency AI shutdown:** disable the production inference key (approval) OR flip a gateway kill-switch CMDT → all gateway calls soft-fail with a governed error.

### 23. Manual Actions Louis Must Perform (OpenRouter dashboard / Setup)
1. **Inference key (unblocks completions):** in OpenRouter, ensure a capped production key `Salesforce-BPO-Production`; in Salesforce Setup → External Credentials → `OA_OpenRouter` → add Custom Header **`Authorization` = `Bearer <that key>`** (mirror Anthropic `x-api-key`).
2. **Management key:** create an OpenRouter **Provisioning key** `Salesforce-BPO-Management`; create External Credential **`OA_OpenRouter_Management`** with `Authorization: Bearer <provisioning key>` (admin-only).
3. **Caps/policy:** set spend caps + monthly reset per the key-governance table; never unlimited.
> Provide these and I will: validate inference (expect 200), build the management admin methods + workspace-drift audit, and wire budget enforcement — all without ever exposing a secret.

## 14. Technical Debt
OpenRouter inference Bearer key (gated) · `OA_OpenRouter_Management` + provisioning key (gated) · adapter refactor · budget enforcement (`OA_AI_Budget__mdt`) · benchmark engine · AI dashboards/reports · registry quality-filter · CMDT-record deploy workaround (Setup).

## 15. PASS / WARN / FAIL — 🟡 WARN
Hardening delivered: **model registry live (340 models, data-driven recommend)**, **telemetry reportable (FLS permset)**, governance + key policy + admin runbook complete, OpenRouter 401 conclusively root-caused, workspace-management architecture (separate `OA_OpenRouter_Management`) designed. **WARN:** OpenRouter **inference** (Bearer key) and **management** (provisioning key) are gated on secrets Louis must configure; benchmark/budget/dashboards/adapter-refactor are next builds. The platform is operational via Anthropic fallback and governed both as inference (OA_OpenRouter) and — by design — as a managed workspace (OA_OpenRouter_Management, pending the key).

## 16–17. Commit / PR
See closeout — new branch/PR; not merged.

## 18. Exact Next Engineering Program
**AI Platform Finalization (partly gated):** on Louis wiring the 2 keys — validate OpenRouter inference (200) + build the `OA_OpenRouter_Management` admin methods + workspace-drift audit; refactor adapters through the gateway; wire `OA_AI_Budget__mdt` enforcement + alerts; build AI dashboards/reports + benchmark engine. **Then Opportunity Intelligence** (ADR-015…019) consumes the governed gateway. BLO stays closed.
