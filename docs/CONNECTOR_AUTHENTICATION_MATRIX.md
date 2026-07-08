# Connector Authentication Matrix

**Status:** Proposed (design only)
**Date:** July 7, 2026
**Owner:** Louis Rubino (lrubino@onealgorithm.com)
**Companion to:** [[AUTHENTICATION_FRAMEWORK]], [[ADR-013-LinkedIn-OAuth-Architecture]],
[[ADR-008-security-and-credential-standard]]

> Every connector — current and planned — classified against the five auth classes. Facts about
> already-built connectors are drawn from verified repo/org state; planned connectors are marked
> **Future**. No configuration is implied by this table; it is a design reference.

---

## 1. Authentication matrix (Task 5)

Legend: ✅ yes · ➖ no/NA · **Public** = keyless open data · **NC** = Named Credential · **EC** =
External Credential.

| Connector | Auth Type | Credential Storage | OAuth | API Key | Public | NC | EC | Webhook | Polling | Refresh Cycle | Risk | Recommended Pattern |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **LinkedIn** | OAuth 3-legged | EC (encrypted) | ✅ | ➖ | ➖ | ✅ `OA_LinkedIn` | ✅ | Future (Lead Sync) | ✅ | Access ~60d (auto) / Refresh ~365d (manual) | MED | Ext+Named Cred, Named Principal, Auth Code — **ADR-013** |
| **Meta** | OAuth 3-legged | EC (encrypted) | ✅ | ➖ | ➖ | Future `OA_Meta` | ✅ | Future | ✅ | Long-lived token ~60d; re-auth periodic | MED | Same as LinkedIn (ADR-013 template) |
| **Google** | OAuth 3-legged (+ JWT option) | EC (encrypted) | ✅ | ➖ | ➖ | Future `OA_Google` | ✅ | Future | ✅ | Access ~1h (auto) / Refresh long-lived | MED | Auth Code Named Principal; JWT service-account for server-to-server |
| **YouTube** | OAuth 3-legged (Google) | EC (encrypted) | ✅ | ➖ | ➖ | Future `OA_YouTube` | ✅ | Future | ✅ | Same as Google | MED | Google OAuth pattern (shares Google identity) |
| **GitHub** | OAuth / App token | EC (encrypted) | ✅ | ➖ | ➖ | Future `OA_GitHub` | ✅ | Optional (repo events) | ✅ | Token long-lived; app tokens short | LOW–MED | Auth Code or GitHub App; Ext+Named Cred |
| **QuickBooks** | OAuth 3-legged (Intuit) | EC (encrypted) | ✅ | ➖ | ➖ | Future `OA_QuickBooks` | ✅ | Optional | ✅ | Access ~1h (auto) / Refresh ~100d rolling | MED–HIGH | Auth Code Named Principal; **accounting scope is not read-only — enforce by discipline** ([[quickbooks-future-workstream-baseline]]) |
| **SAM.gov** | API Key (`X-Api-Key`) | EC (encrypted) | ➖ | ✅ | ➖ | ✅ `OA_SAM` | ✅ | ➖ | ✅ | Static key; rotate on schedule | MED | Ext+Named Cred, custom header — **already the standard** |
| **USASpending** | Public (keyless) | NC only | ➖ | ➖ | ✅ | ✅ `OA_USASpending` | ➖ | ➖ | ✅ | None | LOW | Named Cred, NoAuth |
| **Grants.gov** | Public (keyless) | NC only | ➖ | ➖ | ✅ | ✅ `OA_Grants` (dormant) | ➖ | ➖ | ✅ | None | LOW | Named Cred, NoAuth/Anonymous |
| **SEC (EDGAR)** | Public (User-Agent required) | NC only | ➖ | ➖ | ✅ | Future `OA_SEC` | ➖ | ➖ | ✅ | None (UA policy compliance) | LOW | Named Cred, NoAuth + required User-Agent header |
| **Census** | Public (keyless) | NC only | ➖ | ➖ | ✅ | Future `OA_Census` | ➖ | ➖ | ✅ | None | LOW | Named Cred, NoAuth |
| **IRS (Tax-Exempt EO BMF)** | Public bulk file (no callout) | NC optional / none | ➖ | ➖ | ✅ | N/A (bulk CSV) | ➖ | ➖ | ✅ (scheduled fetch) | None | LOW | Bulk ingestion behind connector interface; no auth |
| **Future AI providers** | API Key or Client Credentials | EC (encrypted) | ➖/✅ | ✅ | ➖ | e.g. `OA_Anthropic` | ✅ | ➖ | ✅ | Static key or app token | MED | Ext+Named Cred; key in EC only (never in object — cf. legacy debt) |

**Notes:**
- "Webhook" = whether the source *offers* real-time push worth adopting later; all are **polling-first** per ADR-013.
- OAuth refresh cycles are the single recurring maintenance item — tracked by `OA_HealthMonitor`.
- QuickBooks carries the platform's highest per-connector security note: its OAuth scope grants write
  access to accounting data; read-only must be enforced operationally, not by the token.

---

## 2. Technical-debt review — do existing connectors already follow the framework? (Task 6)

Classification: **Already Compliant** · **Minor Refactor** · **Major Refactor** · **Future Connector**.

| Connector / component | Current state (verified) | Classification | Gap to close |
|---|---|---|---|
| **SAM.gov** | Ext+Named Cred, `X-Api-Key` header, Named Principal, on connector SDK, dormant | **Already Compliant** | None on auth. Live-callout blocked only by EC principal-access grant (permset) — operational, not design. |
| **USASpending** | Refactored onto SDK in Wave 1; Named Cred, keyless, implements `OA_IEnrichmentConnector` | **Already Compliant** | None on auth. (Historical `OA_USASpendingClient` orphan superseded by the SDK connector.) |
| **Grants.gov** | Named Cred `OA_Grants` (NoAuth/Anonymous), keyless, dormant on feature branch | **Already Compliant** | None on auth. Endpoint verification + enrich() wrapper are functional TODOs, not auth debt. |
| **SEC (EDGAR)** | Connector built (Wave 2); public; **`OA_SEC` Named Credential not yet created**; needs required User-Agent header | **Minor Refactor** | Create `OA_SEC` Named Cred with User-Agent; no secret involved. |
| **Census** | Connector built (Wave 1); public; **`OA_Census` Named Credential not yet created** | **Minor Refactor** | Create `OA_Census` Named Cred (NoAuth); no secret. |
| **IRS (EO BMF)** | Bulk-CSV connector behind the interface; no callout, no auth | **Minor Refactor** | No auth gap. Needs the deferred async bulk orchestrator to schedule fetches — an ingestion, not auth, concern. |
| **OA_Anthropic (AI)** | Named Cred exists; **External Credential historically not committed to repo** (ADR-008 finding) | **Minor Refactor** | Commit/verify the EC so deploys are reproducible; confirm key lives only in EC. |
| **OA_Graph_Credential__c / OA_BookingPoller** (legacy Microsoft Graph) | Hand-rolled OAuth; **`Client_Secret__c` stored as plaintext Text in a custom object**; `getAccessToken` manages tokens manually; Remote Sites present | **Major Refactor** | The canonical debt ADR-008 targets: migrate to Ext+Named Cred, retire the secret fields, delete Remote Sites. Blocked historically by sandbox availability (TD-001). |
| **LinkedIn** | Not built; design ratified in ADR-013 | **Future Connector** | Build per ADR-013 (Ext+Named Cred, Named Principal, Auth Code). |
| **Meta / Google / YouTube / GitHub / QuickBooks** | Not built | **Future Connector** | Reuse the ADR-013 OAuth template; QuickBooks needs its own scope-discipline note. |
| **Future AI providers (beyond Anthropic)** | Not built | **Future Connector** | API-key or Client-Credentials via EC. |

**Summary read:** the *enrichment* connectors are already at or very near the standard (SAM,
USASpending, Grants = compliant; Census, SEC, IRS = minor, mostly "create the Named Credential").
The **only Major Refactor is the legacy Microsoft Graph credential** (`OA_Graph_Credential__c`
plaintext secret) — pre-existing ADR-008 debt, not introduced by this framework. Every OAuth
connector (LinkedIn onward) is greenfield and adopts the standard from day one.

---

## 3. What this means for sequencing

- **No auth rework is required to keep operating the v1.0 enrichment platform** — its connectors are
  compliant or one Named-Credential-creation away.
- **The framework's first real exercise is LinkedIn** (ADR-013), which validates the OAuth path end
  to end before Meta/Google/YouTube/GitHub/QuickBooks reuse it.
- **The one cleanup worth scheduling independently** is retiring `OA_Graph_Credential__c` — it is the
  last hand-rolled-secret in the platform and the reason ADR-008 exists.

See [[AUTHENTICATION_ROADMAP]] for how these fold into the four-phase evolution.
