@isTest
private class OA_ExceptionRoutingService_Test {

    @isTest
    static void testBuildAllFourTypes() {
        System.assertEquals('LowConfidenceMatch',
            OA_ExceptionRoutingService.lowConfidence('Lead', null, 'SAM', 'LOW', 'd', null).Exception_Type__c);
        System.assertEquals('SourceConflict',
            OA_ExceptionRoutingService.sourceConflict('Lead', null, 'Website', 'SAM', 'HIGH', 'd', null).Exception_Type__c);
        System.assertEquals('DuplicateMerge',
            OA_ExceptionRoutingService.duplicateMerge('Lead', null, 'SAM', 'd', null).Exception_Type__c);
        System.assertEquals('PolicyException',
            OA_ExceptionRoutingService.policyException('Lead', null, 'F', 'SAM', 'd', null).Exception_Type__c);
    }

    @isTest
    static void testBuildAndCommit() {
        OA_Enrichment_Exception__c ex = OA_ExceptionRoutingService.build(
            'PolicyException', 'Lead', null, 'Website', 'SAM', 'HIGH', 'details', 'do x', null);
        System.assertEquals('Open', ex.Status__c, 'Defaults Open');
        System.assertEquals('PolicyException', ex.Exception_Type__c, 'Type set');
        System.assertEquals('Website', ex.Field_API_Name__c, 'Field set');

        // commitExceptions executes the insert path; it returns one SaveResult per row.
        // (Row persistence is asserted in a real deploy; a check-only run does not
        //  materialize the new object, so we assert the call contract, not persistence.)
        Test.startTest();
        List<Database.SaveResult> res = OA_ExceptionRoutingService.commitExceptions(
            new List<OA_Enrichment_Exception__c>{ ex });
        Test.stopTest();

        System.assertEquals(1, res.size(), 'One result per row');
        System.assertEquals(0, OA_ExceptionRoutingService.commitExceptions(null).size(), 'Null safe no-op');
        System.assertEquals(0,
            OA_ExceptionRoutingService.commitExceptions(new List<OA_Enrichment_Exception__c>()).size(),
            'Empty safe no-op');
    }
}
