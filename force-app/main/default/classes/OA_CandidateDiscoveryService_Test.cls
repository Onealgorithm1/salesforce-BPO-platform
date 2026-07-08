/**
 * Unit tests for OA_CandidateDiscoveryService — in-memory canonical orgs only (NO callouts, NO live data).
 * Tests run in an isolated transaction and roll back; they never touch production records.
 */
@isTest
private class OA_CandidateDiscoveryService_Test {

    private static OA_CanonicalOrg org(String name, String uei, String cage, String state) {
        OA_CanonicalOrg c = new OA_CanonicalOrg();
        c.organizationName = name;
        c.normalizedName = (name == null ? null : name.toUpperCase());
        c.uei = uei;
        c.cageCode = cage;
        c.state = state;
        c.sourceSystem = 'USASPENDING';
        c.sourceConfidence = 'HIGH';
        return c;
    }

    @isTest
    static void preview_writes_nothing() {
        List<OA_CanonicalOrg> orgs = new List<OA_CanonicalOrg>{ org('Acme Robotics', 'UEIACME000A1', 'CAGE1', 'CO') };
        Test.startTest();
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.preview(orgs);
        Test.stopTest();
        System.assertEquals(false, o.committed, 'preview must not commit');
        System.assertEquals(0, o.inserted, 'preview inserts nothing');
        System.assertEquals(1, o.wouldInsert, 'one unique candidate would insert');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'no rows written in preview');
    }

    @isTest
    static void persist_inserts_unique_needs_review() {
        List<OA_CanonicalOrg> orgs = new List<OA_CanonicalOrg>{ org('Navigational Svcs', 'UEINAV0000B2', 'CAGE2', 'MD') };
        Test.startTest();
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(orgs, true);
        Test.stopTest();
        System.assertEquals(1, o.inserted, 'one candidate inserted');
        List<OA_Discovered_Organization__c> rows = [SELECT Qualification_Status__c, Canonical_Key__c, Source_Payload_Hash__c FROM OA_Discovered_Organization__c];
        System.assertEquals(1, rows.size());
        System.assertEquals('Needs Review', rows[0].Qualification_Status__c, 'unique candidate needs review');
        System.assertEquals('UEI:UEINAV0000B2', rows[0].Canonical_Key__c, 'canonical key from UEI');
        System.assert(String.isNotBlank(rows[0].Source_Payload_Hash__c), 'payload hash populated');
    }

    @isTest
    static void duplicate_of_existing_lead_is_flagged_and_linked() {
        Lead l = new Lead(LastName = 'Dupe', Company = 'Existing Co', Email = 'dupe@example.com', UEI__c = 'UEIDUP0000C3');
        insert l;
        List<OA_CanonicalOrg> orgs = new List<OA_CanonicalOrg>{ org('Existing Co', 'UEIDUP0000C3', 'CAGE3', 'VA') };
        Test.startTest();
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(orgs, true);
        Test.stopTest();
        System.assertEquals(1, o.duplicates, 'flagged as duplicate of existing Lead');
        System.assertEquals(0, o.wouldInsert, 'not counted as a fresh candidate');
        OA_Discovered_Organization__c d = [SELECT Qualification_Status__c, Matched_Lead__c FROM OA_Discovered_Organization__c LIMIT 1];
        System.assertEquals('Duplicate', d.Qualification_Status__c);
        System.assertEquals(l.Id, d.Matched_Lead__c, 'matched to the existing Lead; no Lead created');
        System.assertEquals(1, [SELECT COUNT() FROM Lead], 'no new Lead created by the service');
    }

    @isTest
    static void idempotent_rerun_skips_already_staged() {
        List<OA_CanonicalOrg> orgs = new List<OA_CanonicalOrg>{ org('Repeat Inc', 'UEIREP0000D4', 'CAGE4', 'TX') };
        OA_CandidateDiscoveryService.persist(orgs, true);           // first run inserts
        Test.startTest();
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(orgs, true); // second run
        Test.stopTest();
        System.assertEquals(1, o.skipped, 'same payload hash already staged -> skipped');
        System.assertEquals(0, o.inserted, 'no duplicate candidate inserted');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'still exactly one candidate');
    }

    @isTest
    static void empty_input_is_safe() {
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(new List<OA_CanonicalOrg>(), true);
        System.assertEquals(0, o.evaluated);
        System.assertEquals(0, o.inserted);
    }
}
