# Opportunity Source Matrix

_Design assessment · 2026-07-07 · Opportunity Intelligence (Program 2) · **no live API calls made this sprint** — characteristics from public documentation & prior connector experience; verify each during its build slice._

## Summary matrix
| # | Source | Opportunity type | API? | Auth | Refresh | Scoring value | Complexity | Priority |
|---|---|---|---|---|---|---|---|---|
| 1 | **SAM.gov Contract Opportunities** | Federal contracts / solicitations | ✅ REST (get-opportunities v2) | **data.gov API key** (header) | Daily | ⭐⭐⭐⭐⭐ | Medium | **P1 (first slice)** |
| 2 | **Grants.gov** | Federal grants | ✅ REST/Search2 (public) | None (public) | Daily | ⭐⭐⭐⭐ | Low–Med | P2 |
| 3 | **SBIR/STTR (SBIR.gov)** | Small-business R&D awards/topics | ✅ REST (solicitations API) | None (public) | Weekly | ⭐⭐⭐⭐ | Low–Med | P2 |
| 4 | **NIH** | Grants/funding (NIH Reporter / Guide) | ✅ REST (RePORTER API) | None (public) | Weekly | ⭐⭐⭐ | Medium | P3 |
| 5 | **NSF** | Grants/funding | ✅ REST (award/funding API) | None (public) | Weekly | ⭐⭐⭐ | Medium | P3 |
| 6 | **DOE opportunities** | Grants/FOAs (EERE Exchange / Golden) | ⚠️ Partial API / HTML | Mixed | Weekly | ⭐⭐⭐ | High | P3 |
| 7 | **FedConnect** | Contract + grant notices | ⚠️ Limited/partner API | Registration | Daily | ⭐⭐⭐ | High | P4 |
| 8 | **State procurement portals** | State/local contracts | ❌ mostly no unified API (per-state HTML/portals) | Varies | Varies | ⭐⭐ | Very High | P4 (later) |

Legend: scoring value = usefulness for OA's go/no-go pipeline (EDWOSB/WOSB small-business federal focus).

## Per-source detail
### 1. SAM.gov Contract Opportunities — **P1**
- **API:** `get-opportunities` v2 REST (JSON). *Distinct from the SAM Entity API used by Lead Enrichment* — separate endpoint, its **own data.gov key**.
- **Auth:** data.gov `api_key`. Reuse the ADR-008 Named/External Credential pattern (new `OA_SAM_Opportunities` NC; do **not** reuse the entity NC blindly).
- **Key fields:** noticeId, title, solicitationNumber, fullParentPathName (agency), naicsCode, classificationCode (PSC), typeOfSetAside, placeOfPerformance, postedDate, responseDeadLine, award value (when present), uiLink.
- **Scoring value:** highest — directly feeds NAICS/set-aside/agency/value/deadline scoring for OA's core market.
- **Risks:** the SAM data.gov key work is historically unresolved (alpha vs prod, key validity); rate limits; large result volumes → paginate + dedupe by `noticeId`.
- **Complexity:** Medium (pagination, date windows, set-aside vocabulary mapping).

### 2. Grants.gov — **P2**
- **API:** Search2 REST (public, no key). Opportunity synopsis + detail.
- **Fields:** opportunityNumber, title, agencyCode, CFDA/AssistanceListings, category, postDate, closeDate, awardCeiling/Floor, eligibility.
- **Value:** strong for grant-seeking; already have a dormant Grants.gov staging prototype (`feature/grantsgov-lead-enrichment-staging`) to reuse.
- **Risks:** eligibility parsing; grants ≠ contracts (different pursuit workflow).

### 3. SBIR/STTR — **P2**
- **API:** SBIR.gov solicitations/topics REST (public).
- **Value:** high fit for a small R&D-capable firm; topic-level matching.
- **Risks:** topic taxonomy; agencies publish on varied cadences.

### 4–5. NIH / NSF — **P3**
- Public REST (NIH RePORTER; NSF award/funding APIs). Value moderate unless OA pursues research grants; medium complexity (large schemas).

### 6. DOE — **P3**
- EERE Exchange / Golden FOAs — partial API, some HTML scraping. Higher complexity/maintenance; defer.

### 7. FedConnect — **P4**
- Aggregates notices but limited public API; registration/partner access. Defer until P1–P3 proven.

### 8. State procurement — **P4 (later)**
- No unified API; per-state portals (many HTML). Very high complexity/maintenance; template-only, revisit after federal sources mature.

## Recommendation
Build **SAM.gov Contract Opportunities first** (P1) — highest scoring value for OA's federal small-business focus, a real REST API, and it exercises the full slice (fetch → signal → score → assessment). Grants.gov + SBIR next (public, low-auth). NIH/NSF/DOE/FedConnect/State later.
