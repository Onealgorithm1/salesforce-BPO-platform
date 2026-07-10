/**
 * OA_USASpending_ResponseParser — parses spending_by_award results into canonical organizations.
 *
 * Owns the USASpending response shape. Award rows are AGGREGATED per recipient (keyed by UEI when
 * present, else recipient name) into ONE OA_CanonicalOrg carrying award totals/count/agencies/dates.
 * Additive-tolerant (unknown fields ignored); malformed body throws a typed ParseException; missing
 * results yields an empty list. Never fabricates — absent fields stay null.
 */
public with sharing class OA_USASpending_ResponseParser {

    public class ParseException extends Exception {}

    public List<OA_CanonicalOrg> parse(String body) {
        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new ParseException('USASpending: malformed response body — ' + e.getMessage());
        }

        Object resultsObj = root.get('results');
        if (!(resultsObj instanceof List<Object>)) {
            return new List<OA_CanonicalOrg>();
        }

        // Aggregate awards by recipient.
        Map<String, OA_CanonicalOrg> byRecipient = new Map<String, OA_CanonicalOrg>();
        Map<String, Decimal> totals = new Map<String, Decimal>();
        Map<String, Integer> counts = new Map<String, Integer>();
        Map<String, Set<String>> agencies = new Map<String, Set<String>>();
        Map<String, String> latest = new Map<String, String>();

        for (Object o : (List<Object>) resultsObj) {
            if (!(o instanceof Map<String, Object>)) { continue; }
            Map<String, Object> award = (Map<String, Object>) o;
            String uei = str(award.get('Recipient UEI'));
            String name = str(award.get('Recipient Name'));
            String key = String.isNotBlank(uei) ? ('UEI:' + uei) : ('NAME:' + (name == null ? '' : name.toUpperCase()));

            OA_CanonicalOrg org = byRecipient.get(key);
            if (org == null) {
                org = new OA_CanonicalOrg();
                org.sourceSystem = 'USASpending';
                org.uei = uei;
                org.organizationName = name;
                org.normalizedName = OA_NameNormalizer.normalize(name);
                putIf(org, 'Parent_Organization', str(award.get('Parent Recipient Name')));
                putIf(org, 'Recipient_ID', str(award.get('recipient_id')));
                org.state = str(award.get('Place of Performance State Code'));
                byRecipient.put(key, org);
                totals.put(key, 0);
                counts.put(key, 0);
                agencies.put(key, new Set<String>());
            }
            totals.put(key, totals.get(key) + dec(award.get('Award Amount')));
            counts.put(key, counts.get(key) + 1);
            String ag = str(award.get('Awarding Agency'));
            if (String.isNotBlank(ag)) { agencies.get(key).add(ag); }
            String start = str(award.get('Start Date'));
            if (String.isNotBlank(start) && (latest.get(key) == null || start > latest.get(key))) {
                latest.put(key, start);
            }
        }

        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        for (String key : byRecipient.keySet()) {
            OA_CanonicalOrg org = byRecipient.get(key);
            putIf(org, 'Award_Total', String.valueOf(totals.get(key)));
            putIf(org, 'Award_Count', String.valueOf(counts.get(key)));
            putIf(org, 'Latest_Award_Date', latest.get(key));
            if (!agencies.get(key).isEmpty()) {
                putIf(org, 'Awarding_Agencies', String.join(new List<String>(agencies.get(key)), ','));
            }
            putIf(org, 'Federal_Award_Recipient', 'true');
            org.sourceConfidence = org.hasDeterministicId()
                ? OA_ConfidenceEvaluator.HIGH
                : (String.isNotBlank(org.organizationName) ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW);
            org.sourcePayloadHash = org.payloadHash();
            out.add(org);
        }
        return out;
    }

    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) { org.attributes.put(key, value); }
    }
    private static Decimal dec(Object o) {
        if (o == null) { return 0; }
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return 0; }
    }
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
}