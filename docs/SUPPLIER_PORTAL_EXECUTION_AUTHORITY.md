# Supplier Portal Execution Authority & Cloud Automation Certification (Program 023E)

**Org 00Dbn00000plgUfEAI (verified) · Branch feature/supplier-portal-execution-authority · 2026-07-09**
**Certification only — no production changes, deployments, merges, bid submissions, portal modifications, or scraping.** Grounded in LIVE, read-only evidence.

## 1. Executive Summary
**Can the platform operate without Louis's computer/browser? Mostly yes — with a clean split proven by evidence.**
- **Cloud-native (runs with Louis's PC OFF, no Chrome):** authoritative APIs (SAM.gov, Grants.gov, USASpending) and commercial aggregators (HigherGov/GovTribe) via **Salesforce Apex + Named Credentials + Scheduled Apex**, plus **email intake** via **app-only Microsoft Graph**. This layer detects, parses, normalizes, compliance-screens, scores (OI), and queues opportunities server-side — **no browser, no local PC**.
- **Browser-session-only (cannot be cloud-executed):** **Bonfire/Euna** authenticates with an **httpOnly session cookie** — LIVE evidence shows **no bearer token/JWT in storage and no auth cookie visible to JavaScript**, so the session **cannot be extracted or replicated by Salesforce**. Bonfire's API works only inside an authenticated browser. Its opportunities still reach the cloud **by email** (Bonfire emails invitations), so the cloud can **detect + triage** them via Graph even when the PC is off; the **document pull from buyer subdomains** remains browser-assisted (local) or human.
- **Human-only (never automated):** bid submission, question submission, pricing, any binding portal action.
**Two gated unlocks** make the cloud layer real: an **app-only Graph Named Credential** (cloud email intake) and the **SAM data.gov key** (cloud federal ingestion). With those, the acquisition engine runs unattended in the cloud for discovery→qualification→compliance→OI→review; only portal document retrieval and submission stay browser/human.

## 2. Production Audit (exact evidence)
- Org 00Dbn00000plgUfEAI ✓. Connector SDK, review queue `OA_Opportunity_Signal__c`, `OA_ComplianceScreen`, Knowledge Foundation, Opportunity Intelligence, AI Gateway (OpenRouter), Salesforce Files — present.
- Named Credentials: OA_Anthropic, OA_Census, OA_HdrEcho*, OA_LinkedIn, OA_Meta, OA_OpenRouter(+×2), OA_SAM, OA_SEC, OA_USASpending, OpenAI. **No Microsoft Graph / SAM_Opportunities / Grants NC.** (*delete OA_HdrEcho.)
- **0 scheduled jobs** (governance clean) but **5 Schedulable Apex classes exist** → scheduled cloud execution is available, not activated.
- **Microsoft Graph = LOCAL-ONLY today** (WAM SSO as lrubino on Louis's PC; no Graph NC in Salesforce) → cloud email requires an app-only Graph credential.
- 30 open PRs.

## 3. Execution Authority Matrix
| Source / capability | Where it runs | PC off? | No Chrome? | No local PS? | Scheduled? | Cloud connector? |
|---|---|---|---|---|---|---|
| **SAM.gov / Grants.gov / USASpending** (APIs) | **Salesforce Apex + Named Cred** | **Yes** | **Yes** | **Yes** | Yes (Scheduled Apex) | **Yes** |
| **HigherGov / GovTribe** (aggregator APIs / MCP) | Salesforce Apex + Named Cred (or AI Gateway/MCP) | **Yes** | **Yes** | **Yes** | Yes | **Yes** (subscription) |
| **Email intake** (Bonfire/portal invitation emails) | **App-only Microsoft Graph** (needs Graph NC) | **Yes** | **Yes** | **Yes** | Yes | **Yes** *(after Graph NC)* |
| **Bonfire/Euna portal API** (`projectInvites`, docs) | **Browser session only** (httpOnly cookie) | **No** | **No** | n/a | No | **No** |
| **Local PowerShell Graph** (current lrubino WAM) | Louis's PC | **No** | Yes | No | No | No |
| **Document extraction** | Salesforce AI Gateway (+ optional cloud sidecar) | **Yes** | **Yes** | **Yes** | Yes | **Yes** |
| **Compliance / OI / review queue** | Salesforce | **Yes** | **Yes** | **Yes** | Yes | **Yes** |
| **Bid submission** | Portal + human | n/a | n/a | n/a | never | **never** |

## 4. Supplier Portal Admin Access (Bonfire/Euna — live, read-only)
| Capability | Access channel | Cloud-executable? |
|---|---|---|
| Vendor/org profile, business description, address | **Authenticated API** (`vendors/me`) | No (browser cookie) |
| Commodity/keyword management (`keywords`,`excludedKeywords`) | **Authenticated API** (`vendors/me`) | No |
| Notification settings (`isOptedInToNotifications`) | Authenticated API | No |
| Invitation history / dashboard counters (Invitations/WIP/Submitted/Awarded/Contracts) | Authenticated API (`projectInvites`) + portal | No (but **email mirror = cloud**) |
| Watchlists / opportunity tracking | Portal UI | No |
| Submitted bids / drafts / award notices / Q&A / download history | Portal UI (authenticated) | No |
All Bonfire admin data is **authenticated-browser only** (no public API, httpOnly cookie). Read-only certified; no settings changed.

## 5. Bonfire/Euna Lifecycle Certification (PASS/WARN/FAIL by role)
- **Production cloud connector: FAIL** — httpOnly cookie session, no storable token → not callable from Salesforce/cloud; automated third-party access is ToS-sensitive.
- **Browser-assisted export source: PASS** — authenticated session (local browser) reliably returns full opportunity JSON (`projectInvites`) + profile (`vendors/me`); documents on `{buyer}.bonfirehub.com/opportunities/{id}` (stable path; buyer-subdomain access control; some public, full after invite acceptance).
- **Email reconciliation source: PASS** — Bonfire emails invitations → cloud-readable via Graph → detect/triage without a browser.
- **Manual review source: PASS.**
**Documents:** visible + individually downloadable in the authenticated portal; packages via portal; amendments as addenda (portal + email notice); links are buyer-subdomain, session-gated (not open signed URLs); retrieval **requires a browser session** (cannot be cloud-executed).

## 6. Invitation Ingestion Workflow (automation level)
Invitation email/portal → **[cloud] detect (Graph email or portal export)** → **[cloud] identify portal + buyer (sender domain / `organization.domain`)** → **[cloud] extract project + dates** → document retrieval **[cloud for SAM/Grants; browser/human for Bonfire]** → **[cloud] normalize candidate (`OA_Opportunity_Signal__c`)** → **[cloud] compliance go/no-go** → **[cloud] Opportunity Intelligence** → **[cloud] human review queue (Pending)** → **[human] decision: pursue/reject/team/monitor**. Everything through the review queue is cloud-automatable **except** Bonfire document pull (browser) and the final decision (human).

## 7. Public Solicitation Discovery Workflow (no invitation — Question D)
| Source | Public search (no invite)? | Filters | Cloud? |
|---|---|---|---|
| **SAM.gov** | **Yes** | NAICS, PSC, set-aside, state, agency, keyword, dates | **Yes (API)** |
| **Grants.gov** | **Yes** | keyword, agency, category, dates | **Yes (API)** |
| **HigherGov / GovTribe** | **Yes** (cross-portal incl. SLED) | NAICS/PSC/keyword/geo/agency | **Yes (API/MCP)** |
| **Bonfire buyer portals** | public opp pages exist per buyer; "Agency Explorer" to find agencies | per-buyer | **browser-assisted** |
| **Individual SLED portals** | usually require registration to bid | — | register → then email/aggregator |
**Answer:** If a state doesn't invite us, the platform **can still discover its solicitations via federal APIs + aggregators (cloud)**, recommend whether to **register** (registration task), and monitor after registration (email + aggregator). Per-portal public browsing (Bonfire Agency Explorer) is browser-assisted.

## 8. Cloud Runtime Architecture Options
| Option | Automates | Cannot | Credentials | Risk | PC-off | Browser-dep | Prod-ready |
|---|---|---|---|---|---|---|---|
| **A. Salesforce-only** | federal/aggregator APIs, extraction, compliance, OI, review | email intake, portal docs | Named/External Creds | low | **Yes** | No | high (APIs) |
| **B. Salesforce + Graph (app-only)** | A + **email intake** (invitation detection) | portal-session docs | + Graph app cert | low-med | **Yes** | No | high |
| **C. Salesforce + cloud worker (headless browser)** | B + portal-session pulls (Bonfire) | binding actions | + portal creds in vault | **med-high (ToS/fragile)** | **Yes** | emulated | med (risky) |
| **D. Salesforce + commercial aggregator** | A + broad SLED discovery incl. invites-not-needed | portal-session docs | + aggregator key | low | **Yes** | No | high |
| **E. Local PowerShell / browser only** | portal-session export (Bonfire) | anything when PC off | local WAM/session | low | **No** | **Yes** | low (dependent) |

## 9. Recommended Cloud Architecture — **B + D (+ E only for portal docs)**
**Salesforce (Apex + Named Credentials + Scheduled Apex) as the cloud engine, + app-only Microsoft Graph for email intake, + a commercial aggregator (HigherGov/GovTribe) for SLED discovery.** This runs the full discovery→qualification→compliance→OI→review pipeline **unattended in the cloud, PC off, no browser**. Use **browser-assisted export (local, Option E)** *only* for Bonfire buyer-subdomain document pulls, and **humans** for submission. Avoid Option C (cloud headless browser against Bonfire) unless a sanctioned agreement exists — ToS/fragility risk.

## 10. Go/No-Go Automation Design
`OA_ComplianceScreen` + Knowledge + OI, inputs: metadata, documents (AI-extracted), buyer/agency, NAICS/PSC, set-aside, place of performance, due date, required certs, past-performance + partner requirements, complexity, value, timeline, capability match. Outputs **GO / NO-GO / TEAMING / MONITOR / REVIEW REQUIRED** + rationale + missing requirements + **document citations** (checksum/URL) + confidence + next action + **human approval checkpoint**. Deterministic scoring; AI explains; human decides. Cloud-executable.

## 11. End-to-End Bid Lifecycle Model
Discovered [cloud] → Documents captured [cloud API / browser portal] → AI extraction [cloud] → Compliance [cloud] → OI [cloud] → **Go/No-Go [cloud rec → human decide]** → Capture owner assigned [cloud/human] → Questions tracked [human submits in portal] → Amendments tracked [cloud detect + human] → Proposal tasks [cloud create, human author] → Submission checklist [cloud] → **Human submits in portal** → Receipt tracked [portal→cloud] → Award monitored [portal/email→cloud] → Converted/closed [Salesforce]. **No automatic submission/questions/legal commitments.**

## 12. Salesforce vs Portal System-of-Record
**Portal/agency:** official solicitation, amendments, submission, receipt, award. **Salesforce:** the pursuit (discovery, intake, qualification, compliance, knowledge, documents-with-provenance, OI, review, assignments, tasks, proposal planning, portal-status tracking, amendment tracking, submission readiness, award tracking). **Email (Graph):** notification/reconciliation + cloud invitation detection. **Human:** every binding decision.

## 13. What works if Louis's computer is OFF
Federal + aggregator API ingestion, document extraction, compliance, OI, review-queue population, dashboards, go/no-go recommendations, **and email-based invitation detection** — *provided* the app-only Graph NC and SAM key exist, and scheduled Apex is approved. Everything except portal-session document pulls and submission.

## 14. What requires a browser session
Bonfire/Euna portal API (`projectInvites`, `vendors/me`) and buyer-subdomain **document downloads** — httpOnly cookie, browser-only (local Option E, or a sanctioned cloud worker).

## 15. What can run inside Salesforce
API connectors (SAM/Grants/USASpending/aggregators), normalization, dedup, compliance, OI, review queue, Files storage, AI extraction, dashboards, scheduling, audit logging, retry — all Apex/Named-Cred/Scheduled.

## 16. What requires external middleware
**App-only Microsoft Graph** (cloud email intake — currently no NC) and optionally a **cloud document-extraction sidecar** (Apache-2.0) and a **sanctioned headless-browser worker** if Bonfire portal pulls must be cloud (not recommended).

## 17. Requires human approval
Go/No-Go, teaming commitment, portal question submission, proposal sign-off, registration decisions.

## 18. Should never be automated
**Bid submission, pricing commitment, question submission, any binding portal action, credential/2FA bypass.**

## 19. Portal-by-Portal PASS/WARN/FAIL (cloud connector view)
SAM.gov **PASS** · Grants.gov **PASS** · USASpending **PASS** · HigherGov/GovTribe **PASS** · **Bonfire/Euna FAIL (cloud connector) / PASS (browser-export + email)** · BidNet **WARN** (paid API) · OpenGov/Ion Wave/Vendor Registry **WARN** (email/export) · Jaggaer/Ivalua/Oracle/Coupa/Ariba **WARN/FAIL** (buyer-side/portal → aggregator). **Submission everywhere: human-only.**

## 20. Risks
Bonfire httpOnly session (no cloud path → browser/email only); ToS if headless-browser-automated (avoid); Graph app-only cert = new secret to secure; SAM rate cap/no-modified-date; scheduled unattended AI needs governance approval; document redistribution (store-not-redistribute); over-automation of submission (hard-blocked).

## 21. Technical Debt
Delete OA_HdrEcho; create app-only Graph NC; provision SAM data.gov key; least-priv runtime user; activate 5 Schedulable classes (gated); merge/close 30 open PRs; dashboards.

## 22. Blockers
1. **App-only Microsoft Graph Named Credential** (client-credentials + admin consent + cert) — *Louis/admin* — unblocks cloud email intake. 2. **SAM data.gov key + `OA_SAM_Opportunities` NC** — *Louis*. 3. **Aggregator subscription/key** (HigherGov free / GovTribe) — *Louis*. 4. **Scheduled-job approval** (unattended cloud) — *Louis*. 5. Deploy/merge approvals.

## 23. Decisions Louis Must Make
Provision app-only Graph credential; provision SAM key; choose aggregator; approve scheduled cloud execution; approve merges/deploys; decide whether a cloud headless-browser worker for Bonfire is ever acceptable (recommend **no** — use email + local export).

## 24. Decisions Claude Can Execute
Build Grants.gov cloud connector (public); build SAM/aggregator/Graph NC **skeletons** (Louis adds secrets); wire OCDS-normalized signals + compliance + OI (dormant); write scheduled-Apex (inactive until approved); browser-assisted Bonfire export on demand (local); dashboards; delete OA_HdrEcho.

## 25. Exact Next Engineering Program
**024 — Cloud Federal Ingestion + Email-Intake Foundation:** (a) activate **Grants.gov** cloud connector now (no secret); (b) build **`OA_SAM_Opportunities` + app-only Graph NC skeletons** (Louis supplies secrets); (c) app-only-Graph **email-intake classifier** to detect portal/Bonfire invitations server-side; all → OCDS-normalized review queue + compliance + OI, **human-gated, no submission, scheduling gated**. This makes the platform run PC-off for discovery/triage.

## 26–28. Repository / Commit / PR — `docs/SUPPLIER_PORTAL_EXECUTION_AUTHORITY.md` · commit + PR below.

## 29. Final Executive Recommendation
Run the acquisition engine **in the cloud on Salesforce (Apex + Named Credentials + Scheduled Apex) + app-only Microsoft Graph (email intake) + a commercial aggregator** — this operates **with Louis's computer off and no browser** for discovery, qualification, compliance, opportunity intelligence, and review-queue population, including **detecting Bonfire/portal invitations by email**. Treat **Bonfire's portal API as browser-session-only** (proven httpOnly cookie) — use **local browser-assisted export** for its document pulls, never a cloud connector — and keep **bid submission strictly human and portal-only**. The two credentials that flip this from "local/manual" to "cloud-autonomous" are an **app-only Graph credential** and the **SAM data.gov key**; everything else is already built or Claude-executable. **Verdict: PASS.**
