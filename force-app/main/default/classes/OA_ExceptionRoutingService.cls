/**
 * OA_ExceptionRoutingService — routes the four human-review cases to OA_Enrichment_Exception__c.
 *
 * The ONLY things enrichment sends to a human: low-confidence matches, conflicting
 * authoritative sources, duplicate/merge decisions, and policy exceptions. Everything else is
 * automatic. Builds rows in memory; persisting is a caller-controlled step (commitExceptions).
 */
public with sharing class OA_ExceptionRoutingService {

    public static final String TYPE_LOW_CONFIDENCE = 'LowConfidenceMatch';
    public static final String TYPE_SOURCE_CONFLICT = 'SourceConflict';
    public static final String TYPE_DUPLICATE_MERGE = 'DuplicateMerge';
    public static final String TYPE_POLICY = 'PolicyException';

    public static final String STATUS_OPEN = 'Open';

    /** Build (do not insert) an exception row. */
    public static OA_Enrichment_Exception__c build(
            String exceptionType, String targetObject, Id targetId, String field,
            String source, String confidence, String details, String recommendedResolution, Id runId) {
        return new OA_Enrichment_Exception__c(
            Exception_Type__c = abbrev(exceptionType, 40),
            Target_Object__c = abbrev(targetObject, 80),
            Target_Record_Id__c = targetId == null ? null : String.valueOf(targetId),
            Field_API_Name__c = abbrev(field, 80),
            Source_System__c = abbrev(source, 40),
            Confidence__c = abbrev(confidence, 10),
            Details__c = details,
            Recommended_Resolution__c = abbrev(recommendedResolution, 255),
            Connector_Run__c = runId,
            Status__c = STATUS_OPEN
        );
    }

    public static OA_Enrichment_Exception__c lowConfidence(String targetObject, Id targetId,
            String source, String confidence, String details, Id runId) {
        return build(TYPE_LOW_CONFIDENCE, targetObject, targetId, null, source, confidence,
            details, 'Human review: confirm or reject the low-confidence match.', runId);
    }

    public static OA_Enrichment_Exception__c sourceConflict(String targetObject, Id targetId,
            String field, String source, String confidence, String details, Id runId) {
        return build(TYPE_SOURCE_CONFLICT, targetObject, targetId, field, source, confidence,
            details, 'Human review: resolve the conflicting value.', runId);
    }

    public static OA_Enrichment_Exception__c duplicateMerge(String targetObject, Id targetId,
            String source, String details, Id runId) {
        return build(TYPE_DUPLICATE_MERGE, targetObject, targetId, null, source, null,
            details, 'Human review: approve or reject the merge.', runId);
    }

    public static OA_Enrichment_Exception__c policyException(String targetObject, Id targetId,
            String field, String source, String details, Id runId) {
        return build(TYPE_POLICY, targetObject, targetId, field, source, null,
            details, 'Human review: policy exception.', runId);
    }

    /**
     * Persist exception rows. Internal framework records (not a CRM write) → system mode;
     * the FLS guardrail applies to the CRM write performed by the enrichment writer.
     */
    public static List<Database.SaveResult> commitExceptions(List<OA_Enrichment_Exception__c> exceptions) {
        if (exceptions == null || exceptions.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        return Database.insert(exceptions, false);
    }

    private static String abbrev(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }
}
