# Temporary Runtime User Exception

_Status: **ACTIVE business decision** · Approved by Louis Rubino · 2026-07-06 · Org 00Dbn00000plgUfEAI_

## Decision
For commissioning and early operation of the Lead Enrichment Platform, **`oauser@pboedition.com` is the
temporary runtime user**. This is a conscious **business decision, not the final security model.**

## Why
- The org currently has **0 spare Salesforce licenses** (2 of 2 used), so a dedicated least-privilege
  integration user cannot be created yet.
- We choose to begin **controlled commissioning** rather than block the entire platform indefinitely.

## Risk accepted (explicitly)
- `oauser@pboedition.com` is an **admin / high-privilege** user (Modify All Data).
- MAD **weakens the intended FLS / least-privilege runtime guardrail**: the enrichment writer enforces
  FLS in `USER_MODE`, but a MAD user has broad field access, so the field-level protection is reduced.
- Therefore **all enrichment activation must remain conservative** (below).

## Temporary controls (mandatory while this exception is active)
- **Connectors stay dormant** (`OA_Connector_Registry.<src>.Enabled__c = false`) until explicitly enabled.
- **Start with a very small canary set** (1 synthetic Lead, then a handful).
- **Prefer fill-empty policies**; **avoid broad overwrite** behavior.
- **Full change logging + rollback snapshots** on every write (`OA_Enrichment_Change_Log__c`).
- **Emergency shutdown** available at all times (registry `Enabled__c=false` + revoke assignments).
- **Do NOT schedule 24/7 enrichment** until canary + pilot runs pass.

## Future requirement (must-do when feasible)
When One Algorithm has budget/revenue to support it, **acquire a Salesforce license, create a dedicated
least-privilege runtime user** (Minimum Access profile, **no Modify All Data**, FLS only on trusted
enrichment fields), and **move enrichment execution off `oauser@pboedition.com`.** This restores the
intended security model. Track as the top operational risk until closed.

## Related
- `PRODUCTION_COMMISSIONING_REPORT.md` (blocker B1) · `DEPLOYMENT_PACKAGE.md` §5 (runtime-user checklist)
- ADR-012 (automated enrichment governance) — this exception is a documented, time-boxed deviation.
