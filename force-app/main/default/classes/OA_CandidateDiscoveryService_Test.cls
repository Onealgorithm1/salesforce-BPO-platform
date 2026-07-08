/**
 * Tests for the identity-aware, fusion-enabled OA_CandidateDiscoveryService — in-memory canonical orgs + test-created
 * records only (NO callouts, NO live data). Proves preview 0 DML; NONE->insert Needs Review; Lead match->Duplicate
 * (no Lead created); exact-duplicate skip; cross-source MATCH->fusion (fill-empty + provenance, UPDATE not insert).
 */
@isTest
private class OA_CandidateDiscoveryService_Test {

    private static OA_CanonicalOrg org(String name, String uei, String cage, String state) {
        return org(name, uei, cage, state, 'USASPENDING', null);
    }
    private static OA_CanonicalOrg org(String name, String uei, String cage, String state, String src, String website) {
        OA_CanonicalOrg c = new OA_CanonicalOrg();
        c.organizationName = name;
        c.normalizedName = (name == null ? null : name.toUpperCase());
        c.uei = uei; c.cageCode = cage; c.state = state; c.sourceSystem = src; c.website = website;
        c.sourceConfidence = 'HIGH';
        return c;
    }

    @isTest static void preview_writes_nothing() {
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.preview(
            new List<OA_CanonicalOrg>{ org('Acme Robotics', 'UEIACME000A1', 'CAGE1', 'CO') });
        System.assertEquals(false, o.committed, 'preview must not commit');
        System.assertEquals(0, o.inserted, 'preview inserts nothing');
        System.assertEquals(1, o.wouldInsert, 'one unique candidate would insert');
        System.assertEquals(0, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'no rows written in preview');
    }

    @isTest static void persist_inserts_unique_needs_review() {
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(
            new List<OA_CanonicalOrg>{ org('Navigational Svcs', 'UEINAV0000B2', 'CAGE2', 'MD') }, true);
        System.assertEquals(1, o.inserted, 'one candidate inserted');
        List<OA_Discovered_Organization__c> rows = [SELECT Qualification_Status__c, Canonical_Key__c, Source_Payload_Hash__c FROM OA_Discovered_Organization__c];
        System.assertEquals(1, rows.size());
        System.assertEquals('Needs Review', rows[0].Qualification_Status__c, 'unique candidate needs review');
        System.assertEquals('UEI:UEINAV0000B2', rows[0].Canonical_Key__c, 'canonical key from UEI');
        System.assert(String.isNotBlank(rows[0].Source_Payload_Hash__c), 'payload hash populated');
    }

    @isTest static void duplicate_of_existing_lead_is_flagged_and_linked() {
        Lead l = new Lead(LastName = 'Dupe', Company = 'Existing Co', Email = 'dupe@example.com', UEI__c = 'UEIDUP0000C3');
        insert l;
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(
            new List<OA_CanonicalOrg>{ org('Existing Co', 'UEIDUP0000C3', 'CAGE3', 'VA') }, true);
        System.assertEquals(1, o.duplicates, 'flagged as duplicate of existing Lead');
        System.assertEquals(0, o.wouldInsert, 'not counted as a fresh candidate');
        System.assertEquals(0, o.fused, 'a Lead match is not a candidate fusion');
        OA_Discovered_Organization__c d = [SELECT Qualification_Status__c, Matched_Lead__c FROM OA_Discovered_Organization__c LIMIT 1];
        System.assertEquals('Duplicate', d.Qualification_Status__c);
        System.assertEquals(l.Id, d.Matched_Lead__c, 'matched to the existing Lead; no Lead created');
        System.assertEquals(1, [SELECT COUNT() FROM Lead], 'no new Lead created by the service');
    }

    @isTest static void idempotent_rerun_skips_already_staged() {
        OA_CanonicalOrg c = org('Repeat Inc', 'UEIREP0000D4', 'CAGE4', 'TX');
        OA_CandidateDiscoveryService.persist(new List<OA_CanonicalOrg>{ c }, true);           // first run inserts
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(new List<OA_CanonicalOrg>{ c }, true); // second run
        System.assertEquals(1, o.skipped, 'same payload hash already staged -> skipped');
        System.assertEquals(0, o.inserted, 'no duplicate candidate inserted');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'still exactly one candidate');
    }

    @isTest static void cross_source_match_fuses_existing_candidate() {
        // Existing USASpending candidate: UEI + name + state; NO website/CAGE.
        OA_CanonicalOrg us = org('Fuse Co', 'UEIFUSE0005', null, 'CA', 'USASPENDING', null);
        insert new OA_Discovered_Organization__c(
            Organization_Name__c = 'Fuse Co', Normalized_Name__c = 'FUSE CO', UEI__c = 'UEIFUSE0005', State__c = 'CA',
            Source_System__c = 'USASPENDING', Source_Confidence__c = 'MEDIUM',
            Canonical_Key__c = us.canonicalKey(), Source_Payload_Hash__c = us.payloadHash());
        // Incoming SAM record: SAME UEI + adds CAGE + website; different source -> different payload hash -> MATCH (not exact-dup).
        OA_CanonicalOrg sam = org('Fuse Co', 'UEIFUSE0005', 'CAGE9', 'CA', 'SAM', 'https://fuse.example');
        Test.startTest();
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(new List<OA_CanonicalOrg>{ sam }, true);
        Test.stopTest();
        System.assertEquals(1, o.fused, 'merged into the existing candidate');
        System.assertEquals(0, o.inserted, 'no new candidate inserted');
        System.assertEquals(1, o.updated, 'one candidate updated by fusion');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Discovered_Organization__c], 'still exactly one candidate');
        OA_Discovered_Organization__c d = [SELECT Website__c, CAGE_Code__c, Source_Confidence__c, Discovery_Metadata__c FROM OA_Discovered_Organization__c LIMIT 1];
        System.assertEquals('https://fuse.example', d.Website__c, 'blank website filled from SAM');
        System.assertEquals('CAGE9', d.CAGE_Code__c, 'blank CAGE filled from SAM');
        System.assertEquals('HIGH', d.Source_Confidence__c, 'confidence upgraded MEDIUM->HIGH');
        System.assert(d.Discovery_Metadata__c != null && d.Discovery_Metadata__c.contains('sources'), 'provenance recorded');
    }

    @isTest static void empty_input_is_safe() {
        OA_CandidateDiscoveryService.Outcome o = OA_CandidateDiscoveryService.persist(new List<OA_CanonicalOrg>(), true);
        System.assertEquals(0, o.evaluated);
        System.assertEquals(0, o.inserted);
    }
}
