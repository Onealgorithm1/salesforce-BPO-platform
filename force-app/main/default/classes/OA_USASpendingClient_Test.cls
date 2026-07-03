/**
 * Unit tests for OA_USASpendingClient.
 *
 * Fully mocked (HttpCalloutMock) — NEVER calls the live USASpending.gov endpoint,
 * performs zero DML, and touches no org records. Covers the client's success,
 * non-200, empty-result, missing-key, null-input, and malformed-response paths.
 *
 * Sprint: Connector track — coverage backfill for the already-deployed,
 * pre-SDK USASpending client (roadmap 1C will later re-home this onto the SDK).
 */
@isTest
private class OA_USASpendingClient_Test {

    private static final String ENDPOINT =
        'https://api.usaspending.gov/api/v2/search/spending_by_award/';

    /**
     * Configurable callout mock. Captures the outbound request so tests can assert
     * the client built it correctly, and returns a canned status + body.
     */
    private class Mock implements HttpCalloutMock {
        Integer statusCode;
        String  body;
        HttpRequest captured;

        Mock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }

        public HttpResponse respond(HttpRequest req) {
            this.captured = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            if (body != null) res.setBody(body);
            return res;
        }
    }

    // Builds a well-formed USASpending results payload with `count` rows.
    private static String buildResultsJson(Integer count, Boolean withNulls) {
        List<Object> rows = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> row = new Map<String, Object>{
                'Award ID'                        => 'CONT_AWD_' + i,
                'Recipient Name'                  => 'ACME DEFENSE LLC ' + i,
                'recipient_uei'                   => 'UEI' + i + 'ABCDE',
                'Award Amount'                    => 100000 + i,
                'Awarding Agency'                 => 'Department of Defense',
                'Awarding Sub Agency'             => 'Department of the Navy',
                'Contract Award Type'             => 'DEFINITIVE CONTRACT',
                'Place of Performance State Code' => 'VA',
                'Description'                     => 'IT SUPPORT SERVICES ' + i
            };
            if (withNulls && i == 0) {
                // Exercise the null-amount and null-description branches in parse().
                row.put('Award Amount', null);
                row.put('Description', null);
            }
            rows.add(row);
        }
        return JSON.serialize(new Map<String, Object>{ 'results' => rows });
    }

    @isTest
    static void testSuccessMapsAllFields() {
        Mock mock = new Mock(200, buildResultsJson(2, true));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('ACME DEFENSE LLC', 5);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both rows should be parsed');

        // Row 0 exercises the null branches.
        OA_USASpendingClient.AwardResult r0 = results[0];
        System.assertEquals('CONT_AWD_0', r0.awardId, 'Award ID mapped');
        System.assertEquals('ACME DEFENSE LLC 0', r0.recipientName, 'Recipient Name mapped');
        System.assertEquals('UEI0ABCDE', r0.recipientUei, 'UEI mapped');
        System.assertEquals(null, r0.awardAmount, 'Null amount handled without error');
        System.assertEquals(null, r0.description, 'Null description handled without error');
        System.assertEquals('VA', r0.state, 'State mapped');

        // Row 1 exercises fully-populated mapping incl. Decimal parse.
        OA_USASpendingClient.AwardResult r1 = results[1];
        System.assertEquals(100001, r1.awardAmount, 'Amount parsed to Decimal');
        System.assertEquals('Department of Defense', r1.awardingAgency, 'Agency mapped');
        System.assertEquals('Department of the Navy', r1.awardingSubAgency, 'Sub-agency mapped');
        System.assertEquals('DEFINITIVE CONTRACT', r1.contractType, 'Contract type mapped');
        System.assert(r1.description.startsWith('IT SUPPORT SERVICES'), 'Description mapped');

        // Assert the client built the request correctly.
        System.assertEquals(ENDPOINT, mock.captured.getEndpoint(), 'Endpoint matches USASpending v2');
        System.assertEquals('POST', mock.captured.getMethod(), 'Method is POST');
        System.assert(mock.captured.getBody().contains('ACME DEFENSE LLC'),
            'Request body carries the recipient search text');
    }

    @isTest
    static void testDescriptionAbbreviatedTo500() {
        String longDesc = 'X'.repeat(900);
        String payload = JSON.serialize(new Map<String, Object>{
            'results' => new List<Object>{
                new Map<String, Object>{ 'Award ID' => 'A1', 'Description' => longDesc }
            }
        });
        Test.setMock(HttpCalloutMock.class, new Mock(200, payload));

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('anyone', 1);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One row parsed');
        System.assertEquals(500, results[0].description.length(),
            'Description abbreviated to 500 chars');
    }

    @isTest
    static void testNon200ReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new Mock(500, '{"detail":"server error"}'));

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('ACME', 5);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Non-200 yields an empty list, not an error');
    }

    @isTest
    static void testEmptyResultsArrayReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{"results":[]}'));

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('NoMatchCo', 5);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty results array yields empty list');
    }

    @isTest
    static void testMissingResultsKeyReturnsEmpty() {
        // 200 OK but the payload has no `results` key — parse() must return empty.
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{"page_metadata":{"count":0}}'));

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('NoMatchCo', 5);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Missing results key yields empty list');
    }

    @isTest
    static void testNullLimitDefaultsWithoutError() {
        // limitResults == null exercises the default-limit branch in buildBody().
        Test.setMock(HttpCalloutMock.class, new Mock(200, buildResultsJson(1, false)));

        Test.startTest();
        List<OA_USASpendingClient.AwardResult> results =
            OA_USASpendingClient.searchByRecipient('ACME', null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Null limit defaults and still returns rows');
    }

    @isTest
    static void testMalformedJsonThrows() {
        // Documents current behavior: the client does NOT guard against malformed
        // 200 bodies, so a JSON exception propagates. Flagged as tech debt for 1C.
        Test.setMock(HttpCalloutMock.class, new Mock(200, 'this-is-not-json'));

        Test.startTest();
        Boolean threw = false;
        try {
            OA_USASpendingClient.searchByRecipient('ACME', 5);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Malformed 200 body currently propagates a parse exception');
    }
}
