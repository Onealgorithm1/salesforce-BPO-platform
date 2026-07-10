/**
 * OA_Census_Mapper — canonical Census CONTEXT -> market-context field proposals (Census-specific).
 *
 * Census enriches an EXISTING organization with aggregate market context for its geography; it does
 * NOT propose identity fields (name/UEI) because Census has no organization identity. Downstream, a
 * matched Lead (matched by state/NAICS via the platform) receives these context fields — the write
 * policy decides how. Only present values are proposed; nothing is fabricated.
 */
public with sharing class OA_Census_Mapper {

    public static final String SOURCE = 'Census';

    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        // Context confidence is low by nature — the platform floor will typically gate auto-writes.
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(ps, 'Market_Establishments__c', attr(org, 'Census_Establishments'), band);
        add(ps, 'Market_Employment__c', attr(org, 'Census_Employment'), band);
        add(ps, 'Market_Annual_Payroll__c', attr(org, 'Census_Annual_Payroll'), band);
        add(ps, 'Market_Industry__c', attr(org, 'Census_Industry_Label'), band);
        // NO identity fields (name/UEI) — Census never identifies an organization.
        return ps;
    }

    private static void add(List<OA_EnrichmentWriter.FieldProposal> ps, String field, Object v, String band) {
        if (v != null && String.isNotBlank(String.valueOf(v))) {
            ps.add(new OA_EnrichmentWriter.FieldProposal(field, v, SOURCE, band));
        }
    }
    private static Object attr(OA_CanonicalOrg org, String key) { return org.attributes.get(key); }
}