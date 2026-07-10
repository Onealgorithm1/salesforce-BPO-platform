@isTest
private class OA_Census_Test {

    private class Mock implements HttpCalloutMock {
        Integer s; String b; Mock(Integer s, String b) { this.s = s; this.b = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(s); r.setBody(b); return r;
        }
    }
    private class ThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) { throw new CalloutException('boom'); }
    }
    // Census returns an array-of-arrays: header row + data rows.
    private static String body() {
        return JSON.serialize(new List<Object>{
            new List<Object>{ 'ESTAB', 'EMP', 'PAYANN', 'NAICS2017_LABEL', 'state' },
            new List<Object>{ '12345', '67890', '2345678', 'Professional Services', '51' } });
    }
    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(Source_System__c='Census', Named_Credential__c='OA_Census',
            Endpoint_Path__c='/data/2021/cbp');
    }

    @isTest
    static void testRequest() {
        HttpRequest r = new OA_Census_Request().build('51', cfg());
        System.assertEquals('GET', r.getMethod());
        System.assert(r.getEndpoint().startsWith('callout:OA_Census/data/2021/cbp'), 'routes via NC + path');
        System.assert(r.getEndpoint().contains('for='), 'geography filter');
        System.assert(new OA_Census_Request().build('51', null).getEndpoint().startsWith('callout:OA_Census'), 'default NC');
    }

    @isTest
    static void testParserProducesContextNoIdentity() {
        List<OA_CanonicalOrg> orgs = new OA_Census_ResponseParser().parse(body());
        System.assertEquals(1, orgs.size(), 'One context row');
        OA_CanonicalOrg o = orgs[0];
        // Context, NOT an organization identity
        System.assertEquals(null, o.organizationName, 'No name (context only)');
        System.assertEquals(null, o.uei, 'No UEI (context only)');
        System.assert(!o.hasDeterministicId(), 'No deterministic id');
        System.assertEquals('NONE', o.sourceConfidence, 'Context -> NONE confidence');
        System.assertEquals('12345', o.attributes.get('Census_Establishments'), 'Establishments');
        System.assertEquals('67890', o.attributes.get('Census_Employment'), 'Employment');
        System.assertEquals('51', o.state, 'Geography');
    }

    @isTest
    static void testParserGracefulEmptyAndMalformed() {
        System.assertEquals(0, new OA_Census_ResponseParser().parse('[["ESTAB","state"]]').size(), 'Header only -> empty');
        try { new OA_Census_ResponseParser().parse('{"not":"array"}'); System.assert(false); }
        catch (OA_Census_ResponseParser.ParseException e) { System.assert(e.getMessage().contains('malformed')); }
    }

    @isTest
    static void testMapperContextFieldsOnly() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.sourceConfidence = 'NONE';
        o.attributes.put('Census_Establishments', '12345');
        o.attributes.put('Census_Employment', '67890');
        List<OA_EnrichmentWriter.FieldProposal> ps = new OA_Census_Mapper().toLeadProposals(o);
        Set<String> fields = new Set<String>();
        for (OA_EnrichmentWriter.FieldProposal p : ps) { fields.add(p.fieldApiName); }
        System.assert(fields.contains('Market_Establishments__c'), 'Context fields proposed');
        System.assert(!fields.contains('UEI__c') && !fields.contains('Name'), 'No identity fields');
        System.assertEquals(0, new OA_Census_Mapper().toLeadProposals(null).size(), 'Null safe');
    }

    @isTest
    static void testConnector() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, body()));
        OA_ConnectorResult ok = new OA_Census_Connector().fetch('51', cfg());
        System.assertEquals(1, ok.parsed, 'parsed');
        System.assertEquals('Census', ok.sourceKey);
        Test.setMock(HttpCalloutMock.class, new Mock(404, '[]'));
        System.assertEquals(1, new OA_Census_Connector().fetch('51', cfg()).httpErrors, 'non-2xx');
        Test.setMock(HttpCalloutMock.class, new Mock(200, 'not-json'));
        System.assertEquals(1, new OA_Census_Connector().fetch('51', cfg()).parseErrors, 'malformed');
        System.assertEquals('Census', new OA_Census_Connector().sourceKey());

        Test.setMock(HttpCalloutMock.class, new ThrowMock());
        OA_ConnectorResult thrown = new OA_Census_Connector().fetch('51', cfg());
        System.assertEquals(1, thrown.httpErrors, 'Callout exception recorded');
    }
}