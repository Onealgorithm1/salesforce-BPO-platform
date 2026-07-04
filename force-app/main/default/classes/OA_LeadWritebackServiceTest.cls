/**
 * OA_LeadWritebackServiceTest — covers the governed Lead write-back engine.
 *
 * FLS is enforced by the service, so tests exercise it as a real user holding the
 * relevant permission sets (via System.runAs). The assignment exists ONLY inside the
 * rolled-back test transaction — it never persists and grants no live access:
 *   - fullUser = OA_Connector_Staging + OA_Lead_Writeback_Automation
 *                (read all staging source fields; read/edit the 16 Lead fields)
 * No production records are used (SeeAllData defaults to false).
 */
@IsTest
private class OA_LeadWritebackServiceTest {

    private class Scn {
        User fullUser;
        Id leadId;
        Id stagingId;
    }

    private static User buildUser(String tag) {
        Id pid = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()].ProfileId;
        String uniq = tag + String.valueOf(System.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return new User(
            FirstName = 'WB', LastName = tag,
            Alias = tag.left(8),
            Email = uniq + '@example.com',
            Username = uniq + '@example.com.wbtest',
            ProfileId = pid,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    private static void assignPermsets(Id userId, Set<String> names) {
        List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :names]) {
            psas.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id));
        }
        insert psas;
    }

    /** Build users + one staging row (+ its Lead) with the requested characteristics. */
    private static Scn setup(String reviewStatus, Boolean withLead, Boolean alreadyWritten) {
        Scn sc = new Scn();
        // Phase 1: setup-object DML (User, PermissionSetAssignment) isolated in runAs.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            sc.fullUser = buildUser('wbfull');
            insert sc.fullUser;
            assignPermsets(sc.fullUser.Id,
                new Set<String>{ 'OA_Connector_Staging', 'OA_Lead_Writeback_Automation' });
        }
        // Phase 2: business-object DML as the full user (has create/edit via permsets).
        System.runAs(sc.fullUser) {
            Lead ld = new Lead(LastName = 'WB Target', Company = 'WB Co',
                               Email = 'wbtarget' + String.valueOf(System.now().getTime()) + '@example.com');
            insert ld;
            sc.leadId = ld.Id;

            OA_USASpending_Staging__c st = new OA_USASpending_Staging__c(
                Review_Status__c      = reviewStatus,
                Lead__c               = withLead ? ld.Id : null,
                Recipient_UEI__c      = 'ABC123DEF456',
                Award_ID__c           = 'AWD-001',
                Award_Amount__c       = 12345.67,
                Award_Description__c  = 'Test award description',
                Awarding_Agency__c    = 'Dept of Testing',
                Awarding_Sub_Agency__c= 'Sub Test',
                Contract_Type__c      = 'Firm Fixed Price',
                Performance_State__c  = 'VA',
                Enrichment_Run_ID__c  = 'ENR-001',
                Query_Date__c         = Date.today(),
                Auto_Verified_Date__c = System.now(),
                Gate_Results__c       = 'gates: pass'
            );
            if (alreadyWritten) {
                st.Review_Status__c = 'Written Back';
                st.Written_Back_Date__c = System.now();
            }
            insert st;
            sc.stagingId = st.Id;
        }
        return sc;
    }

    private static OA_LeadWritebackService.RowOutcome outcomeFor(OA_LeadWritebackService.RunSummary s, Id stagingId) {
        for (OA_LeadWritebackService.RowOutcome ro : s.rows) {
            if (ro.stagingId == stagingId) return ro;
        }
        return null;
    }

    // 1 & 2 — preview does not update Lead/staging and returns a proposed outcome
    @IsTest static void testPreviewDoesNotUpdateLeadAndReturnsOutcome() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            Test.startTest();
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
            Test.stopTest();
        }
        System.assertNotEquals(null, sum.runId, 'runId set');
        System.assertEquals(false, sum.commitWrites, 'preview mode');
        System.assertEquals(0, sum.succeeded, 'no writes in preview');
        System.assert(sum.attempted >= 1, 'eligible row attempted');
        System.assertEquals('PREVIEW_OK', outcomeFor(sum, sc.stagingId).status, 'row previewed');

        Lead after = [SELECT USASpending_Latest_Award_ID__c, UEI_Verification_Status__c
                      FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals(null, after.USASpending_Latest_Award_ID__c, 'Lead not written in preview');
        OA_USASpending_Staging__c st = [SELECT Review_Status__c, Before_Snapshot__c
                                        FROM OA_USASpending_Staging__c WHERE Id = :sc.stagingId];
        System.assertEquals('Approved', st.Review_Status__c, 'staging not stamped in preview');
        System.assertEquals(null, st.Before_Snapshot__c, 'no snapshot persisted in preview');
    }

    // 3 — approved row with Lead__c is eligible
    @IsTest static void testApprovedRowEligible() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
        }
        System.assertEquals(1, sum.attempted, 'approved+Lead eligible');
        System.assertEquals('PREVIEW_OK', outcomeFor(sum, sc.stagingId).status);
    }

    // 4 — non-approved row is blocked
    @IsTest static void testNonApprovedBlocked() {
        Scn sc = setup('Pending', true, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
        }
        System.assertEquals(0, sum.attempted, 'not eligible');
        System.assertEquals('ELIGIBILITY', outcomeFor(sum, sc.stagingId).gate);
    }

    // 5 — missing Lead__c is blocked
    @IsTest static void testMissingLeadBlocked() {
        Scn sc = setup('Approved', false, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
        }
        System.assertEquals(0, sum.attempted, 'no deterministic target');
        System.assertEquals('MATCH', outcomeFor(sum, sc.stagingId).gate);
    }

    // 6 — already written-back row is skipped
    @IsTest static void testAlreadyWrittenSkipped() {
        Scn sc = setup('Approved', true, true);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
        }
        System.assertEquals(1, sum.idempotencySkips, 'skipped as already written');
        System.assertEquals('IDEMPOTENCY', outcomeFor(sum, sc.stagingId).gate);
    }

    // 7 — requested limit over 200 is clamped
    @IsTest static void testLimitClamp() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 500, false);
        }
        System.assertEquals(200, sum.effectiveLimit, 'clamped to 200');
        System.assertEquals(true, sum.batchClampApplied, 'clamp flagged');
    }

    // 8 & 9 & 10 — commit writes Lead, snapshot-first, KPI tripwires all zero, no fuzzy
    @IsTest static void testCommitWritesWithSnapshotAndCleanKpis() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RunSummary sum;
        System.runAs(sc.fullUser) {
            Test.startTest();
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, true);
            Test.stopTest();
        }
        System.assertEquals(1, sum.succeeded, 'one Lead written');
        System.assert(sum.snapshotCaptured >= 1, 'snapshot captured');
        System.assertEquals(0, sum.recordsWrittenWithoutSnapshot, 'tripwire: snapshot');
        System.assertEquals(0, sum.recordsWrittenWithoutApproval, 'tripwire: approval');
        System.assertEquals(0, sum.recordsWrittenWithoutRunId, 'tripwire: runId');
        System.assertEquals(0, sum.fuzzyMatchUsedCount, 'no fuzzy matching');

        Lead after = [SELECT USASpending_Latest_Award_ID__c, UEI_Verification_Status__c,
                             USASpending_Source_Run_ID__c
                      FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals('AWD-001', after.USASpending_Latest_Award_ID__c, 'award id written');
        System.assertEquals('Verified', after.UEI_Verification_Status__c, 'status verified');

        OA_USASpending_Staging__c st = [SELECT Review_Status__c, Written_Back_Date__c, Before_Snapshot__c
                                        FROM OA_USASpending_Staging__c WHERE Id = :sc.stagingId];
        System.assertEquals('Written Back', st.Review_Status__c, 'staging stamped');
        System.assertNotEquals(null, st.Written_Back_Date__c, 'written date stamped');
        System.assertNotEquals(null, st.Before_Snapshot__c, 'snapshot persisted before write');
        System.assert(st.Before_Snapshot__c.contains('writeBackRunId'), 'snapshot has runId');
        System.assert(st.Before_Snapshot__c.contains(String.valueOf(sc.leadId)), 'snapshot has leadId');
    }

    // 8b — re-running the same row after a commit is idempotent (no second write)
    @IsTest static void testIdempotentRerun() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, true);
            OA_LeadWritebackService.RunSummary again =
                OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, true);
            System.assertEquals(0, again.succeeded, 'no second write');
            System.assert(again.idempotencySkips >= 1, 'skipped on rerun');
        }
    }

    // 11 — partial failure does not abort the whole run
    @IsTest static void testPartialFailureDoesNotAbort() {
        Scn sc = setup('Approved', true, false);
        Id badStagingId;
        System.runAs(sc.fullUser) {
            Lead ld2 = new Lead(LastName = 'WB Target 2', Company = 'WB Co 2',
                                Email = 'wbtarget2' + String.valueOf(System.now().getTime()) + '@example.com');
            insert ld2;
            OA_USASpending_Staging__c bad = new OA_USASpending_Staging__c(
                Review_Status__c = 'Pending', // not approved => must fail, not abort
                Lead__c = ld2.Id,
                Recipient_UEI__c = 'ZZZ999YYY888',
                Award_ID__c = 'AWD-002', Award_Amount__c = 5,
                Awarding_Agency__c = 'Dept Two', Enrichment_Run_ID__c = 'ENR-002',
                Query_Date__c = Date.today()
            );
            insert bad;
            badStagingId = bad.Id;

            OA_LeadWritebackService.RunSummary sum =
                OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId, badStagingId }, 25, true);

            System.assertEquals(1, sum.succeeded, 'good row written');
            System.assert(sum.failed >= 1, 'bad row failed');
            System.assertEquals('WRITTEN', outcomeFor(sum, sc.stagingId).status, 'good WRITTEN');
            System.assertEquals('FAILED', outcomeFor(sum, badStagingId).status, 'bad FAILED');
        }
    }

    // 12 — this code assigns no permission set (writeBack performs no PSA DML)
    @IsTest static void testNoPermsetAssignmentByCode() {
        Scn sc = setup('Approved', true, false);
        Integer before = [SELECT COUNT() FROM PermissionSetAssignment
                          WHERE PermissionSet.Name = 'OA_Lead_Writeback_Automation'];
        System.runAs(sc.fullUser) {
            OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, false);
        }
        Integer after = [SELECT COUNT() FROM PermissionSetAssignment
                         WHERE PermissionSet.Name = 'OA_Lead_Writeback_Automation'];
        System.assertEquals(before, after, 'writeBack must not assign permission sets');
    }

    // 13 — no connector invocation / no callouts occur
    @IsTest static void testNoCalloutOccurs() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            Test.startTest();
            OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 5, true);
            Test.stopTest();
            System.assertEquals(0, Limits.getCallouts(), 'engine makes no callouts');
        }
    }

    // empty / null input is handled safely
    @IsTest static void testEmptyInput() {
        OA_LeadWritebackService.RunSummary s1 = OA_LeadWritebackService.writeBack(null, 5, false);
        OA_LeadWritebackService.RunSummary s2 = OA_LeadWritebackService.writeBack(new List<Id>(), 5, false);
        System.assertEquals(0, s1.attempted);
        System.assertEquals(0, s2.attempted);
        System.assertEquals(5, s1.effectiveLimit, 'default limit applied');
    }
}
