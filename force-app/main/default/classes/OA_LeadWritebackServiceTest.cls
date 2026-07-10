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

    // Helper: add a second Approved staging row on an existing Lead (distinct award).
    private static Id addApprovedRow(Id leadId, String awardId, Decimal amount, String runId) {
        OA_USASpending_Staging__c st = new OA_USASpending_Staging__c(
            Review_Status__c = 'Approved', Lead__c = leadId,
            Recipient_UEI__c = 'ABC123DEF456', Award_ID__c = awardId, Award_Amount__c = amount,
            Awarding_Agency__c = 'Dept of Testing', Enrichment_Run_ID__c = runId, Query_Date__c = Date.today());
        insert st;
        return st.Id;
    }

    // 14 — TWO Approved rows on ONE Lead: no ListException, exactly one write, the extra deduped.
    // Regression for WARN #12 (duplicate-Id abort). Before the fix this threw
    // System.ListException "Duplicate id in list" and rolled the whole batch back.
    @IsTest static void testTwoApprovedRowsSameLeadNoAbortSingleWrite() {
        Scn sc = setup('Approved', true, false); // row 1: AWD-001 / amount 12345.67 on sc.leadId
        OA_LeadWritebackService.RunSummary sum;
        Id highId;
        System.runAs(sc.fullUser) {
            highId = addApprovedRow(sc.leadId, 'AWD-002', 99999.00, 'ENR-002'); // higher amount
            Test.startTest();
            // List the LOWER-amount row first; the highest amount must still win.
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId, highId }, 25, true);
            Test.stopTest();
        }
        // Reaching here at all proves no uncaught ListException aborted the batch.
        System.assertEquals(1, sum.succeeded, 'exactly one Lead write');
        System.assertEquals(0, sum.failed, 'no failures (no ListException)');
        System.assertEquals(1, sum.dedupedSameLead, 'the extra same-Lead row was deduped');
        System.assertEquals(1, sum.attempted, 'only the winner is attempted');
        System.assertEquals('WRITTEN', outcomeFor(sum, highId).status, 'highest-amount row won');
        OA_LeadWritebackService.RowOutcome dup = outcomeFor(sum, sc.stagingId);
        System.assertEquals('SKIPPED', dup.status, 'lower-amount row skipped');
        System.assertEquals('DEDUPE', dup.gate, 'skipped via DEDUPE gate');

        Lead after = [SELECT USASpending_Latest_Award_ID__c FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals('AWD-002', after.USASpending_Latest_Award_ID__c, 'Lead carries the highest-amount winner');
        OA_USASpending_Staging__c w = [SELECT Review_Status__c FROM OA_USASpending_Staging__c WHERE Id = :highId];
        OA_USASpending_Staging__c d = [SELECT Review_Status__c FROM OA_USASpending_Staging__c WHERE Id = :sc.stagingId];
        System.assertEquals('Written Back', w.Review_Status__c, 'winner stamped Written Back');
        System.assertEquals('Approved', d.Review_Status__c, 'deduped row left Approved (deferred, not lost)');
    }

    // 14b — highest Award_Amount__c wins regardless of list order (here the winner is listed FIRST;
    // test 14 lists the winner LAST — together they prove amount, not order, decides).
    @IsTest static void testDedupeHighestAmountWinsRegardlessOfOrder() {
        Scn sc = setup('Approved', true, false); // AWD-001 amount 12345.67
        OA_LeadWritebackService.RunSummary sum;
        Id highId;
        System.runAs(sc.fullUser) {
            highId = addApprovedRow(sc.leadId, 'AWD-002', 88888.00, 'ENR-002'); // higher amount
            Test.startTest();
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ highId, sc.stagingId }, 25, true);
            Test.stopTest();
        }
        System.assertEquals(1, sum.succeeded, 'one write');
        System.assertEquals(1, sum.dedupedSameLead, 'one deduped');
        System.assertEquals('WRITTEN', outcomeFor(sum, highId).status, 'highest-amount row won');
        System.assertEquals('DEDUPE', outcomeFor(sum, sc.stagingId).gate, 'lower-amount row deduped');
        Lead after = [SELECT USASpending_Latest_Award_ID__c FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals('AWD-002', after.USASpending_Latest_Award_ID__c, 'Lead carries highest-amount award');
    }

    // 14e — tie-break: EQUAL Award_Amount__c falls back to caller order (first-listed wins).
    @IsTest static void testDedupeEqualAmountsFallBackToCallerOrder() {
        Scn sc = setup('Approved', true, false); // AWD-001 amount 12345.67
        OA_LeadWritebackService.RunSummary sum;
        Id tieId;
        System.runAs(sc.fullUser) {
            tieId = addApprovedRow(sc.leadId, 'AWD-002', 12345.67, 'ENR-002'); // SAME amount as AWD-001
            Test.startTest();
            // Equal amounts => the row listed FIRST (AWD-002) wins the tie-break.
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ tieId, sc.stagingId }, 25, true);
            Test.stopTest();
        }
        System.assertEquals(1, sum.succeeded, 'one write');
        System.assertEquals(1, sum.dedupedSameLead, 'one deduped');
        System.assertEquals('WRITTEN', outcomeFor(sum, tieId).status, 'equal amount => first-listed (AWD-002) won');
        System.assertEquals('DEDUPE', outcomeFor(sum, sc.stagingId).gate, 'AWD-001 deduped on tie-break');
        Lead after = [SELECT USASpending_Latest_Award_ID__c FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals('AWD-002', after.USASpending_Latest_Award_ID__c, 'tie-break winner on Lead');
    }

    // 14c — two Approved rows on one Lead in PREVIEW: winner PREVIEW_OK, extra DEDUPE, no DML.
    @IsTest static void testDedupeInPreviewNoDml() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RunSummary sum;
        Id secondId;
        System.runAs(sc.fullUser) {
            secondId = addApprovedRow(sc.leadId, 'AWD-002', 5.00, 'ENR-002');
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId, secondId }, 25, false);
        }
        System.assertEquals(0, sum.succeeded, 'preview writes nothing');
        System.assertEquals(1, sum.dedupedSameLead, 'dedupe applies in preview too');
        System.assertEquals('PREVIEW_OK', outcomeFor(sum, sc.stagingId).status, 'winner previewed');
        System.assertEquals('DEDUPE', outcomeFor(sum, secondId).gate, 'extra deduped in preview');
        Lead after = [SELECT USASpending_Latest_Award_ID__c FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals(null, after.USASpending_Latest_Award_ID__c, 'no Lead write in preview');
    }

    // 14d — distinct Leads in one batch are all written (dedupe must NOT collapse different Leads).
    @IsTest static void testDistinctLeadsAllWritten() {
        Scn sc = setup('Approved', true, false); // Lead A / AWD-001
        OA_LeadWritebackService.RunSummary sum;
        Id stB;
        System.runAs(sc.fullUser) {
            Lead ldB = new Lead(LastName = 'WB D', Company = 'WB Co D',
                                Email = 'wbd' + String.valueOf(System.now().getTime()) + '@example.com');
            insert ldB;
            stB = addApprovedRow(ldB.Id, 'AWD-D', 7.00, 'ENR-D');
            Test.startTest();
            sum = OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId, stB }, 25, true);
            Test.stopTest();
        }
        System.assertEquals(2, sum.succeeded, 'both distinct Leads written');
        System.assertEquals(0, sum.dedupedSameLead, 'no dedupe across distinct Leads');
    }

    // ---------------- ROLLBACK ----------------

    private static OA_LeadWritebackService.RollbackOutcome rbOutcomeFor(
            OA_LeadWritebackService.RollbackSummary s, Id stagingId) {
        for (OA_LeadWritebackService.RollbackOutcome ro : s.rows) {
            if (ro.stagingId == stagingId) return ro;
        }
        return null;
    }

    // R1 — rollback blocked (skipped) when Before_Snapshot__c is null
    @IsTest static void testRollbackBlocksNullSnapshot() {
        Scn sc = setup('Approved', true, false); // Before_Snapshot null
        OA_LeadWritebackService.RollbackSummary rb;
        System.runAs(sc.fullUser) {
            rb = OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId });
        }
        System.assertEquals(0, rb.succeeded, 'nothing restored');
        System.assertEquals(1, rb.skipped, 'skipped');
        System.assertEquals('SNAPSHOT_MISSING', rbOutcomeFor(rb, sc.stagingId).gate);
    }

    // R2 — rollback blocked on invalid snapshot JSON; Lead untouched
    @IsTest static void testRollbackBlocksInvalidJson() {
        Scn sc = setup('Approved', true, false);
        OA_LeadWritebackService.RollbackSummary rb;
        System.runAs(sc.fullUser) {
            update new OA_USASpending_Staging__c(Id = sc.stagingId, Before_Snapshot__c = 'not-valid-json{');
            rb = OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId });
        }
        System.assertEquals(0, rb.succeeded);
        System.assertEquals('SNAPSHOT_INVALID', rbOutcomeFor(rb, sc.stagingId).gate);
        Lead after = [SELECT USASpending_Latest_Award_ID__c FROM Lead WHERE Id = :sc.leadId];
        System.assertEquals(null, after.USASpending_Latest_Award_ID__c, 'Lead untouched');
    }

    // R3 — full round-trip: commit then rollback restores all fields, resets staging, clears markers, audits
    @IsTest static void testRollbackRestoresFieldsAndResetsStaging() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            // Known pre-values (one text set, one status set, one left null to prove null-restore).
            update new Lead(Id = sc.leadId,
                            USASpending_Latest_Award_ID__c = 'ORIG-001',
                            UEI_Verification_Status__c = 'Unverified');

            OA_LeadWritebackService.RunSummary w =
                OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 1, true);
            System.assertEquals(1, w.succeeded, 'committed');
            Lead mid = [SELECT USASpending_Latest_Award_ID__c, UEI_Verification_Status__c
                        FROM Lead WHERE Id = :sc.leadId];
            System.assertEquals('AWD-001', mid.USASpending_Latest_Award_ID__c, 'commit overwrote');
            System.assertEquals('Verified', mid.UEI_Verification_Status__c, 'commit set Verified');

            OA_LeadWritebackService.RollbackSummary rb =
                OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId });
            System.assertEquals(1, rb.attempted, 'attempted 1');
            System.assertEquals(1, rb.succeeded, 'restored 1');
            System.assertEquals(0, rb.failed, 'no failures');
            System.assertEquals(0, rb.rollbackFailures, 'no rollback failures');
            System.assertEquals('RESTORED', rbOutcomeFor(rb, sc.stagingId).status);

            Lead after = [SELECT USASpending_Latest_Award_ID__c, UEI_Verification_Status__c, USASpending_UEI__c
                          FROM Lead WHERE Id = :sc.leadId];
            System.assertEquals('ORIG-001', after.USASpending_Latest_Award_ID__c, 'restored pre-value');
            System.assertEquals('Unverified', after.UEI_Verification_Status__c, 'restored status');
            System.assertEquals(null, after.USASpending_UEI__c, 'restored null field');

            OA_USASpending_Staging__c st = [SELECT Review_Status__c, Written_Back_Date__c, Written_Back_By__c,
                                                   Before_Snapshot__c, Gate_Results__c
                                            FROM OA_USASpending_Staging__c WHERE Id = :sc.stagingId];
            System.assertEquals('Approved', st.Review_Status__c, 'reset to Approved');
            System.assertEquals(null, st.Written_Back_Date__c, 'cleared written date');
            System.assertEquals(null, st.Written_Back_By__c, 'cleared written by');
            System.assertNotEquals(null, st.Before_Snapshot__c, 'snapshot kept for audit');
            System.assert(st.Gate_Results__c.contains('Rolled back'), 'audit note appended');
        }
    }

    // R4 — rollback refuses snapshot whose leadId != staging Lead__c
    @IsTest static void testRollbackRefusesLeadIdMismatch() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            Lead other = new Lead(LastName = 'Other', Company = 'Other Co',
                                  Email = 'other' + String.valueOf(System.now().getTime()) + '@example.com');
            insert other;
            String snapJson = JSON.serialize(new Map<String, Object>{
                'leadId' => other.Id,
                'capturedAt' => System.now().format(),
                'writeBackRunId' => 'WB-x',
                'fields' => new Map<String, Object>{ 'USASpending_Latest_Award_ID__c' => 'X' }
            });
            update new OA_USASpending_Staging__c(Id = sc.stagingId, Before_Snapshot__c = snapJson);
            OA_LeadWritebackService.RollbackSummary rb =
                OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId });
            System.assertEquals(0, rb.succeeded);
            System.assertEquals('LEAD_MISMATCH', rbOutcomeFor(rb, sc.stagingId).gate);
        }
    }

    // R5 — partial success + summary counts + only explicit ids (valid restore + null-snapshot skip together)
    @IsTest static void testRollbackPartialAndCounts() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            // Row A: commit to generate a valid snapshot.
            OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 1, true);
            // Row B: approved, no snapshot (never committed).
            Lead ldB = new Lead(LastName = 'WB B', Company = 'WB Co B',
                                Email = 'wbb' + String.valueOf(System.now().getTime()) + '@example.com');
            insert ldB;
            OA_USASpending_Staging__c stB = new OA_USASpending_Staging__c(
                Review_Status__c = 'Approved', Lead__c = ldB.Id,
                Recipient_UEI__c = 'BBB222CCC333', Award_ID__c = 'AWD-B', Award_Amount__c = 9,
                Awarding_Agency__c = 'Dept B', Enrichment_Run_ID__c = 'ENR-B', Query_Date__c = Date.today());
            insert stB;

            OA_LeadWritebackService.RollbackSummary rb =
                OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId, stB.Id });
            System.assertEquals(1, rb.attempted, 'one reached restore DML');
            System.assertEquals(1, rb.succeeded, 'row A restored');
            System.assertEquals(1, rb.skipped, 'row B skipped (no snapshot)');
            System.assertEquals('RESTORED', rbOutcomeFor(rb, sc.stagingId).status);
            System.assertEquals('SKIPPED', rbOutcomeFor(rb, stB.Id).status);
        }
    }

    // R6 — rollback makes no callout and assigns no permission set
    @IsTest static void testRollbackNoCalloutNoPermset() {
        Scn sc = setup('Approved', true, false);
        System.runAs(sc.fullUser) {
            OA_LeadWritebackService.writeBack(new List<Id>{ sc.stagingId }, 1, true);
        }
        Integer before = [SELECT COUNT() FROM PermissionSetAssignment
                          WHERE PermissionSet.Name = 'OA_Lead_Writeback_Automation'];
        System.runAs(sc.fullUser) {
            Test.startTest();
            OA_LeadWritebackService.rollback(new List<Id>{ sc.stagingId });
            Test.stopTest();
            System.assertEquals(0, Limits.getCallouts(), 'rollback makes no callouts');
        }
        Integer aft = [SELECT COUNT() FROM PermissionSetAssignment
                       WHERE PermissionSet.Name = 'OA_Lead_Writeback_Automation'];
        System.assertEquals(before, aft, 'rollback assigns no permission set');
    }

    // empty input handled safely
    @IsTest static void testRollbackEmptyInput() {
        OA_LeadWritebackService.RollbackSummary rb = OA_LeadWritebackService.rollback(new List<Id>());
        System.assertEquals(0, rb.attempted);
        System.assertNotEquals(null, rb.runId);
    }
}