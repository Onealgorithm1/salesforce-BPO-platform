# ADR-002 — Client Isolation Strategy

**Status:** Accepted
**Date:** June 19, 2026
**Decider:** Louis Rubino (lrubino@onealgorithm.com)
**Review:** With each new client engagement; mandatory review before first external client onboarding

---

## Context

One Algorithm operates as both an ISV and BPO platform provider. As the company grows, it will deploy Salesforce capabilities to multiple client organizations. A foundational decision must be made about how client data and configurations are isolated from each other and from One Algorithm's internal operations.

Three deployment models were evaluated:

1. **One dedicated Salesforce org per client** — each client gets their own Salesforce organization
2. **Shared org with multi-tenant namespacing** — all clients co-exist in a single Salesforce org, separated by record ownership or custom objects
3. **Communities portal on OA org** — clients access their data via a Salesforce Experience Cloud site on OA's production org

Current state at time of decision:
- One Algorithm's production org (`00Dbn00000plgUfEAI`) contains 13,286 leads, active email campaigns, and ISV operations
- No client orgs exist yet; first client onboarding has not occurred
- Company holds EDWOSB certification with federal contractor obligations
- `clients/pbo/` in the repository represents OA's own org (PBO Edition), not an external client

---

## Decision

**Each client receives a dedicated, independent Salesforce organization.**

OA's platform packages (Core + Modules) are installed into the client's org. Client-specific configuration is maintained in `clients/{code}/` and deployed as a source overlay — never as part of the package. One Algorithm's internal org (`clients/pbo/`) is strictly OA's own operations and is never co-mingled with client data.

---

## Rationale

### Data Isolation

In a shared org, SOQL queries traverse record ownership boundaries if sharing rules are misconfigured. A single misconfigured sharing rule can expose Client A's data to Client B. In dedicated orgs, SOQL cannot cross org boundaries — isolation is enforced by the Salesforce platform itself, not by application-layer controls.

### Security

A breach, privilege escalation, or misconfigured permission set in a shared org potentially exposes all clients simultaneously. In dedicated orgs, a security incident is scoped to one client. OA's own operations are never at risk from a client org incident.

### Federal Contractor Compliance (EDWOSB)

As an EDWOSB, OA is subject to federal acquisition regulations. Federal clients may require data residency assurances, FedRAMP-adjacent controls, and contractual guarantees that their data is not co-located with commercial data. Dedicated orgs satisfy these requirements; shared orgs do not.

### License Separation

Each client org carries its own Salesforce license agreement. Clients pay for their own user licenses, data storage, and API limits. In a shared org model, OA would bear all licensing costs and would need to implement complex metering for charge-back — operationally unsustainable.

### Upgrade Independence

Clients may have different upgrade cadences, regulatory freeze windows, or UAT timelines. In a shared org, any change affects all clients simultaneously. In dedicated orgs, each client controls when they accept upgrades.

---

## Consequences

### Positive
- Platform-enforced data isolation — no application-layer trust required
- Breach of one client org does not propagate
- Satisfies federal contractor data requirements out of the box
- Each client org is independently auditable
- Clients can self-administer without risk to OA operations or other clients

### Negative
- Infrastructure overhead: each new client requires org provisioning, package installation, and ongoing maintenance
- OA must maintain relationships with each client's admin for deployments, upgrades, and incident response
- No economies of scale from shared infrastructure

### Constraints Added
- `clients/{code}/` directories are org-specific config overlays — never deployed to more than one org
- No OA service account may have standing access to more than one client org simultaneously
- Cross-org data flows between client orgs are permanently prohibited
- OA production org data (`00Dbn00000plgUfEAI`) is never replicated to or from any client org

---

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|-----------------|
| Shared org with namespacing | SOQL can cross "namespace" boundaries; single sharing rule error exposes all clients; incompatible with federal requirements |
| Communities portal on OA org | Client data would reside in OA's org — no isolation; violates data residency requirements; OA org breach exposes all clients |
| Hybrid (shared for small clients, dedicated for federal) | Two deployment models double maintenance burden; creates inconsistency in governance controls |

---

## Implementation Notes

### Client Onboarding Sequence
1. Provision new Salesforce org (client purchases or OA provisions via trial)
2. Register client in `docs/CLIENT_DEPLOYMENT_STRATEGY.md` Client Version Matrix
3. Install OA-Core-Platform package
4. Install required feature module packages
5. Deploy `clients/{code}/` overlay
6. Verify with post-install validation script

### Repository Structure
```
clients/
├── pbo/          ← OA's own org (not a client)
└── {code}/       ← One directory per client org
    └── main/default/
        ├── permissionsets/
        ├── settings/
        ├── customMetadata/
        ├── labels/
        └── email/
```

---

## Related Decisions

- [[ADR-001-namespace-strategy]] — Package type and namespace decisions are upstream of client distribution model
- [[ADR-003-package-boundary-strategy]] — Defines what is in packages vs. client overlays
- `docs/CLIENT_DEPLOYMENT_STRATEGY.md` — Full deployment runbook implementing this decision
- `docs/SECURITY_MODEL.md` — Service account policy for client org access
