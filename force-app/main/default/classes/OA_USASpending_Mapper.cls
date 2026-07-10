/**
 * OA_USASpending_Mapper — canonical USASpending org -> Lead field proposals (USASpending-specific).
 * Emits proposals only for present values; the platform write policy decides how each is written.
 */
public with sharing class OA_USASpending_Mapper {

    public static final String SOURCE = 'USASpending';

    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(ps, 'UEI__c', org.uei, band);
        add(ps, 'Federal_Contractor__c', attr(org, 'Federal_Award_Recipient'), band);
        add(ps, 'Total_Award_Amount__c', attr(org, 'Award_Total'), band);
        add(ps, 'Award_Count__c', attr(org, 'Award_Count'), band);
        add(ps, 'Awarding_Agencies__c', attr(org, 'Awarding_Agencies'), band);
        add(ps, 'Latest_Award_Date__c', attr(org, 'Latest_Award_Date'), band);
        add(ps, 'Parent_Organization__c', attr(org, 'Parent_Organization'), band);
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