/**
 * OA_SEC_Request — builds the SEC EDGAR submissions request (SEC-specific).
 *
 * Reads Named Credential + path from the registry. SEC EDGAR is PUBLIC (no key) but REQUIRES a
 * descriptive User-Agent header per SEC access policy — set here (not a secret). Input is a CIK
 * (zero-padded to 10 digits for the submissions endpoint).
 */
public with sharing class OA_SEC_Request {

    private static final String DEFAULT_NC = 'OA_SEC';
    private static final String DEFAULT_PATH = '/submissions';
    // SEC requires a descriptive UA identifying the requester; not a secret.
    private static final String USER_AGENT = 'OneAlgorithm LeadEnrichment (lrubino@onealgorithm.com)';

    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String nc = (cfg != null && String.isNotBlank(cfg.Named_Credential__c)) ? cfg.Named_Credential__c : DEFAULT_NC;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c)) ? cfg.Endpoint_Path__c : DEFAULT_PATH;
        String cik = padCik(input);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path + '/CIK' + cik + '.json');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', USER_AGENT);
        req.setTimeout(30000);
        return req;
    }

    /** SEC submissions endpoint expects a 10-digit zero-padded CIK. */
    @TestVisible
    private String padCik(String input) {
        String digits = input == null ? '' : input.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) { return '0000000000'; }
        return digits.leftPad(10, '0').right(10);
    }
}
