/**
 * OA_USASpending_Request — builds the USASpending spending_by_award POST (USASpending-specific).
 *
 * Reads Named Credential + endpoint path from OA_Connector_Registry__mdt (no hardcoded
 * registration). USASpending is a PUBLIC, keyless API — no secret is ever sent.
 */
public with sharing class OA_USASpending_Request {

    private static final String DEFAULT_NC = 'OA_USASpending';
    private static final String DEFAULT_PATH = '/api/v2/search/spending_by_award/';
    private static final Integer DEFAULT_LIMIT = 100;

    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String nc = (cfg != null && String.isNotBlank(cfg.Named_Credential__c)) ? cfg.Named_Credential__c : DEFAULT_NC;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c)) ? cfg.Endpoint_Path__c : DEFAULT_PATH;
        String term = input == null ? '' : input.trim();

        Map<String, Object> body = new Map<String, Object>{
            'filters' => new Map<String, Object>{
                'recipient_search_text' => new List<String>{ term },
                'award_type_codes' => new List<String>{ 'A', 'B', 'C', 'D' }
            },
            'fields' => new List<String>{
                'Award ID', 'Recipient Name', 'Recipient UEI', 'Award Amount', 'Awarding Agency',
                'Start Date', 'recipient_id', 'Parent Recipient Name', 'Place of Performance State Code' },
            'page' => 1,
            'limit' => DEFAULT_LIMIT,
            'sort' => 'Award Amount',
            'order' => 'desc'
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(30000);
        return req;
    }
}
