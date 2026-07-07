# State & Diversity Certification Connectors — Design (Research Only)

_Status: **RESEARCH / DESIGN ONLY — no code** · 2026-07-06. Documents how FUTURE connectors will
enrich organizations with diversity/small-business certifications, on the frozen platform._

## Scope
Certifications that qualify a business for set-asides and supplier-diversity programs:
- **SWaM** (Virginia Small, Women-owned, Minority-owned)
- **HUB** (e.g. Texas Historically Underutilized Business; also federal HUBZone — distinct)
- **MBE** (Minority Business Enterprise) · **WBE** (Women's Business Enterprise)
- **DBE** (Disadvantaged Business Enterprise — USDOT/UCP, state-administered)
- **SDVOSB** (Service-Disabled Veteran-Owned — federal via SAM/VA; some state analogs)
- Other **state certifications** (per-state programs and directories)

## Data-source reality (why research first)
| Program | Typical source | Interface | Notes |
|---|---|---|---|
| SWaM (VA) | VA SBSD directory | Search UI; no stable public API | Likely UI/scrape-restricted → confirm ToS |
| HUB (TX) | TX CMBL/HUB directory | Search UI / downloadable lists | Bulk list possible |
| MBE/WBE | NMSDC / WBENC / state UCP directories | Mostly UI; some CSV | Fragmented; per-issuer |
| DBE | State UCP directories (per state) | UI + periodic CSV | Bulk CSV is common → bulk pattern |
| SDVOSB | Federal via SAM.gov (already a SAM business type) | SAM API | **Already covered by the SAM connector** (socioeconomic certs) |
| SBA certs (8a/WOSB/EDWOSB/HUBZone) | SAM.gov / SBA DSBS | SAM API / DSBS UI | 8a/WOSB/HUBZone via SAM; DSBS has no clean API |

**Key finding:** the strongest, cleanest certification data (federal socioeconomic set-asides incl.
SDVOSB/WOSB/EDWOSB/8a/HUBZone) already arrives via the **SAM connector** (`Socioeconomic_Certifications`
attribute). Many STATE certification directories are **UI-only** or **bulk CSV**, not stable JSON APIs.

## How future certification connectors fit the frozen platform (no platform change)
Each certification source is just another connector:
- **REST/JSON directory** → `OA_Cert_<Issuer>_Request/ResponseParser/Mapper/Connector` implementing
  `OA_IEnrichmentConnector` (SAM/SEC pattern).
- **Bulk CSV directory** (common for DBE/HUB) → a bulk connector like **IRS** (parser + connector, no
  HTTP; an upstream importer feeds chunks).
- **UI-only** → **do NOT scrape**; defer until a sanctioned API/bulk feed exists (or use SAM where the
  cert is federal).

**Canonical mapping:** certifications become attributes on `OA_CanonicalOrg` (e.g.
`Certification_SWaM`, `Certification_MBE`, `Certification_DBE`, `Cert_Expiration`) and map to Lead cert
fields via `OA_Field_Write_Policy__mdt`. They feed the **Qualification Engine** ICP rules (e.g. "MBE
required") — reusing the existing engine, no new matching logic.

**Confidence / identity:** cert directories usually key by business name + state (state programs) or by
UEI (federal) → HIGH when a UEI/EIN is present, else MEDIUM. Cert connectors are enrichment sources,
not new identity sources.

## Recommendation
1. **Reuse SAM** for federal socioeconomic certs (SDVOSB/WOSB/EDWOSB/8a/HUBZone) — already built.
2. For state programs, prefer sources that publish **bulk CSV** (DBE/HUB) → the IRS bulk pattern.
3. **No code** until a target program with a stable public interface + acceptable ToS is selected;
   then it is a standard connector (Request/Parser/Mapper/Connector + metadata) with zero platform change.
