# Metadata Classification — One Algorithm BPO Platform

**Last updated:** June 19, 2026
**Status:** Pre-retrieval decision record
**Purpose:** Maps every known piece of org metadata to its target package directory.
             This document must be reviewed and approved BEFORE running any retrieval.
             It is the authoritative reference for where metadata lives in this repo.

---

## How to Use This Document

1. Before retrieval: verify every item below has a `TARGET` assigned.
2. During retrieval: use the manifest commands in Section 6.
3. After retrieval: use Section 5 (Post-Retrieval Audit) to split deferred items.
4. Anytime a new metadata item is created in the org: add it to this document.

---

## Classification Key

| Symbol | Meaning |
|--------|---------|
| `force-app/` | Core Platform — deployed to every client org |
| `modules/marketing-automation/` | Marketing Module — deployed to orgs using outreach automation |
| `clients/pbo/` | PBO-specific — One Algorithm internal only, never deployed to clients |
| `EXCLUDED` | Not retrievable or not ownable by this repo |
| `DEFERRED` | Target confirmed but cannot be isolated until post-retrieval audit |

---

## 1. Apex Classes (27 org-owned)

### Core Platform → `force-app/main/default/classes/`

| Class | Rationale |
|-------|-----------|
| `OA_EmailSender` | Generic email dispatcher; any module or client org could use it |
| `OA_EmailSender_Test` | Test class for above |

### Marketing Automation Module → `modules/marketing-automation/main/default/classes/`

| Class | Rationale |
|-------|-----------|
| `OA_DripScheduler` | Drives email drip cadence for EDWOSB outreach campaign |
| `OA_DripScheduler_Test` | Test class for above |
| `OA_FollowUpScheduler` | Schedules follow-up emails in outreach sequence |
| `OA_FollowUpScheduler_Test` | Test class for above |

### PBO Client Config → `clients/pbo/main/default/classes/`

| Class | Rationale |
|-------|-----------|
| `TestLinkCOACustomerToLMALicense` | ISV/LMA test — only valid because OA has LMA installed |
| `ChangePasswordController` | OA website Communities controller (Salesforce-generated) |
| `ChangePasswordControllerTest` | Test class for above |
| `CommunitiesLandingController` | OA website Communities controller (Salesforce-generated) |
| `CommunitiesLandingControllerTest` | Test class for above |
| `CommunitiesLoginController` | OA website Communities controller (Salesforce-generated) |
| `CommunitiesLoginControllerTest` | Test class for above |
| `CommunitiesSelfRegConfirmController` | OA website Communities controller (Salesforce-generated) |
| `CommunitiesSelfRegConfirmControllerTest` | Test class for above |
| `CommunitiesSelfRegController` | OA website Communities controller (Salesforce-generated) |
| `CommunitiesSelfRegControllerTest` | Test class for above |
| `ForgotPasswordController` | OA website Communities controller (Salesforce-generated) |
| `ForgotPasswordControllerTest` | Test class for above |
| `MicrobatchSelfRegController` | OA website Communities controller (Salesforce-generated) |
| `MicrobatchSelfRegControllerTest` | Test class for above |
| `MyProfilePageController` | OA website Communities controller (Salesforce-generated) |
| `MyProfilePageControllerTest` | Test class for above |
| `SiteLoginController` | OA website site controller (Salesforce-generated) |
| `SiteLoginControllerTest` | Test class for above |
| `SiteRegisterController` | OA website site controller (Salesforce-generated) |
| `SiteRegisterControllerTest` | Test class for above |

**Apex Class count check:** 2 (core) + 4 (marketing) + 21 (pbo) = **27 total** ✓

---

## 2. Apex Triggers (1 org-owned)

### PBO Client Config → `clients/pbo/main/default/triggers/`

| Trigger | Object | Rationale |
|---------|--------|-----------|
| `linkCOACustomerToLMALicense` | COA Customer | Ties ISV license records; requires LMA package (sfLma). Client orgs will not have LMA installed. Cannot deploy to clients. |

---

## 3. Flows (3 org-owned retrievable)

### Marketing Automation Module → `modules/marketing-automation/main/default/flows/`

| Flow | Status | Rationale |
|------|--------|-----------|
| `OA_EDWOSB_Outreach_Sequence` | Inactive | Primary outreach sequence — marketing module core functionality |
| `OA_Reply_Detection` | Active (v3) | Detects campaign email replies — marketing module reply handling |
| `lead_by_ramesh` | Active | Lead processing flow for campaign intake |

### EXCLUDED (not ownable)

| Flow | Reason |
|------|--------|
| `MHolt__Org_Expiration_Notification` | `MHolt` managed package namespace — cannot be retrieved or owned |

---

## 4. Custom Fields — Lead Object (22 org-owned)

### Confirmed Core → `force-app/main/default/objects/Lead/fields/`

| Field API Name | Type | Rationale |
|----------------|------|-----------|
| `Compatibility_Score__c` | Number | AI scoring output — cross-module, cross-client value |
| `Geography_Tier__c` | Picklist/Number | Geographic scoring — cross-module, cross-client value |

### Deferred — Pending Post-Retrieval Audit

| Item | Status |
|------|--------|
| Remaining 20 `OA_*` Lead fields | Currently retrieved via `Lead.*` wildcard into `force-app/`. After retrieval, audit each field API name. Campaign tracking fields (`OA_*` outreach/reply fields) should move to `modules/marketing-automation/main/default/objects/Lead/fields/`. See Section 5. |

---

## 5. Permission Sets (2 org-owned)

### Core Platform → `force-app/main/default/permissionsets/`

| Permission Set | Rationale |
|----------------|-----------|
| `OpenAI_Access` | Grants access to OpenAI Named Credential; applies to any module using AI callouts |

### Marketing Automation Module → `modules/marketing-automation/main/default/permissionsets/`

| Permission Set | Rationale |
|----------------|-----------|
| `OA_Campaign_Fields` | Grants campaign field access; specific to the marketing module outreach workflow |

---

## 6. Duplicate Rules (3 org-owned)

### Core Platform → `force-app/main/default/duplicateRules/`

| Rule | Rationale |
|------|-----------|
| `Lead.OA_Partner_Duplicate_Rule` | OA custom duplicate logic; foundational to data quality across all modules |
| `Contact.Standard_Rule_for_Contacts_with_Duplicate_Leads` | Standard data quality rule; not module-specific |
| `Lead.Standard_Rule_for_Leads_with_Duplicate_Contacts` | Standard data quality rule; not module-specific |

---

## 7. Matching Rules (4 org-owned)

### Core Platform → `force-app/main/default/matchingRules/`

| Rule | Rationale |
|------|-----------|
| `Lead.Standard_Lead_Match_Rule_v1_0` | Standard matching; core data quality |
| `Lead.OA_Partner_Duplicate_Match` | OA custom matching logic; used by duplicate rule above |
| `Contact.Standard_Contact_Match_Rule_v1_1` | Standard matching; core data quality |
| `Account.Standard_Account_Match_Rule_v1_0` | Standard matching; core data quality |

---

## 8. Static Resources (6 org-owned)

### PBO Client Config → `clients/pbo/main/default/staticresources/`

| Resource | Rationale |
|----------|-----------|
| `construction` | OA website "under construction" page asset |
| `onealgo` | OA brand asset package |
| `OnealgorithLogo` | OA corporate logo |
| `leaflet` | JavaScript mapping library; used only by `worldMap` LWC (OA website component) |
| `SiteSamples` | Salesforce-provided site template samples, installed with OA site |
| `SNA_kMhXn_sf_default_cdn_One_Algorithm1` | Auto-named OA CDN static resource (Salesforce site builder managed) |

**Note:** `leaflet` is a third-party JS library dependency of `worldMap`. Since `worldMap` is PBO-specific, `leaflet` follows it to `clients/pbo/`.

---

## 9. Lightning Web Components (7 org-owned)

### PBO Client Config → `clients/pbo/main/default/lwc/`

| Component | Rationale |
|-----------|-----------|
| `contactform` | OA website contact form — carries OA branding and routing |
| `contactFormNew` | Updated version of above |
| `worldMap` | OA website world map visualization (depends on `leaflet` static resource) |
| `customheader` | OA website branded header |
| `policy` | OA website policy/legal page component |
| `serviceAccordion` | OA website services section — OA-specific service descriptions |
| `oneAlgorithmLanding` | OA website landing page component — unmistakably OA-branded |

**Decision note:** Although `contactform` and `serviceAccordion` could be argued as generic patterns, all 7 LWC bundles embed OA-specific logic, routes, or branding. None would be deployable to a client org without modification. All classified as PBO.

---

## 10. Visualforce Pages (24 org-owned)

### PBO Client Config → `clients/pbo/main/default/pages/`

All 24 pages are standard Salesforce Communities/Site template pages, auto-created when the OA public site was provisioned. They are paired with the Communities/Site Apex controllers classified under PBO above.

| Page | Notes |
|------|-------|
| `AnswersHome` | Standard community page |
| `BandwidthExceeded` | Standard error page |
| `ChangePassword` | Standard auth page |
| `CommunitiesLanding` | Standard community page |
| `CommunitiesLogin` | Standard auth page |
| `CommunitiesSelfReg` | Standard self-registration page |
| `CommunitiesSelfRegConfirm` | Standard self-registration page |
| `CommunitiesTemplate` | Standard community layout |
| `Exception` | Standard error page |
| `FileNotFound` | Standard error page |
| `ForgotPassword` | Standard auth page |
| `ForgotPasswordConfirm` | Standard auth page |
| `IdeasHome` | Standard community page |
| `InMaintenance` | Standard maintenance page |
| `MicrobatchSelfReg` | Standard self-registration page |
| `my_Test` | **Review for deletion** — likely a test/dev artifact |
| `MyProfilePage` | Standard community page |
| `SiteLogin` | Standard auth page |
| `SiteRegister` | Standard registration page |
| `SiteRegisterConfirm` | Standard registration confirmation |
| `SiteTemplate` | Standard site layout |
| `StdExceptionTemplate` | Standard error template |
| `Unauthorized` | Standard error page |
| `UnderConstruction` | Standard maintenance page |

**Post-retrieval action:** Evaluate whether the 24 standard site pages have been modified from Salesforce defaults. If unmodified, consider adding them to `.forceignore` and removing them from the manifest — they provide no source control value if stock.

---

## 11. Visualforce Components (4 org-owned)

### PBO Client Config → `clients/pbo/main/default/components/`

| Component | Rationale |
|-----------|-----------|
| `SiteFooter` | OA website site template footer |
| `SiteHeader` | OA website site template header |
| `SiteLogin` | OA website site login component |
| `SitePoweredBy` | Standard site template attribution component |

---

## 12. Email Templates (org-owned, count unconfirmed)

### Marketing Automation Module → `modules/marketing-automation/main/default/email/`

Email templates are folder-scoped — retrieved via `EmailFolder` + `EmailTemplate` wildcard in `package-marketing.xml`.

**Known issue (TD-007):** Day 3, Day 5, and Day 10 templates exist in two versions each (one in an active folder, one in a stale temp directory). Post-retrieval audit required.

**Post-retrieval action:** Identify and remove duplicate templates before first commit.

---

## 13. Metadata Not Yet Created (Planned)

| Metadata | Target | Phase |
|----------|--------|-------|
| `OA_AI_LeadScorer` (ApexClass) | `force-app/` | Phase 1–2 |
| `OA_AI_GeoClassifier` (ApexClass) | `force-app/` | Phase 1–2 |
| `OA_CLM_Contract__c` (CustomObject) | `modules/contract-lifecycle/` | Phase 3 |
| `OA_COMP_AuditRecord__c` (CustomObject) | `modules/compliance-automation/` | Phase 4 |
| `OA_AI_AgentSession__c` (CustomObject) | `modules/ai-agents/` | Phase 5 |
| `OA_GOV_BoardMeeting__c` (CustomObject) | `modules/governance/` | Phase 6 |
| OpenAI Named Credential | `force-app/` | Phase 1–2 |
| Agentforce agent configs | `modules/ai-agents/` | Phase 5 |

---

## 14. Metadata Excluded from This Repository

| Metadata | Reason |
|----------|--------|
| `MHolt__Org_Expiration_Notification` (Flow) | Managed package (MHolt namespace) |
| All CHANNEL_ORDERS__* metadata | Managed package |
| All sfcma__* metadata | Managed package |
| All sfLma__* metadata | Managed package |
| All sfFma__* metadata | Managed package |
| All KPIapp__* metadata | Managed package |
| `MobileConfig` | Not accessible via Metadata API (confirmed June 2026) |
| `EinsteinActivityCaptureSetting` | Not accessible via Metadata API (confirmed June 2026) |
| `sfdcInternalInt__*` permission sets | Platform-internal, not deployable |
| ~40 standard platform layouts | Auto-generated by Salesforce, not customized |

---

## Section 5: Post-Retrieval Audit Checklist

After running retrieval, complete these steps before the first commit:

### 5.1 Lead Custom Field Split

1. Open `force-app/main/default/objects/Lead/fields/`
2. List all 22 retrieved field files
3. For each field:
   - If name starts with `OA_` AND relates to campaign/outreach tracking → move file to `modules/marketing-automation/main/default/objects/Lead/fields/`
   - `Compatibility_Score__c` and `Geography_Tier__c` → stay in `force-app/`
4. Update `package-core.xml` to replace `Lead.*` with named field members for the 2 core fields
5. Update `package-marketing.xml` to add named `CustomField` members for all marketing fields

### 5.2 Email Template Deduplication

1. Open `modules/marketing-automation/main/default/email/`
2. Identify duplicate templates for Day 3, Day 5, Day 10 sequences
3. Confirm which version is active (cross-reference `OA_EDWOSB_Outreach_Sequence` flow logic)
4. Delete the stale versions from the filesystem before committing

### 5.3 VF Page Modification Check

1. For each of the 24 pages in `clients/pbo/main/default/pages/`
2. Check if any content differs from the standard Salesforce Communities/Site template
3. If a page is completely stock (no OA customization): add it to `.forceignore`
4. If a page has OA customizations: keep it in source control

### 5.4 my_Test VF Page

1. Review `clients/pbo/main/default/pages/my_Test.page`
2. This page name suggests it was a development test artifact
3. If it has no purpose: delete from org via Setup, remove from manifest

### 5.5 Communities/Site Apex Class Modification Check

1. The 20 Communities/Site Apex classes are Salesforce-generated boilerplate
2. Compare each class against the Salesforce default template
3. If completely unmodified from default: consider adding to `.forceignore`
4. If any OA-specific logic was added: keep in source control

---

## Section 6: Retrieval Command Reference

```bash
# Authenticate first (run once per session)
sf org login web --alias pbo-prod

# --- LAYER 1: Core Platform ---
# Retrieves into force-app/ (default package directory)
sf project retrieve start \
  --manifest manifest/package-core.xml \
  --target-org pbo-prod

# --- LAYER 2: Marketing Automation Module ---
# Retrieves into modules/marketing-automation/
sf project retrieve start \
  --manifest manifest/package-marketing.xml \
  --target-org pbo-prod \
  --output-dir modules/marketing-automation

# --- LAYER 3: PBO Client Configuration ---
# Retrieves into clients/pbo/
sf project retrieve start \
  --manifest manifest/package-pbo.xml \
  --target-org pbo-prod \
  --output-dir clients/pbo

# --- FULL BASELINE (all layers at once, into default dir for sorting) ---
# Use only for initial bulk retrieval; manually sort into layers afterward
sf project retrieve start \
  --manifest manifest/package-all.xml \
  --target-org pbo-prod
```

**WARNING before retrieval:**
1. Pause OneDrive sync (Settings → OneDrive → Pause syncing 2 hours)
2. Close all editors that have files in the repo open
3. Confirm no other processes are writing to the repo directory
4. Resume OneDrive sync only after retrieval completes and you have verified no conflict copies

---

## Manifest-to-Directory Cross-Reference

| Manifest | Target Directory | Retrieved With |
|----------|-----------------|----------------|
| `manifest/package-core.xml` | `force-app/` | Default (no `--output-dir` needed) |
| `manifest/package-marketing.xml` | `modules/marketing-automation/` | `--output-dir modules/marketing-automation` |
| `manifest/package-pbo.xml` | `clients/pbo/` | `--output-dir clients/pbo` |
| `manifest/package-all.xml` | `force-app/` (then sort) | Default; for initial baseline only |

---

## Classification Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-19 | `OA_EmailSender` → Core | Generic email utility; other modules will depend on it |
| 2026-06-19 | `OA_DripScheduler`, `OA_FollowUpScheduler` → Marketing | Campaign-specific schedulers; no value outside outreach module |
| 2026-06-19 | Communities/Site classes (20) → PBO | OA website infrastructure; not deployable to client orgs |
| 2026-06-19 | `linkCOACustomerToLMALicense` trigger → PBO | Requires LMA (sfLma) installed; client orgs will not have LMA |
| 2026-06-19 | All 6 static resources → PBO | OA branding and website assets; no client would receive these |
| 2026-06-19 | All 7 LWC bundles → PBO | OA website components; embed OA-specific branding and routing |
| 2026-06-19 | All 4 VF components → PBO | OA site template parts; tied to Communities site |
| 2026-06-19 | All 24 VF pages → PBO | Standard Communities/Site pages; tied to OA public site |
| 2026-06-19 | `OA_Campaign_Fields` → Marketing | Grants marketing field access; marketing-module-specific |
| 2026-06-19 | `OpenAI_Access` → Core | Integration access; applies to any AI-capable module |
| 2026-06-19 | All duplicate/matching rules → Core | Data quality applies org-wide and to all client orgs |
| 2026-06-19 | `MHolt__Org_Expiration_Notification` → EXCLUDED | Managed package namespace; not ownable |
| 2026-06-19 | `Compatibility_Score__c`, `Geography_Tier__c` → Core | AI scoring fields; cross-module, cross-client value |
| 2026-06-19 | Remaining OA_* Lead fields → DEFERRED | Cannot split Lead.* wildcard until field API names confirmed post-retrieval |
