/**
 * OA_Census_ResponseParser — parses Census array-of-arrays into canonical CONTEXT records.
 *
 * IMPORTANT: Census is AGGREGATE (a geography/industry), not an organization. Each parsed
 * OA_CanonicalOrg therefore has NO identity (name/UEI/EIN null) — it carries only market-context
 * attributes for the geography. Confidence is NONE (context, not an entity). It is meant to enrich
 * an EXISTING organization matched by state/NAICS, never to identify or create one.
 *
 * Response shape: a JSON array of arrays; row 0 = headers, rows 1..N = values, e.g.
 *   [ ["ESTAB","EMP","PAYANN","NAICS2017_LABEL","state"], ["12345","67890","234567","Prof...", "51"] ]
 */
public with sharing class OA_Census_ResponseParser {

    public class ParseException extends Exception {}

    public List<OA_CanonicalOrg> parse(String body) {
        List<Object> rows;
        try {
            rows = (List<Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new ParseException('Census: malformed response body (expected array-of-arrays) — ' + e.getMessage());
        }
        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        if (rows == null || rows.size() < 2 || !(rows[0] instanceof List<Object>)) {
            return out; // no header + data -> nothing (graceful)
        }

        // header -> index
        Map<String, Integer> idx = new Map<String, Integer>();
        List<Object> header = (List<Object>) rows[0];
        for (Integer i = 0; i < header.size(); i++) {
            idx.put(String.valueOf(header[i]), i);
        }

        for (Integer r = 1; r < rows.size(); r++) {
            if (!(rows[r] instanceof List<Object>)) { continue; }
            List<Object> row = (List<Object>) rows[r];
            OA_CanonicalOrg org = new OA_CanonicalOrg();
            org.sourceSystem = 'Census';
            // NO identity — context only.
            org.state = cell(row, idx, 'state');
            putIf(org, 'Census_Establishments', cell(row, idx, 'ESTAB'));
            putIf(org, 'Census_Employment', cell(row, idx, 'EMP'));
            putIf(org, 'Census_Annual_Payroll', cell(row, idx, 'PAYANN'));
            putIf(org, 'Census_Industry_Label', cell(row, idx, 'NAICS2017_LABEL'));
            putIf(org, 'Census_Geography', org.state);
            // Context, not an entity -> NONE confidence.
            org.sourceConfidence = OA_ConfidenceEvaluator.NONE;
            org.sourcePayloadHash = org.payloadHash();
            out.add(org);
        }
        return out;
    }

    private static String cell(List<Object> row, Map<String, Integer> idx, String col) {
        Integer i = idx.get(col);
        if (i == null || i >= row.size() || row[i] == null) { return null; }
        return String.valueOf(row[i]);
    }
    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) { org.attributes.put(key, value); }
    }
}