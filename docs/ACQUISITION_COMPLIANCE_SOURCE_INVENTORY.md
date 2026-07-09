# Enterprise Opportunity Acquisition & Compliance Intelligence — Certified Source Inventory

**Program 022 · Org 00Dbn00000plgUfEAI · 2026-07-09 · Branch feature/opportunity-acquisition-compliance-intelligence**
Organizes WHERE opportunities and compliance obligations come from, before Proposal Intelligence. Registry object: `OA_Acquisition_Source__c` (deployed; 10 top sources seeded live, remainder in the gated seed script).

## Governing rule
Do **not** scrape unless the access method + Terms of Service are **certified**. Prefer, in order: **API → Export → RSS/feed → Email intake → File download**. Web-UI-only sources are tracked but not scraped; their intelligence arrives via the **Outlook email channel** or manual review.

---

## KEY FINDING — Outlook email is the highest-leverage connector
Live read-only audit of `lrubino@onealgorithm.com` (Microsoft Graph `Mail.Read`, no write scopes), 400 messages over 2026-06-30 → 07-09:

| Classification | Count (10 days) |
|---|---|
| Solicitation/Bid | 123 |
| RFP | 18 |
| RFQ | 4 · RFI 1 | 
| Portal Alert | 22 |
| Partner/Teaming | 12 |
| Vendor Registration | 7 |
| Certification | 4 |
| Noise (newsletters) | 209 |

**≈146 opportunity emails in 10 days.** Most government portals already push to this mailbox, so a **single read-only email connector** captures the majority of sources with clean ToS — far cheaper than 40 scrapers.

**Top opportunity-producing sender domains (evidence):** `bidnet.com` (131) · `gobonfire.com` (10, Bonfire) · `fedconnect.net` (9) · `messages.dhs.gov` (8) · `nyscr.ny.gov` (6) · `pa.gov` (6) · `dms.myflorida.com` (5) · `nassaucountyny.gov` (5) · `cgieva.com` (4, eVA) · `ivalua.com` (OhioBuys) · `newnycontracts.com` (NY MWBE) · `nasasp.org`.
**Real partner/teaming (Partner Intelligence):** `stragistics.com` (teaming), `aps.pro` (DB subcontracting), `medianow.com`.

**Missing high-value sources discovered (NOT in the supplied list):** **BidNet Direct** (dominant, 131 emails), **Ivalua** (OhioBuys platform), **NASASP**, **NY New Contracts / MWBE (newnycontracts.com)**, **DHS notifications**.

---

## Certified source inventory

Legend — Produces: O=Opportunity, C=Compliance, R=Registration, P=Partner-Intel, A=Administrative. Access: API/Export/Email/RSS/Webhook/File/UI. Scrape: Y/N/?(unknown). Cert: Certified/Review/Uncertified.

### Federal
| Source | Produces | Access | Scrape | Cert | Priority |
|---|---|---|---|---|---|
| SAM.gov | O,R | **API** (data.gov key) | Y | Certified (connector built) | **P1** |
| Grants.gov | O | **API** (public) | Y | Certified (connector built) | P2 |
| FedConnect | O | Email + UI | ? | Review | P2 |
| GSA eOffer | R,O | UI only | N | Review | P3 |
| SBA Certify (sba.gov) | C | UI only | N | Review | P3 |
| DHS notifications | O,A | Email | ? | Review | P3 |

### State procurement
| Source | Jur | Produces | Access | Scrape | Priority |
|---|---|---|---|---|---|
| JAGGAER | PA | O | API/SaaS (supplier network) | ? | P2 |
| PA eMarketplace | PA | O | Email + UI | ? | P2 |
| PA DOS | PA | C,R | UI | ? | P3 |
| MyFloridaMarketPlace | FL | O | Email + UI | ? | P2 |
| NJSTART | NJ | O | Email + UI | ? | P2 |
| NJ Business | NJ | R | UI | ? | P3 |
| Delaware OSD / MyMarketplace | DE | O | UI | ? | P3 |
| COMMBUYS | MA | O | Email + UI | ? | P2 |
| Cal eProcure | CA | O | UI | ? | P3 |
| eVA (cgieva.com) | VA | O | Email + UI | ? | P2 |
| Virginia SBSD | VA | C,R | UI | ? | P3 |
| OhioBuys (Ivalua) | OH | O | Email + UI | ? | P2 |
| NC eVP | NC | O | UI | ? | P3 |
| NC SOS | NC | C,R | UI | ? | P3 |
| SFS eSupplier | NY | R | UI | ? | P3 |
| NY New Contracts / MWBE | NY | O,R | Email | ? | P2 |
| NYC PASSPort | NY | O,R | UI | ? | P2 |
| NYS Contract Reporter (NYSCR) | NY | O | Email + export | ? | P2 |
| RGRTA Supplier Portal | NY | R | UI | ? | P3 |
| NYSCR Registered Agent portal | NY | A | UI | ? | Defer |

### Local / county / aggregators
| Source | Produces | Access | Scrape | Cert | Priority |
|---|---|---|---|---|---|
| **BidNet Direct** | O | **Email Alert** (+paid API) | ? | Certified (email) | **P1** |
| Nassau County | O | Email + UI | ? | Review | P2 |
| SF City Partner | O,R | UI | ? | Review | P3 |

### Certification / diversity compliance
| Source | Produces | Access | Scrape | Priority |
|---|---|---|---|---|
| WBENC | C | UI | **N** | P3 |
| Prism Compliance / BDISBO | C | UI/portal | ? | P3 |
| Massachusetts Diversity Certification | C | UI | ? | P3 |
| SBA (EDWOSB/WOSB/8a) | C | UI | N | P3 |
| NASASP | R | Email + UI | ? | P3 |

### Vendor registration
Handled as R rows above (NJ Business, SFS eSupplier, RGRTA, GSA eOffer registration, NASASP). Track renewal/registration **deadlines** via email; no scraping.

### Partner / commercial / Zendesk
| Source | Produces | Access | Scrape | Cert | Priority |
|---|---|---|---|---|---|
| Bonfire | O | Email (+limited supplier API) | ? | Review | P2 |
| Zendesk Partner Portal | P | **API** (REST + token) | Y (API) | Review (needs token) | P2 |
| One Algorithm Zendesk help portal | A,P | **API** (REST + token) | Y (API) | Review (needs token) | P3 |
| Stragistics / aps.pro (partners) | P | Email | Y | Certified (email) | P2 |

### Email intake
| Source | Produces | Access | Scrape | Cert | Priority |
|---|---|---|---|---|---|
| **Outlook lrubino@onealgorithm.com** | O,C,R,P | **Graph API Mail.Read** (read-only) | Y | **Certified** | **P1** |

---

## Recommended phased connector roadmap
- **P1 (build first — highest coverage, cleanest ToS):**
  1. **Outlook Email Intake** — Graph `Mail.Read`, read-only classifier → normalize into the existing `OA_Opportunity_Signal__c` review queue (reuse ADR-015…019 pipeline + human gates). Captures BidNet, Bonfire, FedConnect, OhioBuys, Nassau, NYSCR, PA, MyFlorida, eVA in one governed channel.
  2. **SAM.gov Opportunities** — reuse the built connector (activate with data.gov key).
- **P2 (targeted APIs/feeds where they beat email):** Grants.gov (built) · JAGGAER supplier API · NYSCR export/feed · Zendesk Partner API (partner intelligence → Knowledge Foundation profiles) · Bonfire (email + verify supplier API).
- **P3 (compliance/registration deadline tracking, no scraping):** WBENC, SBA (EDWOSB), MA/VA diversity, NASASP, GSA eOffer — capture renewal/registration **deadlines** from email into a compliance calendar; manual portal action.
- **Defer:** UI-only administrative portals with no email/API (Registered Agent, RGRTA) — manual.

## Governance & safety
Email audit was **read-only** (no delete/archive/send/modify; scope `Mail.Read` only). No source is scraped. Every ingested signal flows through the existing human-gated review queue (ADR-018). Registry certifies access method + scraping status so connectors only consume approved channels. Zendesk/API sources need a token (secret) — **gated**, not created here.

## What was built
`OA_Acquisition_Source__c` registry (11 fields) + `OA_Acquisition_Source_Platform` permset (deployed, assigned). 10 P1/P2 sources seeded live; full inventory in `scripts/apex/seed_acquisition_sources.apex` (gated bulk write >10). No connectors built yet — this is the certified foundation they consume.
