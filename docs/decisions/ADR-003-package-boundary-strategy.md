# ADR-003 — Package Boundary Strategy

**Status:** Accepted
**Date:** June 19, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Before adding any new metadata type; before creating any new package

---

## Context

The One Algorithm platform contains metadata that serves different purposes and must be deployed to different audiences:

- **Platform utilities** that every client org needs (e.g., data quality rules, email sender class)
- **Feature modules** that only some clients need (e.g., marketing automation, CLM)
- **OA-specific assets** that must never leave OA's own org (e.g., branding, community pages, LMA logic)
- **Client-specific configuration** that is unique to one org (e.g., branded email templates, client permission sets)

Without clear boundaries, metadata drifts — OA branding ends up in client deployments, client customizations pollute platform packages, and upgrade paths become brittle.

The following metadata exists in the production org at the time of this decision:
- 27 Apex classes, 1 trigger, 3 flows
- 7 LightningComponentBundle, 4 ApexComponent, 24 ApexPage (VF)
- 6 StaticResource (logos, CDN assets)
- Custom fields on Lead, 2 PermissionSets, 3 DuplicateRules, 4 MatchingRules
- Email templates and folders

---

## Decision

**Three-layer package boundary architecture:**

```
LAYER 1 — Core Platform Package  (force-app/)
    Reusable platform utilities, valid for any Salesforce org
    Deployed to: All client orgs, OA production
    Package: OA-Core-Platform (unlocked)

LAYER 2 — Feature Module Packages  (modules/{module-name}/)
    Opt-in feature sets, valid for clients who purchase the module
    Deployed to: Client orgs that license the module; OA production
    Packages: OA-Marketing-Automation, OA-CLM, OA-Compliance, OA-AI-Agents, OA-Governance (unlocked)
    Dependencies: All modules depend on OA-Core-Platform; no module depends on another module

LAYER 3 — Client Overlay  (clients/{code}/)
    Org-specific configuration — NOT a package
    Deployed to: Exactly one org via sf project deploy start --source-dir
    Content: Permission sets, settings, email templates, labels, profiles, branding assets
```

**Classification rules** (in priority order):

1. If metadata is OA-brand-specific or references OA's own domain, org, or operations → `clients/pbo/`
2. If metadata belongs to a specific feature module (marketing, CLM, compliance, AI, governance) → `modules/{module}/`
3. If metadata is reusable across any client org with no modification → `force-app/`
4. If metadata is configured differently per client → `clients/{client-code}/`

---

## Rationale

### Why This Boundary Set

**Core must be brand-neutral.** A client org cannot receive OA's logo, VF pages, or LWC site components. If they were in the core package, every client installation would deploy One Algorithm's website into the client's Salesforce. The boundary between `force-app/` and `clients/pbo/` enforces this.

**Modules must be independent of each other.** A circular dependency (Module A depends on Module B, which depends on Module A) is unresolvable in Salesforce's package dependency graph. The rule that no module depends on another module prevents this permanently.

**Client overlay is not a package for correctness reasons.** A Salesforce package installs the same metadata into every org it is installed in. Client-specific email templates, branded labels, and org-specific settings are definitionally not the same across orgs — putting them in a package would require parameterization that Salesforce packages do not support. Source deployment (not package install) is the correct mechanism.

**SFDX project structure mirrors the boundary.** The `packageDirectories` in `sfdx-project.json` map directly to this hierarchy. Layer 1 = first package directory. Layer 2 = additional package directories with `dependencies`. Layer 3 = source directories that are not packages.

---

## Boundary Rules — Current Metadata Classification

### Layer 1 — Core Platform (`force-app/`)
| Metadata | Type | Reason |
|----------|------|--------|
| OA_EmailSender, OA_EmailSender_Test | ApexClass | Generic email utility, org-neutral |
| Lead custom fields (OA_ prefixed) | CustomField | Shared data model extension |
| OpenAI_Access | PermissionSet | Grants AI feature access across any org |
| 3 DuplicateRules, 4 MatchingRules | Data quality | Standard platform hygiene, any org |

### Layer 2 — Marketing Module (`modules/marketing-automation/`)
| Metadata | Type | Reason |
|----------|------|--------|
| OA_DripScheduler, OA_FollowUpScheduler (+ tests) | ApexClass | Campaign scheduling — module feature |
| OA_EDWOSB_Outreach_Sequence, OA_Reply_Detection | Flow | Campaign automation — module feature |
| lead_by_ramesh | Flow | Org-owned flow, marketing function |
| OA_Campaign_Fields | PermissionSet | Grants marketing field access |
| EmailFolder *, EmailTemplate * | Email | Marketing email assets |

### Layer 3A — PBO Client Overlay (`clients/pbo/`)
| Metadata | Type | Reason |
|----------|------|--------|
| 20 Communities/Site ApexClass controllers | ApexClass | OA website — never deployed to clients |
| TestLinkCOACustomerToLMALicense | ApexClass | LMA-specific, OA ISV operations |
| linkCOACustomerToLMALicense | ApexTrigger | LMA automation, OA ISV only |
| 6 StaticResource (logos, leaflet, CDN) | StaticResource | OA branding — never deployed to clients |
| 7 LWC (contactform, worldMap, etc.) | LightningComponentBundle | OA website components |
| 4 VF Components (SiteHeader, SiteFooter, etc.) | ApexComponent | OA site chrome |
| 24 VF Pages | ApexPage | OA website pages |

---

## Consequences

### Positive
- No OA brand asset can accidentally enter a client deployment
- Package upgrades (Core, Module) are independent — upgrading Marketing module does not require touching Core
- New modules can be added without modifying existing packages
- Client overlay changes can be deployed without a package version bump
- Boundary is self-documenting via directory structure

### Negative
- Metadata classification requires discipline and ongoing review
- Some metadata may be ambiguous (e.g., an Apex class that is "almost" generic but has one OA-specific reference)
- Adding a new feature requires deciding which layer it belongs to before writing code

### Constraints Added
- No metadata in `force-app/` may reference OA's org ID, domain, or brand
- No metadata in `force-app/` or `modules/` may contain hardcoded email addresses, custom URLs, or org-specific IDs
- No module may declare another module as a dependency
- `clients/pbo/` is never deployed to any org other than `00Dbn00000plgUfEAI`
- A new metadata item's layer assignment must be documented in `docs/METADATA_CLASSIFICATION.md` before retrieval

---

## Post-Retrieval Audit Required

At the time of this ADR, the following classification decisions are deferred pending retrieval:

| Deferred Item | Decision Needed |
|--------------|----------------|
| Lead.* custom fields | After retrieval, identify which are `OA_` core fields vs. any OA-specific operational fields |
| Email templates | Review for OA-specific vs. reusable template content |
| VF page modifications | Confirm all 24 pages are OA-site-specific (no generic utility pages) |

The Post-Retrieval Audit Checklist in `docs/METADATA_CLASSIFICATION.md` must be completed before any package version is created.

---

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|-----------------|
| Single package for everything | Cannot separate OA assets from client-deployable assets; upgrade blast radius affects all clients |
| Feature-flag-based single package | Salesforce has no native feature flag mechanism; requires complex custom metadata; fragile |
| Separate repo per package | Increases overhead without architectural benefit for current team size; cross-repo dependency management becomes painful |
| Module depends on Module (e.g., Compliance depends on CLM) | Creates circular dependency risk; forces clients to install unneeded packages |

---

## Related Decisions

- [[ADR-001-namespace-strategy]] — Package namespace decision applies to all packages in all layers
- [[ADR-002-client-isolation-strategy]] — The reason client overlays exist is the dedicated-org model
- `docs/METADATA_CLASSIFICATION.md` — Live registry implementing this boundary
- `manifest/package-core.xml` — Retrieval manifest for Layer 1
- `manifest/package-marketing.xml` — Retrieval manifest for Layer 2
- `manifest/package-pbo.xml` — Retrieval manifest for Layer 3A (PBO)
