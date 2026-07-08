/**
 * OA_SAMOpportunities_ResponseParser — SAM Get Opportunities response -> normalized rows.
 *
 * Implements the SDK foundation contract (OA_IConnectorParser). Owns all SAM
 * response-shape knowledge; returns generic OA_ConnectorRow objects. Tolerates
 * unknown fields; throws OA_ConnectorException on an unparseable body so the
 * engine records a parse outcome (one bad response never aborts the run).
 *
 * Response shape:
 *   { "totalRecords": N, "limit": L, "offset": O,
 *     "opportunitiesData": [ { noticeId, title, solicitationNumber,
 *       fullParentPathName, naicsCode|naicsCodes[], classificationCode,
 *       typeOfSetAside, typeOfSetAsideDescription,
 *       placeOfPerformance:{city:{name}, state:{code}}, postedDate,
 *       responseDeadLine, award:{amount}, active, type, uiLink } ] }
 * Each row also carries `totalRecords` so the service can paginate.
 */
public with sharing class OA_SAMOpportunities_ResponseParser implements OA_IConnectorParser {

    public List<OA_ConnectorRow> parse(String body) {
        List<OA_ConnectorRow> rows = new List<OA_ConnectorRow>();
        if (String.isBlank(body)) {
            return rows;
        }
        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new OA_ConnectorException('SAM Opportunities: unparseable JSON body: ' + e.getMessage());
        }
        if (!(parsed instanceof Map<String, Object>)) {
            throw new OA_ConnectorException('SAM Opportunities: unexpected top-level JSON (expected object).');
        }
        Map<String, Object> root = (Map<String, Object>) parsed;

        // SAM error responses carry an `error` object / message.
        if (root.get('error') != null) {
            throw new OA_ConnectorException('SAM Opportunities returned error: '
                + String.valueOf(root.get('error')));
        }

        Object totalObj = root.get('totalRecords');
        String total = totalObj == null ? null : String.valueOf(totalObj);

        Object data = root.get('opportunitiesData');
        if (!(data instanceof List<Object>)) {
            return rows; // no results block -> empty (not an error)
        }
        for (Object o : (List<Object>) data) {
            if (!(o instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> h = (Map<String, Object>) o;
            OA_ConnectorRow row = new OA_ConnectorRow();
            row.put('noticeId', h.get('noticeId'));
            row.put('title', h.get('title'));
            row.put('solicitationNumber', h.get('solicitationNumber'));
            row.put('agency', h.get('fullParentPathName'));
            row.put('naics', naics(h));
            row.put('psc', h.get('classificationCode'));
            row.put('setAside', firstNonBlank(
                asString(h.get('typeOfSetAsideDescription')), asString(h.get('typeOfSetAside'))));
            row.put('placeOfPerformance', placeOfPerformance(h.get('placeOfPerformance')));
            row.put('postedDate', h.get('postedDate'));
            row.put('responseDeadLine', h.get('responseDeadLine'));
            row.put('value', awardAmount(h.get('award')));
            row.put('active', h.get('active'));
            row.put('type', h.get('type'));
            row.put('uiLink', h.get('uiLink'));
            row.put('totalRecords', total);
            rows.add(row);
        }
        return rows;
    }

    private static String naics(Map<String, Object> h) {
        Object single = h.get('naicsCode');
        if (single != null && String.isNotBlank(String.valueOf(single))) {
            return String.valueOf(single);
        }
        Object multi = h.get('naicsCodes');
        if (multi instanceof List<Object>) {
            List<String> parts = new List<String>();
            for (Object c : (List<Object>) multi) {
                if (c != null) { parts.add(String.valueOf(c)); }
            }
            return parts.isEmpty() ? null : String.join(parts, ', ');
        }
        return null;
    }

    private static String placeOfPerformance(Object pop) {
        if (!(pop instanceof Map<String, Object>)) {
            return null;
        }
        Map<String, Object> m = (Map<String, Object>) pop;
        String city = nestedName(m.get('city'));
        String state = firstNonBlank(nestedCode(m.get('state')), nestedName(m.get('state')));
        List<String> parts = new List<String>();
        if (String.isNotBlank(city)) { parts.add(city); }
        if (String.isNotBlank(state)) { parts.add(state); }
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static String awardAmount(Object award) {
        if (award instanceof Map<String, Object>) {
            Object amt = ((Map<String, Object>) award).get('amount');
            return amt == null ? null : String.valueOf(amt);
        }
        return null;
    }

    private static String nestedName(Object o) {
        return (o instanceof Map<String, Object>) ? asString(((Map<String, Object>) o).get('name')) : null;
    }
    private static String nestedCode(Object o) {
        return (o instanceof Map<String, Object>) ? asString(((Map<String, Object>) o).get('code')) : null;
    }
    private static String asString(Object o) {
        return o == null ? null : String.valueOf(o);
    }
    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : (String.isNotBlank(b) ? b : null);
    }
}
