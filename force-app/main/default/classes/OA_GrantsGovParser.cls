/**
 * OA_GrantsGovParser — turns a Grants.gov Search2 response body into normalized rows.
 *
 * Implements the SDK foundation contract (OA_IConnectorParser). Owns all
 * source-specific JSON knowledge; returns generic OA_ConnectorRow objects.
 * Throws OA_ConnectorException on a body it cannot parse (or a Grants.gov
 * error payload) so the engine records a parse/HTTP outcome rather than aborting.
 *
 * Search2 response shape (verified live 2026-07-08):
 *   { "errorcode":0, "msg":"...", "data": { "hitCount":N,
 *     "oppHits":[ {id,number,title,agencyCode,agency,openDate,closeDate,
 *                  oppStatus,docType,cfdaList[]} ] } }
 */
public with sharing class OA_GrantsGovParser implements OA_IConnectorParser {

    public List<OA_ConnectorRow> parse(String body) {
        List<OA_ConnectorRow> rows = new List<OA_ConnectorRow>();
        if (String.isBlank(body)) {
            return rows;
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new OA_ConnectorException('Grants.gov: unparseable JSON body: ' + e.getMessage());
        }

        if (!(parsed instanceof Map<String, Object>)) {
            throw new OA_ConnectorException('Grants.gov: unexpected top-level JSON (expected object).');
        }
        Map<String, Object> root = (Map<String, Object>) parsed;

        Object ec = root.get('errorcode');
        if (ec != null && Decimal.valueOf(String.valueOf(ec)) != 0) {
            throw new OA_ConnectorException('Grants.gov returned error: '
                + String.valueOf(root.get('msg')));
        }

        Object dataObj = root.get('data');
        if (!(dataObj instanceof Map<String, Object>)) {
            return rows; // no data block -> zero results
        }
        Object hits = ((Map<String, Object>) dataObj).get('oppHits');
        if (!(hits instanceof List<Object>)) {
            return rows; // no hits -> empty (not an error)
        }

        for (Object o : (List<Object>) hits) {
            if (!(o instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> h = (Map<String, Object>) o;
            OA_ConnectorRow row = new OA_ConnectorRow();
            row.put('id', h.get('id'));
            row.put('number', h.get('number'));
            row.put('title', h.get('title'));
            row.put('agency', h.get('agency'));
            row.put('agencyCode', h.get('agencyCode'));
            row.put('openDate', h.get('openDate'));
            row.put('closeDate', h.get('closeDate'));
            row.put('oppStatus', h.get('oppStatus'));
            row.put('docType', h.get('docType'));

            Object cfda = h.get('cfdaList');
            if (cfda instanceof List<Object>) {
                List<String> parts = new List<String>();
                for (Object c : (List<Object>) cfda) {
                    if (c != null) { parts.add(String.valueOf(c)); }
                }
                row.put('cfda', String.join(parts, ', '));
            }
            rows.add(row);
        }
        return rows;
    }
}
