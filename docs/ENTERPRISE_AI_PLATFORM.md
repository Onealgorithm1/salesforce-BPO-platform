# Enterprise AI Platform — Architecture, Connectivity & Governance Certification

**Date:** 2026-07-09 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/enterprise-ai-platform`
**Mode:** engineering · architecture · runtime certification · governance. **Reuse existing connectors/adapters; no new secrets; no credential replacement; no automation; no scheduling; no merge; no production changes** (connectivity tests were read-only, zero-token model-list GETs).
**Not Opportunity Intelligence** — this is the provider-agnostic AI foundation OI (and every future AI subsystem) will consume.

---

## 1. Executive Summary
The Enterprise AI foundation is **audited, connectivity-validated, and fully architected/governed** — reuse-first, no new metadata deployed. **Anthropic is live in production** (HTTP 200, ~673 ms, catalog incl. `claude-sonnet-5`, `claude-opus-4-8`, `claude-haiku-4-5`); **OpenAI and OpenRouter credentials exist but are not accessible to the runtime user** (missing External-Credential principal grant — the same pattern resolved for SAM). The **gateway, model orchestration, token/spend governance, observability, catalog, and AI-governance model are specified** and ready to build on top of the existing adapters (`OA_AISummaryService`, `OA_ProposalAdapter`). **Verdict: 🟡 WARN** — architecture + connectivity + governance certified and Anthropic live, but the reusable gateway + token/spend-governance **code is design-complete, not yet built**, and 2 of 3 providers need credential access.

## 2. Production AI Audit (Phase 0 — live)
| Asset | Finding |
|---|---|
| Named Credentials | **OpenAI, OA_Anthropic, OA_OpenRouter** (3) |
| External Credentials | **OA_Anthropic, OA_OpenRouter** (no `OpenAI` EC accessible) |
| AI Apex (adapters) | `OA_AISummaryService`, `OA_AISummaryQueueable`, `OA_ProposalAdapter` (dormant, advisory) |
| Gateway / orchestration | **none** |
| Token/cost log object | **none** |
| Model catalog / routing config | **none** |
| Runtime user | `oauser` (has Anthropic EC access) |
**Conclusion:** connectivity + adapters exist; the platform layer (gateway, orchestration, governance, observability) is greenfield.

## 3. AI Gateway Architecture (Phase 2 — design)
```
Salesforce (workflow / adapter)
        │  route(workload, prompt, opts)
        ▼
   OA_AI_Gateway  ── resolves model per workload (OA_AI_Model__mdt) ── enforces budget ── logs tokens/cost
        │
        ├── Anthropic adapter  (LIVE)      → claude-*  (Sonnet 5 / Opus 4.8 / Haiku 4.5 / Fable 5)
        ├── OpenRouter adapter (pending EC) → gpt / gemini / deepseek / qwen / llama (multi-model)
        └── OpenAI adapter     (pending EC) → gpt-*
```
**Principle:** no workflow calls a provider directly — everything routes through `OA_AI_Gateway`. Existing adapters (`OA_AISummaryService`/`OA_ProposalAdapter`) refactor to call the gateway (reuse, not duplicate). Provider-agnostic: workload→model is config-driven with runtime override + fallback.
**Buildable components (next sprint):** `OA_AI_Gateway` (Apex, routing+call+token-capture), `OA_AI_Model__mdt` (workload→model/provider/fallback config), `OA_AI_Request_Log__c` (per-request token/cost/latency audit — 1 new object), `OA_AI_Budget__mdt` (budgets/thresholds).

## 4. Connectivity Results (Phase 1 — safe, zero-token model-list GETs)
| Provider | Status | Latency | Evidence |
|---|---|---|---|
| **Anthropic** | **200 ✅** | 673 ms | ~10 models incl. `claude-sonnet-5`, `claude-opus-4-8`, `claude-haiku-4-5` |
| **OpenRouter** | **CalloutException** | — | EC `OA_OpenRouter` not accessible to runtime user (missing principal grant) |
| **OpenAI** | **CalloutException** | — | EC `OpenAI` not accessible (missing principal grant / key) |
**Fix for OpenAI/OpenRouter (same as SAM):** grant the EC principal access on a permission set (`externalCredentialPrincipalAccesses`) assigned to the runtime user; confirm each EC key is populated. No secrets handled here.

## 5. Model Routing Matrix (Phase 3 — default model per workload; runtime override supported)
| Workload | Default model | Rationale | Fallback |
|---|---|---|---|
| Meeting Summary | `claude-haiku-4-5` | fast/cheap, short | Sonnet 5 |
| Classification | `claude-haiku-4-5` | cheap, high-volume | Sonnet 5 |
| Executive Summary | `claude-sonnet-5` | balanced quality | Opus 4.8 |
| Document Analysis | `claude-sonnet-5` | large context, balanced | Opus 4.8 |
| Campaign Analysis | `claude-sonnet-5` | balanced | Haiku 4.5 |
| Proposal Writing | `claude-opus-4-8` | highest quality/long-form | Sonnet 5 |
| Research | `claude-opus-4-8` | deep reasoning | Sonnet 5 |
| Opportunity Intelligence (future) | `claude-sonnet-5` | scoring/reasoning at scale | Opus 4.8 |
**No hardcoded provider** — resolved from `OA_AI_Model__mdt`; `opts.model`/`opts.provider` override; OpenRouter provides non-Anthropic models (GPT/Gemini/DeepSeek/Qwen/Llama) once its EC is granted.

## 6. Model Catalog (Phase 7 — live Anthropic; others documented)
| Model | Context (approx) | Strengths | Recommended workloads | Rel. cost |
|---|---|---|---|---|
| **claude-opus-4-8** | large | top reasoning/long-form | proposals, research, complex | $$$$ |
| claude-opus-4-7 | large | strong reasoning | complex analysis | $$$$ |
| **claude-sonnet-5** | large | balanced quality/speed | analysis, summaries, OI | $$ |
| claude-sonnet-4-6/4-5 | large | balanced (prior gen) | general | $$ |
| **claude-haiku-4-5** | mid | fast/cheap | classification, short summaries | $ |
| claude-fable-5 | — | specialized | (creative/variant) | $$ |
| *(via OpenRouter)* GPT / Gemini / DeepSeek / Qwen / Llama | varies | multi-vendor, cost options | fallback/cost-optimized | varies |
Catalog is **dynamically discoverable** via each provider's `/models` endpoint (as done live for Anthropic).

## 7. Token Governance (Phase 4 — capture schema, per request)
`OA_AI_Request_Log__c` (design): Provider, Model, Workflow, Prompt_Tokens, Completion_Tokens, Total_Tokens, Estimated_Cost, Latency_Ms, Retries, Failure_Reason, User, Salesforce_Record_Id, Object, Business_Process, Requested_At. **Every gateway call logs one row** (reuse the `OA_Connector_Run__c` telemetry pattern; new object because token/cost fields are AI-specific). Anthropic responses return `usage.input_tokens`/`output_tokens` for exact capture.

## 8. Spend Governance (Phase 5 — recommendations)
Budgets (via `OA_AI_Budget__mdt`): **daily / monthly / per-user / per-workflow / per-provider.** Threshold alerts at **50 / 75 / 90 / 100 %** (email/platform-event). **Enforcement:** at 100% the gateway soft-blocks non-critical workloads (returns a governed error, never silently drops); executive override permset for hard stops. Cost = tokens × per-model rate (rate table in `OA_AI_Model__mdt`).

## 9–10. AI Dashboards & Monitoring (Phase 6/10)
From `OA_AI_Request_Log__c`: **Requests, Latency, Errors, Retries, Failures, Timeouts, Avg Cost, Avg Tokens, Cost by Model/Workflow/User/Object/Opportunity.** Tiers: **Executive AI** (spend/ROI), **Operations AI** (errors/latency/retries), **Engineering AI** (model perf), **BD AI** (AI usage per pipeline stage), **Cost**, **Provider** (uptime/latency by provider). Interim: a read-only monitor script (like the pipeline monitors) once the log object exists.

## 11. AI Governance (Phase 8)
| Area | Policy |
|---|---|
| Prompt governance | prompts versioned + reviewed; no PII/secret interpolation; templated |
| Human approval | AI output is **advisory**; human approves before any CRM write (BLO-style gate) |
| Audit | every request logged (`OA_AI_Request_Log__c`) + output attached to the record |
| Confidence | model/temperature per workload; low-confidence → human review |
| Fallback / Retry | provider fallback (OpenRouter); bounded retry on transient error |
| Privacy | minimize data sent; strip PII where possible; opt-out records excluded |
| Federal compliance | **AI providers process data externally → ATO/FedRAMP + BAA review required before federal data** |
| Data residency | document provider regions; restrict sensitive/FOUO data from external LLMs |
| Least privilege | gateway runs as a least-priv AI runtime user; EC access scoped per provider |
| Prompt injection | treat model output as untrusted; never auto-execute; sanitize before use |
| Model selection | config-driven (`OA_AI_Model__mdt`); no hardcoded provider; runtime override audited |

## 12. Enterprise Readiness (Phase 11)
- **Is AI production-ready?** **Partial** — Anthropic connectivity live + governed advisory adapters exist; the **gateway + token/spend governance + observability are designed, not built**.
- **Blocks enterprise scale:** gateway/orchestration not built; token/spend governance not implemented; only 1 of 3 providers accessible.
- **Blocks federal deployment:** external-LLM data residency + ATO/FedRAMP + BAA; FOUO/PII data-handling policy; audit completeness.
- **Blocks unattended AI:** human-approval gates (AI is advisory today), spend enforcement, monitoring/alerting, prompt-injection controls.
- **Governance remaining:** budgets, data-residency policy, prompt-injection controls, human-in-loop enforcement.

## 13. Technical Debt
- Build `OA_AI_Gateway` + `OA_AI_Model__mdt` + `OA_AI_Request_Log__c` + `OA_AI_Budget__mdt` (the platform layer).
- Grant EC principal access for OpenAI + OpenRouter (permset, same as SAM) + confirm keys.
- Refactor `OA_AISummaryService`/`OA_ProposalAdapter` to route through the gateway.
- AI dashboards + spend alerts; federal data-residency policy.

## 14. PASS / WARN / FAIL — 🟡 WARN
Provider-agnostic AI **architecture, connectivity certification, model catalog, routing matrix, token/spend governance, observability, and AI-governance model are delivered**, with **Anthropic live** and existing adapters reused — **no new secrets, no credential replacement, no production changes.** **WARN:** the reusable gateway + token/spend-governance **code is design-complete, not yet built**; OpenAI + OpenRouter need EC principal grants. Not a FAIL — the foundation is certified and buildable; not a full PASS until the gateway is implemented and ≥2 providers are live.

## 15–16. Commit / PR
See closeout — new branch/PR; not merged.

## 17. Exact Next Engineering Program
**AI Gateway Implementation (build sprint, gated):** build `OA_AI_Gateway` + `OA_AI_Model__mdt` + `OA_AI_Request_Log__c` + `OA_AI_Budget__mdt` (check-only → deploy dormant); grant OpenAI/OpenRouter EC principal access; refactor the existing adapters to route through the gateway; wire token/cost logging + spend alerts. Then **Opportunity Intelligence** (ADR-015…019) consumes this governed AI platform — begun only with explicit approval. BLO stays closed.
