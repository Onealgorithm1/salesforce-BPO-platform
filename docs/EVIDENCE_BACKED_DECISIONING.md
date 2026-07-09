# Evidence-Backed Decisioning & Enterprise Document Pipeline — Program 024D

**Org:** 00Dbn00000plgUfEAI (verified by ID) · **Branch:** feature/evidence-backed-decisioning (stacked on 024C `e00db27`)
**Mode:** Engineering · **Verdict:** WARN (delivered scope PASS; full in-engine wiring blocked by integration debt — see §3/§12)

---

## 1. Executive Summary

024D makes the platform **explainable**: every recommendation can now be traced to supporting documents, confidence, provenance, and extraction date. It does so **without forking the five decision engines** — which is deliberate, because Phase 0 revealed the platform's real state (below). Instead of five divergent edits, 024D adds **one reusable citation layer** (`OA_EvidenceCitation`) that any engine calls to become evidence-backed, plus evidence-rollup fields on the signal and partner profile, plus document version-lineage fields. Binary-document processing and SAM.gov are **certified** (architecture + exact remaining work), not built, because both require external infrastructure/credentials that cannot be safely staged here.

**The headline finding (Phase 10, stated up front because it dominates everything): the entire platform exists as ~14 unmerged PRs. `main` contains only `OA_Opportunity_Signal__c`.** The AI Gateway, all five decision engines, and every other object live only on unmerged feature branches (deployed in the org). This is the platform's #1 risk and it is why 024D wires evidence via a shared layer rather than editing engines it would have to import from five other branches.

---

## 2. Production Audit (Phase 0) — ground truth

| Component | On `main` | In org (deployed) |
|---|---|---|
| `OA_Opportunity_Signal__c` | **yes** | yes |
| `OA_AI_Gateway`, `OA_AI_ModelRegistry` | no | yes (018/019) |
| `OA_ComplianceScreen` | no | yes (023) |
| `OA_OpportunityQualification` | no | yes (024A) |
| `OA_PursuitInvestment`, `OA_PartnerIntelligence` | no | yes (024B) |
| `OA_OpportunityIntelligence` | no | yes (020) |
| `OA_DocumentIntelligence`, `OA_Knowledge_Document__c` | no (024C branch) | yes (024C) |
| `OA_Company_Profile__c`, `OA_Acquisition_Source__c` | no | yes |
| Named/External Credentials | — | `OA_OpenRouter`, `OA_USASpending`; **no SAM key, no Graph NC** |

Every engine 024D must serve is confirmed live in the org; almost none is on `main`.

## 3. Architecture Review (Phase 10 — critical, not a rubber-stamp)

1. **Integration debt is the dominant risk.** 14 unmerged PRs (#69–#82). The platform has never been assembled and tested as a whole on `main`. Each new program branches off a near-empty `main` and compiles against the *org*. This works for additive builds but makes true cross-engine integration (024D's stated mission) structurally unsafe — importing five engines from five branches to edit them would multiply drift and guarantee merge conflicts. **Recommendation: a consolidation program that merges #69–#82 to `main` in dependency order must precede deeper wiring.** This is the single highest-value next step.
2. **`OA_AI_Gateway` untracked-on-`main`** but in the org — same root cause.
3. **Over-engineering risk avoided:** 024D adds *no* new object and *no* new scoring engine (per the rules). It reuses `OA_Knowledge_Document__c` + native Files + `ContentDocumentLink`.
4. **Licensing:** binary pipeline explicitly excludes AGPL (see §7).

## 4. Evidence Layer Assessment (Phase 1)

**Question: keep `OA_Knowledge_Document__c`, or can Salesforce Files + existing metadata replace it?**
**Answer: keep it — with evidence.** `ContentVersion`/`ContentDocument` store the *binary* and native version chain, but cannot serve as the evidence layer:
- No queryable typed extraction (NAICS, PSC, certifications, confidence) — you would have to add many custom fields to `ContentVersion`, which is largely **immutable per version** (re-extraction/status changes would force new file versions).
- No **typed, mutable links** to Opportunity Signal / Company Profile / Acquisition Source.
- No **confidence/provenance/review-status** as first-class, reportable data.
- No clean **many-to-many citation** (one document supporting several opportunities).

`OA_Knowledge_Document__c` remains justified as the queryable, mutable citation/evidence layer that **references** Files for storage (storage never duplicated). **No migration recommended.**

## 5. Document Architecture Recommendation

Keep the split: **Files = storage** (binary, native versioning, `ContentDocumentLink` for native doc↔many-records), **`OA_Knowledge_Document__c` = evidence/citation** (typed extraction, confidence, provenance, typed links, version-lineage). 024D adds version-lineage fields (`Document_Status__c`, `Supersedes__c`, `Effective_Date__c`) rather than a parallel object.

## 6. Evidence Graph (Phase 3)

The graph **Document → Evidence → Requirement → Partner → Opportunity → Decision → Recommendation** is realized with existing metadata, no new object:
- **Document → Evidence:** `OA_Knowledge_Document__c.Content_Document_Id__c` → `ContentDocument`.
- **Evidence → Opportunity / Partner / Source:** typed lookups (`Opportunity_Signal__c`, `Company_Profile__c`, `Acquisition_Source__c`).
- **Many-to-many (doc ↔ many records):** native `ContentDocumentLink`.
- **Evidence → Decision → Recommendation:** `OA_EvidenceCitation` rolls the citation onto the decision record (`Evidence_*` fields), so the recommendation carries its evidence.
- **Version lineage:** `Supersedes__c` self-lookup + `Document_Status__c`.

A dedicated junction object (`OA_Evidence_Citation__c`) is **deferred** until many-to-many citation demand is proven — per "no unnecessary objects."

## 7. Binary Document Strategy (Phase 4) — certified, not built

Apex cannot parse PDF/DOCX/XLSX/ZIP/scanned images. Recommended **lowest-maintenance** architecture:
- **Outside Salesforce:** a small **stateless** parsing microservice — **Apache Tika** or **Unstructured (both Apache-2.0, NOT AGPL)** — that accepts a file and returns text/structure. Deployed as a container (Cloud Run) reached from Apex via a **Named Credential**. No document is stored outside Salesforce (pass-through only).
- **Inside Salesforce:** ingestion, checksum/dedupe, provenance, linkage, confidence, and **structured extraction via the existing AI Gateway** on the returned text.
- **OCR** (scanned PDFs/images): the same service with Tesseract, or a cloud OCR API via Named Credential.
- **Explicitly excluded:** any AGPL component; `pdfplumber` is fine (MIT) for text PDFs but does not cover DOCX/OCR, so Tika/Unstructured is preferred as the single dependency.
- **Today's safe behavior:** `OA_DocumentIntelligence.extract()` routes binary to `Manual Review` — honest, no fake success.
- **Remaining work:** stand up the container + Named Credential; add a `parseBinary()` branch that calls it before the AI step. Effort: ~1 sprint; blockers: infra provisioning + a Named Credential (gated).

## 8. Partner Evidence Assessment (Phase 6)

Partner intelligence must not rely solely on AI summaries. 024D adds document-backed evidence to `OA_Company_Profile__c`: `Evidence_Document_Count__c`, `Evidence_Summary__c` (cited documents with confidence + provenance), `Has_Capability_Statement__c`. `OA_EvidenceCitation.citeProfile()` populates them from linked `OA_Knowledge_Document__c` records. **Pilot:** the One Algorithm profile now shows 1 evidence document and `Has_Capability_Statement = true` — a *document-backed* fact, not an AI claim. Collecting capability statements / certifications / past-performance for IronGrove & Patriot Allied remains the data task.

## 9. Evidence-Backed Decisioning (Phase 2) — how the engines consume evidence

Rather than editing five engines on five branches, 024D provides `OA_EvidenceCitation` — the shared layer they call:
- `cite(signalId)` → assembles supporting documents (excluding Superseded/Withdrawn/Duplicate), selects **highest confidence**, and rolls a traceable summary (document, type, source, **confidence, provenance/checksum, extraction date, URL**) onto the signal (`Evidence_Count__c`, `Evidence_Confidence__c`, `Evidence_Summary__c`, `Evidence_Backed__c`, `Last_Evidence_Date__c`).
- `citeProfile(profileId)` → same for partners.
- `explain(signalId)` → read-only citation for engines that only need to justify a recommendation.
- **Unsupported guard:** with no evidence, the summary explicitly reads *"UNSUPPORTED until documents are ingested and extracted"* and `Evidence_Backed__c = false`.

Each engine becomes evidence-backed with a **one-line call** — the reuse-first, low-coupling path. Actually inserting that call into each engine is deferred to the consolidation program (§3), where the engines live on one branch and can be edited without cross-branch drift.

## 10. SAM.gov Readiness (Phase 7)

Dormant connector exists (`OA_SAM_Opportunities` design, memory). **Remaining once a data.gov key is provided:** (1) create `OA_SAM_Opportunities` Named + External Credential (API-key auth, gated secret); (2) Remote Site / NC endpoint `api.sam.gov`; (3) enable the dormant search call (`opportunities/v2/search`, `postedFrom/To` ≤1yr, `limit=1000` to beat the ~10/day non-federal cap); (4) normalize to `OA_Opportunity_Signal__c` (OCDS) → screen → **ingest attachments via `resourceLinks` into the evidence layer** (Files + `OA_DocumentIntelligence`). **Effort:** ~0.5 sprint once the key exists. **Blocking risk:** key issuance + role-based request cap. **Deploy path:** additive, dormant, same pattern as Grants.gov.

## 11. Pilot Results (Phases 8–9) — end-to-end traceability, live

- **`cite('a10Pn00000edQzlIAE')`** (real 024C Grants signal, prior Compliance decision **GO**) → `Evidence_Count=1`, `Evidence_Confidence=HIGH`, `Evidence_Backed=true`. Summary: `[HIGH] KD-0000001 (Solicitation, Grants.gov) - extracted 2026-07-09 - checksum aa36f302… - url=https://grants.gov/…`. **The GO decision is now explainable and traceable to a specific government document + checksum.**
- **`citeProfile('a0xPn0000082YLxIAM')`** (One Algorithm) → 1 evidence document, `Has_Capability_Statement=true`.
- **Traceability chain demonstrated:** Opportunity signal → linked evidence (`OA_Knowledge_Document__c` → `ContentDocument`) → Compliance decision (GO) now carrying the citation → **Review_Status Pending (human review)** → *no* Opportunity. **Opportunity count unchanged at 1 (pre-existing); 0 auto-created.**
- Dedupe/versioning: citation excludes Superseded/Withdrawn evidence (unit-proven).

## 12. Architecture Risks

- **Integration debt (#1):** 14 unmerged PRs; consolidation must precede deeper wiring.
- Binary documents remain in `Manual Review` until the parsing service exists.
- Citation currently uses single typed lookups; true many-to-many citation needs the deferred junction if demand appears.
- SAM.gov blocked on data.gov key + cap.

## 13. Technical Debt

Consolidation/merge of #69–#82; insert `OA_EvidenceCitation` calls into each engine (post-consolidation); binary parsing microservice + Named Credential; SAM.gov activation; least-privilege runtime user; native Files-based UI for evidence.

## 14. Simplification Recommendations

- **Merge before building more.** The most valuable next action is not a new feature but **consolidating the platform onto `main`**.
- Keep the single evidence object; do **not** add a junction object until many-to-many is real.
- One parsing dependency (Tika *or* Unstructured), not several.
- Keep decision numbers deterministic; AI only for narrative/extraction (already the pattern).

## 15. Production Changes

- **Added (dormant, additive):** `OA_EvidenceCitation` (+test); 5 evidence-rollup fields on `OA_Opportunity_Signal__c`; 3 version-lineage fields on `OA_Knowledge_Document__c`; 3 partner-evidence fields on `OA_Company_Profile__c`; permset `OA_Evidence_Decisioning_Access` (assigned to `oauser` for FLS).
- **Data updated (pilot):** evidence rollup on 1 signal + 1 company profile (review-queue working records; **not** Lead/Campaign/Opportunity).
- **No** new objects, triggers, flows, schedules, secrets, scoring engines, or Opportunities.

## 16. Validation Evidence · 17. Deployment IDs · 18. Test Results

- Check-only: **`0AfPn0000023wkfKAA`** — 14/14 components, 4 tests, 0 failures, **97% coverage** on `OA_EvidenceCitation`.
- Deploy (dormant): **`0AfPn0000023wmHKAQ`** — 14/14, 4 tests, 0 errors.
- Tests: highest-confidence rollup + superseded exclusion; unsupported-recommendation guard; partner capability-statement detection; `explain()` read-only. All pass.

## 19. Rollback Plan

Not merged — abandon the branch to revert source. In-org: null the `Evidence_*`/version fields, unassign + delete `OA_Evidence_Decisioning_Access`, destructive-deploy `OA_EvidenceCitation`(+test) and the 11 added fields. No triggers/schedules; CRM untouched.

## 20. Verdict — **WARN**

Delivered scope is solid (citation layer, rollups, versioning, partner evidence, binary + SAM certification, live traceability pilot, 97% coverage). **WARN, not PASS,** for one honest reason: the success criterion *"every decision engine cites evidence"* is met **by mechanism** (any engine gains it with a one-line call) but **not by in-engine edit**, because the engines live on five unmerged branches and editing them here would deepen the integration debt this very review identifies as the platform's top risk. The correct sequence is consolidate → then insert the calls. Everything else passes.

## 21. Commit Hash · 22. Pull Request

See close.

## 23. Exact Next Engineering Program

**024E — Platform Consolidation & Engine Evidence Wiring:** merge PRs #69–#82 to `main` in dependency order (Gateway → objects → engines → evidence layer → citation), then insert `OA_EvidenceCitation.cite()`/`explain()` into `OA_ComplianceScreen`, `OA_OpportunityQualification`, `OA_PursuitInvestment`, `OA_PartnerIntelligence`, and `OA_OpportunityIntelligence` so each decision persists its evidence citation — now safe because all engines sit on one branch. This resolves the integration debt **and** completes the in-engine wiring in the same motion.
