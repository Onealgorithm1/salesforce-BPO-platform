/**
 * OA_SAM_Request — builds the SAM.gov Entity API request (SAM-specific).
 *
 * Reads the endpoint path + Named Credential from the connector registry
 * (OA_Connector_Registry__mdt) so registration is metadata-driven, not hardcoded. The
 * data.gov API key is injected as an 'X-Api-Key' header by the OA_SAM External Credential —
 * this builder NEVER puts a key (or api_key= param) in the URL, so no secret appears in the
 * endpoint, logs, or source.
 *
 * All SAM-specific request knowledge lives here; the enrichment platform stays connector-agnostic.
 */
public with sharing class OA_SAM_Request {

    private static final String DEFAULT_NAMED_CRED = 'OA_SAM';
    private static final String DEFAULT_PATH = '/entity-information/v3/entities';
    // Identity + certification sections only (keeps the response lean; no PII bulk).
    private static final String INCLUDE_SECTIONS = 'entityRegistration,coreData';

    /** Build the GET request for one input (a 12-char UEI, else a legal-name search). */
    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String namedCred = (cfg != null && String.isNotBlank(cfg.Named_Credential__c))
            ? cfg.Named_Credential__c : DEFAULT_NAMED_CRED;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c))
            ? cfg.Endpoint_Path__c : DEFAULT_PATH;

        String term = input == null ? '' : input.trim();
        String searchParam = buildSearchParam(term);

        String endpoint = 'callout:' + namedCred + path
            + '?' + searchParam
            + '&includeSections=' + INCLUDE_SECTIONS
            + '&page=0&size=1';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        // NO api_key here — X-Api-Key is added by the OA_SAM External Credential.
        req.setTimeout(30000);
        return req;
    }

    /** A 12-char alphanumeric term is a UEI (ueiSAM); anything else is a legal-name search. */
    @TestVisible
    private String buildSearchParam(String term) {
        if (String.isNotBlank(term) && term.length() == 12 && term.isAlphanumeric()) {
            return 'ueiSAM=' + EncodingUtil.urlEncode(term, 'UTF-8');
        }
        String safe = String.isBlank(term) ? '' : term;
        return 'legalBusinessName=' + EncodingUtil.urlEncode(safe, 'UTF-8');
    }
}
