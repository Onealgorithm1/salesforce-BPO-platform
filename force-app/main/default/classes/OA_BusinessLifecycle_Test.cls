/**
 * OA_BusinessLifecycle_Test — coverage for the BLO engine (states, approval, creation, orchestrator).
 * Uses only test-context DML; asserts governance (human-approval gate, dedup, no-bypass of the
 * Require_Email_Or_Contact_Person_Email rule, idempotency, rollback). No production data touched.
 */
@isTest
private class OA_BusinessLifecycle_Test {

    @testSetup
    static void setup() {
        List<OA_Discovered_Organization__c> cs = new List<OA_Discovered_Organization__c>{
            new OA_Discovered_Organization__c(Organization_Name__c='Alpha Corp', UEI__c='UEIALPHA0001',
                Source_System__c='USASpending', Source_Confidence__c='HIGH', Confidence_Score__c=47,
                Canonical_Key__c='UEI:UEIALPHA0001', Qualification_Status__c='Approved'),
            new OA_Discovered_Organization__c(Organization_Name__c='Beta Corp', UEI__c='UEIBETA00002',
                Source_System__c='SEC', Qualification_Status__c='Needs Review'),
            new OA_Discovered_Organization__c(Organization_Name__c='Gamma Corp', UEI__c='UEIDEDUP0003',
                Source_System__c='USASpending', Qualification_Status__c='Approved'),
            new OA_Discovered_Organization__c(Organization_Name__c='Delta Corp', UEI__c='UEIDELTA0004',
                Source_System__c='SAM', Qualification_Status__c='Approved')
        };
        insert cs;
        // Dedup target: an existing Lead sharing Gamma's UEI (with contact email to satisfy the org rule).
        insert new Lead(Company='Gamma Existing', LastName='Gamma Existing',
            UEI__c='UEIDEDUP0003', Contact_Person_s_Email__c='gamma@example.com');
    }

    private static Id candByName(String n) {
        return [SELECT Id FROM OA_Discovered_Organization__c WHERE Organization_Name__c = :n LIMIT 1].Id;
    }

    @isTest static void testStateMachine() {
        System.assert(OA_LifecycleStates.canTransition('Needs Review', 'Approved'));
        System.assert(!OA_LifecycleStates.canTransition('Needs Review', 'Converted'));
        System.assert(OA_LifecycleStates.canTransition(null, 'Approved'));   // null -> Needs Review
        System.assert(OA_LifecycleStates.isTerminal('Converted'));
        System.assertEquals('Needs Review', OA_LifecycleStates.effective(null));
    }

    @isTest static void testApprovalPreviewAndCommitAndGuards() {
        Id beta = candByName('Beta Corp');
        Test.startTest();
        // preview = 0 DML
        OA_CandidateApprovalService.RunSummary prev =
            OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Approved', 'tester', 'looks good', false);
        System.assertEquals(0, prev.dmlRows);
        System.assertEquals(1, prev.applied);
        // commit
        OA_CandidateApprovalService.RunSummary com =
            OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Approved', 'tester', 'ok', true);
        System.assertEquals(1, com.dmlRows);
        // CONVERT_GUARD: approval engine cannot set Converted
        OA_CandidateApprovalService.RunSummary guard =
            OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Converted', 'tester', 'x', true);
        System.assertEquals(1, guard.blocked);
        System.assertEquals('CONVERT_GUARD', guard.outcomes[0].gate);
        Test.stopTest();
        System.assertEquals('Approved',
            [SELECT Qualification_Status__c FROM OA_Discovered_Organization__c WHERE Id = :beta].Qualification_Status__c);
    }

    @isTest static void testCreatePreviewZeroDml() {
        Id alpha = candByName('Alpha Corp');
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.preview(new List<Id>{alpha});
        Test.stopTest();
        System.assertEquals(0, s.dmlRows);
        System.assertEquals('PREVIEW_OK', s.rows[0].status);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE UEI__c='UEIALPHA0001']);
    }

    @isTest static void testCreateCommitSuccessWithEmail() {
        Id alpha = candByName('Alpha Corp');
        Map<Id, String> emails = new Map<Id, String>{ alpha => 'alpha@example.com' };
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{alpha}, emails, true);
        Test.stopTest();
        System.assertEquals(1, s.created, 'expected one Lead created');
        System.assertEquals(1, s.createdLeadIds.size());
        OA_Discovered_Organization__c c =
            [SELECT Qualification_Status__c, Matched_Lead__c FROM OA_Discovered_Organization__c WHERE Id = :alpha];
        System.assertEquals('Converted', c.Qualification_Status__c);
        System.assertNotEquals(null, c.Matched_Lead__c);
    }

    @isTest static void testCreateBlockedNoEmailNeverBypassesRule() {
        Id delta = candByName('Delta Corp');
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{delta}, null, true);
        Test.stopTest();
        System.assertEquals(0, s.created);
        System.assertEquals(1, s.failed);
        System.assertEquals('VALIDATION', s.rows[0].gate);   // org email rule enforced, not bypassed
    }

    @isTest static void testEligibilityAndDedupAndIdempotency() {
        Id beta = candByName('Beta Corp');      // Needs Review -> ELIGIBILITY skip
        Id gamma = candByName('Gamma Corp');    // UEI matches existing Lead -> MATCH
        Test.startTest();
        OA_LeadCreationService.RunSummary elig = OA_LeadCreationService.create(new List<Id>{beta}, null, true);
        System.assertEquals('ELIGIBILITY', elig.rows[0].gate);
        OA_LeadCreationService.RunSummary ded = OA_LeadCreationService.create(new List<Id>{gamma}, null, true);
        System.assertEquals(1, ded.duplicates);
        System.assertEquals('MATCH', ded.rows[0].gate);
        // now gamma is linked -> IDEMPOTENCY on re-run
        OA_LeadCreationService.RunSummary idem = OA_LeadCreationService.create(new List<Id>{gamma}, null, true);
        System.assertEquals('IDEMPOTENCY', idem.rows[0].gate);
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Matched_Lead__c FROM OA_Discovered_Organization__c WHERE Id = :gamma].Matched_Lead__c);
    }

    @isTest static void testRollbackCreated() {
        Id alpha = candByName('Alpha Corp');
        Test.startTest();
        OA_LeadCreationService.RunSummary s =
            OA_LeadCreationService.create(new List<Id>{alpha}, new Map<Id,String>{alpha=>'a@example.com'}, true);
        Integer n = OA_LeadCreationService.rollbackCreated(s.createdLeadIds);
        Test.stopTest();
        System.assertEquals(1, n);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Id IN :s.createdLeadIds]);
        System.assertEquals('Lead Ready',
            [SELECT Qualification_Status__c FROM OA_Discovered_Organization__c WHERE Id = :alpha].Qualification_Status__c);
    }

    @isTest static void testOrchestrator() {
        Id delta = candByName('Delta Corp');
        Test.startTest();
        OA_BusinessLifecycleService.LifecycleReport prev = OA_BusinessLifecycleService.preview(new List<Id>{delta});
        System.assertEquals(0, prev.creation.dmlRows);
        OA_BusinessLifecycleService.LifecycleReport adv = OA_BusinessLifecycleService.advance(
            new List<Id>{delta}, 'Lead Ready', 'tester', 'ready',
            new Map<Id,String>{delta=>'delta@example.com'}, true);
        Test.stopTest();
        System.assertNotEquals(null, adv.approval);
        System.assertEquals(1, adv.creation.created);
    }
}
