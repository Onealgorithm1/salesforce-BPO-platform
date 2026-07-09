/**
 * OA_USASpendingRequest — builds the USASpending search request (Connector SDK).
 *
 * Sprint 1C-1: re-homes the proven request-body logic from OA_USASpendingClient
 * onto the SDK contract (OA_IConnectorRequest). Behavior-preserving.
 *
 * Sprint 1C-2: endpoint now routes through the OA_USASpending Named Credential
 * ('callout:OA_USASpending/...'). USASpending.gov is a public API — the Named
 * Credential uses no authentication and holds no secret.
 */
public class OA_USASpendingRequest implements OA_IConnectorRequest {

    @TestVisible
    private static final String ENDPOINT =
        'callout:OA_USASpending/api/v2/search/spending_by_award/';

    private static final Integer DEFAULT_LIMIT = 5;

    public HttpRequest build(OA_ConnectorContext ctx, Object input) {
        String recipientName = input == null ? null : String.valueOf(input);

        // Record the search term so the mapper can stamp Search_Term__c for this input.
        ctx.config.put('searchTerm', recipientName);

        Integer lim = DEFAULT_LIMIT;
        Object cfgLim = ctx.config.get('limit');
        if (cfgLim != null) {
            lim = Integer.valueOf(String.valueOf(cfgLim));
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(buildBody(recipientName, lim));
        req.setTimeout(30000);
        return req;
    }

    @TestVisible
    private String buildBody(String recipientName, Integer lim) {
        Map<String, Object> filters = new Map<String, Object>{
            'recipient_search_text' => new List<String>{ recipientName },
            'award_type_codes'      => new List<String>{ 'A', 'B', 'C', 'D' }
        };
        Map<String, Object> body = new Map<String, Object>{
            'filters' => filters,
            'fields'  => new List<String>{
                'Award ID', 'Recipient Name', 'recipient_uei',
                'Award Amount', 'Awarding Agency', 'Awarding Sub Agency',
                'Contract Award Type', 'Place of Performance State Code', 'Description'
            },
            'page'  => 1,
            'limit' => lim,
            'sort'  => 'Award Amount',
            'order' => 'desc'
        };
        return JSON.serialize(body);
    }
}