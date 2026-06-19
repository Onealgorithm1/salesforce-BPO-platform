# ADR-004 — Metadata Retrieval Strategy

**Status:** Accepted
**Date:** June 19, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before any additional retrieval beyond the three-layer baseline

---

## Context

The One Algorithm production org (`00Dbn00000plgUfEAI`) contains all platform metadata in an unmanaged, unversioned state. The first retrieval is a one-time baseline operation that establishes source-of-truth for all subsequent development. Errors during this retrieval could:

- Overwrite the committed repository foundation with incorrect files
- Mix metadata from different layers into the wrong directories
- Pull managed package metadata that should be excluded (namespaced components)
- Create partial states where some layers are retrieved and others are not

Several decisions were made during the pre-retrieval gate review (June 19, 2026) regarding retrieval order, validation, rollback procedures, and backup requirements. This ADR documents those decisions so future retrievals follow the same discipline.

### Known Production Org State at Time of First Retrieval

- 27 Apex classes (org-owned, unmanaged)
- 1 Apex trigger
- 3 Flows (org-owned, unmanaged)
- 7 LightningComponentBundle
- 4 ApexComponent, 24 ApexPage (VF)
- 6 StaticResource
- ~22 Lead custom fields
- 2 PermissionSets
- 3 DuplicateRules, 4 MatchingRules
- Email templates and folders
- Multiple managed package namespaces excluded by .forceignore: `CHANNEL_ORDERS__*`, `sfcma__*`, `sfLma__*`, `sfFma__*`, `KPIapp__*`, `MHolt__*`

---

## Decision

**Retrieve metadata in three sequential passes, one per manifest, with a git commit between each pass.**

Do not use a single bulk retrieval (`package-all.xml`) for the baseline. Layer-by-layer retrieval with intermediate commits provides:
- Rollback granularity (can revert one layer without losing others)
- Validation opportunity between layers
- Accurate git blame for which metadata belongs to which layer

---

## Retrieval Order

**Order is mandatory. Never reverse it.**

| Pass | Manifest | Target Directory | Justification |
|------|----------|-----------------|---------------|
| 1 | `manifest/package-core.xml` | `force-app/main/default/` | Smallest, safest, establishes the foundation layer first |
| 2 | `manifest/package-marketing.xml` | `modules/marketing-automation/main/default/` | Depends on Core; validated after Core is committed |
| 3 | `manifest/package-pbo.xml` | `clients/pbo/main/default/` | Largest; OA-specific assets; retrieved last to isolate from platform layers |

**Why this order:**

Core first ensures that if the retrieval stops partway, the most reusable and most important metadata (data quality rules, email utility, core permission set) is already committed. Marketing second because it depends on Core entities (Lead fields). PBO last because it is the largest, most complex layer and the one most likely to require post-retrieval cleanup.

---

## Retrieval Commands

### Pre-Flight (every retrieval session)

```bash
# 1. Verify git is clean — no uncommitted changes
git status
# Expected: nothing to commit, working tree clean

# 2. Verify target org is authenticated
sf org display --target-org oauser@pboedition.com

# 3. Verify no OneDrive conflicts exist
# (Windows only — pause OneDrive before proceeding)
```

### Pass 1 — Core Platform

```bash
sf project retrieve start \
  --manifest manifest/package-core.xml \
  --target-org oauser@pboedition.com
```

Validate before committing:
- `git status` shows only `force-app/` changes
- `ls force-app/main/default/classes/` shows OA_EmailSender files
- `ls force-app/main/default/objects/Lead/fields/` shows Lead field files
- `ls force-app/main/default/duplicateRules/` shows 3 files
- `ls force-app/main/default/matchingRules/` shows 4 files
- No unexpected metadata types (no LWC, no VF pages, no static resources)

```bash
git add force-app/
git commit -m "feat: retrieve core platform metadata (Layer 1 — Core)"
git push origin main
```

### Pass 2 — Marketing Automation

```bash
sf project retrieve start \
  --manifest manifest/package-marketing.xml \
  --target-org oauser@pboedition.com \
  --output-dir modules/marketing-automation
```

Validate before committing:
- `git status` shows only `modules/` changes
- `ls modules/marketing-automation/main/default/classes/` shows drip/follow-up classes
- `ls modules/marketing-automation/main/default/flows/` shows 3 flow files
- `ls modules/marketing-automation/main/default/email/` shows templates
- No force-app/ changes (Core layer not disturbed)

```bash
git add modules/
git commit -m "feat: retrieve marketing automation metadata (Layer 2 — Marketing)"
git push origin main
```

### Pass 3 — PBO Client Overlay

```bash
sf project retrieve start \
  --manifest manifest/package-pbo.xml \
  --target-org oauser@pboedition.com \
  --output-dir clients/pbo
```

Validate before committing:
- `git status` shows only `clients/pbo/` changes
- `ls clients/pbo/main/default/classes/` shows ~21 site controllers
- `ls clients/pbo/main/default/lwc/` shows 7 LWC bundles
- `ls clients/pbo/main/default/pages/` shows ~24 VF pages
- `ls clients/pbo/main/default/staticresources/` shows 6 static resources
- No force-app/ or modules/ changes

```bash
git add clients/pbo/
git commit -m "feat: retrieve PBO client overlay metadata (Layer 3A — PBO)"
git push origin main
```

---

## Validation Requirements

### Before Each Retrieval Pass

| Check | Command | Expected Result |
|-------|---------|----------------|
| Git clean | `git status` | nothing to commit |
| Org authenticated | `sf org display --target-org oauser@pboedition.com` | Active, no errors |
| OneDrive paused | (visual check of tray icon) | Sync paused |

### After Each Retrieval Pass (Before Committing)

| Check | What to Verify |
|-------|---------------|
| File count reasonable | Count files vs. manifest member count. Should be within 20% of estimate. |
| No managed package files | `grep -r "sfLma__\|sfcma__\|CHANNEL_ORDERS__\|KPIapp__\|MHolt__" force-app/ modules/ clients/` — must return zero results |
| Correct layer isolation | `git diff --stat` shows only the expected target directory (`force-app/`, `modules/`, or `clients/pbo/`) |
| No .gitkeep deletion | `.gitkeep` files may co-exist with real metadata; they are not deleted by retrieval |
| API version consistent | Spot-check one `-meta.xml` file: must show `<apiVersion>67.0</apiVersion>` |

### Post-All-Retrievals (Phase 2 Gate)

| Check | Description |
|-------|-------------|
| Lead field audit | Count unique fields; identify AI-scoring fields vs. campaign fields; document in METADATA_CLASSIFICATION.md |
| Cross-layer dependency check | No Apex class in force-app/ imports a class that is in clients/pbo/ |
| Manifest reconciliation | Every member in every manifest has a corresponding file on disk |
| Managed namespace absence | Full grep across all three layers confirms zero managed namespace prefixes |

---

## Rollback Procedure

### Rollback Level 1 — Retrieval produced unexpected files (before commit)

Discard all untracked files in the affected layer:

```bash
# For Layer 1 failure
git clean -fd force-app/

# For Layer 2 failure
git clean -fd modules/

# For Layer 3A failure
git clean -fd clients/pbo/

# Verify state
git status
```

### Rollback Level 2 — Committed but retrieval was wrong (before push)

Reset the last commit (keeps changes staged for review):

```bash
git reset HEAD~1
# Review what is now staged
git diff --cached --stat
# Then either recommit (fixed) or discard
git checkout -- force-app/   # or modules/ or clients/pbo/
git clean -fd force-app/
```

### Rollback Level 3 — Pushed to GitHub but retrieval was wrong

Revert the commit on the remote:

```bash
# Create a revert commit (safe, non-destructive)
git revert HEAD
git push origin main
```

**Do NOT use `git push --force` to remove a pushed commit.** Always use `git revert`.

### Rollback Level 4 — Complete recovery from foundation

If all local files are lost or corrupted:

```bash
# Clone the repository fresh from GitHub
git clone https://github.com/Onealgorithm1/salesforce-BPO-platform.git
cd salesforce-BPO-platform
# Repository is at latest pushed state; re-run any unpushed retrievals
```

---

## Git Requirements

### Before ANY Retrieval

- [ ] `git status` must show `nothing to commit, working tree clean`
- [ ] At least one prior commit must exist (provides rollback point)
- [ ] Remote must be configured and reachable

### Commit Discipline

- One commit per retrieval layer — never combine layers into one commit
- Commit immediately after validating each layer — do not leave retrieved metadata uncommitted overnight
- Push after every commit — GitHub is the only off-device backup
- Use the prescribed commit message format:
  - `feat: retrieve core platform metadata (Layer 1 — Core)`
  - `feat: retrieve marketing automation metadata (Layer 2 — Marketing)`
  - `feat: retrieve PBO client overlay metadata (Layer 3A — PBO)`

### Branch Strategy During Retrieval

All retrieval commits go directly to `main`. This is the ONLY time direct commits to main are acceptable, because:
- Retrieval is a read-only operation (no Salesforce changes)
- Retrieval is idempotent (can be re-run safely)
- There is no "wrong" version to protect against with a feature branch — the metadata comes from the live org

After the baseline is established, all future changes follow the standard GitFlow process (feature branches, PRs, CI gate).

---

## Backup Requirements

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| Off-device backup before retrieval | Push foundation commit to GitHub | DONE (2be29ac) |
| Windows Long Paths enabled | Registry: LongPathsEnabled=1 | DONE (verified June 19, 2026) |
| OneDrive sync paused during retrieval | Manual step — pause via tray icon | Required each session |
| Post-retrieval backup | Commit + push each layer immediately after retrieval | Required each layer |

**Why GitHub is the backup:** The repository path is inside OneDrive (`C:\Users\louis\OneDrive\Documents\GitHub\...`). OneDrive provides file-level sync but can create conflict copies during rapid file writes. GitHub is the authoritative, conflict-free backup. Every commit pushed to GitHub is recoverable regardless of what happens to the local OneDrive copy.

---

## Success Criteria

### Phase 1 is complete when ALL of the following are true:

1. Three commits exist after the foundation commit:
   - `feat: retrieve core platform metadata (Layer 1 — Core)`
   - `feat: retrieve marketing automation metadata (Layer 2 — Marketing)`
   - `feat: retrieve PBO client overlay metadata (Layer 3A — PBO)`

2. All three commits are pushed to `origin/main`

3. `git status` is clean (nothing to commit)

4. File count across all layers:
   - `force-app/main/default/` — 34–38 files (excluding .gitkeep)
   - `modules/marketing-automation/main/default/` — 22–32 files
   - `clients/pbo/main/default/` — 147–168 files

5. Zero managed namespace references: `grep -rn "sfLma__\|sfcma__\|CHANNEL_ORDERS__\|KPIapp__\|MHolt__" force-app/ modules/ clients/` returns no results

6. No merge conflicts, no OneDrive conflict files present

7. Phase 2 (Metadata Classification) is initiated — METADATA_CLASSIFICATION.md post-retrieval checklist started

---

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|-----------------|
| Single bulk retrieval using package-all.xml | No layer isolation; if something goes wrong, entire retrieval must be redone; git history doesn't reflect layer boundaries |
| Retrieve directly to main without committing per-layer | No rollback granularity; a bad Layer 3A retrieval can corrupt a valid Layer 1 without recovery |
| Retrieve to a feature branch | Unnecessarily complex for a read-only baseline operation; retrieval is idempotent and does not benefit from branching |
| Manual file creation instead of retrieval | Metadata XML is complex and error-prone by hand; org is the source of truth |

---

## Related Decisions

- [[ADR-001-namespace-strategy]] — No namespace means retrieved metadata has no prefix complications
- [[ADR-002-client-isolation-strategy]] — Layer 3A exists because clients are isolated per ADR-002
- [[ADR-003-package-boundary-strategy]] — This ADR implements the retrieval sequence that populates the boundaries defined in ADR-003
- `docs/METADATA_CLASSIFICATION.md` — Post-retrieval audit checklist
- `manifest/package-core.xml`, `manifest/package-marketing.xml`, `manifest/package-pbo.xml` — Source manifests for each pass
