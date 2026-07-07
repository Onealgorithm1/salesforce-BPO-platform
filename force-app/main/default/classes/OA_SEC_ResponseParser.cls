/**
 * OA_SEC_ResponseParser — parses a SEC EDGAR submissions response into a canonical organization.
 *
 * Owns the SEC response shape. The submissions endpoint returns ONE company object (not a list) →
 * one OA_CanonicalOrg keyed by CIK (deterministic -> HIGH confidence). Additive-tolerant; malformed
 * body throws a typed ParseException; an empty/identity-less body yields an empty list. Never
 * fabricates — absent fields (e.g. website is frequently blank) stay null.
 */
public with sharing class OA_SEC_ResponseParser {

    public class ParseException extends Exception {}

    public List<OA_CanonicalOrg> parse(String body) {
        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new ParseException('SEC: malformed response body — ' + e.getMessage());
        }

        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        String cik = str(root.get('cik'));
        String name = str(root.get('name'));
        if (String.isBlank(cik) && String.isBlank(name)) {
            return out; // nothing identifiable
        }

        OA_CanonicalOrg org = new OA_CanonicalOrg();
        org.sourceSystem = 'SEC';
        org.cik = cik;
        org.organizationName = name;
        org.normalizedName = OA_NameNormalizer.normalize(name);
        putIf(org, 'Ticker', joinList(root.get('tickers')));
        putIf(org, 'Exchange', joinList(root.get('exchanges')));
        putIf(org, 'SIC', str(root.get('sic')));
        putIf(org, 'Industry', str(root.get('sicDescription')));
        putIf(org, 'Filing_Status', str(root.get('category')));
        putIf(org, 'Entity_Type', str(root.get('entityType')));
        putIf(org, 'State_Of_Incorporation', str(root.get('stateOfIncorporation')));

        Map<String, Object> biz = asMap(asMap(root.get('addresses')).get('business'));
        org.address = str(biz.get('street1'));
        org.city = str(biz.get('city'));
        org.state = str(biz.get('stateOrCountry'));
        org.postalCode = str(biz.get('zipCode'));
        String website = str(root.get('website'));
        org.website = String.isBlank(website) ? null : website; // often blank -> null

        org.sourceConfidence = org.hasDeterministicId()
            ? OA_ConfidenceEvaluator.HIGH
            : (String.isNotBlank(name) ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW);
        org.sourcePayloadHash = org.payloadHash();
        out.add(org);
        return out;
    }

    private static String joinList(Object listObj) {
        if (!(listObj instanceof List<Object>)) { return null; }
        List<String> vals = new List<String>();
        for (Object o : (List<Object>) listObj) {
            if (o != null && String.isNotBlank(String.valueOf(o))) { vals.add(String.valueOf(o)); }
        }
        return vals.isEmpty() ? null : String.join(vals, ',');
    }
    private static Map<String, Object> asMap(Object o) {
        return (o instanceof Map<String, Object>) ? (Map<String, Object>) o : new Map<String, Object>();
    }
    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) { org.attributes.put(key, value); }
    }
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
}
