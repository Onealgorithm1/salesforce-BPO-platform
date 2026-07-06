/**
 * OA_GrantsParser — parses a Grants.gov Search2 response into normalized rows (Connector SDK).
 *
 * Owns the Grants.gov response-shape knowledge and returns generic OA_ConnectorRow objects.
 * Guards a malformed body by throwing OA_ConnectorException (the engine records a parse
 * error) rather than letting a raw JSON exception propagate.
 *
 * Expected shape (subset):
 *   { "errorcode": 0, "msg": "SUCCESS",
 *     "data": { "hitCount": N, "oppHits": [ {
 *         "id": "358001", "number": "ABC-2026-001", "title": "...",
 *         "agencyCode": "HHS-ACF", "agency": "...", "oppStatus": "posted",
 *         "docType": "synopsis", "openDate": "01/15/2026", "closeDate": "03/15/2026",
 *         "cfdaList": ["93.123"], "alnist": ["93.123"] } ] } }
 *
 * A missing or non-list 'oppHits' yields zero rows (a clean, empty outcome).
 */
public class OA_GrantsParser implements OA_IConnectorParser {

    private static final String DETAIL_BASE = 'https://www.grants.gov/search-results-detail/';

    public List<OA_ConnectorRow> parse(String body) {
        List<OA_ConnectorRow> out = new List<OA_ConnectorRow>();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new OA_ConnectorException('Grants: malformed response body — ' + e.getMessage());
        }

        Map<String, Object> data = asMap(parsed.get('data'));
        Object hitsObj = data.get('oppHits');
        if (!(hitsObj instanceof List<Object>)) {
            // Missing or non-list 'oppHits' -> no rows (clean, empty outcome).
            return out;
        }

        for (Object o : (List<Object>) hitsObj) {
            if (!(o instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> hit = (Map<String, Object>) o;

            OA_ConnectorRow r = new OA_ConnectorRow();
            String oppId = str(hit.get('id'));
            r.put('oppId',             oppId);
            r.put('opportunityNumber', str(hit.get('number')));
            r.put('title',             str(hit.get('title')));
            r.put('agencyCode',        str(hit.get('agencyCode')));
            r.put('agencyName',        str(hit.get('agency')));
            r.put('oppStatus',         str(hit.get('oppStatus')));
            r.put('docType',           str(hit.get('docType')));
            r.put('openDate',          str(hit.get('openDate')));
            r.put('closeDate',         str(hit.get('closeDate')));
            r.put('cfdaNumbers',       extractCfda(hit));
            if (String.isNotBlank(oppId)) {
                r.put('opportunityUrl', DETAIL_BASE + oppId);
            }

            out.add(r);
        }
        return out;
    }

    /** Join CFDA/ALN numbers into a compact, staging-friendly string. Prefers cfdaList, falls back to alnist. */
    private String extractCfda(Map<String, Object> hit) {
        List<String> codes = collectStrings(hit.get('cfdaList'));
        if (codes.isEmpty()) {
            codes = collectStrings(hit.get('alnist'));
        }
        return codes.isEmpty() ? null : String.join(codes, ',');
    }

    private List<String> collectStrings(Object listObj) {
        List<String> codes = new List<String>();
        if (listObj instanceof List<Object>) {
            for (Object item : (List<Object>) listObj) {
                String code = str(item);
                if (String.isNotBlank(code)) {
                    codes.add(code);
                }
            }
        }
        return codes;
    }

    private static Map<String, Object> asMap(Object o) {
        return (o instanceof Map<String, Object>)
            ? (Map<String, Object>) o
            : new Map<String, Object>();
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
