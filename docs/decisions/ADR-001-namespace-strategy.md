# ADR-001 — Namespace Strategy

**Status:** Accepted
**Date:** June 19, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** Required before any AppExchange listing work begins (Phase 3)

---

## Context

One Algorithm is building a multi-layer Salesforce platform using SFDX unlocked packages. The platform currently serves internal One Algorithm operations and direct-contract client deployments. A future AppExchange listing is anticipated for Phase 3 (2027+).

Salesforce namespaces are:
- Required for AppExchange managed package listings
- Permanently associated with a DevHub org — cannot be changed or transferred
- Once registered, all custom API names in managed packages carry the prefix (e.g., `onealgo__Field__c`)
- Migrating from no-namespace unlocked packages to a namespaced managed package requires rebuilding all metadata with prefixed API names — there is no in-place upgrade path

Current state at time of decision:
- `sfdx-project.json` has `"namespace": ""`
- No `sf package create` has been run
- No namespace registered in DevHub (`sreeni@onealgorithm.com` / `00Dd0000000haZPEAY`)
- Platform has active custom fields, Apex classes, and permission sets with unprefixed API names (`OA_EmailSender`, `Compatibility_Score__c`, etc.)

---

## Decision

**Use no namespace through Phase 0–2 (all work through end of 2026).**

`sfdx-project.json` retains `"namespace": ""`. Packages will be created and versioned as unlocked packages without a namespace. No namespace will be registered in DevHub until the AppExchange listing decision is made.

**Target namespace for future registration: `onealgo`**
- 7 characters, brand-representative, likely globally available
- Availability must be verified in DevHub before registration
- Must be confirmed unique across all Salesforce AppExchange listings

**Namespace registration decision deadline:** Q1 2027, or when AppExchange listing is placed on the product roadmap — whichever comes first.

---

## Rationale

1. **Irreversibility.** Namespace registration cannot be undone. Choosing the wrong name or registering prematurely locks the organization into a name and org relationship permanently.

2. **Migration cost.** Registering a namespace now requires migrating all existing custom metadata API names in the production org to prefixed equivalents — a destructive, error-prone operation with no rollback path once data exists on the prefixed fields.

3. **No current benefit.** Namespaces provide value only for AppExchange managed packages and push upgrades. Unlocked packages for internal use and direct-contract clients work identically with or without a namespace.

4. **Unlocked packages are the correct Phase 0–2 vehicle.** Direct client deployments do not require AppExchange. Unlocked packages can be distributed via installation keys, which satisfies current business requirements.

---

## Consequences

### Positive
- All current API names remain unchanged — no migration required
- Development can proceed immediately without namespace infrastructure overhead
- Namespace choice can be made with full information about the platform's scope and identity

### Negative
- Cannot list any package on AppExchange until namespace is registered and packages are converted to managed
- Unlocked package to managed package conversion requires parallel deployment strategy (managed package is not an in-place upgrade)

### Constraints Added
- Any custom field or class API name created now (`OA_*`, `Compatibility_Score__c`, etc.) will require a corresponding namespaced version when managed packages are created — keep API names consistent and well-documented
- If a namespace is needed earlier than Q1 2027, this ADR must be revisited and a migration plan prepared

---

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|-----------------|
| Register namespace `oa` now | Too short; high conflict risk; forces immediate migration |
| Register `onealgorithm` (12 chars) now | Premature; same migration cost; full name may be too long for field prefix readability |
| Use namespaced unlocked packages as transition | No benefit over no-namespace for unlocked; adds prefix overhead without AppExchange eligibility |
| Managed package immediately | Requires namespace; Security Review (6–12 weeks); incompatible with current dev velocity |

---

## Related Decisions

- [[ADR-002-client-isolation-strategy]] — Governs client org model, which determines how packages are distributed
- [[ADR-003-package-boundary-strategy]] — Governs what goes in each package, relevant to namespace scope
- `docs/CLIENT_DEPLOYMENT_STRATEGY.md` Section 3.2 — Package strategy narrative
