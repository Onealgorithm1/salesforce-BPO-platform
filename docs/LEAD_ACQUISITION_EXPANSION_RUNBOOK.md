# Lead Acquisition — SAM Pilot Closeout & Supervised Expansion Runbook (Phase 18)

**Date:** 2026-07-08 · **Org:** `00Dbn00000plgUfEAI` (verified by ID) · **Branch:** `feature/lead-acquisition-sam-live-pilot`
**Mode:** live-org inspection + documentation only. **No deploy · no merge · no scheduling · no automation · no Lead/Account change.**
All facts below are from the **live production org** (source of truth), not repository inference.

---

## 1. Production verification (live)
| Metric | Value |
|---|---|
| Org ID | `00Dbn00000plgUfEAI` ✅ |
| Candidates (`OA_Discovered_Organization__c`) | **6** (unchanged; fusion updated, did not insert) |
| Leads | **13,301** (unchanged) |
| Accounts | **1** (unchanged) |
| Candidates `Needs Review` | 6 |
| SAM-fused candidates (CAGE now populated) | 2 (ORG-00011, ORG-00013) |
| Acquisition async jobs | **0** |
| Acquisition schedules (CronTrigger) | **0** |
| Connector registry | all 6 sources `Enabled__c=false` / `Draft` (SAM, USASpending, SEC, IRS, Census, StateRegistry) |

**No automation, no scheduling, connectors dormant.** The pilot ran as manual synchronous Apex.

## 2. SAM pilot closeout (evidence)
- **Credential fix:** `OA_SAM` EC gained a Custom Header `X-Api-Key` (raw data.gov key). Runtime permset `OA_SAM_Temp_Principal` assigned to `oauser`.
- **Smoke (read-only, 0 DML):** `GET /entity-information/v3/entities?ueiSAM=YA8LJBJCND19` → **HTTP 200**, 3,398-byte JSON.
- **Parser:** THE AEROSPACE CORPORATION · UEI `YA8LJBJCND19` · CAGE `12782` · 2310 E EL SEGUNDO BLVD, EL SEGUNDO, CA 90245 · https://aerospace.org · canonicalKey `UEI:YA8LJBJCND19` · payloadHash `c13a…bb965` · confidence HIGH.
- **First production cross-source fusion (USASpending × SAM), 2 updates / 0 inserts:**
  | Candidate | UEI | SAM filled | Completeness |
  |---|---|---|---|
  | ORG-00011 THE AEROSPACE CORPORATION | YA8LJBJCND19 | CAGE 12782, website, El Segundo CA 90245 | **23 → 47** |
  | ORG-00013 NATIONAL AEROSPACE SOLUTIONS LLC | KAA7ML3GU9A6 | CAGE 77SY4, Reston 20190 | **23 → 37** |
- **Fill-empty verified** (state CA/TN not overwritten); **provenance** in `Discovery_Metadata__c` (`sources:[{system:SAM,payloadHash,confidence:HIGH,fusedAt}]`); both stayed **Needs Review**; `Matched_Lead__c`/`Matched_Account__c` null.
- **No Lead/Account change; no automation; no schedule.** Pilot DML = 2 update rows on the candidate object only.

## 3. Housekeeping assessment (evaluate only — nothing performed)
| Item | Assessment | Verdict |
|---|---|---|
| Replace `OA_SAM_Temp_Principal` with a properly-named production permset (`OA_SAM_Connector`, carrying the EC principal grant) | Temp permset is a Sprint-31 test object; it *works* but is misnamed and mixes concerns. Acceptable for supervised pilots. | **Fix before volume** (🔴 permset + EC principal metadata + reassign, then retire temp) |
| Migrate raw `X-Api-Key` header value → hyphen-free `ApiKey` auth parameter + `{!$Credential.OA_SAM.ApiKey}` | Raw key is encrypted in the EC, not in metadata/URL/logs. Low-sensitivity revocable rate-limit key. Works today. | **Optional hygiene** before handoff/volume (🔴 EC change) |
| Is the current setup acceptable for **supervised** pilots? | Proven: HTTP 200, correct fusion, 0 unintended writes, dormant connector, no automation, bounded manual runs. | **YES** |
| What must be fixed before **volume / unattended** operation | (a) least-privilege runtime user — pilot runs as `oauser` (admin/MAD), the top standing operational risk; (b) proper permset (above); (c) org **Matching/Duplicate Rules** are empty scaffolds — identity resolution is Apex-only today; (d) **NAICS** not populated by SAM sections (completeness ceiling); (e) candidate **review dashboards/alerts** (analytics E4) + review staffing; (f) enqueue **cadence** design (queueable spacing, still no scheduler). | **Backlog before scale** |

## 4. Next connector recommendation (live evidence)
| Source | Live status | Credential | ICP fit | Verdict |
|---|---|---|---|---|
| **USASpending** | **HTTP 200**, 28 recipients for one term ("Aerospace"); idempotent (top-3 skipped as exact-dup) | **None** (public) | **High** — federal award recipients = the federal-contractor ICP | ✅ **RECOMMENDED NEXT** |
| SEC | **HTTP 200**, `wouldInsert=1` (RTX Corp, CIK 0000101829) | None (public) | Medium — large public filers, off the EDWOSB small-biz ICP | Good secondary |
| SAM | Done (enrichment proven) | data.gov key (configured) | High (enrichment, not discovery) | Complete |
| IRS | **Not viable** — connector has no `OA_IRS_Request` class (incomplete) | — | Low (tax-exempt orgs, off-ICP) | Skip |
| Census | Not an organization registry (aggregate business patterns) | — | None for entity discovery | Skip |
| StateRegistry | Template only (no concrete connector class) | — | TBD | Not built |

**Recommendation: USASpending.** It is the **discovery seed** for the exact population we want (federal contractors), is **live at HTTP 200 with breadth** (28 orgs for a single term), needs **no credential** (lowest-risk expansion — no EC/key gate like SAM), is **idempotent** (safe re-runs — proven by the 3 skips), and it **feeds the SAM enrichment pipeline just proven** (discover → fuse CAGE/address/website). SEC is a strong *follow-on* to add public-prime identity, but is narrower and off the small-business ICP.

## 5. Supervised USASpending expansion pilot — runbook
> Manual, gated, bounded. No scheduler, no automation. Writes only `OA_Discovered_Organization__c`.

- **Source:** `USASpending` (registry DeveloperName; class `OA_USASpending_Connector`; public API `/api/v2/search/spending_by_award/`).
- **Input strategy:** `recipient_search_text` term(s) aligned to the ICP (e.g., an EDWOSB-relevant recipient name or NAICS-adjacent keyword). Use terms/paging that surface **new** recipients (avoid the already-loaded Aerospace top-3). One term per supervised run.
- **Max Candidate impact:** `maxResults = 3` → **≤3 new candidates per run**, each `Needs Review`. New orgs `wouldInsert`; existing repeat as `skipped` (idempotent). No Lead/Account writes possible (service writes candidate object only).
- **Preview (0 DML):**
  ```apex
  OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run('USASpending', '<term>', false, 3);
  System.debug('parsed='+r.parsed+' wouldInsert='+r.candidates.wouldInsert+' fused='+r.candidates.fused
    +' dup='+r.candidates.duplicates+' skipped='+r.candidates.skipped);   // expect DML=0
  ```
- **Commit (≤3 writes):**
  ```apex
  OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run('USASpending', '<term>', true, 3);
  System.debug('inserted='+r.candidates.inserted+' fused='+r.candidates.updated+' committed='+r.candidates.committed);
  ```
- **Rollback (idempotent):** capture the inserted Ids from the run; `delete [SELECT Id FROM OA_Discovered_Organization__c WHERE Id IN :newIds]`. Fusion updates are reversible via the pre-run field snapshot (fill-empty only touched previously-null fields). No Lead/Account/automation to unwind.
- **Validation:** candidate count delta ≤3; new rows `Source_System__c='USASpending'`, `Qualification_Status__c='Needs Review'`, `Matched_Lead__c`/`Matched_Account__c` null; Leads 13,301 & Accounts 1 unchanged; 0 async jobs; 0 schedules; connector `Enabled__c` still false.
- **Review-queue verification:** confirm new candidates surface in the review view as `Needs Review` with `Recommended_Action__c`/`Qualification_Reasons__c` populated; optionally SAM-enrich each new UEI via the proven fusion path (`run('SAM', <uei>, true, 3)`).

## 6. Governance
Doc-only sprint on `feature/lead-acquisition-sam-live-pilot`. No deploy, no merge. Live production unchanged this sprint (6 candidates / 13,301 leads / 1 account; 0 async; 0 schedules; connectors dormant). Standing changes remain from Phase 17b (SAM EC Custom Header; `OA_SAM_Temp_Principal` assigned).

## 7. Verdict — 🟢 PASS
SAM pilot closed with evidence; housekeeping assessed (nothing unsafe performed); next connector (USASpending) recommended on live evidence; supervised runbook prepared. No scheduling, no automation, no Lead/Account change, no merge.

**Next approval gate (Louis):** authorize a supervised **USASpending** discovery pilot (≤3 new candidates, preview→commit) using an ICP-aligned term — or first approve the pre-volume housekeeping (least-priv permset + runtime user). Nothing runs until you approve.
