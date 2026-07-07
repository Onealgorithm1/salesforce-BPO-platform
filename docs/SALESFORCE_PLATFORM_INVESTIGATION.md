# Salesforce Platform Investigation — Metadata vs Data-Layer "No such column"

_Sprint 15 · evidence-only · 2026-07-07 · Org 00Dbn00000plgUfEAI · oauser@pboedition.com (System Administrator)_

## Conclusion (up front)
**The metadata inconsistency is NOT a Salesforce platform bug, NOT a deployment failure, and NOT an
application/code defect. It is a FIELD-LEVEL SECURITY (FLS) configuration gap.** The runtime user
(`oauser`, System Administrator) has **no FLS** on the newly-deployed custom fields, so SOQL / describe /
DML / anonymous Apex — which enforce FLS for the running user — report those fields as **"No such column"
/ "Field does not exist."** Tooling `FieldDefinition` ignores FLS, so it still lists them → the exact
"Tooling shows it, data layer doesn't" split. Grant FLS to the runtime user and every layer agrees.

## Task 1 — Deployment verification
| Deploy | Status | Components | Errors |
|---|---|---|---|
| `0AfPn0000022zz7KAA` (platform types) | **Succeeded** | 184/184 | 0 component, 0 test |
| `0AfPn000002308nKAA` (44 CMDT records) | **Succeeded** | 44/44 | 0 |
No failures, no warnings. Deployment is not the cause.

## Task 2 — Layer consistency comparison
| Layer | `Lead.UEI__c` (new) | `Lead.UEI_Verification_Status__c` (old, FLS via assigned permset) | CMDT field |
|---|---|---|---|
| **Tooling API** (FieldDefinition) | ✅ exists | ✅ exists | ✅ |
| **Metadata API** (deploy) | ✅ deployed | ✅ | ✅ |
| **SOQL** (raw REST v67, FLS-enforced) | ❌ `No such column` | ✅ returns data | ✅ |
| **Schema describe** (REST, FLS-enforced) | ❌ absent | ✅ present | ✅ |
| **DML** (data API + Apex) | ❌ `No such column` | ✅ | n/a |
| **Anonymous Apex** compile | ❌ `Field does not exist` | ✅ | ✅ |
The split correlates perfectly with **whether the running user has FLS on the field** — not with the API,
and not with deploy recency per se.

## Task 3 — Scope
Affected = **custom fields on which `oauser` has no FLS**:
- The 29 new Lead enrichment fields (FLS only via the **unassigned** `OA_Lead_Enrichment_Runtime` permset).
- The 4 new objects' fields (the runtime permset granted Lead FLS only, never the enrichment-object fields; and it's unassigned).
- `OA_SAM_Entity_Staging__c` fields (permset with their FLS never assigned to oauser).

NOT affected = anything `oauser` can see:
- Standard fields (Company, …) — profile grants them.
- Old Lead custom fields (`UEI_Verification_Status__c`, …) — FLS via the **assigned** Writeback Reviewer permset.
- CMDT types/fields/records — Custom Metadata fields are not gated by per-record FLS the same way → queryable.
- New objects at the **object level** (`SELECT Id`/`COUNT()`) — no field referenced → no FLS check → works.

## Task 4 — Root-cause proof (FLS)
```
oauser profile: System Administrator
FieldPermissions granting READ on Lead.UEI__c:            OA Lead Enrichment Runtime (read+edit)  ← permset only
FieldPermissions on Lead.UEI__c via System Administrator: 0                                        ← profile has NONE
FieldPermissions on Lead.UEI_Verification_Status__c:      OA Lead Writeback Reviewer / Automation  ← Reviewer IS assigned to oauser
OA_Lead_Enrichment_Runtime FLS on UEI__c:                 present (metadata) — but assignment REVOKED in Sprint 13 cleanup
```
**Timeline that proves it:** Sprint 13 canary — permset `OA_Lead_Enrichment_Runtime` **assigned** → `SELECT
UEI__c` returned `CANARYUEI001` (visible). Sprint 13 cleanup — permset **revoked** → `SELECT UEI__c` →
`No such column` ("regression"). Nothing about the field/metadata changed; only the FLS assignment did.

**Documented Salesforce behavior:** a field the running user has no FLS on is reported as INVALID_FIELD
("No such column … If you are attempting to use a custom field …") in SOQL/DML, and is omitted from the
user-context describe. Metadata API deploys do **not** auto-grant FLS to the System Administrator profile
(a well-known deployment gotcha) — FLS must be granted via profile or permission set. See sources below.

## Task 6 — Recovery (in our control; no code, no Support)
**Fix = grant FLS on the enrichment fields to the runtime user, and keep it assigned during operation.**
1. Expand `OA_Lead_Enrichment_Runtime` to also grant object CRUD + field FLS on the 4 enrichment objects
   (currently it covers only the 29 Lead fields).
2. Assign the permset to `oauser` (JIT) and **keep it assigned** through commissioning (do not revoke
   mid-commissioning as happened in Sprint 13).
3. Re-run Sprint 14 Track A: confirm `SELECT UEI__c FROM Lead` and `SELECT Target_Object__c FROM
   OA_Enrichment_Change_Log__c` both succeed → all layers agree.
(These are gated actions for a later sprint; Sprint 15 is investigation-only and performed none of them.)

## Corrections to prior sprints
The Sprint 13/14 "schema propagation lag" hypothesis was a **misdiagnosis**. The verified cause was FLS
the entire time: the Sprint-13 change-log/exception non-persistence and the `Lead.UEI__c` "regression"
are both explained by the runtime user lacking FLS on those fields after the permset was revoked.

## Sources
- [Salesforce/Informatica — "No such column" custom field cause = field access/FLS](https://knowledge.informatica.com/s/article/000204004)
- [FormAssembly — INVALID_FIELD: No such column (FLS / field access)](https://help.formassembly.com/help/467677-salesforce-error-invalid-field-no-such-column)
- [Qlik — Resolve "No such column on entity" (field-level access)](https://community.qlik.com/t5/Official-Support-Articles/Salesforce-Resolve-error-quot-No-such-column-X-on-entity-X/ta-p/1829257)
