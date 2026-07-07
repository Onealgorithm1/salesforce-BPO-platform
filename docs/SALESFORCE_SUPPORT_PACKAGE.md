# Salesforce Support Case Package (prepared — NOT to be opened)

_Sprint 15 · 2026-07-07 · prepared per deliverable requirement_

## ⚠️ Determination: a Support case is NOT warranted
The investigation (`SALESFORCE_PLATFORM_INVESTIGATION.md`) concluded the "No such column" behavior is a
**Field-Level Security configuration gap**, not a Salesforce platform defect. A case would be closed by
Salesforce as "working as designed — grant FLS to the user." **Do not open a case.** This package is
retained only as a ready template should a genuine, FLS-independent platform anomaly appear later.

If (and only if) a future anomaly persists AFTER FLS is confirmed granted to the running user, submit the
following.

## Case package (template)
- **Org ID:** 00Dbn00000plgUfEAI (Production, Enterprise Edition, API 67.0)
- **Affected user:** oauser@pboedition.com (System Administrator)
- **Deployment IDs:** `0AfPn0000022zz7KAA` (184/184, Succeeded), `0AfPn000002308nKAA` (44/44, Succeeded)
- **Exact error messages:**
  - `No such column 'UEI__c' on entity 'Lead'. If you are attempting to use a custom field, be sure to append the '__c' after the custom field name. Please reference your WSDL or the describe call for the appropriate names.`
  - `No such column 'Target_Object__c' on entity 'OA_Enrichment_Change_Log__c'.`
  - Anonymous Apex: `Field does not exist: Target_Object__c on OA_Enrichment_Change_Log__c`
- **Reproduction steps (as run):**
  1. `sf api request rest "/services/data/v67.0/query/?q=SELECT+UEI__c+FROM+Lead+LIMIT+1"` → INVALID_FIELD (server-side, raw REST, no CLI cache).
  2. `sf data query -q "SELECT Target_Object__c FROM OA_Enrichment_Change_Log__c LIMIT 1"` → No such column.
  3. `sf sobject describe -s Lead` → UEI__c absent (user-context describe).
  4. Tooling: `SELECT COUNT() FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='Lead' AND QualifiedApiName='UEI__c'` → 1 (field exists).
- **Evidence by layer:** Tooling = field exists; Metadata API = deploy Succeeded; SOQL / Describe / DML /
  Anonymous Apex = "No such column". (Full matrix in the investigation doc.)
- **Timeline (UTC):** deploy #1 01:42:31 → deploy #2 01:46:16 → canary write with permset assigned
  (UEI__c visible) → permset revoked in cleanup (UEI__c → "No such column"). Persisted 30+ min after
  revocation; resolved conceptually by the FLS finding.
- **Expected behavior:** a deployed custom field is queryable/insertable.
- **Actual behavior:** field is "No such column" for a user WITHOUT FLS on it (documented Salesforce
  behavior), while present in Tooling FieldDefinition (which ignores FLS).
- **Root cause (self-diagnosed):** FLS not granted to the running user (profile has none; the granting
  permission set was unassigned). **Resolution is customer-side configuration, not a Salesforce fix.**

## Recommended action (instead of a case)
Grant FLS on the enrichment fields to the runtime user (assign/expand `OA_Lead_Enrichment_Runtime`) and
keep it assigned; re-verify all layers agree. See `SALESFORCE_PLATFORM_INVESTIGATION.md` §Recovery.
