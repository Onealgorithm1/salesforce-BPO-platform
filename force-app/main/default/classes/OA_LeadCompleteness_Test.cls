@isTest
private class OA_LeadCompleteness_Test {
    private static OA_CanonicalOrg base() {
        OA_CanonicalOrg c = new OA_CanonicalOrg();
        c.organizationName = 'Acme Federal';
        c.sourceSystem = 'SAM';
        return c;
    }

    @isTest static void null_is_zero_needs_enrichment() {
        OA_LeadCompleteness.Result r = OA_LeadCompleteness.evaluate(null);
        System.assertEquals(0, r.score);
        System.assertEquals('Needs Enrichment', r.band);
    }

    @isTest static void identity_only_needs_enrichment() {
        OA_LeadCompleteness.Result r = OA_LeadCompleteness.evaluate(base());
        System.assertEquals(10, r.score, 'identity only');
        System.assertEquals('Needs Enrichment', r.band);
    }

    @isTest static void sam_like_profile_scores_mid() {
        OA_CanonicalOrg c = base();
        c.uei = 'UEI1'; c.cageCode = 'CG1';         // gov 15
        c.address = '1 Main'; c.city = 'DC'; c.state = 'DC'; c.postalCode = '20001'; // location 12
        c.website = 'https://acme.example';          // website 10
        OA_LeadCompleteness.Result r = OA_LeadCompleteness.evaluate(c);
        // identity 10 + gov 15 + location 12 + website 10 = 47
        System.assertEquals(47, r.score);
        System.assertEquals('Needs Enrichment', r.band, 'acquisition identity is below campaign-ready');
    }

    @isTest static void full_profile_is_campaign_ready() {
        OA_CanonicalOrg c = base();
        c.uei = 'UEI1'; c.cageCode = 'CG1'; c.ein = 'EIN1';              // gov 20
        c.address = '1 Main'; c.city = 'DC'; c.state = 'DC'; c.postalCode = '20001'; // 12
        c.website = 'https://acme.example';                              // 10
        c.naics = '541512';                                             // 10
        c.phone = '2025550100';                                         // 5
        c.attributes = new Map<String, Object>{ 'Award Amount' => 1000000, 'business_type' => 'SDB' }; // contract 15 + profile 13
        OA_LeadCompleteness.Result r = OA_LeadCompleteness.evaluate(c);
        // 10+20+12+10+10+5+15+13 = 95
        System.assertEquals(95, r.score);
        System.assertEquals('Campaign Ready', r.band);
        System.assertEquals(15, r.breakdown.get('contract'));
        System.assertEquals(13, r.breakdown.get('businessProfile'));
    }

    @isTest static void band_thresholds() {
        System.assertEquals('Campaign Ready', OA_LeadCompleteness.band(90));
        System.assertEquals('Review', OA_LeadCompleteness.band(70));
        System.assertEquals('Needs Enrichment', OA_LeadCompleteness.band(69));
    }
}
