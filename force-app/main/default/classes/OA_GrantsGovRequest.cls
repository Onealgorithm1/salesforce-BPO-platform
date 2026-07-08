/**
 * OA_GrantsGovRequest — builds the Grants.gov Search2 POST request for one input.
 *
 * Opportunity Intelligence (Program 2) Phase 1. Implements the certified SDK
 * foundation contract (OA_IConnectorRequest) — the SDK owns transport; this class
 * only shapes the request. Routes exclusively through a Named Credential
 * (ADR-008); no secret material (Grants.gov Search2 is a public, keyless API).
 *
 * Endpoint: POST callout:OA_GrantsGov/v1/api/search2  (public, no auth)
 * The per-input Object is treated as a keyword string; run-scoped config
 * (rows, oppStatuses, namedCredential, endpointPath) comes from the context.
 */
public with sharing class OA_GrantsGovRequest implements OA_IConnectorRequest {

    public HttpRequest build(OA_ConnectorContext ctx, Object input) {
        Map<String, Object> cfg = (ctx != null && ctx.config != null)
            ? ctx.config : new Map<String, Object>();

        String nc = cfg.containsKey('namedCredential')
            ? String.valueOf(cfg.get('namedCredential')) : 'OA_GrantsGov';
        String path = cfg.containsKey('endpointPath')
            ? String.valueOf(cfg.get('endpointPath')) : '/v1/api/search2';

        String keyword = (input != null) ? String.valueOf(input)
            : (cfg.containsKey('keyword') ? String.valueOf(cfg.get('keyword')) : '');
        Integer rows = cfg.containsKey('rows')
            ? Integer.valueOf(String.valueOf(cfg.get('rows'))) : 25;
        String oppStatuses = cfg.containsKey('oppStatuses')
            ? String.valueOf(cfg.get('oppStatuses')) : 'posted';

        Map<String, Object> body = new Map<String, Object>{
            'keyword' => keyword,
            'rows' => rows,
            'oppStatuses' => oppStatuses
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(body));
        return req;
    }
}
