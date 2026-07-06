@isTest
private class OA_ChangeLogService_Test {

    private static Lead newLead(String company, String rating) {
        Lead l = new Lead(LastName='Test', Company=company, Rating=rating,
            Email='t' + Math.abs(Crypto.getRandomInteger()) + '@example.com');
        insert l;
        return l;
    }

    @isTest
    static void testSnapshotAndBuildLog() {
        Lead l = newLead('Acme', 'Hot');
        String snap = OA_ChangeLogService.snapshot(l, new Set<String>{ 'Rating' });
        System.assert(snap.contains('Rating') && snap.contains('Hot'), 'Snapshot captures value');

        OA_Enrichment_Change_Log__c log = OA_ChangeLogService.buildLog(
            'Lead', l.Id, 'Rating', 'Hot', 'Warm', 'SAM', 'Overwrite', 'HIGH', null, snap,
            OA_ChangeLogService.TYPE_ENRICH);
        System.assert(log.Reversible__c, 'Reversible when snapshot present');
        System.assertEquals('Hot', log.Old_Value__c, 'Old value');
        System.assertEquals('Warm', log.New_Value__c, 'New value');

        OA_Enrichment_Change_Log__c noSnap = OA_ChangeLogService.buildLog(
            'Lead', l.Id, 'Rating', 'Hot', 'Warm', 'SAM', 'Overwrite', 'HIGH', null, null,
            OA_ChangeLogService.TYPE_ENRICH);
        System.assert(!noSnap.Reversible__c, 'Not reversible without snapshot');
    }

    @isTest
    static void testCommitAndRollback() {
        Lead l = newLead('Acme', 'Hot');
        String snap = OA_ChangeLogService.snapshot(l, new Set<String>{ 'Rating' });

        // simulate an enrichment write
        l.Rating = 'Cold';
        update l;

        OA_Enrichment_Change_Log__c log = OA_ChangeLogService.buildLog(
            'Lead', l.Id, 'Rating', 'Hot', 'Cold', 'SAM', 'Overwrite', 'HIGH', null, snap,
            OA_ChangeLogService.TYPE_ENRICH);

        Test.startTest();
        OA_ChangeLogService.commitLogs(new List<OA_Enrichment_Change_Log__c>{ log });
        List<SObject> restored = OA_ChangeLogService.rollback(new List<OA_Enrichment_Change_Log__c>{ log });
        Test.stopTest();

        // rollback restores the (physical) Lead from the before-snapshot.
        System.assertEquals(1, restored.size(), 'One record restored');
        System.assertEquals('Hot', [SELECT Rating FROM Lead WHERE Id = :l.Id].Rating, 'Rating rolled back');
        System.assertEquals(0, OA_ChangeLogService.rollback(null).size(), 'Null safe');
        System.assertEquals(0, OA_ChangeLogService.commitLogs(null).size(), 'Null safe commit');
    }
}
