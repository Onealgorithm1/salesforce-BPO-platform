@isTest
private class OA_USASpending_Test {

    private class Mock implements HttpCalloutMock {
        Integer s; String b; Mock(Integer s, String b) { this.s = s; this.b = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(s); r.setBody(b); return r;
        }
    }
    private class ThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) { throw new CalloutException('boom'); }
    }

    private static Map<String, Object> award(String uei, String name, Decimal amt, String agency, String start) {
        return new Map<String, Object>{
            'Recipient UEI' => uei, 'Recipient Name' => name, 'Award Amount' => amt,
            'Awarding Agency' => agency, 'Start Date' => start, 'Parent Recipient Name' => 'ACME HOLDINGS',
            'Place of Performance State Code' => 'VA', 'recipient_id' => 'r-1' };
    }
    private static String body(List<Object> results, Boolean extras) {
        Map<String, Object> root = new Map<String, Object>{ 'results' => results };
        if (extras) { root.put('page_metadata', new Map<String, Object>{ 'page' => 1 }); }
        return JSON.serialize(root);
    }
    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(Source_System__c='USASpending', Named_Credential__c='OA_USASpending',
            Endpoint_Path__c='/api/v2/search/spending_by_award/');
    }

    @isTest
    static void testRequestPostNoKey() {
        HttpRequest r = new OA_USASpending_Request().build('ACME DEFENSE', cfg());
        System.assertEquals('POST', r.getMethod(), 'POST');
        System.assert(r.getEndpoint().startsWith('callout:OA_USASpending/api/v2/search/spending_by_award/'), 'routes via NC');
        System.assert(r.getBody().contains('recipient_search_text'), 'search body');
        System.assert(!r.getBody().containsIgnoreCase('api_key'), 'no key');
        HttpRequest d = new OA_USASpending_Request().build('X', null);  // null cfg defaults
        System.assert(d.getEndpoint().startsWith('callout:OA_USASpending'), 'default NC');
    }

    @isTest
    static void testParserAggregatesByRecipient() {
        List<Object> results = new List<Object>{
            award('ABC123DEF456', 'ACME DEFENSE LLC', 100, 'DoD', '2025-01-01'),
            award('ABC123DEF456', 'ACME DEFENSE LLC', 250, 'DoE', '2026-03-01') };
        List<OA_CanonicalOrg> orgs = new OA_USASpending_ResponseParser().parse(body(results, true));
        System.assertEquals(1, orgs.size(), 'Aggregated to one recipient');
        OA_CanonicalOrg o = orgs[0];
        System.assertEquals('ABC123DEF456', o.uei, 'UEI');
        System.assertEquals('350', o.attributes.get('Award_Total'), 'Totals summed');
        System.assertEquals('2', o.attributes.get('Award_Count'), 'Count');
        System.assertEquals('2026-03-01', o.attributes.get('Latest_Award_Date'), 'Latest date');
        System.assert(String.valueOf(o.attributes.get('Awarding_Agencies')).contains('DoD'), 'Agencies');
        System.assertEquals('ACME HOLDINGS', o.attributes.get('Parent_Organization'), 'Parent');
        System.assertEquals('true', o.attributes.get('Federal_Award_Recipient'), 'Flag');
        System.assertEquals('HIGH', o.sourceConfidence, 'UEI -> HIGH');
    }

    @isTest
    static void testParserMultipleRecipientsAndNameOnly() {
        List<Object> results = new List<Object>{
            award('UEIAAAAAAAA1', 'ORG ONE', 10, 'DoD', '2025-01-01'),
            award(null, 'ORG TWO', 20, 'DoE', '2025-02-01') };
        List<OA_CanonicalOrg> orgs = new OA_USASpending_ResponseParser().parse(body(results, false));
        System.assertEquals(2, orgs.size(), 'Two distinct recipients');
        Boolean sawMedium = false;
        for (OA_CanonicalOrg o : orgs) { if (o.uei == null) { sawMedium = (o.sourceConfidence == 'MEDIUM'); } }
        System.assert(sawMedium, 'Name-only recipient -> MEDIUM');
    }

    @isTest
    static void testParserEmptyAndMalformed() {
        System.assertEquals(0, new OA_USASpending_ResponseParser().parse('{"results":[]}').size(), 'Empty');
        System.assertEquals(0, new OA_USASpending_ResponseParser().parse('{"no_results":1}').size(), 'Missing results');
        try { new OA_USASpending_ResponseParser().parse('nope'); System.assert(false); }
        catch (OA_USASpending_ResponseParser.ParseException e) { System.assert(e.getMessage().contains('malformed')); }
    }

    @isTest
    static void testMapper() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.uei = 'ABC123DEF456'; o.sourceConfidence = 'HIGH';
        o.attributes.put('Award_Total', '350'); o.attributes.put('Federal_Award_Recipient', 'true');
        List<OA_EnrichmentWriter.FieldProposal> ps = new OA_USASpending_Mapper().toLeadProposals(o);
        Set<String> fields = new Set<String>();
        for (OA_EnrichmentWriter.FieldProposal p : ps) { fields.add(p.fieldApiName); System.assertEquals('USASpending', p.sourceSystem); }
        System.assert(fields.contains('UEI__c') && fields.contains('Total_Award_Amount__c'), 'Mapped fields');
        System.assertEquals(0, new OA_USASpending_Mapper().toLeadProposals(null).size(), 'Null safe');
    }

    @isTest
    static void testConnectorMockPaths() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, body(new List<Object>{ award('ABC123DEF456','ACME',100,'DoD','2025-01-01') }, false)));
        OA_ConnectorResult ok = new OA_USASpending_Connector().fetch('ACME', cfg());
        System.assertEquals(1, ok.parsed, 'parsed'); System.assertEquals('USASpending', ok.sourceKey);

        Test.setMock(HttpCalloutMock.class, new Mock(500, '{}'));
        System.assertEquals(1, new OA_USASpending_Connector().fetch('ACME', cfg()).httpErrors, 'non-2xx');

        Test.setMock(HttpCalloutMock.class, new Mock(200, 'not-json'));
        System.assertEquals(1, new OA_USASpending_Connector().fetch('ACME', cfg()).parseErrors, 'malformed');
        System.assertEquals('USASpending', new OA_USASpending_Connector().sourceKey(), 'sourceKey');

        Test.setMock(HttpCalloutMock.class, new ThrowMock());
        OA_ConnectorResult thrown = new OA_USASpending_Connector().fetch('ACME', cfg());
        System.assertEquals(1, thrown.httpErrors, 'Callout exception recorded');
        System.assert(!thrown.messages.isEmpty(), 'Failure message captured');
    }
}
