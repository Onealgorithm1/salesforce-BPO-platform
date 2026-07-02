# Metadata Registry

**Version:** 0.1 (Proposed)
**Date:** July 2, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Status:** Proposed. Governed by [ADR-009](decisions/ADR-009-metadata-registry.md).

**Confidence labels:** every row below is `[Verified from source]` (from `git ls-files` on
2026-07-02) unless marked `[Unverified]` (org/runtime) or `[Proposed/Future]`. Runtime activation
state of any component is `[Unverified]` from the repository.

Authoritative inventory of committed platform metadata, by type and package layer. Complements
[`METADATA_CLASSIFICATION.md`](METADATA_CLASSIFICATION.md) (which governs layer assignment).

---

## 1. Apex classes `[Verified from source]`

### Layer 1 — `force-app` (OA-Core-Platform)
| Class | Test | Purpose |
|-------|------|---------|
| `OA_DripScheduler` | `OA_DripScheduler_Test` | Campaign enrollment gate (cohort `'Wave 1'`). |
| `OA_FollowUpScheduler` | `OA_FollowUpScheduler_Test` | Day 3/5/10 follow-up cadence. |
| `OA_SendGovernor` | `OA_SendGovernor_Test` | Daily cap, business-day/holiday gating. |
| `OA_EmailSender` | `OA_EmailSender_Test` | Sends campaign emails (Apex-invocable from Flow). |
| `OA_BookingPoller` | `OA_BookingPoller_Test` | Microsoft Bookings polling. **Duplicated — see §8.** |
| `OA_CommPreferenceService` | `OA_CommPreferenceServiceTest` | Communication preference service layer. |
| `OA_UnsubscribeEndpoint` | `OA_UnsubscribeEndpointTest` | Public unsubscribe endpoint. |
| `OA_UnsubscribeTokenService` | `OA_UnsubscribeTokenServiceTest` | Token issue/validate for unsubscribe. |
| `OA_UnsubscribeEventHandler` | `OA_UnsubscribeEventHandlerTest` | Platform-event handler for async unsubscribe. |
| `OA_USASpendingClient` | **none** | USASpending connector. **No test; zero callers — see §8.** |

### Layer 2 — `modules/marketing-automation` (OA-Marketing-Automation)
| Class | Test | Purpose |
|-------|------|---------|
| `OA_AISummaryService` | `OA_AISummaryService_Test` | Transcript → AI summary. |
| `OA_AISummaryQueueable` | `OA_AISummaryQueueable_Test` | Async bridge for AI summary. |
| `OA_ArtifactPoller` | `OA_ArtifactPoller_Test` | Meeting artifact (recording/transcript) polling. |
| `OA_ReplayBookingService` | `OA_ReplayBookingService_Test` | Replay/reprocess bookings. |
| `OA_BookingPoller` | `OA_BookingPoller_Test` | **Duplicate of the Layer 1 class — see §8.** |

> Coverage note: every class ships a test **except `OA_USASpendingClient`**. `[Verified from source]`

---

## 2. Triggers `[Verified from source]`
| Trigger | Location | Purpose |
|---------|----------|---------|
| `OA_UnsubscribeRequestTrigger` | `force-app` | Handles `OA_Unsubscribe_Request__e` platform events. |

## 3. Flows `[Verified from source]`
| Flow | Purpose | Committed status |
|------|---------|------------------|
| `OA_EDWOSB_Outreach_Sequence` | Post-enrollment Day-1 email; segment routing. | `<status>Active</status>` in source (org runtime `[Unverified]`; contradicts TD-003). |
| `OA_PostMeeting_Nurture` | Post-meeting nurture. | See file. |
| `OA_Reply_Detection` | Reply detection. | See file. |

> `lead_by_ramesh.flow-meta.xml` exists in the working tree but is **untracked** (not committed).

## 4. Custom objects, platform events, and settings `[Verified from source]`
| API name | Kind | Notes |
|----------|------|-------|
| `Lead` | Standard (custom fields) | Evergreen/campaign fields — see [Data Dictionary](EVERGREEN_DATA_DICTIONARY.md) §2. |
| `OA_Campaign_Settings__c` | Custom Setting (hierarchy) | Governor state (cap/sends/reset). |
| `OA_USASpending_Staging__c` | Custom Object | USASpending staging (19 fields). |
| `OA_Communication_Preference__c` | Custom Object | Preference state. |
| `OA_Communication_Preference_Audit__c` | Custom Object | Preference change audit. |
| `OA_Communication_Preference_Token__c` | Custom Object | Unsubscribe tokens. |
| `OA_Graph_Credential__c` | Custom Object | Graph OAuth creds (**plaintext fields — see [Security Baseline](SECURITY_BASELINE.md)**). |
| `OA_Unsubscribe_Request__e` | Platform Event | Async unsubscribe (`Token_Hash__c`, `Correlation_Id__c`, `Request_Metadata__c`). |
| `OA_Graph_Config__mdt` | Custom Metadata Type | Graph config (Campaign_Id, Graph_User_OID, Is_Enabled, Booking_Marker, Alert_Owner_Id). |

## 5. Named / External Credentials `[Verified from source]`
| Name | Type | Notes |
|------|------|-------|
| `OA_Anthropic` | Named Credential (SecuredEndpoint) | References `<externalCredential>OA_Anthropic</externalCredential>` — **but no External Credential metadata is committed** (gap; see §8). |
| — | External Credential | **None committed.** |

## 6. Remote Site Settings `[Verified from source]`
| Name | URL | Migration target |
|------|-----|------------------|
| `MicrosoftGraph` | `https://graph.microsoft.com` | Named/External Credential (Security Baseline). |
| `MicrosoftLogin` | `https://login.microsoftonline.com` | Named/External Credential. |
| `OA_USASpending` | `https://api.usaspending.gov` | Named Credential (Sprint 1C). |

## 7. Permission sets `[Verified from source]`
| Permission set | Purpose |
|----------------|---------|
| `OA_Campaign_Fields` | Campaign field access. |
| `OA_Marketing_Automation` | Marketing module access. |
| `OA_CommPreference_Admin` | Communication-preference admin. |
| `OA_Unsubscribe_Guest_Access` | **Minimal** guest access for the public unsubscribe endpoint. |

---

## 8. Registry-derived findings (for Technical Debt) `[Verified from source]`
1. **Duplicate `OA_BookingPoller`** in both `force-app` and `modules/marketing-automation` — layer-boundary violation; one should be canonical.
2. **`OA_USASpendingClient` has no test** — blocks CI deploy; orphaned (zero callers).
3. **`OA_Anthropic` Named Credential references a missing External Credential** — the External Credential metadata is not in the repo; deploys may fail or rely on an org-only object `[Unverified]`.
4. **Credential-in-object** — `OA_Graph_Credential__c` stores secrets as Text fields (see [Security Baseline](SECURITY_BASELINE.md)).
5. **Remote Sites vs. Named Credentials** — three Remote Sites remain; the standard is Named/External Credential.

These feed [`TECHNICAL_DEBT.md`](TECHNICAL_DEBT.md); numbers there should be reconciled.

---

## Related documents
- [ADR-009 — Metadata Registry](decisions/ADR-009-metadata-registry.md)
- [Metadata Classification](METADATA_CLASSIFICATION.md)
- [Canonical Data Model](CANONICAL_DATA_MODEL.md) · [Evergreen Data Dictionary](EVERGREEN_DATA_DICTIONARY.md)
- [Security Baseline](SECURITY_BASELINE.md) · [Technical Debt](TECHNICAL_DEBT.md)
