/**
 * OA_BusinessLifecycle_Test — coverage for the BLO engine (states, approval, creation, orchestrator)
 * including BLO Phase 2 contact-resolution: reviewer-supplied Reviewed_Contact_Email__c, the Lead Ready
 * READINESS gate, and no-bypass of the Require_Email_Or_Contact_Person_Email rule. No production data touched.
 */
@isTest
private class OA_BusinessLifecycle_Test {

    @testSetup
    static void setup() {
        List<OA_Discovered_Organization__c> cs = new List<OA_Discovered_Organization__c>{
            // Alpha: approved WITH a reviewer-supplied contact email (field-read happy path)
            new OA_Discovered_Organization__c(Organization_Name__c='Alpha Corp', UEI__c='UEIALPHA0001',
                Source_System__c='USASpending', Source_Confidence__c='HIGH', Confidence_Score__c=47,
                Canonical_Key__c='UEI:UEIALPHA0001', Qualification_Status__c='Approved',
                Reviewed_Contact_Email__c='alpha@example.com'),
            // Beta: needs review (eligibility)
            new OA_Discovered_Organization__c(Organization_Name__c='Beta Corp', UEI__c='UEIBETA00002',
                Source_System__c='SEC', Qualification_Status__c='Needs Review'),
            // Gamma: approved, UEI matches an existing Lead (dedup)
            new OA_Discovered_Organization__c(Organization_Name__c='Gamma Corp', UEI__c='UEIDEDUP0003',
                Source_System__c='USASpending', Qualification_Status__c='Approved'),
            // Delta: approved, NO reviewed email (readiness / no-email blocking)
            new OA_Discovered_Organization__c(Organization_Name__c='Delta Corp', UEI__c='UEIDELTA0004',
                Source_System__c='SAM', Qualification_Status__c='Approved'),
            // Epsilon: approved, SEC/CIK-only (no UEI/CAGE) — matches an existing Lead by CIK
            new OA_Discovered_Organization__c(Organization_Name__c='Epsilon Corp', CIK__c='0000012345',
                Source_System__c='SEC', Qualification_Status__c='Approved')
        };
        insert cs;
        insert new Lead(Company='Gamma Existing', LastName='Gamma Existing',
            UEI__c='UEIDEDUP0003', Contact_Person_s_Email__c='gamma@example.com');
        insert new Lead(Company='Epsilon Existing', LastName='Epsilon Existing',
            CIK__c='0000012345', Contact_Person_s_Email__c='epsilon@example.com');
    }

    private static OA_Discovered_Organization__c candByName(String n) {
        return [SELECT Id, Reviewed_Contact_Email__c FROM OA_Discovered_Organization__c
                WHERE Organization_Name__c = :n LIMIT 1];
    }

    @isTest static void testStateMachine() {
        System.assert(OA_LifecycleStates.canTransition('Needs Review', 'Approved'));
        System.assert(!OA_LifecycleStates.canTransition('Needs Review', 'Converted'));
        System.assert(OA_LifecycleStates.canTransition(null, 'Approved'));
        System.assert(OA_LifecycleStates.isTerminal('Converted'));
        System.assertEquals('Needs Review', OA_LifecycleStates.effective(null));
    }

    @isTest static void testApprovalGuardsAndReadinessGate() {
        Id beta = candByName('Beta Corp').Id;
        Id delta = candByName('Delta Corp').Id;
        Test.startTest();
        // approve Beta (preview 0 DML then commit)
        System.assertEquals(0, OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Approved', 'r', 'ok', false).dmlRows);
        System.assertEquals(1, OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Approved', 'r', 'ok', true).dmlRows);
        // CONVERT_GUARD
        System.assertEquals('CONVERT_GUARD',
            OA_CandidateApprovalService.transition(new List<Id>{beta}, 'Converted', 'r', 'x', true).outcomes[0].gate);
        // READINESS: Delta (Approved, no reviewed email) cannot become Lead Ready
        OA_CandidateApprovalService.RunSummary blocked =
            OA_CandidateApprovalService.transition(new List<Id>{delta}, 'Lead Ready', 'r', 'go', true);
        System.assertEquals(1, blocked.blocked);
        System.assertEquals('READINESS', blocked.outcomes[0].gate);
        // supply reviewed email -> now Lead Ready is allowed
        update new OA_Discovered_Organization__c(Id = delta, Reviewed_Contact_Email__c = 'delta@example.com');
        OA_CandidateApprovalService.RunSummary ok =
            OA_CandidateApprovalService.transition(new List<Id>{delta}, 'Lead Ready', 'r', 'go', true);
        System.assertEquals(1, ok.applied);
        Test.stopTest();
        System.assertEquals('Lead Ready',
            [SELECT Qualification_Status__c FROM OA_Discovered_Organization__c WHERE Id = :delta].Qualification_Status__c);
    }

    @isTest static void testCreatePreviewZeroDml() {
        Id alpha = candByName('Alpha Corp').Id;
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.preview(new List<Id>{alpha});
        Test.stopTest();
        System.assertEquals(0, s.dmlRows);
        System.assertEquals('PREVIEW_OK', s.rows[0].status);
        System.assert(s.rows[0].reason.contains('Lead Ready'));   // reviewed email present
    }

    @isTest static void testCreateFromReviewedFieldEmail() {
        Id alpha = candByName('Alpha Corp').Id;   // has Reviewed_Contact_Email__c; NO map passed
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{alpha}, null, true);
        Test.stopTest();
        System.assertEquals(1, s.created, 'field-supplied reviewed email should satisfy the rule');
        OA_Discovered_Organization__c c =
            [SELECT Qualification_Status__c, Matched_Lead__c FROM OA_Discovered_Organization__c WHERE Id = :alpha];
        System.assertEquals('Converted', c.Qualification_Status__c);
        System.assertNotEquals(null, c.Matched_Lead__c);
    }

    @isTest static void testCreateFromMapOverride() {
        Id delta = candByName('Delta Corp').Id;   // no field email; map supplies it
        Test.startTest();
        OA_LeadCreationService.RunSummary s =
            OA_LeadCreationService.create(new List<Id>{delta}, new Map<Id,String>{delta=>'delta@example.com'}, true);
        Test.stopTest();
        System.assertEquals(1, s.created);
    }

    @isTest static void testCreateBlockedNoEmailNeverBypasses() {
        Id delta = candByName('Delta Corp').Id;   // no field email, no map
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{delta}, null, true);
        Test.stopTest();
        System.assertEquals(0, s.created);
        System.assertEquals(1, s.failed);
        System.assertEquals('VALIDATION', s.rows[0].gate);
    }

    @isTest static void testEligibilityDedupIdempotency() {
        Id beta = candByName('Beta Corp').Id;
        Id gamma = candByName('Gamma Corp').Id;
        Test.startTest();
        System.assertEquals('ELIGIBILITY',
            OA_LeadCreationService.create(new List<Id>{beta}, null, true).rows[0].gate);
        OA_LeadCreationService.RunSummary ded = OA_LeadCreationService.create(new List<Id>{gamma}, null, true);
        System.assertEquals(1, ded.duplicates);
        System.assertEquals('MATCH', ded.rows[0].gate);
        System.assertEquals('IDEMPOTENCY',
            OA_LeadCreationService.create(new List<Id>{gamma}, null, true).rows[0].gate);
        Test.stopTest();
    }

    @isTest static void testCikAwareDedup() {
        Id eps = candByName('Epsilon Corp').Id;   // CIK-only; matches existing Lead by CIK
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{eps}, null, true);
        Test.stopTest();
        System.assertEquals(1, s.duplicates, 'CIK-only candidate should link via CIK, not create');
        System.assertEquals('MATCH', s.rows[0].gate);
        System.assertEquals(0, s.created);
    }

    @isTest static void testRollbackCreated() {
        Id alpha = candByName('Alpha Corp').Id;
        Test.startTest();
        OA_LeadCreationService.RunSummary s = OA_LeadCreationService.create(new List<Id>{alpha}, null, true);
        Integer n = OA_LeadCreationService.rollbackCreated(s.createdLeadIds);
        Test.stopTest();
        System.assertEquals(1, n);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Id IN :s.createdLeadIds]);
        System.assertEquals('Lead Ready',
            [SELECT Qualification_Status__c FROM OA_Discovered_Organization__c WHERE Id = :alpha].Qualification_Status__c);
    }

    @isTest static void testOrchestrator() {
        Id delta = candByName('Delta Corp').Id;
        update new OA_Discovered_Organization__c(Id = delta, Reviewed_Contact_Email__c = 'delta@example.com');
        Test.startTest();
        System.assertEquals(0, OA_BusinessLifecycleService.preview(new List<Id>{delta}).creation.dmlRows);
        OA_BusinessLifecycleService.LifecycleReport adv = OA_BusinessLifecycleService.advance(
            new List<Id>{delta}, 'Lead Ready', 'tester', 'ready', null, true);
        Test.stopTest();
        System.assertNotEquals(null, adv.approval);
        System.assertEquals(1, adv.creation.created);
    }
}
