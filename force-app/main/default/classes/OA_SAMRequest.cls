/**
 * OA_SAMRequest — builds the SAM.gov Entity API GET request (Connector SDK, dormant).
 *
 * Routes through the OA_SAM Named Credential ('callout:OA_SAM/entity-information/v3/entities').
 * The data.gov API key is injected as an 'X-Api-Key' header by the OA_SAM External
 * Credential — this builder NEVER puts the key (or an 'api_key=' query param) in the URL,
 * so no secret appears in the endpoint, logs, or this repository.
 *
 * Input contract: a String. If it matches the 12-char UEI shape it is sent as `ueiSAM`;
 * otherwise it is sent as `legalBusinessName`. No live callout is ever made here — the
 * request is only sent through OA_ConnectorHttp, which is mocked in every test.
 */
public class OA_SAMRequest implements OA_IConnectorRequest {

    @TestVisible
    private static final String BASE_PATH =
        'callout:OA_SAM/entity-information/v3/entities';

    // Sections requested from the Entity API (identity + certification only for staging).
    private static final String INCLUDE_SECTIONS = 'entityRegistration,coreData';

    private static final Integer DEFAULT_PAGE_SIZE = 1;

    public HttpRequest build(OA_ConnectorContext ctx, Object input) {
        String term = input == null ? null : String.valueOf(input).trim();

        // Record the search term so the mapper can stamp it for this input.
        ctx.config.put('searchTerm', term);

        Integer size = DEFAULT_PAGE_SIZE;
        Object cfgSize = ctx.config.get('pageSize');
        if (cfgSize != null) {
            size = Integer.valueOf(String.valueOf(cfgSize));
        }

        String searchParam = buildSearchParam(term);
        String endpoint = BASE_PATH
            + '?' + searchParam
            + '&includeSections=' + INCLUDE_SECTIONS
            + '&page=0'
            + '&size=' + size;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        // NO api_key here — the X-Api-Key header is added by the OA_SAM External Credential.
        req.setTimeout(30000);
        return req;
    }

    /** UEI is exactly 12 alphanumeric chars; anything else is treated as a legal name search. */
    @TestVisible
    private String buildSearchParam(String term) {
        if (String.isNotBlank(term) && term.length() == 12 && term.isAlphanumeric()) {
            return 'ueiSAM=' + EncodingUtil.urlEncode(term, 'UTF-8');
        }
        String safe = String.isBlank(term) ? '' : term;
        return 'legalBusinessName=' + EncodingUtil.urlEncode(safe, 'UTF-8');
    }
}