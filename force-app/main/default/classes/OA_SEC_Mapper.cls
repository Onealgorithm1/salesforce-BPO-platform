/**
 * OA_SEC_Mapper — canonical SEC org -> Lead field proposals (SEC-specific).
 * Emits proposals only for present values; the platform write policy governs how each is written.
 */
public with sharing class OA_SEC_Mapper {

    public static final String SOURCE = 'SEC';

    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(ps, 'CIK__c', org.cik, band);
        add(ps, 'Ticker__c', attr(org, 'Ticker'), band);
        add(ps, 'Exchange__c', attr(org, 'Exchange'), band);
        add(ps, 'SIC_Code__c', attr(org, 'SIC'), band);
        add(ps, 'Industry', attr(org, 'Industry'), band);
        add(ps, 'Website', org.website, band);
        add(ps, 'State', org.state, band);
        return ps;
    }

    private static void add(List<OA_EnrichmentWriter.FieldProposal> ps, String field, Object v, String band) {
        if (v != null && String.isNotBlank(String.valueOf(v))) {
            ps.add(new OA_EnrichmentWriter.FieldProposal(field, v, SOURCE, band));
        }
    }
    private static Object attr(OA_CanonicalOrg org, String key) { return org.attributes.get(key); }
}