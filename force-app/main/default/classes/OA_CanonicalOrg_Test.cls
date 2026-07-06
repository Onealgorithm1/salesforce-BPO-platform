@isTest
private class OA_CanonicalOrg_Test {

    @isTest
    static void testGetValue() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.organizationName = 'Acme Defense';
        o.uei = 'ABC123DEF456';
        o.state = 'VA';
        o.attributes.put('Registration_Status', 'Active');

        System.assertEquals('Active', o.getValue('Registration_Status'), 'Attribute exact');
        System.assertEquals('Active', o.getValue('registration_status'), 'Attribute case-insensitive');
        System.assertEquals('ABC123DEF456', o.getValue('UEI'), 'Known prop');
        System.assertEquals('Acme Defense', o.getValue('company'), 'Company alias');
        System.assertEquals('VA', o.getValue('state'), 'State prop');
        System.assertEquals(null, o.getValue(''), 'Blank field -> null');
        System.assertEquals(null, o.getValue('nonexistent'), 'Unknown -> null');
    }

    @isTest
    static void testCanonicalKeyPreference() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.normalizedName = 'ACME DEFENSE';
        o.state = 'VA';
        System.assert(o.canonicalKey().startsWith('NAME:'), 'Falls back to name hash');
        System.assert(!o.hasDeterministicId(), 'No id yet');

        o.cageCode = '1AB23';
        System.assertEquals('CAGE:1AB23', o.canonicalKey(), 'CAGE preferred over name');
        o.cik = '0000320193';
        System.assertEquals('CIK:0000320193', o.canonicalKey(), 'CIK preferred over CAGE');
        o.npi = '1234567890';
        System.assertEquals('NPI:1234567890', o.canonicalKey(), 'NPI preferred over CIK');
        o.ein = '12-3456789';
        System.assertEquals('EIN:12-3456789', o.canonicalKey(), 'EIN preferred over NPI');
        o.uei = 'abc123def456';
        System.assertEquals('UEI:ABC123DEF456', o.canonicalKey(), 'UEI preferred + uppercased');
        System.assert(o.hasDeterministicId(), 'Has id now');
    }

    @isTest
    static void testPayloadHash() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.organizationName = 'Acme';
        o.uei = 'ABC123DEF456';
        String h1 = o.payloadHash();
        System.assert(String.isNotBlank(h1) && h1.length() <= 64, 'Hash produced');
        o.uei = 'ZZZ999';
        System.assertNotEquals(h1, o.payloadHash(), 'Hash changes with identity');
    }
}
