/**
 * OA_IRS_Mapper — canonical IRS org -> Lead field proposals (IRS-specific).
 * Emits proposals only for present values; the platform write policy governs how each is written.
 */
public with sharing class OA_IRS_Mapper {

    public static final String SOURCE = 'IRS';

    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(ps, 'EIN__c', org.ein, band);
        add(ps, 'Tax_Exempt_Status__c', attr(org, 'Exempt_Status'), band);
        add(ps, 'Tax_Exempt_Subsection__c', attr(org, 'Subsection'), band);
        add(ps, 'NTEE_Code__c', attr(org, 'NTEE_Code'), band);
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