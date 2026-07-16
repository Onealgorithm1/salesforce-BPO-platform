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

    /** Commit tests must arm the kill switch the way production would: via org default. */
    private static void enableCommit() {
        insert new OA_Enrichment_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Writer_Commit_Enabled__c = true);
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
        enableCommit();
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
        enableCommit();
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
    static void testSaveFailureRoutesExceptionAndDiscardsLogs() {
        enableCommit();
        // Sprint 25 Defect #2: when the CRM update fails (here STRING_TOO_LONG on FirstName(40)),
        // the writer must NOT commit misleading change logs, must route an exception, and must
        // reflect that nothing persisted — while continuing safely.
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('FirstName', 'Overwrite')
        };
        Lead l = newLead('ACME6', null, 'Hot');   // FirstName is null
        String tooLong = '0123456789012345678901234567890123456789012345678901234567890123'; // 64 > 40
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>{
            new OA_EnrichmentWriter.FieldProposal('FirstName', tooLong, 'SAM', 'HIGH')
        };
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrich(l, ps, null, true);
        Test.stopTest();

        System.assert(r.committed, 'Commit path ran');
        System.assertEquals(0, r.written, 'Failed save -> nothing counted as written');
        System.assert(r.exceptions.size() >= 1, 'A failure exception was routed');
        System.assertEquals('PolicyException', r.exceptions[0].Exception_Type__c, 'Routed as PolicyException');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Enrichment_Change_Log__c],
            'No misleading change log persisted for the failed write');
        System.assert([SELECT COUNT() FROM OA_Enrichment_Exception__c] >= 1, 'Exception persisted');
        System.assertEquals(null, [SELECT FirstName FROM Lead WHERE Id = :l.Id].FirstName,
            'Field not persisted (update was rejected)');
    }

    @isTest
    static void testBatchCommitUsesBoundedDml() {
        enableCommit();
        // Scalability regression: many connector matches across several Leads must commit with a
        // CONSTANT number of DML statements (one Lead update + one change-log insert + one exception
        // insert), NOT one-per-match. Reproduces the OAT defect shape: 3 Leads x 10 "award matches".
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('Website', 'FillEmptyOnly')
        };
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            leads.add(new Lead(LastName = 'B', Company = 'Batch' + i,
                Email = 'batch' + i + '@example.com'));
        }
        insert leads;
        leads = [SELECT Id, Website FROM Lead WHERE Id IN :leads];

        List<OA_EnrichmentWriter.WorkItem> work = new List<OA_EnrichmentWriter.WorkItem>();
        for (Lead l : leads) {
            for (Integer k = 0; k < 10; k++) {      // 10 matches per Lead, each proposing a Website
                work.add(new OA_EnrichmentWriter.WorkItem(l,
                    new List<OA_EnrichmentWriter.FieldProposal>{
                        new OA_EnrichmentWriter.FieldProposal(
                            'Website', 'https://site' + k + '.example.com', 'SAM', 'HIGH') }));
            }
        }

        Test.startTest();
        Integer before = Limits.getDmlStatements();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrichAll(work, null, true);
        Integer used = Limits.getDmlStatements() - before;
        Test.stopTest();

        System.assert(r.committed, 'committed');
        System.assertEquals(3, r.written, 'first match fills each Lead once (FillEmptyOnly)');
        System.assertEquals(27, r.conflicts, '9 later matches per Lead x 3 route to conflict');
        System.assert(used <= 3,
            'bulk commit must use <=3 DML statements regardless of match count; used=' + used);
        System.assertEquals(3, [SELECT COUNT() FROM Lead WHERE Website != null AND Id IN :leads],
            'all three Leads persisted in one update');
        System.assertEquals(27, [SELECT COUNT() FROM OA_Enrichment_Exception__c],
            'conflicts persisted in one insert');
    }

    @isTest
    static void testBatchPartialFailureDiscardsOnlyFailedTarget() {
        enableCommit();
        // Bulk SaveResult handling: one Lead's write fails (STRING_TOO_LONG) while others succeed.
        // Only the failed target's audit is discarded; the healthy targets still persist.
        OA_FieldWritePolicyEngine.policyOverride = new List<OA_Field_Write_Policy__mdt>{
            pol('FirstName', 'Overwrite')
        };
        Lead ok1 = newLead('OK-A', null, 'Hot');
        Lead bad = newLead('BAD',  null, 'Hot');
        Lead ok2 = newLead('OK-B', null, 'Hot');
        String tooLong = '0123456789012345678901234567890123456789012345678901234567890123'; // 64 > 40
        List<OA_EnrichmentWriter.WorkItem> work = new List<OA_EnrichmentWriter.WorkItem>{
            new OA_EnrichmentWriter.WorkItem(ok1, new List<OA_EnrichmentWriter.FieldProposal>{
                new OA_EnrichmentWriter.FieldProposal('FirstName', 'Aaron', 'SAM', 'HIGH') }),
            new OA_EnrichmentWriter.WorkItem(bad, new List<OA_EnrichmentWriter.FieldProposal>{
                new OA_EnrichmentWriter.FieldProposal('FirstName', tooLong, 'SAM', 'HIGH') }),
            new OA_EnrichmentWriter.WorkItem(ok2, new List<OA_EnrichmentWriter.FieldProposal>{
                new OA_EnrichmentWriter.FieldProposal('FirstName', 'Bella', 'SAM', 'HIGH') })
        };
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrichAll(work, null, true);
        Test.stopTest();

        System.assertEquals(2, r.written, 'two healthy targets persisted; failed one discarded');
        System.assertEquals(2, [SELECT COUNT() FROM OA_Enrichment_Change_Log__c],
            'only the two successful writes have audit rows');
        System.assert([SELECT COUNT() FROM OA_Enrichment_Exception__c] >= 1,
            'the failed target routed a PolicyException');
        System.assertEquals(null, [SELECT FirstName FROM Lead WHERE Id = :bad.Id].FirstName,
            'failed target not persisted');
        System.assertEquals('Aaron', [SELECT FirstName FROM Lead WHERE Id = :ok1.Id].FirstName,
            'healthy target A persisted');
        System.assertEquals('Bella', [SELECT FirstName FROM Lead WHERE Id = :ok2.Id].FirstName,
            'healthy target B persisted');
    }

    @isTest
    static void testCommitSuppressedWithoutKillSwitch() {
        // The kill switch: commitWrites=true with no org-default flag must run as preview.
        seedPolicies();
        Lead l = newLead('ACME7', null, 'Hot');
        Test.startTest();
        OA_EnrichmentWriter.Result r = OA_EnrichmentWriter.enrich(l, proposals('HIGH'), null, true);
        Test.stopTest();

        System.assert(!r.committed, 'Commit must be suppressed when Writer_Commit_Enabled__c is off');
        System.assert(String.join(r.messages, ' ').contains('COMMIT SUPPRESSED'),
            'Suppression must be visible in Result.messages');
        Lead db = [SELECT Website, Rating FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, db.Website, 'No DML without the kill switch');
        System.assertEquals('Hot', db.Rating, 'No DML without the kill switch');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Enrichment_Change_Log__c],
            'No audit rows persisted when suppressed');
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