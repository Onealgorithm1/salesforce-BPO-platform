@isTest
private class OA_SAM_Request_Test {

    private static OA_Connector_Registry__mdt cfg() {
        return new OA_Connector_Registry__mdt(
            Source_System__c='SAM', Named_Credential__c='OA_SAM',
            Endpoint_Path__c='/entity-information/v3/entities');
    }

    @isTest
    static void testUeiRequestNoKeyInUrl() {
        HttpRequest r = new OA_SAM_Request().build('ABC123DEF456', cfg());
        String url = r.getEndpoint();
        System.assert(url.startsWith('callout:OA_SAM/entity-information/v3/entities'), 'Routes via NC + path from registry');
        System.assertEquals('GET', r.getMethod(), 'GET');
        System.assert(url.contains('ueiSAM=ABC123DEF456'), '12-char UEI sent as ueiSAM');
        System.assert(!url.containsIgnoreCase('api_key'), 'No api_key param');
        System.assert(!url.containsIgnoreCase('x-api-key'), 'No key value in URL');
        System.assertEquals('application/json', r.getHeader('Accept'), 'Accept header');
    }

    @isTest
    static void testNameSearchAndNullConfigDefaults() {
        HttpRequest r = new OA_SAM_Request().build('Acme Defense', null);
        String url = r.getEndpoint();
        System.assert(url.startsWith('callout:OA_SAM'), 'Null config -> default Named Credential');
        System.assert(url.contains('legalBusinessName='), 'Non-UEI term -> legal name search');
    }

    @isTest
    static void testBuildSearchParamBranches() {
        OA_SAM_Request req = new OA_SAM_Request();
        System.assert(req.buildSearchParam('ABC123DEF456').startsWith('ueiSAM='), '12 alnum -> UEI');
        System.assert(req.buildSearchParam('Acme, Inc').startsWith('legalBusinessName='), 'text -> name');
        System.assert(req.buildSearchParam('').startsWith('legalBusinessName='), 'blank -> name');
        System.assert(req.buildSearchParam('SHORT').startsWith('legalBusinessName='), 'not 12 chars -> name');
    }
}