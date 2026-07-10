/**
 * OA_SAM_Mapper — maps a canonical SAM organization to enrichment field proposals (SAM-specific).
 *
 * Produces OA_EnrichmentWriter.FieldProposal rows (target CRM field + value + source + confidence)
 * for the platform's write policy engine to govern. This is the ONLY place the SAM→CRM field
 * mapping lives; the enrichment writer/policy engine stay connector-agnostic. Null/blank source
 * values are NOT proposed (never fabricate a value).
 *
 * Target CRM field names are the platform's convention; whether a field is actually written is
 * decided entirely by OA_Field_Write_Policy__mdt (fill-empty / overwrite / never / floor).
 */
public with sharing class OA_SAM_Mapper {

    public static final String SOURCE = 'SAM';

    /** Canonical SAM org -> Lead field proposals (only for values that are present). */
    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> proposals = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) {
            return proposals;
        }
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;

        add(proposals, 'UEI__c', org.uei, band);
        add(proposals, 'CAGE_Code__c', org.cageCode, band);
        add(proposals, 'SAM_Registration_Status__c', attr(org, 'Registration_Status'), band);
        add(proposals, 'SAM_Registration_Expiration__c', attr(org, 'Registration_Expiration'), band);
        add(proposals, 'Entity_Type__c', attr(org, 'Entity_Type'), band);
        add(proposals, 'Business_Types__c', attr(org, 'Business_Types'), band);
        add(proposals, 'Socioeconomic_Certifications__c', attr(org, 'Socioeconomic_Certifications'), band);
        add(proposals, 'Website', org.website, band);
        add(proposals, 'Phone', org.phone, band);      // usually null (unavailable) -> not proposed
        add(proposals, 'State', org.state, band);

        return proposals;
    }

    private static void add(List<OA_EnrichmentWriter.FieldProposal> proposals,
                            String field, Object value, String band) {
        if (value != null && String.isNotBlank(String.valueOf(value))) {
            proposals.add(new OA_EnrichmentWriter.FieldProposal(field, value, SOURCE, band));
        }
    }

    private static Object attr(OA_CanonicalOrg org, String key) {
        return org.attributes.get(key);
    }
}