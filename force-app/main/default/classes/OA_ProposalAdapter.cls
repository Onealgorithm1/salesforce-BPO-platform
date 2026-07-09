/**
 * OA_ProposalAdapter — operational glue between a canonical org and the existing per-source mappers.
 *
 * The canonical->Lead field mapping is inherently source-specific (each connector ships its own
 * *_Mapper.toLeadProposals(OA_CanonicalOrg)); the frozen platform deliberately keeps no shared
 * mapper interface. This adapter is the ONE place the orchestrator resolves a source key to its
 * mapper — the same call the Sprint 16 canary/pilot made by hand — so no platform/connector class
 * changes. It only forwards to existing mappers; it never fabricates or governs values (the
 * OA_EnrichmentWriter + OA_FieldWritePolicyEngine still decide what is written).
 */
public with sharing class OA_ProposalAdapter {

    /** Resolve a source key to its mapper and return Lead field proposals (never null). */
    public static List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(String source, OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> none = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null || String.isBlank(source)) {
            return none;
        }
        switch on source.trim().toUpperCase() {
            when 'SAM'                 { return new OA_SAM_Mapper().toLeadProposals(org); }
            when 'USASPENDING'         { return new OA_USASpending_Mapper().toLeadProposals(org); }
            when 'CENSUS'              { return new OA_Census_Mapper().toLeadProposals(org); }
            when 'IRS'                 { return new OA_IRS_Mapper().toLeadProposals(org); }
            when 'SEC'                 { return new OA_SEC_Mapper().toLeadProposals(org); }
            when 'STATEREGISTRY', 'STATE' { return new OA_StateRegistry_Mapper().toLeadProposals(org); }
            when else                  { return none; }
        }
    }
}