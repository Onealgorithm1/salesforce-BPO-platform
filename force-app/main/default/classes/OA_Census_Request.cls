/**
 * OA_Census_Request — builds a U.S. Census County Business Patterns request (Census-specific).
 * Reads Named Credential + path from the registry. Census is a PUBLIC API (key optional; none sent
 * here). Input is a state FIPS code (e.g. '51'); the connector enriches an existing organization
 * with aggregate market context for that geography — it never identifies an organization.
 */
public with sharing class OA_Census_Request {

    private static final String DEFAULT_NC = 'OA_Census';
    private static final String DEFAULT_PATH = '/data/2021/cbp';
    private static final String GET_VARS = 'ESTAB,EMP,PAYANN,NAICS2017_LABEL';

    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String nc = (cfg != null && String.isNotBlank(cfg.Named_Credential__c)) ? cfg.Named_Credential__c : DEFAULT_NC;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c)) ? cfg.Endpoint_Path__c : DEFAULT_PATH;
        String stateFips = String.isBlank(input) ? '' : input.trim();

        String endpoint = 'callout:' + nc + path
            + '?get=' + GET_VARS
            + '&for=' + EncodingUtil.urlEncode('state:' + stateFips, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);
        return req;
    }
}
