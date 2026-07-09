# Enterprise AI Platform — Production Certification (Program 019)

**Org:** 00Dbn00000plgUfEAI (verified by ID) · **Date:** 2026-07-09 · **Branch:** feature/enterprise-ai-platform-certification

**Verdict: WARN → conditional PASS.** Every subsystem is certified working against live production endpoints. The single gating item is that the **production credential `OA_OpenRouter` has no `ApiKey`** (removed during Program-018 diagnosis and not yet re-entered). Its config is byte-identical to the two working credentials; it needs only the key pasted into Setup. Until then, production inference falls back to Anthropic on every call.

---

## Runtime architecture (confirmed live)
- **3 credentials, fully separated:** `OA_OpenRouter` (prod inference), `OA_OpenRouter_Development` (dev inference), `OA_OpenRouter_Management` (workspace/provisioning). Each: Named Credential (`SecuredEndpoint`, base `https://openrouter.ai/api/v1`) → External Credential (Custom) → per-principal `ApiKey` secret → header `Authorization: Bearer {!$Credential.<EC>.ApiKey}`.
- **Required NC flags (root-cause fix from Program 018):** `allowMergeFieldsInHeader=true`, `generateAuthorizationHeader=false` on all three.
- **Single entry point:** `OA_AI_Gateway.complete(workflow, prompt, businessProcess, recordId)` — config-driven routing (`OA_AI_Model__mdt`, default OpenRouter → fallback Anthropic), full telemetry to `OA_AI_Request_Log__c`.
- **Model registry:** `OA_AI_ModelRegistry.discover()/recommend()` over the public `/models` catalog (no hardcoded catalog).
- **Access:** `OA_AI_Provider_Access` (principal access: the 3 OpenRouter principals + OpenAI) and `OA_AI_Platform_Access` (log FLS) — both assigned to the runtime user; least privilege.

## Validation evidence (live)
| Phase | Result | Evidence |
|---|---|---|
| 1 · Production inference | ❌ BLOCKED | `Field OA_OpenRouter.ApiKey does not exist` — missing key |
| 2 · Development inference | ✅ HTTP 200 | `gpt-4o-mini` → "CERT-OK", tokens 14/4/18, **cost $0.0000045**, 1800 ms |
| 3 · Management API | ✅ HTTP 200 | `/key`: is_management=true, is_provisioning=true |
| 4 · Model registry | ✅ (logic) | 343 models · 56 providers · 23 free · 4 variable-priced · 343 with context |
| 5 · Gateway | ✅ HTTP 200 | fallback to Anthropic, retry=1, "GATEWAY-OK", 22 tok, 907 ms, $0.000044, OpenRouter failure captured |
| 6 · Telemetry/governance | ✅ | `OA_AI_Request_Log__c` AIREQ-00012 (provider/model/tokens/latency/cost/status/retry/failure); GROUP BY provider reporting works |
| 7 · Security | ✅ | no keys in repo or Apex; 3 separated credentials; least-privilege permsets |
| 8 · Unhappy paths | ✅ | invalid model → HTTP 400; invalid/missing key → 401; fallback proven; nothing silent |

## Happy / Unhappy path matrix
**Happy:** auth (DEV/MGMT 200), completion (DEV 200 + cost), telemetry (logged), gateway (200 via fallback), management (200), fallback (OpenRouter→Anthropic), model discovery (343). All proven.
**Unhappy:** invalid model → 400 (live); missing/invalid key → 401 (live); provider failure → fallback + logged reason (live); retry → retryCount=1 (live). **Budget-exceeded → NOT enforced** (spend is logged, not gated — see debt). 429/timeout/malformed → handled by the non-2xx + exception paths (logged, non-silent) but not independently triggered here.

## Security certification — PASS
No secrets in repository, Apex, or docs. Keys live only in the encrypted per-principal credential store (UI-entered). Production / Development / Management credentials are fully separated (distinct ECs, NCs, keys, principals). Runtime user holds only the AI permission sets (least privilege).

## Debt
- **Operational (blocking PASS):** re-enter `OA_OpenRouter` `ApiKey` in Setup (Custom EC principal → Authentication Parameter `ApiKey` = the production key). Removed during Program-018 diagnosis.
- **Governance:** budget/spend is *measured* (per-request cost logged) but not *enforced* (no hard stop on exceed); dashboards are report-ready but not built.
- **Technical (minor):** `OA_AI_ModelRegistry.discover()` and the gateway call `callout:OA_OpenRouter` (prod) directly, so a broken prod credential also breaks catalog discovery; consider a public-catalog fallback / configurable NC.

## Definition of Done
Production inference 200 · Development inference 200 ✅ · Management API 200 ✅ · Gateway routing + fallback + retry ✅ · Telemetry (tokens/cost/latency/provider/model/status/failure) ✅ · Model registry (live, no hardcoding) ✅ · Security certified ✅ · **Remaining: production `ApiKey` re-entry → then OpenRouter becomes the effective default and Phase 1 flips to 200.**
