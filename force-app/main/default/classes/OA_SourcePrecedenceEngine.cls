/**
 * OA_SourcePrecedenceEngine — metadata-driven source-of-truth precedence.
 *
 * Reads OA_Enrichment_Source__mdt (only Active records count) to decide which source wins a
 * conflict and whether a source is trusted. Lower Precedence__c number = higher priority.
 * No hardcoded ordering — everything comes from metadata; tests inject rows via the override.
 */
public with sharing class OA_SourcePrecedenceEngine {

    /** Test injection point — when non-null, used instead of querying the CMDT. */
    @TestVisible
    private static List<OA_Enrichment_Source__mdt> sourceOverride;

    private static List<OA_Enrichment_Source__mdt> sources() {
        if (sourceOverride != null) {
            return sourceOverride;
        }
        return [
            SELECT Source_System__c, Display_Name__c, Precedence__c, Trusted__c,
                   Authoritative_For__c, Active__c
            FROM OA_Enrichment_Source__mdt
            WHERE Active__c = true
        ];
    }

    private static Map<String, OA_Enrichment_Source__mdt> byKey() {
        Map<String, OA_Enrichment_Source__mdt> m = new Map<String, OA_Enrichment_Source__mdt>();
        for (OA_Enrichment_Source__mdt s : sources()) {
            if (s.Active__c == true && String.isNotBlank(s.Source_System__c)) {
                m.put(s.Source_System__c.toUpperCase(), s);
            }
        }
        return m;
    }

    /** Precedence for a source; unknown/inactive sources get the lowest priority. */
    public static Decimal precedence(String sourceSystem) {
        OA_Enrichment_Source__mdt s = get(sourceSystem);
        return (s == null || s.Precedence__c == null) ? 999999 : s.Precedence__c;
    }

    public static Boolean isTrusted(String sourceSystem) {
        OA_Enrichment_Source__mdt s = get(sourceSystem);
        return s != null && s.Trusted__c == true;
    }

    public static Boolean isKnown(String sourceSystem) {
        return get(sourceSystem) != null;
    }

    /** The winning (higher-priority = lower number) of two sources. Known beats unknown. */
    public static String winner(String a, String b) {
        if (String.isBlank(a)) { return b; }
        if (String.isBlank(b)) { return a; }
        return precedence(a) <= precedence(b) ? a : b;
    }

    private static OA_Enrichment_Source__mdt get(String sourceSystem) {
        if (String.isBlank(sourceSystem)) {
            return null;
        }
        return byKey().get(sourceSystem.toUpperCase());
    }
}