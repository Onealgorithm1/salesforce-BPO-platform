@isTest
private class OA_EnrichmentWriter_Test {

    private static OA_Field_Write_Policy__mdt pol(String field, String mode) {
        return new OA_Field_Write_Policy__mdt(
            Target_Object__c='Lead', Target_Field__c=field, Source_System__c='SAM',
            Write_Mode__c=mode, Confidence_Floor__c='HIGH', Conflict_Behavior__c='Review',
            Trusted__c=true, Active__c=true);
    }

    private static void seedPolicies() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'FillEmptyOnly'),
            pol('Rating', 'Overwrite'),
            pol('Company', 'Never')
        };
    }

    private static Lead newLead(String company, String website, String rating) {
        Lead l = new Lead(LastName='T', Company=company, Website=website, Rating=rating,
            Email='w' + Math.abs(Crypto.getRandomInteger()) + '@example.com');
        insert l;
        return l;
    }

    private static List<OA_EnrichmentWriter.FieldProposal> proposals(String band) {
        return new List<OA_EnrichmentWriter.FieldProposal>{
            new OA_EnrichmentWriter.FieldProposal('Website', 'https://new.example.com', 'SAM', band),
            new OA_EnrichmentWriter.FieldProposal('Rating', 'Warm', 'SAM', band),
            new OA_EnrichmentWriter.FieldProposal('Company', 'SHOULD_NOT_WRITE', 'SAM', band)
        };
    }

    @isTest
    static void testPreviewMakesNoDml() {
        seedPolicies();
        Lead l = newLead('ACME', null, 'Hot');
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.preview(l, proposals('HIGH'), null);
        Test.stopTest();

        System.assert(!r.committed, 'Preview never commits');
        System.assertEquals(2, r.written, 'Website (blank->fill) + Rating (overwrite)');
        System.assertEquals('SKIP_NEVER', r.outcomeByField.get('Company'), 'Company Never');
        // No DML: DB copy unchanged
        Lead db = [SELECT Website, Rating FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, db.Website, 'Website not persisted in preview');
        System.assertEquals('Hot', db.Rating, 'Rating not persisted in preview');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Enrichment_Change_Log__c], 'No logs persisted in preview');
    }

    @isTest
    static void testCommitWritesAndLogs() {
        seedPolicies();
        Lead l = newLead('ACME2', null, 'Hot');
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrich(l, proposals('HIGH'), null, true);
        Test.stopTest();

        System.assert(r.committed, 'Committed');
        System.assertEquals(2, r.written, 'Two fields written');
        System.assertEquals(2, r.changeLogs.size(), 'Two change-log rows built');
        // Lead is a physical object -> its writes persist and are asserted directly.
        Lead db = [SELECT Website, Rating, Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('https://new.example.com', db.Website, 'Website filled');
        System.assertEquals('Warm', db.Rating, 'Rating overwritten');
        System.assertEquals('ACME2', db.Company, 'Company never overwritten');
    }

    @isTest
    static void testConflictRoutesException() {
        seedPolicies();
        Lead l = newLead('ACME3', 'https://old.example.com', 'Hot');
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrich(l, proposals('HIGH'), null, true);
        Test.stopTest();

        System.assertEquals(1, r.conflicts, 'Website fill-empty on populated -> conflict');
        System.assertEquals(1, r.exceptions.size(), 'One exception routed');
        System.assertEquals('SourceConflict', r.exceptions[0].Exception_Type__c, 'Routed as SourceConflict');
        // Website conflicts (not written); the independent Rating overwrite still applies.
        System.assertEquals(1, r.written, 'Only Rating overwrite written; Website conflicted');
        System.assertEquals('https://old.example.com',
            [SELECT Website FROM Lead WHERE Id = :l.Id].Website, 'Website not overwritten');
    }

    @isTest
    static void testBelowFloorAndNullTarget() {
        seedPolicies();
        Lead l = newLead('ACME4', null, 'Hot');
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.preview(l, proposals('LOW'), null);
        System.assertEquals('SKIP_BELOW_FLOOR', r.outcomeByField.get('Website'), 'LOW below HIGH floor');
        System.assertEquals(0, r.written, 'Nothing written below floor');

        OA_EnrichmentWriter.Result rn = OA_EnrichmentWriter.enrich(null, proposals('HIGH'), null, false);
        System.assertEquals(0, rn.proposed, 'Null target -> no work');
        System.assert(!rn.messages.isEmpty(), 'Message recorded');
    }

    @isTest
    static void testTypeErrorAndNoChange() {
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('NumberOfEmployees', 'Overwrite'),
            pol('Rating', 'Overwrite')
        };
        Lead l = newLead('ACME5', null, 'Hot');
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>{
            // String into a Number field -> put() throws -> routed as a policy exception
            new OA_EnrichmentWriter.FieldProposal('NumberOfEmployees', 'not-a-number', 'SAM', 'HIGH'),
            // Same value under Overwrite -> NO_CHANGE
            new OA_EnrichmentWriter.FieldProposal('Rating', 'Hot', 'SAM', 'HIGH')
        };
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.preview(l, ps, null);
        System.assertEquals('SKIP_TYPE_ERROR', r.outcomeByField.get('NumberOfEmployees'), 'Type error routed');
        System.assertEquals(1, r.exceptions.size(), 'Type error -> policy exception');
        System.assertEquals('PolicyException', r.exceptions[0].Exception_Type__c, 'Routed as PolicyException');
        System.assertEquals(1, r.noChange, 'Same value -> no change');
        System.assertEquals(0, r.written, 'Nothing written');
    }
}
