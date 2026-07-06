/**
 * OA_SAM_ResponseParser_Test — unit + CONTRACT tests for the SAM parser.
 * Verifies expected fields/identifiers exist, schema changes fail gracefully, unknown/additive
 * fields do not break parsing, and canonical mapping is correct.
 */
@isTest
private class OA_SAM_ResponseParser_Test {

    private static Map<String, Object> reg(Boolean withUei) {
        Map<String, Object> r = new Map<String, Object>{
            'legalBusinessName' => 'ACME DEFENSE LLC',
            'dbaName' => 'ACME',
            'registrationStatus' => 'Active',
            'registrationExpirationDate' => '2027-03-15'
        };
        // UEI and CAGE are both deterministic identifiers -> only the withUei fixture carries them,
        // so the name-only fixture genuinely has NO deterministic id (expected MEDIUM confidence).
        if (withUei) {
            r.put('ueiSAM', 'ABC123DEF456');
            r.put('cageCode', '1AB23');
        }
        return r;
    }

    private static Map<String, Object> core() {
        return new Map<String, Object>{
            'entityInformation' => new Map<String, Object>{
                'entityURL' => 'https://acme.example.com', 'entityStructureDesc' => 'Corporate Entity' },
            'physicalAddress' => new Map<String, Object>{
                'addressLine1' => '1 Innovation Way', 'city' => 'Reston',
                'stateOrProvinceCode' => 'VA', 'zipCode' => '20190' },
            'businessTypes' => new Map<String, Object>{
                'businessTypeList' => new List<Object>{
                    new Map<String, Object>{ 'businessTypeCode' => '27' },
                    new Map<String, Object>{ 'businessTypeCode' => 'A5' } },
                'sbaBusinessTypeList' => new List<Object>{
                    new Map<String, Object>{ 'sbaBusinessTypeDesc' => 'Woman Owned Small Business' } } }
        };
    }

    private static String body(Boolean withUei, Boolean withExtras, Boolean withCore) {
        Map<String, Object> r = reg(withUei);
        Map<String, Object> entity = new Map<String, Object>{ 'entityRegistration' => r };
        if (withCore) { entity.put('coreData', core()); }
        if (withExtras) {
            r.put('someAdditiveField', 'future');       // additive API change
            entity.put('unknownSection', new Map<String, Object>{ 'x' => 1 });
        }
        return JSON.serialize(new Map<String, Object>{ 'totalRecords' => 1, 'entityData' => new List<Object>{ entity } });
    }

    @isTest
    static void testCanonicalMappingAndIdentifiers() {
        List<OA_CanonicalOrg> orgs = new OA_SAM_ResponseParser().parse(body(true, false, true));
        System.assertEquals(1, orgs.size(), 'One org');
        OA_CanonicalOrg o = orgs[0];
        // Contract: identifiers + expected fields exist
        System.assertEquals('ABC123DEF456', o.uei, 'UEI');
        System.assertEquals('1AB23', o.cageCode, 'CAGE');
        System.assertEquals('ACME DEFENSE LLC', o.organizationName, 'Legal name');
        System.assertEquals('ACME DEFENSE', o.normalizedName, 'Normalized');
        System.assertEquals('https://acme.example.com', o.website, 'Website');
        System.assertEquals('VA', o.state, 'State');
        System.assertEquals('Reston', o.city, 'City');
        System.assertEquals('Active', o.attributes.get('Registration_Status'), 'Reg status attr');
        System.assertEquals('2027-03-15', o.attributes.get('Registration_Expiration'), 'Reg exp attr');
        System.assertEquals('ACME', o.attributes.get('DBA'), 'DBA attr');
        System.assertEquals('Corporate Entity', o.attributes.get('Entity_Type'), 'Entity type');
        System.assertEquals('27,A5', o.attributes.get('Business_Types'), 'Business types joined');
        System.assertEquals('Woman Owned Small Business', o.attributes.get('Socioeconomic_Certifications'), 'Certs');
        // Unavailable fields must be null, not fabricated
        System.assertEquals(null, o.phone, 'Phone unavailable -> null');
        System.assertEquals(null, o.naics, 'NAICS unavailable -> null');
        // Confidence + hash
        System.assertEquals('HIGH', o.sourceConfidence, 'UEI -> HIGH confidence');
        System.assert(String.isNotBlank(o.sourcePayloadHash), 'Payload hash set');
        System.assertEquals('SAM', o.sourceSystem, 'Source stamped');
    }

    @isTest
    static void testAdditiveAndUnknownFieldsTolerated() {
        List<OA_CanonicalOrg> orgs = new OA_SAM_ResponseParser().parse(body(true, true, true));
        System.assertEquals(1, orgs.size(), 'Additive/unknown fields do not break parsing');
        System.assertEquals('ABC123DEF456', orgs[0].uei, 'Still maps UEI');
    }

    @isTest
    static void testNameOnlyIsMediumConfidence() {
        List<OA_CanonicalOrg> orgs = new OA_SAM_ResponseParser().parse(body(false, false, true));
        System.assertEquals('MEDIUM', orgs[0].sourceConfidence, 'No UEI, has name -> MEDIUM');
        System.assert(!orgs[0].hasDeterministicId(), 'No deterministic id');
    }

    @isTest
    static void testMissingCoreDataGraceful() {
        List<OA_CanonicalOrg> orgs = new OA_SAM_ResponseParser().parse(body(true, false, false));
        System.assertEquals(1, orgs.size(), 'Parses with only entityRegistration');
        System.assertEquals(null, orgs[0].website, 'No coreData -> website null (no crash)');
        System.assertEquals(null, orgs[0].attributes.get('Business_Types'), 'No business types');
    }

    @isTest
    static void testMissingEntityDataYieldsEmpty() {
        System.assertEquals(0, new OA_SAM_ResponseParser().parse('{"totalRecords":0}').size(),
            'Missing entityData -> empty (graceful)');
        System.assertEquals(0, new OA_SAM_ResponseParser().parse('{"totalRecords":0,"entityData":[]}').size(),
            'Empty entityData -> empty');
    }

    @isTest
    static void testMalformedThrowsParseException() {
        try {
            new OA_SAM_ResponseParser().parse('this-is-not-json');
            System.assert(false, 'Should have thrown');
        } catch (OA_SAM_ResponseParser.ParseException e) {
            System.assert(e.getMessage().contains('malformed'), 'Graceful typed failure');
        }
    }
}
