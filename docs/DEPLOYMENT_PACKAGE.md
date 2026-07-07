# Lead Enrichment Platform — Deployment Package

_Status: **design/checklist — for controlled deployment** · 2026-07-06. Nothing here is executed; the
platform is dormant until each gate below is consciously passed (ADR-012)._

## 1. Deployment sequence (order matters)
1. **Objects + fields** — `OA_Connector_Run__c`, `OA_Enrichment_Change_Log__c`, `OA_Enrichment_Exception__c`,
   `OA_Discovered_Organization__c` (+ any new Lead custom fields the field-write policies reference).
2. **Custom Metadata Types** (the `__mdt` type + field definitions only, NO records yet).
3. **Apex** — platform (SDK, engines, `OA_IEnrichmentConnector`, `OA_ConnectorRunner`, `OA_ConnectorResult`,
   `OA_CanonicalOrg`) then connectors (SAM/USASpending/Census/IRS/SEC/StateRegistry) + tests.
4. **Named Credentials** (secret-free) — after the org-side External Credentials exist (keyed sources).
5. **Permission sets** (unassigned).
6. **CMDT records** — LAST, in a SEPARATE deployment (see §2).

> **Why records last / separate:** a check-only or single deploy that CREATES a CMDT type AND its
> records in the same transaction throws an opaque `UNKNOWN_EXCEPTION`. Deploy the types first
> (steps 1–5), then the records (step 6) once the types physically exist in the org.

## 2. CMDT record deployment order
Deploy records only after their type + referenced Apex/objects exist:
1. `OA_Enrichment_Source` (precedence/trust) → 2. `OA_Connector_Registry` (references connector classes) →
3. `OA_Field_Write_Policy` (references Lead fields) → 4. `OA_Qualification_Rule` → 5. `OA_Enrichment_Pipeline`.
**All records ship `Enabled__c=false` / `Active__c=false` (dormant).** Activation is a later, per-connector decision.

## 3. Rollback plan
- **Metadata:** each deploy is a discrete Salesforce deployment ID → roll back by deploying the prior
  package (Git tag/commit). Objects/fields are additive; no destructive changes.
- **Data writes:** every enrichment write has a before-snapshot on `OA_Enrichment_Change_Log__c`;
  `OA_ChangeLogService.rollback(logs)` restores prior values. No enrichment runs until activation.
- **Kill switch:** flip the relevant `OA_Connector_Registry.<src>.Enabled__c` to false (dispatcher skips it).
- **Git:** platform lives on feature branches off `main` (`1a66832`); nothing merged/deployed yet.

## 4. Pre-deploy validation checklist
```
[ ] Org verified = 00Dbn00000plgUfEAI
[ ] Check-only validation SUCCEEDED (types+objects+Apex; records held for step 6)
[ ] 90%+ coverage; 0 test failures
[ ] No secrets in source (externalCredentials/ git-ignored; scan clean)
[ ] All CMDT sample records Enabled/Active = false
[ ] No scheduler/Queueable/Batch/trigger references the enrichment writer
[ ] meeting-tracking WIP + excluded files not in the package
```

## 5. Runtime user checklist (required before any live write)
```
[ ] Dedicated integration user (NOT a human admin)
[ ] Minimum Access profile (NO "Modify All Data" — MAD bypasses FLS and voids the field guardrail)
[ ] Full Salesforce license (Integration/Platform licenses cannot edit Lead)  ← BLOCKER: 0 spare licenses today
[ ] Enrichment permission set(s) assigned JIT (not standing)
[ ] FLS granted only on the trusted fields the write policies target
```

## 6. External Credential enablement checklist (keyed sources — SAM)
```
[ ] External Credential OA_SAM exists (Setup) with Principal + X-Api-Key AuthHeader (verified: yes)
[ ] Real API key entered in Setup ONLY (never in repo)
[ ] EC principal access granted to the runtime user via a permission set DEPLOY
    (SetupEntityAccess type ExternalCredentialParameter; NOT insertable via API; MAD does not substitute)
[ ] Rotation procedure documented; key rotated if ever exposed
```

## 7. Permission-set checklist
```
[ ] OA_<Source>_Connector permset: staging CRUD + FLS only; no Delete/ViewAll/ModifyAll
[ ] Unassigned at rest; JIT-assigned to the runtime user for a run; revoked after
[ ] Keyed sources: a separate permset carrying EC principal access (JIT)
```

## 8. Named Credential verification checklist
```
[ ] OA_USASpending — NoAuthentication, endpoint https://api.usaspending.gov (verified)
[ ] OA_SAM — SecuredEndpoint, EC OA_SAM, api-alpha.sam.gov (verified; X-Api-Key header present)
[ ] OA_Census / OA_SEC / OA_Grants — create secret-free NCs before enabling those connectors
[ ] Every connector callout routes via callout:<NC> (no hardcoded URLs, no key in URL)
```
