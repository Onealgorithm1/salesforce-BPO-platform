/**
 * OA_StateRegistry_Request — generic Secretary-of-State / business-registry request builder.
 *
 * State-agnostic: the state-specific Named Credential + endpoint path come from the connector
 * registry (OA_Connector_Registry__mdt), NOT hardcoded. Input is a business name or entity number.
 * A concrete state connector (extending OA_StateRegistry_Template) reuses this unchanged.
 */
public with sharing class OA_StateRegistry_Request {

    private static final String DEFAULT_NC = 'OA_StateRegistry';
    private static final String DEFAULT_PATH = '/search';

    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String nc = (cfg != null && String.isNotBlank(cfg.Named_Credential__c)) ? cfg.Named_Credential__c : DEFAULT_NC;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c)) ? cfg.Endpoint_Path__c : DEFAULT_PATH;
        String term = input == null ? '' : input.trim();

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path + '?q=' + EncodingUtil.urlEncode(term, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);
        return req;
    }
}