/**
 * OA_GrantsRequest — builds the Grants.gov Search2 request (Connector SDK, dormant).
 *
 * Routes through the OA_Grants Named Credential
 * ('callout:OA_Grants/v1/api/search2'). Grants.gov Search2 is a PUBLIC, keyless REST
 * endpoint — this builder sends NO API key, NO Authorization header, and NO secret of
 * any kind. Nothing here (or anywhere in this connector) references a credential secret.
 *
 * Input contract: a String keyword (e.g. an agency name, NAICS keyword, or topic). The
 * search body defaults to open ('posted') opportunities — the timing-signal use case —
 * and a small page size. Both are overridable via ctx.config ('oppStatuses', 'pageSize').
 *
 * No live callout is ever made here — the request is only sent through OA_ConnectorHttp,
 * which is mocked in every test.
 */
public class OA_GrantsRequest implements OA_IConnectorRequest {

    @TestVisible
    private static final String SEARCH_PATH = 'callout:OA_Grants/v1/api/search2';

    // Open opportunities are the outreach-timing signal; overridable via config.
    @TestVisible
    private static final String DEFAULT_OPP_STATUSES = 'posted';

    // Modest default page — v1 is a manual, single-callout run (governor-safe).
    private static final Integer DEFAULT_ROWS = 10;
    private static final Integer MAX_ROWS = 25;

    public HttpRequest build(OA_ConnectorContext ctx, Object input) {
        String keyword = input == null ? null : String.valueOf(input).trim();

        // Record the search term so the mapper can stamp it for this input.
        ctx.config.put('searchTerm', keyword);

        Integer rows = DEFAULT_ROWS;
        Object cfgRows = ctx.config.get('pageSize');
        if (cfgRows != null) {
            rows = Integer.valueOf(String.valueOf(cfgRows));
        }
        if (rows < 1) { rows = DEFAULT_ROWS; }
        if (rows > MAX_ROWS) { rows = MAX_ROWS; }

        String oppStatuses = DEFAULT_OPP_STATUSES;
        Object cfgStatuses = ctx.config.get('oppStatuses');
        if (cfgStatuses != null && String.isNotBlank(String.valueOf(cfgStatuses))) {
            oppStatuses = String.valueOf(cfgStatuses);
        }

        // Search2 is a POST with a JSON body. Keyword is left blank-safe.
        Map<String, Object> payload = new Map<String, Object>{
            'keyword'        => (keyword == null ? '' : keyword),
            'oppStatuses'    => oppStatuses,
            'rows'           => rows,
            'startRecordNum' => 0
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SEARCH_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000);
        return req;
    }
}
