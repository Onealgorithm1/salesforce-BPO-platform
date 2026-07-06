@isTest
private class OA_NameNormalizer_Test {

    @isTest
    static void testNormalizeStripsSuffixAndPunctuation() {
        System.assertEquals('ACME DEFENSE', OA_NameNormalizer.normalize('Acme Defense, LLC'),
            'Suffix + punctuation stripped, uppercased');
        System.assertEquals('ACME DEFENSE', OA_NameNormalizer.normalize('  ACME   Defense Inc.  '),
            'Whitespace collapsed, INC removed');
    }

    @isTest
    static void testNormalizeBlankAndAllSuffix() {
        System.assertEquals(null, OA_NameNormalizer.normalize('   '), 'Blank -> null');
        System.assertEquals(null, OA_NameNormalizer.normalize(null), 'Null -> null');
        // A name that is ONLY a suffix falls back to the punctuation-stripped form.
        System.assertEquals('LLC', OA_NameNormalizer.normalize('LLC'), 'All-suffix falls back');
    }

    @isTest
    static void testSimilarity() {
        System.assertEquals(1, OA_NameNormalizer.similarity('Acme Defense LLC', 'ACME DEFENSE inc'),
            'Same normalized tokens -> 1');
        System.assertEquals(0, OA_NameNormalizer.similarity('Acme', 'Globex'), 'Disjoint -> 0');
        System.assertEquals(0, OA_NameNormalizer.similarity(null, 'x'), 'Blank -> 0');
        Decimal partial = OA_NameNormalizer.similarity('Acme Defense Systems', 'Acme Defense');
        System.assert(partial > 0 && partial < 1, 'Partial overlap between 0 and 1');
    }
}
