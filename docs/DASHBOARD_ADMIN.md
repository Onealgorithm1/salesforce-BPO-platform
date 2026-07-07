# Administrator Dashboard — Lead Enrichment

_Design (build-ready, not deployed) · Sprint 27 · audience: admin · config/health, some panels are Setup/Tooling views, not report objects_

Folder: **"OA Enrichment — Admin"**. Refresh: on-demand + daily. Some items are Setup/Tooling reads (noted).

| # | Component | Type | Shows | Source |
|---|---|---|---|---|
| A1 | **Dormant vs Active** | Status | active policies (0), enabled connectors (0), scheduled jobs (0) | CMDT / CronTrigger |
| A2 | **Registry Status** | Table | 6 connectors: `Enabled__c`, `Status__c`, `Named_Credential__c` | `OA_Connector_Registry__mdt` |
| A3 | **Policy Status** | Table | 22 policies: field, `Write_Mode__c`, `Active__c` (0 active) | `OA_Field_Write_Policy__mdt` |
| A4 | **Named Credential Health** | Table | OA_USASpending (endpoint set), OA_SAM (alpha, needs principal access), OA_Census/OA_SEC (**not deployed**) | Tooling `NamedCredential`/`NamedCredentialParameter` |
| A5 | **Permission Status** | Table | `OA_Lead_Enrichment_Runtime` (1 assign = oauser), `OA_SAM_Connector` (0), `OA_Connector_Staging` (0) | `PermissionSetAssignment` |
| A6 | **Runtime User** | Tile | `oauser@pboedition.com` — **MAD exception (top risk)**; least-priv pending | manual/PermSet |
| A7 | **Platform Version** | Tile | `lead-enrichment-v1.1` (main a0c8bd0) | git/manual |
| A8 | **Deployment History** | Table | recent `DeployRequest` (Status, CheckOnly, tests) | Tooling `DeployRequest` |
| A9 | **Validation History** | Table | recent check-only validations (e.g. `0AfPn0000023Bk9KAE`) | Tooling `DeployRequest WHERE CheckOnly=true` |

**Admin CLI snippets** (for panels not backed by report objects):
- Registry: `sf data query -q "SELECT Source_System__c,Enabled__c FROM OA_Connector_Registry__mdt"`
- Policies: `... FROM OA_Field_Write_Policy__mdt`
- NC health: `sf data query -t -q "SELECT DeveloperName,Endpoint,PrincipalType FROM NamedCredential"`
- Deploy history: `sf data query -t -q "SELECT Id,Status,CheckOnly,NumberTestErrors,CreatedDate FROM DeployRequest ORDER BY CreatedDate DESC LIMIT 10"`

**Red flags to watch:** runtime permset assignment must stay = 1 (revoking hides fields — "No such column"); any connector `Enabled__c=true` or active policy when a run isn't authorized; Census/SEC NC still absent.
