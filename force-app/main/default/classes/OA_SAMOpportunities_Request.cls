/**
 * OA_SAMOpportunities_Request — builds the SAM.gov Get Opportunities GET request.
 *
 * Opportunity Intelligence (Program 2) Phase 2. Implements the certified SDK
 * foundation contract (OA_IConnectorRequest). Routes exclusively through the
 * OA_SAM_Opportunities Named/External Credential (ADR-008): the data.gov API key
 * is injected as the `X-Api-Key` header by the External Credential — it is NEVER
 * placed in the URL, Apex, config, or logs (secret hygiene).
 *
 * Endpoint: GET callout:OA_SAM_Opportunities/opportunities/v2/search
 *   Required: postedFrom, postedTo (MM/dd/yyyy, <= 1-year window)
 *   Paging:   limit (<=1000), offset
 *   Filters:  ncode (NAICS), typeOfSetAside, ptype, status, ccode (PSC), state
 * All values come from the run-scoped context config (no secrets among them).
 */
public with sharing class OA_SAMOpportunities_Request implements OA_IConnectorRequest {

    public HttpRequest build(OA_ConnectorContext ctx, Object input) {
        Map<String, Object> cfg = (ctx != null && ctx.config != null)
            ? ctx.config : new Map<String, Object>();

        String nc = str(cfg.get('namedCredential'), 'OA_SAM_Opportunities');
        String path = str(cfg.get('endpointPath'), '/opportunities/v2/search');

        // `input` (when supplied) is the page offset for this call; else read cfg.
        Integer offset = (input instanceof Integer)
            ? (Integer) input
            : intOf(cfg.get('offset'), 0);
        Integer limitSize = Math.min(intOf(cfg.get('limit'), 100), 1000);

        List<String> qs = new List<String>();
        addParam(qs, 'postedFrom', str(cfg.get('postedFrom'), null));
        addParam(qs, 'postedTo', str(cfg.get('postedTo'), null));
        addParam(qs, 'limit', String.valueOf(limitSize));
        addParam(qs, 'offset', String.valueOf(offset));
        addParam(qs, 'ptype', str(cfg.get('ptype'), null));          // procurement type
        addParam(qs, 'status', str(cfg.get('status'), 'active'));
        addParam(qs, 'ncode', str(cfg.get('ncode'), null));          // NAICS filter
        addParam(qs, 'typeOfSetAside', str(cfg.get('typeOfSetAside'), null));
        addParam(qs, 'ccode', str(cfg.get('ccode'), null));          // PSC filter
        addParam(qs, 'state', str(cfg.get('state'), null));

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path + '?' + String.join(qs, '&'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        return req;
    }

    private static void addParam(List<String> qs, String key, String val) {
        if (String.isNotBlank(val)) {
            qs.add(key + '=' + EncodingUtil.urlEncode(val, 'UTF-8'));
        }
    }
    private static String str(Object v, String dflt) {
        return v == null ? dflt : String.valueOf(v);
    }
    private static Integer intOf(Object v, Integer dflt) {
        return v == null ? dflt : Integer.valueOf(String.valueOf(v));
    }
}
