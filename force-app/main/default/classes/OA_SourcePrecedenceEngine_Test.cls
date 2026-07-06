@isTest
private class OA_SourcePrecedenceEngine_Test {

    private static void seed() {
        OA_SourcePrecedenceEngine.sourceOverride = new List<OA_Enrichment_Source__mdt>{
            new OA_Enrichment_Source__mdt(Source_System__c='SAM', Precedence__c=10, Trusted__c=true, Active__c=true),
            new OA_Enrichment_Source__mdt(Source_System__c='USASpending', Precedence__c=50, Trusted__c=true, Active__c=true),
            new OA_Enrichment_Source__mdt(Source_System__c='Legacy', Precedence__c=5, Trusted__c=false, Active__c=false)
        };
    }

    @isTest
    static void testPrecedenceAndTrust() {
        seed();
        System.assertEquals(10, OA_SourcePrecedenceEngine.precedence('SAM'), 'SAM precedence');
        System.assertEquals(10, OA_SourcePrecedenceEngine.precedence('sam'), 'Case-insensitive');
        System.assertEquals(999999, OA_SourcePrecedenceEngine.precedence('Unknown'), 'Unknown lowest');
        System.assertEquals(999999, OA_SourcePrecedenceEngine.precedence('Legacy'), 'Inactive excluded');
        System.assert(OA_SourcePrecedenceEngine.isTrusted('SAM'), 'SAM trusted');
        System.assert(!OA_SourcePrecedenceEngine.isTrusted('Unknown'), 'Unknown not trusted');
        System.assert(OA_SourcePrecedenceEngine.isKnown('USASpending'), 'Known');
        System.assert(!OA_SourcePrecedenceEngine.isKnown('Legacy'), 'Inactive unknown');
    }

    @isTest
    static void testWinner() {
        seed();
        System.assertEquals('SAM', OA_SourcePrecedenceEngine.winner('SAM', 'USASpending'), 'Lower number wins');
        System.assertEquals('SAM', OA_SourcePrecedenceEngine.winner('USASpending', 'SAM'), 'Order-independent');
        System.assertEquals('SAM', OA_SourcePrecedenceEngine.winner(null, 'SAM'), 'Blank a');
        System.assertEquals('SAM', OA_SourcePrecedenceEngine.winner('SAM', null), 'Blank b');
    }
}
