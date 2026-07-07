@isTest
private class OA_SEC_Test {

    private class Mock implements HttpCalloutMock {
        Integer s; String b; Mock(Integer s, String b) { this.s = s; this.b = b; }
        public HttpResponse respond(HttpRequest req) { HttpResponse r = new HttpResponse(); r.setStatusCode(s); r.setBody(b); return r; }
    }
    private class ThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) { throw new CalloutException('boom'); }
    }

    private static String body(Boolean withCik, Boolean blankWebsite) {
        Map<String, Object> m = new Map<String, Object>{
            'name' => 'APPLE INC', 'tickers' => new List<Object>{ 'AAPL' }, 'exchanges' => new List<Object>{ 'Nasdaq' },
            'sic' => '3571', 'sicDescription' => 'Electronic Computers', 'category' => 'Large accelerated filer',
            'entityType' => 'operating', 'stateOfIncorporation' => 'CA',
            'addresses' => new Map<String, Object>{ 'business' => new Map<String, Object>{
                'street1' => 'ONE APPLE PARK WAY', 'city' => 'CUPERTINO', 'stateOrCountry' => 'CA', 'zipCode' => '95014' } },
            'website' => blankWebsite ? '' : 'https://apple.com', 'futureField' => 'x' };
        if (withCik) { m.put('cik', '320193'); }
        return JSON.serialize(m);
    }
    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(Source_System__c='SEC', Named_Credential__c='OA_SEC', Endpoint_Path__c='/submissions');
    }

    @isTest
    static void testRequestPadsCikAndUserAgent() {
        OA_SEC_Request req = new OA_SEC_Request();
        HttpRequest r = req.build('320193', cfg());
        System.assert(r.getEndpoint().contains('/CIK0000320193.json'), 'CIK zero-padded to 10');
        System.assertEquals('GET', r.getMethod());
        System.assert(String.isNotBlank(r.getHeader('User-Agent')), 'SEC User-Agent set');
        System.assert(!r.getEndpoint().containsIgnoreCase('api_key'), 'no key');
        // padCik branches
        System.assertEquals('0000000000', req.padCik(''), 'blank -> zeros');
        System.assertEquals('0000320193', req.padCik('CIK 320193'), 'strips non-digits');
        System.assertEquals('0000320193', req.padCik('0000000320193'), 'long -> last 10');
        System.assert(new OA_SEC_Request().build('1', null).getEndpoint().startsWith('callout:OA_SEC'), 'default NC');
    }

    @isTest
    static void testParserMapsPublicCompany() {
        OA_CanonicalOrg o = new OA_SEC_ResponseParser().parse(body(true, false))[0];
        System.assertEquals('320193', o.cik, 'CIK');
        System.assertEquals('APPLE INC', o.organizationName, 'Name');
        System.assertEquals('AAPL', o.attributes.get('Ticker'), 'Ticker');
        System.assertEquals('Nasdaq', o.attributes.get('Exchange'), 'Exchange');
        System.assertEquals('3571', o.attributes.get('SIC'), 'SIC');
        System.assertEquals('Electronic Computers', o.attributes.get('Industry'), 'Industry');
        System.assertEquals('CUPERTINO', o.city, 'HQ city');
        System.assertEquals('CA', o.state, 'HQ state');
        System.assertEquals('https://apple.com', o.website, 'Website');
        System.assertEquals('Large accelerated filer', o.attributes.get('Filing_Status'), 'Filing status');
        System.assertEquals('HIGH', o.sourceConfidence, 'CIK -> HIGH');
    }

    @isTest
    static void testParserBlankWebsiteEmptyAndMalformed() {
        System.assertEquals(null, new OA_SEC_ResponseParser().parse(body(true, true))[0].website, 'Blank website -> null');
        System.assertEquals('MEDIUM', new OA_SEC_ResponseParser().parse(body(false, false))[0].sourceConfidence, 'No CIK, has name -> MEDIUM');
        System.assertEquals(0, new OA_SEC_ResponseParser().parse('{}').size(), 'No cik/name -> empty');
        try { new OA_SEC_ResponseParser().parse('nope'); System.assert(false); }
        catch (OA_SEC_ResponseParser.ParseException e) { System.assert(e.getMessage().contains('malformed')); }
    }

    @isTest
    static void testMapper() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.cik = '320193'; o.sourceConfidence = 'HIGH'; o.attributes.put('Ticker', 'AAPL');
        Set<String> fields = new Set<String>();
        for (OA_EnrichmentWriter.FieldProposal p : new OA_SEC_Mapper().toLeadProposals(o)) { fields.add(p.fieldApiName); System.assertEquals('SEC', p.sourceSystem); }
        System.assert(fields.contains('CIK__c') && fields.contains('Ticker__c'), 'Mapped');
        System.assertEquals(0, new OA_SEC_Mapper().toLeadProposals(null).size(), 'Null safe');
    }

    @isTest
    static void testConnector() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, body(true, false)));
        OA_ConnectorResult ok = new OA_SEC_Connector().fetch('320193', cfg());
        System.assertEquals(1, ok.parsed); System.assertEquals('SEC', ok.sourceKey);
        Test.setMock(HttpCalloutMock.class, new Mock(403, '{}'));
        System.assertEquals(1, new OA_SEC_Connector().fetch('320193', cfg()).httpErrors, 'non-2xx');
        Test.setMock(HttpCalloutMock.class, new Mock(200, 'nope'));
        System.assertEquals(1, new OA_SEC_Connector().fetch('320193', cfg()).parseErrors, 'malformed');
        Test.setMock(HttpCalloutMock.class, new ThrowMock());
        System.assertEquals(1, new OA_SEC_Connector().fetch('320193', cfg()).httpErrors, 'callout exception');
        System.assertEquals('SEC', new OA_SEC_Connector().sourceKey());
    }
}
