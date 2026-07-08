/**
 * Tests for OA_IdentityResolution — test-created data only (no SeeAllData); read-only (no DML by the resolver).
 * Proves cross-identifier matching, ambiguity->REVIEW, exact-duplicate, no-match, and Lead/Candidate/Account matching.
 */
@isTest
private class OA_IdentityResolution_Test {

    private static OA_CanonicalOrg org(String name, String uei, String cage, String cik, String ein, String state, String website) {
        OA_CanonicalOrg c = new OA_CanonicalOrg();
        c.organizationName = name; c.normalizedName = (name == null ? null : name.toUpperCase());
        c.uei = uei; c.cageCode = cage; c.cik = cik; c.ein = ein; c.state = state; c.website = website;
        c.sourceSystem = 'TEST';
        return c;
    }

    @isTest static void no_match_is_none() {
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('Unseen Co','UEINONE01','','','','CA',null));
        System.assertEquals(OA_IdentityResolution.Decision.NONE, r.decision);
    }

    @isTest static void exact_payload_hash_is_duplicate() {
        OA_CanonicalOrg src = org('Dup Co','UEIDUP01','','','', 'CA', null);
        insert new OA_Discovered_Organization__c(
            Organization_Name__c='Dup Co', UEI__c='UEIDUP01', Source_System__c='USASpending',
            Canonical_Key__c=src.canonicalKey(), Source_Payload_Hash__c=src.payloadHash(), Normalized_Name__c='DUP CO');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(src);
        System.assertEquals(OA_IdentityResolution.Decision.EXACT_DUPLICATE, r.decision);
        System.assertEquals(OA_IdentityResolution.MatchedType.CANDIDATE, r.matchedType);
    }

    @isTest static void cross_identifier_cik_matches_lead_discovered_by_cik() {
        // A Lead exists (as if from SEC) keyed by CIK; incoming org (from another source) shares the CIK.
        insert new Lead(LastName='X', Company='Prime Co', Email='p@example.com', CIK__c='0000012927');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('Prime Co', null, null, '0000012927', null, 'VA', null));
        System.assertEquals(OA_IdentityResolution.Decision.MATCH, r.decision);
        System.assertEquals(OA_IdentityResolution.MatchedType.LEAD, r.matchedType);
        System.assert(r.matchedIdentifiers.contains('CIK'), r.matchedIdentifiers.toString());
    }

    @isTest static void shared_uei_matches_existing_candidate() {
        insert new OA_Discovered_Organization__c(Organization_Name__c='UEI Co', UEI__c='UEISHARE1', Source_System__c='SAM', Normalized_Name__c='UEI CO');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('UEI Co Renamed','UEISHARE1',null,null,null,'MD',null));
        System.assertEquals(OA_IdentityResolution.Decision.MATCH, r.decision);
        System.assertEquals(99, r.confidence);
        System.assert(r.matchedIdentifiers.contains('UEI'));
    }

    @isTest static void domain_match_is_high() {
        insert new OA_Discovered_Organization__c(Organization_Name__c='Web Co', Website__c='https://webco.example/about', Source_System__c='SEC', Normalized_Name__c='WEB CO', UEI__c='UEIWEB99');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('Different Name', null, null, null, null, 'NY', 'http://www.webco.example'));
        System.assertEquals(OA_IdentityResolution.Decision.MATCH, r.decision);
        System.assert(r.matchedIdentifiers.contains('domain'));
    }

    @isTest static void name_plus_state_is_review_not_match() {
        insert new OA_Discovered_Organization__c(Organization_Name__c='Ambi Co', Normalized_Name__c='AMBI CO', State__c='TX', Source_System__c='USASpending', UEI__c='UEIAMBI01');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('Ambi Co', null, null, null, null, 'TX', null));
        System.assertEquals(OA_IdentityResolution.Decision.REVIEW, r.decision, 'name+state is ambiguous -> review, not auto-merge');
        System.assert(r.confidence < OA_IdentityResolution.T_MATCH);
    }

    @isTest static void account_domain_match_supported() {
        insert new Account(Name='ACCT CO', Website='https://acctco.example');
        OA_IdentityResolution.MatchResult r = OA_IdentityResolution.resolve(org('ACCT CO', null, null, null, null, 'CA', 'https://acctco.example'));
        System.assertEquals(OA_IdentityResolution.MatchedType.ACCOUNT, r.matchedType);
        System.assertEquals(OA_IdentityResolution.Decision.MATCH, r.decision);
    }

    @isTest static void resolver_does_no_dml() {
        Integer before = Limits.getDmlStatements();
        OA_IdentityResolution.resolve(org('Any','UEIX',null,null,null,'CA',null));
        System.assertEquals(before, Limits.getDmlStatements(), 'resolve is read-only');
    }

    @isTest static void null_input_safe() {
        System.assertEquals(OA_IdentityResolution.Decision.NONE, OA_IdentityResolution.resolve(null).decision);
    }
}
