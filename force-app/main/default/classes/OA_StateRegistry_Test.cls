@isTest
private class OA_StateRegistry_Test {

    private class Mock implements HttpCalloutMock {
        Integer s; String b; Mock(Integer s, String b) { this.s = s; this.b = b; }
        public HttpResponse respond(HttpRequest req) { HttpResponse r = new HttpResponse(); r.setStatusCode(s); r.setBody(b); return r; }
    }
    // A concrete state connector proving the template is extended with only a parseBody override.
    private class ExampleState extends OA_StateRegistry_Template {
        ExampleState() { this.stateKey = 'StateRegistry_XX'; }
        protected override List<OA_CanonicalOrg> parseBody(String body) {
            OA_CanonicalOrg o = new OA_CanonicalOrg();
            o.sourceSystem = sourceKey(); o.organizationName = 'OVERRIDDEN'; o.sourceConfidence = 'MEDIUM';
            return new List<OA_CanonicalOrg>{ o };
        }
    }

    private static String body() {
        return JSON.serialize(new Map<String, Object>{ 'results' => new List<Object>{
            new Map<String, Object>{ 'name' => 'ACME LLC', 'entityNumber' => 'S123', 'status' => 'Active',
                'formationDate' => '2020-01-01', 'registeredAgent' => 'John Doe', 'state' => 'VA' } } });
    }
    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(Source_System__c='StateRegistry', Named_Credential__c='OA_StateRegistry', Endpoint_Path__c='/search');
    }

    @isTest
    static void testRequest() {
        HttpRequest r = new OA_StateRegistry_Request().build('ACME', cfg());
        System.assertEquals('GET', r.getMethod());
        System.assert(r.getEndpoint().startsWith('callout:OA_StateRegistry/search'), 'routes via NC + path');
        System.assert(new OA_StateRegistry_Request().build('x', null).getEndpoint().startsWith('callout:OA_StateRegistry'), 'default NC');
    }

    @isTest
    static void testTemplateDefaultParse() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, body()));
        OA_ConnectorResult res = new OA_StateRegistry_Template().fetch('ACME', cfg());
        System.assertEquals(1, res.parsed, 'Generic shape parsed');
        OA_CanonicalOrg o = res.organizations[0];
        System.assertEquals('ACME LLC', o.organizationName, 'Name');
        System.assertEquals('S123', o.attributes.get('State_Entity_Number'), 'Entity number');
        System.assertEquals('Active', o.attributes.get('State_Registration_Status'), 'Status');
        System.assertEquals('MEDIUM', o.sourceConfidence, 'Name-based -> MEDIUM');
        System.assert(!o.hasDeterministicId(), 'State entity number is NOT a canonical identifier');
        System.assertEquals('StateRegistry', new OA_StateRegistry_Template().sourceKey(), 'Default source key');
    }

    @isTest
    static void testTemplateNon2xxAndMalformed() {
        Test.setMock(HttpCalloutMock.class, new Mock(500, '{}'));
        System.assertEquals(1, new OA_StateRegistry_Template().fetch('x', cfg()).httpErrors, 'non-2xx recorded');
        Test.setMock(HttpCalloutMock.class, new Mock(200, 'not-json'));
        System.assertEquals(0, new OA_StateRegistry_Template().fetch('x', cfg()).parsed, 'Malformed tolerated -> empty');
    }

    @isTest
    static void testSubclassOverride() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{}'));
        OA_ConnectorResult res = new ExampleState().fetch('x', cfg());
        System.assertEquals(1, res.parsed, 'Subclass parseBody override used');
        System.assertEquals('OVERRIDDEN', res.organizations[0].organizationName, 'State-specific parse');
        System.assertEquals('StateRegistry_XX', res.sourceKey, 'Subclass source key');
    }

    @isTest
    static void testMapper() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.sourceSystem = 'StateRegistry_VA'; o.state = 'VA'; o.sourceConfidence = 'MEDIUM';
        o.attributes.put('State_Entity_Number', 'S123');
        o.attributes.put('State_Registration_Status', 'Active');
        Set<String> f = new Set<String>();
        for (OA_EnrichmentWriter.FieldProposal p : new OA_StateRegistry_Mapper().toLeadProposals(o)) {
            f.add(p.fieldApiName); System.assertEquals('StateRegistry_VA', p.sourceSystem);
        }
        System.assert(f.contains('State_Entity_Number__c'), 'State fields mapped');
        System.assertEquals(0, new OA_StateRegistry_Mapper().toLeadProposals(null).size(), 'Null safe');
    }
}