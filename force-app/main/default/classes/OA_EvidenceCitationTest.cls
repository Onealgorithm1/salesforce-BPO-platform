/**
 * OA_EvidenceCitationTest — Program 024D.
 * Proves the evidence-citation layer: rollup onto a signal, highest-confidence selection,
 * exclusion of superseded/withdrawn evidence, the unsupported-recommendation path, and partner citation.
 */
@IsTest
private class OA_EvidenceCitationTest {

    private static OA_Knowledge_Document__c evidence(Id signalId, Id profileId, String type, String source, String conf, String status) {
        return new OA_Knowledge_Document__c(
            Opportunity_Signal__c = signalId, Company_Profile__c = profileId,
            Document_Type__c = type, Source__c = source, Confidence__c = conf,
            Extraction_Status__c = 'Extracted', Document_Status__c = status,
            Content_Document_Id__c = '068000000000000AAA',
            Provenance__c = 'file=' + type + ' | source=' + source + ' | checksum=abc123');
    }

    @IsTest
    static void signalCitationRollsUpHighestConfidence() {
        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c(Title__c = 'VA Cloud BPO', Source__c = 'SAM.gov', Review_Status__c = 'Pending');
        insert sig;
        insert new List<OA_Knowledge_Document__c>{
            evidence(sig.Id, null, 'Solicitation', 'SAM.gov', 'HIGH', 'Original'),
            evidence(sig.Id, null, 'Capability Statement', 'Company', 'MEDIUM', 'Original'),
            evidence(sig.Id, null, 'Amendment', 'SAM.gov', 'LOW', 'Superseded')  // excluded
        };

        Test.startTest();
        OA_EvidenceCitation.Citation c = OA_EvidenceCitation.cite(sig.Id);
        Test.stopTest();

        System.assertEquals(2, c.evidenceCount, 'superseded evidence excluded');
        System.assertEquals('HIGH', c.highestConfidence, 'highest confidence wins');
        System.assert(c.evidenceBacked, 'evidence-backed');
        OA_Opportunity_Signal__c saved = [SELECT Evidence_Count__c, Evidence_Confidence__c, Evidence_Backed__c,
            Evidence_Summary__c, Last_Evidence_Date__c FROM OA_Opportunity_Signal__c WHERE Id = :sig.Id];
        System.assertEquals(2, saved.Evidence_Count__c);
        System.assertEquals('HIGH', saved.Evidence_Confidence__c);
        System.assertEquals(true, saved.Evidence_Backed__c);
        System.assert(saved.Evidence_Summary__c.contains('checksum='), 'summary carries provenance (traceable)');
        System.assert(saved.Evidence_Summary__c.contains('[HIGH]'), 'summary shows confidence per document');
    }

    @IsTest
    static void unsupportedRecommendationIsFlagged() {
        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c(Title__c = 'No evidence', Source__c = 'Grants.gov', Review_Status__c = 'Pending');
        insert sig;

        Test.startTest();
        OA_EvidenceCitation.Citation c = OA_EvidenceCitation.cite(sig.Id);
        Test.stopTest();

        System.assertEquals(0, c.evidenceCount);
        System.assertEquals('None', c.highestConfidence);
        System.assert(!c.evidenceBacked, 'no evidence => not backed');
        System.assert(c.summary.contains('UNSUPPORTED'), 'unsupported recommendation is explicitly flagged');
        OA_Opportunity_Signal__c saved = [SELECT Evidence_Backed__c FROM OA_Opportunity_Signal__c WHERE Id = :sig.Id];
        System.assertEquals(false, saved.Evidence_Backed__c);
    }

    @IsTest
    static void partnerCitationDetectsCapabilityStatement() {
        OA_Company_Profile__c cp = new OA_Company_Profile__c(Organization_Name__c = 'Test Partner');
        insert cp;
        insert new List<OA_Knowledge_Document__c>{
            evidence(null, cp.Id, 'Capability Statement', 'Partner', 'MEDIUM', 'Original'),
            evidence(null, cp.Id, 'Certification', 'Partner', 'MEDIUM', 'Original')
        };

        Test.startTest();
        OA_EvidenceCitation.Citation c = OA_EvidenceCitation.citeProfile(cp.Id);
        Test.stopTest();

        System.assertEquals(2, c.evidenceCount);
        OA_Company_Profile__c saved = [SELECT Evidence_Document_Count__c, Has_Capability_Statement__c,
            Evidence_Summary__c FROM OA_Company_Profile__c WHERE Id = :cp.Id];
        System.assertEquals(2, saved.Evidence_Document_Count__c);
        System.assertEquals(true, saved.Has_Capability_Statement__c, 'capability statement detected');
        System.assertNotEquals(null, saved.Evidence_Summary__c);
    }

    @IsTest
    static void explainIsReadOnly() {
        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c(Title__c = 'Explain', Source__c = 'SAM.gov', Review_Status__c = 'Pending');
        insert sig;
        insert evidence(sig.Id, null, 'RFP', 'SAM.gov', 'HIGH', 'Original');

        Test.startTest();
        OA_EvidenceCitation.Citation c = OA_EvidenceCitation.explain(sig.Id);
        Test.stopTest();

        System.assertEquals(1, c.evidenceCount);
        System.assertEquals('HIGH', c.highestConfidence);
        OA_Opportunity_Signal__c saved = [SELECT Evidence_Count__c FROM OA_Opportunity_Signal__c WHERE Id = :sig.Id];
        System.assertEquals(null, saved.Evidence_Count__c, 'explain() does not write');
    }
}
