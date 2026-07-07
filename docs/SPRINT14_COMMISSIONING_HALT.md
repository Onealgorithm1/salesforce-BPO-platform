# Sprint 14 — Commissioning HALT at Track A (schema propagation incomplete)

_2026-07-07 · Org 00Dbn00000plgUfEAI · branch feature/sprint14-pilot_

## Decision: STOP (per Track A)
Track A requires all schema layers to agree before continuing; if propagation is incomplete,
**Stop. Wait. Do not continue.** Propagation is incomplete, so Tracks B–G (canary revalidation,
rollback drill, 5-Lead pilot, operational validation, monitoring, readiness) were **NOT executed**.
No production Leads were touched this sprint.

## Evidence (all layers must agree — they do not)
| Layer | Result |
|---|---|
| Tooling `FieldDefinition` (metadata) | ✅ `Lead.UEI__c` and `OA_Enrichment_Change_Log__c.Target_Object__c` exist |
| Deploy history | ✅ All deploys Succeeded (0AfPn0000022zz7KAA, 0AfPn000002308nKAA, …) |
| SOQL (data layer) | ❌ `No such column 'Target_Object__c'` / `No such column 'UEI__c'` |
| `sobject describe` (data layer) | ❌ 0 custom fields on the 4 new objects |
| DML (data API + Apex) | ❌ `No such column` on insert |
| Anonymous Apex compile | ❌ `Field does not exist` |
| **Regression** | ❌ `Lead.UEI__c` (successfully written+read in Sprint 13) is now `No such column` |

## Root cause (assessment)
An **org-level schema-describe cache inconsistency**, not a code/metadata defect. The metadata deployed
correctly (Tooling confirms; deploys Succeeded). The rapid succession of production deploys in
Sprints 12–13 (fields, platform types, CMDT records, activate/deactivate toggles) repeatedly invalidated
the org's describe cache; it has not reconciled, and a previously-working field regressed — a hallmark of
a stuck/thrashing describe cache or a platform-side propagation delay.

## Recovery plan (no code changes; no more deploys)
1. **Wait** for the org's schema describe to reconcile. **Do NOT deploy anything** — each deploy resets
   the reconciliation clock and can prolong it.
2. Re-run Track A verification (SOQL a new-object field + `Lead.UEI__c`; `sobject describe`; anon-Apex
   compile; a data-API insert). Proceed only when **all layers agree**.
3. If it does not reconcile within a reasonable window (hours), open a **Salesforce Support case**:
   custom fields confirmed by `FieldDefinition` and by Succeeded deploys are returning `No such column`
   in SOQL/DML/describe; provide deploy IDs `0AfPn0000022zz7KAA` / `0AfPn000002308nKAA`.
4. Once green, resume Sprint 14 at Track B (reuse canary `00QPn000012Ktl3MAC`; do not create another):
   revalidate canary persistence → rollback drill → 5-Lead pilot → monitoring → readiness.

## State
Platform deployed dormant (metadata present); org dormant (0 connectors enabled, 0 active policies,
0 permset assignments, 0 enrichment scheduled jobs). Canary Lead `00QPn000012Ktl3MAC` retained + clean.
No production Leads modified this sprint. main = 1a66832 unchanged.

## Go/No-Go
**NO-GO** for canary revalidation and the 5-Lead pilot until schema propagation completes. This is an
operational/infrastructure blocker, not a software issue.
