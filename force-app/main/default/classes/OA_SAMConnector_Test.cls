/**
 * OA_SAMConnector_Test — proves the dormant SAM.gov connector on the SDK.
 *
 * FULLY MOCKED (OA_ConnectorMock) — NEVER calls the live SAM.gov endpoint, asserts the
 * connector performs NO DML (nothing written to staging), and asserts NO API key / no
 * 'api_key=' query param ever appears in the request URL (the key is an External-Credential
 * header, never in source or URL). Covers success + mapping, UEI vs legal-name search,
 * non-200, empty, missing-key, and malformed response.
 */
@isTest
private class OA_SAMConnector_Test {

    private static final String BASE = 'callout:OA_SAM/entity-information/v3/entities';

    // Build a SAM-entity-shaped response body with `count` entities.
    private static String entitiesJson(Integer count, Boolean firstRowNulls) {
        List<Object> entities = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> reg = new Map<String, Object>{
                'ueiSAM'                     => 'UEI' + i + 'ABCDE123',
                'cageCode'                   => '1AB2' + i,
                'legalBusinessName'          => 'ACME DEFENSE LLC ' + i,
                'registrationStatus'         => 'Active',
                'registrationExpirationDate' => '2027-03-15'
            };
            Map<String, Object> core = new Map<String, Object>{
                'physicalAddress'   => new Map<String, Object>{ 'stateOrProvinceCode' => 'VA' },
                'entityInformation' => new Map<String, Object>{ 'entityURL' => 'https://acme.example' },
                'businessTypes'     => new Map<String, Object>{
                    'businessTypeList' => new List<Object>{
                        new Map<String, Object>{ 'businessTypeCode' => '27' },
                        new Map<String, Object>{ 'businessTypeCode' => 'A5' }
                    }
                }
            };
            if (firstRowNulls && i == 0) {
                reg.put('cageCode', null);
                reg.put('registrationExpirationDate', null);
                core.put('businessTypes', null);
            }
            entities.add(new Map<String, Object>{ 'entityRegistration' => reg, 'coreData' => core });
        }
        return JSON.serialize(new Map<String, Object>{
            'totalRecords' => count, 'entityData' => entities });
    }

    private static OA_ConnectorRunResult runWith(Integer status, String body, Object input) {
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(status, body));
        return new OA_ConnectorEngine().run(
            new OA_SAMConnector(),
            new OA_ConnectorContext('SAM-RUN-01'),
            new List<Object>{ input });
    }

    @isTest
    static void testSuccessMapsStagingInMemoryNoDml() {
        Integer dmlBefore = Limits.getDmlStatements();

        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, entitiesJson(2, true), 'ABC123DEF456');
        Test.stopTest();

        System.assertEquals(1, result.requested, 'One input');
        System.assertEquals(2, result.parsed, 'Two entities parsed');
        System.assertEquals(2, result.mapped, 'Two staging records mapped in memory');
        System.assert(result.isClean(), 'Run is clean');

        // Proof of no DML / no staging write:
        System.assertEquals(dmlBefore, Limits.getDmlStatements(), 'Zero DML statements');
        System.assertEquals(0, [SELECT COUNT() FROM OA_SAM_Entity_Staging__c],
            'No staging records were inserted');

        // Row 0 exercises the null branches.
        OA_SAM_Entity_Staging__c s0 = (OA_SAM_Entity_Staging__c) result.stagingRecords[0];
        System.assertEquals('UEI0ABCDE123', s0.UEI__c, 'UEI mapped');
        System.assertEquals(null, s0.CAGE_Code__c, 'Null CAGE handled');
        System.assertEquals('ACME DEFENSE LLC 0', s0.Legal_Business_Name__c, 'Legal name mapped');
        System.assertEquals('Active', s0.Registration_Status__c, 'Registration status mapped');
        System.assertEquals('VA', s0.Physical_State__c, 'State mapped');
        System.assertEquals(null, s0.Registration_Expiration_Date__c, 'Null date handled');
        System.assertEquals(null, s0.Business_Types__c, 'Null business types handled');

        // Framework-managed fields + review gate.
        System.assertEquals('Pending', s0.Review_Status__c, 'Review gate defaulted to Pending');
        System.assertEquals('SAM-RUN-01', s0.Source_Run_ID__c, 'Run id stamped');
        System.assert(String.isNotBlank(s0.Source_Endpoint__c), 'Source endpoint stamped');
        System.assertEquals(200, s0.HTTP_Status__c, 'HTTP status stamped');
        System.assertEquals(Date.today(), s0.Query_Date__c, 'Query date stamped');
        System.assert(String.isNotBlank(s0.Source_Payload_Ref__c), 'Payload hash ref stamped');
        System.assert(String.isNotBlank(s0.Dedupe_Key__c), 'Dedupe key stamped');

        // Row 1 exercises full mapping incl. CAGE, date, business types.
        OA_SAM_Entity_Staging__c s1 = (OA_SAM_Entity_Staging__c) result.stagingRecords[1];
        System.assertEquals('1AB21', s1.CAGE_Code__c, 'CAGE mapped');
        System.assertEquals(Date.newInstance(2027, 3, 15), s1.Registration_Expiration_Date__c, 'Reg exp date parsed');
        System.assertEquals('27,A5', s1.Business_Types__c, 'Business types joined');
        System.assertEquals('https://acme.example', s1.Entity_URL__c, 'Entity URL mapped');
    }

    @isTest
    static void testConnectorMetadata() {
        OA_SAMConnector c = new OA_SAMConnector();
        System.assertEquals('SAM', c.sourceKey(), 'Source key');
        System.assertEquals('callout:OA_SAM', c.namedCredential(), 'Named credential declared');
        System.assertEquals(OA_SAM_Entity_Staging__c.SObjectType, c.stagingType(), 'Staging type');
        System.assert(c.requestBuilder() instanceof OA_SAMRequest, 'Request builder wired');
        System.assert(c.parser() instanceof OA_SAMParser, 'Parser wired');
        System.assert(c.mapper() instanceof OA_SAMMapper, 'Mapper wired');
    }

    @isTest
    static void testRequestByUeiNoKeyInUrl() {
        OA_ConnectorMock mock = new OA_ConnectorMock(200, entitiesJson(1, false));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new OA_ConnectorEngine().run(new OA_SAMConnector(),
            new OA_ConnectorContext('R2'), new List<Object>{ 'ABC123DEF456' });
        Test.stopTest();

        String url = mock.lastRequest.getEndpoint();
        System.assert(url.startsWith(BASE), 'Routes through OA_SAM Named Credential');
        System.assertEquals('GET', mock.lastRequest.getMethod(), 'GET method');
        System.assert(url.contains('ueiSAM=ABC123DEF456'), '12-char UEI sent as ueiSAM');
        // No secret ever in the URL:
        System.assert(!url.containsIgnoreCase('api_key'), 'No api_key query param in URL');
        System.assert(!url.containsIgnoreCase('x-api-key'), 'No X-Api-Key value in URL');
    }

    @isTest
    static void testLegalNameSearchWhenNotUei() {
        OA_ConnectorMock mock = new OA_ConnectorMock(200, entitiesJson(1, false));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new OA_ConnectorEngine().run(new OA_SAMConnector(),
            new OA_ConnectorContext('R3'), new List<Object>{ 'Acme Defense' });
        Test.stopTest();

        String url = mock.lastRequest.getEndpoint();
        System.assert(url.contains('legalBusinessName='), 'Non-UEI term sent as legalBusinessName');
        System.assert(!url.containsIgnoreCase('api_key'), 'No api_key query param');
    }

    @isTest
    static void testNon200RecordsHttpError() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(429, '{"error":"rate limited"}', 'ABC123DEF456');
        Test.stopTest();

        System.assertEquals(1, result.httpErrors, 'Non-200 recorded');
        System.assertEquals(0, result.mapped, 'Nothing mapped on non-200');
        System.assert(!result.isClean(), 'Run not clean');
    }

    @isTest
    static void testEmptyEntityDataParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, '{"totalRecords":0,"entityData":[]}', 'NoMatchCo');
        Test.stopTest();

        System.assertEquals(0, result.parsed, 'No entities parsed');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(result.isClean(), 'Empty result is a clean run');
    }

    @isTest
    static void testMissingEntityDataKeyParsesZero() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, '{"totalRecords":0}', 'NoMatchCo');
        Test.stopTest();

        System.assertEquals(0, result.mapped, 'Missing entityData key yields zero mapped');
        System.assert(result.isClean(), 'Still clean');
    }

    @isTest
    static void testMalformedResponseHandledSafely() {
        Test.startTest();
        OA_ConnectorRunResult result = runWith(200, 'this-is-not-json', 'ABC123DEF456');
        Test.stopTest();

        System.assertEquals(1, result.parseErrors, 'Malformed body recorded as a parse error');
        System.assertEquals(0, result.mapped, 'Nothing mapped');
        System.assert(!result.isClean(), 'Run not clean');
    }
}
