# Source Certification Matrix & Rankings (Program 023A)

Companion to `ENTERPRISE_CONNECTOR_ARCHITECTURE.md`. Certifies every realistic One Algorithm opportunity source and ranks by ROI. **Design only — no build/deploy.** Governance rule applied: API → SDK → Webhook → Export → RSS → File → browser-assisted (ToS-clean) → email → manual. Never scrape when a supported path exists.

## A. Certification matrix (integration path per source/platform)
Legend — Auth: none / key / OAuth / cert / membership. Path: the certified highest-governance method. ToS: A=automation allowed, M=membership/paid, ?=verify, N=no automation.

### Federal (authoritative APIs)
| Source | Official API | Auth | Path | Docs | Incremental | ToS | Recommendation |
|---|---|---|---|---|---|---|---|
| **SAM.gov** (all contract agencies: DoD/Army/Navy/AF, DLA, NASA SEWP, DOE, DOT, HHS, VA, EPA, USDA, Commerce, Interior, Justice, Treasury) | **Yes** — Get Opportunities v2 | key (data.gov) | **API** | attachment API/links | postedFrom/To cursor | A | **BUILD (code exists; NC+key gate)** |
| **Grants.gov** (all grant agencies incl. NIH/NSF/HHS/DOE/USDA) | **Yes** — search2 REST | none | **API** | package download | date cursor | A | **BUILD (code exists)** |
| **SBIR.gov** (SBIR/STTR) | Yes — solicitations API | none | API | links | date | A | Near-term |
| FedConnect | No public API | — | Email + portal | portal | — | ? | Reconcile only (mirrors SAM) |
| GSA eBuy / eOffer | eLibrary/OpenData APIs; eBuy holder-only | key/login | API (catalog) + portal | portal | — | ?/M | Catalog API only; eBuy = holder portal |

### State / Local (platform adapters — one build covers many portals)
| Platform | Portals | Supplier API? | Path | ToS | Recommendation |
|---|---|---|---|---|---|
| **BidNet Direct** (mdf) | many county/city (dominant in inbox: 131/10d) | **Paid API** + email | **API (paid)** or email | M | Near-term (paid) / email now |
| **Ivalua** | OhioBuys + states | buyer-side; supplier portal+email | Adapter + email | ? | Medium |
| **Bonfire** | municipal/higher-ed | limited; portal+email invites | Adapter (export) + email | ? | Medium |
| **Jaggaer** | PA + universities/states | buyer-side REST; supplier portal | Adapter + email | ? | Medium |
| **OpenGov (ProcureNow)** | many municipalities | limited public API; portal+email | Adapter + email | ? | Medium |
| **Ion Wave** | municipal/state | portal + email alerts | Email + export | ? | Medium |
| **SAP Ariba** | commercial + gov | **Ariba Discovery** alerts/API | API (membership) | M | Long-term |
| **Coupa / Oracle** | commercial + some gov | buyer-side; supplier portal | Portal + email | ? | Long-term |
| **Periscope / mdf (COMMBUYS)** | MA + others | buyer-side | Export + email | ? | Medium |
| **Vendor Registry** | county/city | registration + email notices | Email | ? | Low |

### Commercial aggregator
| Source | API | Path | Cost | Recommendation |
|---|---|---|---|---|
| **Deltek GovWin IQ** | Yes (subscription) | **API** | $$$ | Long-term coverage accelerator (federal+state+local in one) |

### Partner ecosystems (partner-intelligence, not opportunity intake)
| Partner | API | Auth | Path | Recommendation |
|---|---|---|---|---|
| Salesforce (PRM) | Yes | OAuth | API | Medium (→ Knowledge Foundation) |
| **Zendesk Partner** | Yes (REST) | token | **API** | Near/Medium (token gated) |
| AWS Partner Central | Yes | OAuth/role | API | Medium |
| Microsoft Partner Center | Yes | OAuth | API | Medium |
| Google / ServiceNow / Oracle / Cisco / Adobe / Red Hat | varies | OAuth/key | API where available | Long-term |

### Certifications / registrations (NO API → compliance calendar, never scrape)
| Body | API | Handling |
|---|---|---|
| SBA (EDWOSB/WOSB/8(a)/HUBZone) | reflected in SAM entity | renewal tracking + SAM entity check |
| WBENC · NMSDC · VA SWaM (SBSD) · NC HUB · NY VendRep · state cert systems | None (portal) | **compliance calendar** (deadline tracking); manual renewal |

## B. Connector Scorecard (1=poor … 5=excellent; Legal risk 1=high-risk … 5=safe)
| Source/Platform | Automation | Reliability | Completeness | Latency | Cost | Maint. | Legal | Biz value | Effort(low=better) | Overall |
|---|---|---|---|---|---|---|---|---|---|---|
| **SAM.gov API** | 5 | 5 | 5 | 5 | 5 | 4 | 5 | 5 | 5 | **★ 1** |
| **Grants.gov API** | 5 | 5 | 4 | 5 | 5 | 4 | 5 | 4 | 5 | **★ 2** |
| Email→authoritative reconcile | 4 | 4 | 3 | 5 | 5 | 4 | 5 | 5 | 4 | **3** |
| BidNet Direct API (paid) | 5 | 4 | 4 | 4 | 2 | 3 | 4 | 5 | 3 | 4 |
| SBIR.gov API | 5 | 4 | 3 | 4 | 5 | 4 | 5 | 3 | 4 | 5 |
| Ivalua/Bonfire/Jaggaer/OpenGov adapters | 3 | 3 | 4 | 3 | 4 | 2 | 3 | 4 | 2 | 6 |
| Zendesk/AWS/MS partner APIs | 4 | 4 | 3 | 4 | 4 | 3 | 5 | 3 | 3 | 7 |
| Deltek GovWin IQ | 5 | 5 | 5 | 4 | 1 | 3 | 4 | 5 | 3 | 8 (cost-gated) |
| Ariba Discovery | 4 | 4 | 3 | 4 | 2 | 2 | 4 | 3 | 2 | 9 |
| Cert bodies (calendar) | 2 | 5 | 2 | 3 | 5 | 4 | 5 | 4 | 4 | 10 (compliance, not intake) |

## C. Ranked roadmap (ROI tiers)
- **IMMEDIATE (build now — code exists, authoritative, ToS-clean, low effort):**
  1. **SAM.gov** — needs data.gov key + `OA_SAM_Opportunities` NC (gated secret). Covers all federal contract agencies.
  2. **Grants.gov** — public API, already built. Covers all federal grant agencies.
  3. **Email→SAM/Grants reconciliation** — turn inbox alerts into authoritative records.
- **NEAR-TERM (medium effort, high coverage):** BidNet Direct API (paid; dominant local coverage) · SBIR.gov · Zendesk Partner API (→ Knowledge Foundation).
- **MEDIUM-TERM (platform adapters, reused across many portals):** Ivalua (OhioBuys) · Bonfire · Jaggaer · OpenGov · Ion Wave · Periscope/COMMBUYS · AWS/MS Partner Center.
- **LONG-TERM (high cost/effort or niche):** Deltek GovWin IQ (paid accelerator) · Ariba Discovery · Coupa/Oracle supplier portals · remaining partner ecosystems · compliance-calendar automation.

## D. Coverage math (why this design wins)
- **2 API connectors** (SAM + Grants) → ~majority of **federal** opportunities across 20+ agencies.
- **~8 platform adapters** → dozens of **state/local** portals (config per instance).
- **1 paid aggregator** (GovWin/BidNet) → broad long-tail coverage without per-portal builds.
- **Outlook** → notification + reconciliation safety net for anything not yet connected.
- **Certifications** → compliance calendar, zero connectors.
Result: **~12 governed integrations + config** replace 100+ scrapers, with human approval as the only production gate.
