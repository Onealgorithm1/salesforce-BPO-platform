public class OA_USASpendingClient {

    private static final String ENDPOINT =
        'https://api.usaspending.gov/api/v2/search/spending_by_award/';

    // No auth required — USASpending.gov is a public federal open-data API.

    public class AwardResult {
        public String  awardId;
        public String  recipientName;
        public String  recipientUei;
        public Decimal awardAmount;
        public String  awardingAgency;
        public String  awardingSubAgency;
        public String  contractType;
        public String  state;
        public String  description;
    }

    // Search by recipient name — returns top N awards sorted by total amount descending.
    // Safe to call from Schedulable via @future(callout=true) or from a Flow action.
    public static List<AwardResult> searchByRecipient(String recipientName, Integer limitResults) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(buildBody(recipientName, limitResults != null ? limitResults : 5));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('[OA_USASpendingClient] HTTP ' + res.getStatusCode()
                + ' for "' + recipientName + '": ' + res.getBody().abbreviate(400));
            return new List<AwardResult>();
        }

        return parse(res.getBody());
    }

    private static String buildBody(String recipientName, Integer lim) {
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

    private static List<AwardResult> parse(String body) {
        List<AwardResult> out = new List<AwardResult>();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> rows = (List<Object>) parsed.get('results');
        if (rows == null) return out;

        for (Object o : rows) {
            Map<String, Object> row = (Map<String, Object>) o;
            AwardResult a    = new AwardResult();
            a.awardId        = (String) row.get('Award ID');
            a.recipientName  = (String) row.get('Recipient Name');
            a.recipientUei   = (String) row.get('recipient_uei');
            Object amt       = row.get('Award Amount');
            a.awardAmount    = amt != null ? Decimal.valueOf(String.valueOf(amt)) : null;
            a.awardingAgency = (String) row.get('Awarding Agency');
            a.awardingSubAgency = (String) row.get('Awarding Sub Agency');
            a.contractType   = (String) row.get('Contract Award Type');
            a.state          = (String) row.get('Place of Performance State Code');
            a.description    = row.get('Description') != null
                               ? ((String) row.get('Description')).abbreviate(500) : null;
            out.add(a);
        }
        return out;
    }
}