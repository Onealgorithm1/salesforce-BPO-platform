# Enterprise Evidence & Document Intelligence Foundation — Program 024C

**Org:** 00Dbn00000plgUfEAI (verified by ID) · **Branch:** feature/enterprise-evidence-document-intelligence
**Mode:** Engineering · **Verdict:** PASS · **Governance:** dormant, human-gated, 0 auto-Opportunities

---

## 1. Executive Summary

The platform has three governed *decision* layers (Compliance → Qualification → Pursuit Investment). They are only as good as the **evidence** they consume. Program 024C builds the **evidence foundation**: a framework that turns documents into structured, traceable, confidence-scored business intelligence.

**Strategic principle enforced in code:** *AI summarizes evidence; AI never replaces evidence.* Every extracted value is traceable to **source + document + checksum + confidence**. Nothing is a free-floating AI assertion — each record points to the actual file in Salesforce Files and records where it came from.

Two components, both dormant:
- **`OA_Knowledge_Document__c`** — the evidence model (25 fields). Points to a `ContentDocument` (never duplicates storage); links evidence to Opportunity Signal / Company Profile / Acquisition Source; carries the full extracted-evidence set + provenance + confidence + review status.
- **`OA_DocumentIntelligence`** — `ingest()` (checksum + dedupe + provenance + linkage) and `extract()` (AI-Gateway structured extraction + confidence assignment; binary files routed to a parser sidecar). Reuses the existing **AI Gateway**; introduces **no** new scoring engine and **no** duplicate metadata.

---

## 2. Production Audit (Phase 0)

| Check | Result |
|---|---|
| Production org | 00Dbn00000plgUfEAI (by ID) |
| Branch | feature/enterprise-evidence-document-intelligence (off main) |
| `OA_Knowledge_Document__c` | **Did not exist** → built (the evidence object; justified, no duplication) |
| Existing document/extraction classes | **None** → built `OA_DocumentIntelligence` |
| Salesforce Files / ContentDocument / ContentVersion | Present (native storage — **reused**, not duplicated) |
| AI Gateway (`OA_AI_Gateway`, `OA_AI_ModelRegistry`) | Present in org (018/019-certified) — **reused** |
| Opportunity Intelligence / Compliance / Qualification / Investment | Present (link targets) |
| Named / External Credentials | `OA_OpenRouter` (AI), `OA_USASpending`; no SAM key, no Graph NC |

Note: `OA_AI_Gateway`/`OA_AI_ModelRegistry` are deployed in the org but their source lives on the (unmerged) OpenRouter workstream branch, not `main`. 024C compiles against the org's copy and does **not** re-commit them (no workstream mixing).

---

## 3. Target State Validation (Phase 1)

Inspected before design: **ContentVersion / ContentDocument have no Apex triggers** (safe to insert Files during the pilot). `OA_Opportunity_Signal__c.Source__c` is a **restricted** picklist (Grants.gov/SAM.gov/SBIR/Federal Register) — the evidence object uses its **own** independent `Source__c` picklist, so there is no collision. New reportable fields ship with an FLS permission set (metadata-API deploys omit FLS).

---

## 4. Enterprise Evidence Inventory (Phase 2)

Document types the framework is designed to understand (captured in `Document_Type__c` + `Source__c`):

- **Federal:** SAM.gov attachments, Grants.gov packages, Amendments, RFI, RFP, RFQ, SOW, PWS, Evaluation Criteria, Attachments.
- **Partner:** Capability Statements, Certifications, Contract Vehicles, Past Performance, Technology Competencies, Partner Agreements.
- **Company (One Algorithm):** Capability Statement, Certifications (SBA / WOSB / EDWOSB / MBE / SWaM / HUB), GSA.
- **Proposal:** Resumes, Pricing templates, Staffing plans, Technical narratives, Win themes.

---

## 5. Evidence Model (Phase 3) — `OA_Knowledge_Document__c` (25 fields)

Provenance & identity: `Source__c`, `Document_Type__c`, `Version__c`, `Checksum__c` (SHA-256), `Content_Document_Id__c` (→ the Salesforce File), `Provenance__c`, `Review_Status__c`.
Linkage: `Acquisition_Source__c`, `Opportunity_Signal__c`, `Company_Profile__c`.
Extraction: `Extraction_Status__c`, `AI_Summary__c`, `Extracted_Requirements__c`, `Extracted_Certifications__c`, `Extracted_Technologies__c`, `Extracted_NAICS__c`, `Extracted_PSC__c`, `Extracted_Agencies__c`, `Extracted_Dates__c`, `Extracted_Clauses__c`.
Confidence & telemetry: `Confidence__c`, `AI_Provider__c`, `AI_Model__c`, `AI_Total_Tokens__c`, `AI_Estimated_Cost__c`.

Storage is **never** duplicated — the binary always lives in `ContentDocument`; the evidence record references it.

---

## 6. Document Ingestion (Phase 4) — `OA_DocumentIntelligence.ingest()`

`ingest(contentVersionId, signalId, profileId, source, docType, url)`:
- computes a **SHA-256 checksum** of the file bytes;
- **idempotent dedupe** — a matching checksum returns the existing record (no duplicate documents);
- records **provenance** (file, type, source, checksum, URL, timestamp) and **linkage** to signal / profile;
- sets `Extraction_Status__c='Pending'`, `Review_Status__c='Pending'`.

Supports Salesforce Files today; Grants.gov / SAM.gov packages and manual uploads follow the same path once fetched into Files.

---

## 7. Document Extraction (Phase 5) — `OA_DocumentIntelligence.extract()`

- Reads the file text (text-extractable types); **binary (PDF/DOCX) is flagged for an Apache-2.0 OCR/parser sidecar** — Apex cannot parse binary and the class does **not** pretend to. Honest failure over fake success.
- One **AI Gateway** call (`Document_Extraction` workflow) returns strict JSON: title, agency, opportunity number, deadline, set-aside, NAICS, PSC, contract vehicles, certifications, evaluation criteria, submission instructions, key personnel, technologies, security requirements, labor categories, pricing references, summary.
- Persists parsed fields + AI telemetry; assigns confidence. **Callout-before-DML** respected (the gateway logs internally → exactly one gateway call per transaction).
- **Reuse-before-build:** uses the existing OpenRouter gateway. An external OCR/parsing sidecar (Tika / Unstructured, Apache-2.0) is *documented* as the only justified future addition for binary documents; it is **not** introduced here.

---

## 8. Evidence Linking (Phase 6)

Every evidence record links to the intelligence layers via `Opportunity_Signal__c` (Compliance / Qualification / Investment / Opportunity Intelligence) and `Company_Profile__c` (Partner Intelligence / Knowledge Foundation) and `Acquisition_Source__c`. This makes each recommendation **evidence-backed**: a qualification/compliance decision can be traced to the document, page-level provenance, checksum, and confidence that supports it. (Downstream engines reading these fields is the next program — 024C lays the traceable foundation.)

---

## 9. Confidence Model (Phase 7)

| Confidence | Rule (implemented) |
|---|---|
| **HIGH** | Verified government document (`Source__c` = SAM.gov / Grants.gov), extraction succeeded |
| **MEDIUM** | Company- or Partner-supplied document (claimant-supplied, not government-verified) |
| **LOW** | AI inference only / unknown source / extraction failed / binary pending sidecar |

Every evidence record — and therefore every recommendation that cites it — carries a confidence grade.

---

## 10. Pilot Results (Phase 9) — 2 real documents, live

| Doc | Source | Confidence | Extraction | Live evidence |
|---|---|---|---|---|
| **KD-0000001** — Grants.gov HHS-2026-ACF-ACYF-CA-0037 *(real posted opportunity)* | Grants.gov | **HIGH** | Extracted | Agency `HHS-ACF-CB`; linked to signal `a10Pn00000edQzlIAE`; OpenRouter 382 tok / $0.000764. **NAICS/certs left null — the synopsis didn't state them and the AI did not invent them (grounded).** |
| **KD-0000000** — One Algorithm capability statement *(real owned)* | Company | **MEDIUM** | Extracted | Certs EDWOSB/WOSB/WBE-MBE; NAICS 541511/541611/561110; tech Salesforce/OpenRouter-Anthropic/M365; linked to Company Profile `a0xPn0000082YLxIAM`; OpenRouter 454 tok / $0.000908. |

**Dedupe proven:** re-ingesting the government file returned the same record (2→2, no duplicate). **0 new Opportunities** (org Opportunity count unchanged at 1, pre-existing). **No autonomous CRM writes** — evidence records only; `Review_Status__c='Pending'`.

---

## 11. Production Changes

- **Added (dormant, additive):** object `OA_Knowledge_Document__c` (+25 fields), classes `OA_DocumentIntelligence` (+test), permset `OA_Document_Intelligence_Access`.
- **Data inserted (pilot):** 2 `ContentVersion` files + 2 `OA_Knowledge_Document__c` evidence records.
- **Data updated (pilot):** the 2 evidence records (extraction fields).
- **Permset assigned:** `OA_Document_Intelligence_Access` → `oauser@pboedition.com` (FLS visibility; reversible; no trigger/schedule/activation).
- **No** triggers, flows, schedules, secrets, Opportunities, or duplicate metadata.

---

## 12. Validation Evidence · 13. Deployment IDs · 14. Test Results

- Check-only validation: **`0AfPn0000023wRJKAY`** — 29/29 components, 3 tests, 0 failures, **92% coverage** on `OA_DocumentIntelligence`.
- Deploy (dormant additive): **`0AfPn0000023wSvKAI`** — 29/29 components, 3 tests, 0 errors.
- Tests: `ingestChecksumsDedupesAndLinks`, `extractStructuredEvidenceWithConfidence` (HIGH for gov source), `companySourceIsMediumConfidence` (MEDIUM) — all pass.

---

## 15. Risks

- Text-only extraction today; **binary PDFs/DOCX require an OCR/parser sidecar** (documented, not built) — until then such files are correctly parked in `Manual Review`.
- Extraction quality depends on gateway model + document text quality; confidence grading mitigates over-trust.
- Government synopses are sparse (as the pilot showed) — full package documents will yield richer NAICS/PSC/clauses.

## 16. Technical Debt

- OCR/parser sidecar (Apache-2.0 Tika/Unstructured) for binary documents.
- SAM.gov document ingestion (blocked on data.gov key — dormant connector strategy documented in Phase 8).
- Downstream: have Compliance/Qualification/Investment *read* `OA_Knowledge_Document__c` evidence and cite it in their rationales.
- Queueable batch ingestion; native Files-based UI; least-privilege runtime user.

## 17. Rollback Plan

Not merged — abandoning the branch reverts source. In-org rollback: delete the 2 pilot evidence records + 2 ContentVersions, unassign + delete `OA_Document_Intelligence_Access`, and destructive-deploy `OA_DocumentIntelligence`(+test) and `OA_Knowledge_Document__c`. No triggers/schedules to disable; CRM (Lead/Campaign/Opportunity) untouched.

## 18. Verdict — **PASS**

Production verified; runtime constraints inspected before design; evidence inventory complete; evidence model implemented + FLS; AI Gateway and native Files reused (no duplicate metadata/storage); confidence model implemented (HIGH/MEDIUM/LOW proven live); evidence linked to signal + company profile; safe 2-document pilot with grounded extraction, dedupe, and 0 Opportunities; rollback documented; no scraping, no autonomous proposal/bid.

## 19. Commit Hash · 20. Pull Request

See commit + PR recorded at close.

## 21. Exact Next Engineering Program

**024D — Evidence-Backed Decisioning + Binary Document Pipeline:** (1) have Compliance, Qualification, and Pursuit Investment **read** `OA_Knowledge_Document__c` and cite the evidence (document + confidence) in their rationales — so no recommendation exists without traceable evidence; (2) stand up the **OCR/parser sidecar** (Apache-2.0 Tika/Unstructured) so binary RFP/SOW/PWS packages become extractable; (3) provision the **data.gov key** to ingest real SAM.gov solicitation packages into the evidence layer.
