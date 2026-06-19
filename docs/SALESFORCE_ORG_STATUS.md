# Salesforce Org Status — PBO Production

**Last assessed:** June 19, 2026
**Assessed by:** Claude Code via SF CLI
**Org ID:** 00Dbn00000plgUfEAI

---

## Users

| Name | Username | Profile | License | Status |
|------|----------|---------|---------|--------|
| Louis Rubino | oauser@pboedition.com | System Administrator | Salesforce | Active |
| Sreenivas | sreeni@onealgorithm.com | System Administrator | Salesforce | Active |
| Louis R (former) | louisrubino@onealgorithm.com | Min Access API Only | Salesforce | Deactivated June 19, 2026 |
| Chatter Expert | chatter_expert@... | Chatter Free | Chatter Free | Active (platform) |
| Insights Integration | insights@... | Insights Integration | Salesforce Integration | Active (platform) |

**License pool:** 2 Salesforce licenses (fully consumed by oauser + sreeni)
**Next action if 3rd user needed:** Purchase additional Salesforce license

---

## Installed Managed Packages

| Namespace | Package | Version | Purpose |
|-----------|---------|---------|---------|
| CHANNEL_ORDERS | Channel Orders App | — | Order management |
| sfcma | Checkout / CMA | — | Commerce/checkout |
| sfLma | License Management App | — | ISV license management |
| sfFma | Feature Management App | — | ISV feature flags |
| KPIapp | KPI Dashboard App | — | Reporting |

**Note:** These packages contain 504 Apex classes and 18 triggers. None are org-owned. None should enter this repository.

---

## Org-Owned Apex (27 classes, 1 trigger)

### Custom OA_ Classes
| Class | API Version | Purpose |
|-------|-------------|---------|
| OA_DripScheduler | 61 | Scheduled drip email sender |
| OA_DripScheduler_Test | 61 | Test class |
| OA_EmailSender | 61 | Core email send logic |
| OA_EmailSender_Test | 61 | Test class |
| OA_FollowUpScheduler | 61 | Follow-up email scheduler |
| OA_FollowUpScheduler_Test | 61 | Test class |
| TestLinkCOACustomerToLMALicense | 61 | ISV license link test |

### Communities/Site Classes (standard platform, low priority)
ChangePasswordController, CommunitiesLandingController, CommunitiesLoginController,
CommunitiesSelfRegConfirmController, CommunitiesSelfRegController, ForgotPasswordController,
MicrobatchSelfRegController, MyProfilePageController, SiteLoginController, SiteRegisterController
(+ Test counterparts for each)

### Org-Owned Trigger
| Trigger | Object | API Version |
|---------|--------|-------------|
| linkCOACustomerToLMALicense | (COA Customer object) | 61 |

---

## Flows (Unmanaged)

| Flow | Status | Last Version | Notes |
|------|--------|--------------|-------|
| OA_Reply_Detection | Active | v3 | Core reply detection for email campaigns |
| OA_EDWOSB_Outreach_Sequence | Inactive | — | Primary outreach sequence, currently deactivated |
| lead_by_ramesh | Active | — | Lead processing flow, 2 paused interviews |
| MHolt__Org_Expiration_Notification | Active | — | Org expiration alert |

**Note:** OA_EDWOSB_Outreach_Sequence is deactivated. Email is driven by OA_FollowUpScheduler Apex directly.

---

## Einstein Activity Capture

| Item | Status |
|------|--------|
| EAC org-level | Enabled |
| Microsoft Graph API | Enabled |
| Configuration | OA EDWOSB Outreach (ID: 063Pn0000043irpIAA) |
| Enrolled user | Louis Rubino (oauser@pboedition.com) |
| Connected mailbox | lrubino@onealgorithm.com |
| OAuth accepted | June 19, 2026 17:12 UTC |
| Email sync | Enabled, bidirectional |
| Event sync | Enabled, bidirectional |
| Contact sync | Enabled, bidirectional |
| StandardEinsteinActivityCapturePsl | 1/100 used |
| StandardEinsteinActivityCapture2Psl | 1/2 used |

---

## Custom Fields on Lead (22 org-owned)

Key fields:
- `Compatibility_Score__c` — AI scoring field (0% populated)
- `Geography_Tier__c` — Geographic scoring (0% populated)
- Additional OA_ prefixed campaign and outreach tracking fields

**Note:** AI scoring fields exist but the scoring layer has never been implemented. 13,286 leads with empty scores.

---

## LWC Components (7 org-owned)

contactform, contactFormNew, worldMap, customheader, policy, serviceAccordion, oneAlgorithmLanding

---

## Static Resources (6 org-owned)

construction, onealgo, OnealgorithLogo, leaflet, SiteSamples, SNA_kMhXn_sf_default_cdn_One_Algorithm1

---

## Permission Sets (Org-owned)

| Permission Set | Purpose |
|----------------|---------|
| OA_Campaign_Fields | Campaign field access for outreach users |
| OpenAI_Access | OpenAI integration access (implementation pending) |

---

## Known Issues / Technical Debt

1. **API version debt:** OA_ classes at v61, trigger at v61. Current org API: v67.
2. **OA_EDWOSB_Outreach_Sequence deactivated** — primary flow not running, Apex scheduler filling gap
3. **2 paused FlowInterviews** from lead_by_ramesh stuck at sending_email element
4. **AI scoring fields 0% populated** — scoring logic never built
5. **Duplicate email templates** — Day 3, Day 5, Day 10 exist in two versions each (stale temp dir)
6. **No sandbox environment** — changes go directly to production
7. **Former user (Louis R / louisrubino@onealgorithm.com) deactivated June 19, 2026**

---

## Connected Integrations

| App | Type | Status |
|-----|------|--------|
| Pipedream | OAuth | Active |
| Salesforce Integration for Zendesk | OAuth | Active |
| SfdcSIQActivitySyncEngine | OAuth | Active (EAC backend) |
| tbid.digital.salesforce.com | OAuth | Active (investigate) |
| OIQ_Integration | Connected App | Active (investigate) |
| PartnerTrial | Connected App | Active |
| Environment Hub | Connected App | Active |
