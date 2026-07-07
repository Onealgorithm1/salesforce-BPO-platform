/**
 * OA_StateRegistry_Mapper — canonical state-registry org -> Lead field proposals (state-agnostic).
 * Reused by every state connector. Emits proposals only for present values.
 */
public with sharing class OA_StateRegistry_Mapper {

    public static final String SOURCE = 'StateRegistry';

    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        String source = String.isNotBlank(org.sourceSystem) ? org.sourceSystem : SOURCE;
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(ps, 'State_Entity_Number__c', attr(org, 'State_Entity_Number'), source, band);
        add(ps, 'State_Registration_Status__c', attr(org, 'State_Registration_Status'), source, band);
        add(ps, 'State_Formation_Date__c', attr(org, 'State_Formation_Date'), source, band);
        add(ps, 'Registered_Agent__c', attr(org, 'Registered_Agent'), source, band);
        add(ps, 'State', org.state, source, band);
        return ps;
    }

    private static void add(List<OA_EnrichmentWriter.FieldProposal> ps, String field, Object v, String source, String band) {
        if (v != null && String.isNotBlank(String.valueOf(v))) {
            ps.add(new OA_EnrichmentWriter.FieldProposal(field, v, source, band));
        }
    }
    private static Object attr(OA_CanonicalOrg org, String key) { return org.attributes.get(key); }
}
