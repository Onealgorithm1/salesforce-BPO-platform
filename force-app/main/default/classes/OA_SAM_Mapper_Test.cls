@isTest
private class OA_SAM_Mapper_Test {

    private static OA_CanonicalOrg org() {
        OA_CanonicalOrg o = new OA_CanonicalOrg();
        o.uei = 'ABC123DEF456';
        o.cageCode = '1AB23';
        o.website = 'https://acme.example.com';
        o.state = 'VA';
        o.phone = null;  // unavailable
        o.sourceConfidence = 'HIGH';
        o.attributes.put('Registration_Status', 'Active');
        return o;
    }

    @isTest
    static void testToLeadProposals() {
        List<OA_EnrichmentWriter.FieldProposal> ps = new OA_SAM_Mapper().toLeadProposals(org());
        Map<String, OA_EnrichmentWriter.FieldProposal> byField = new Map<String, OA_EnrichmentWriter.FieldProposal>();
        for (OA_EnrichmentWriter.FieldProposal p : ps) { byField.put(p.fieldApiName, p); }

        System.assert(byField.containsKey('UEI__c'), 'UEI proposed');
        System.assert(byField.containsKey('Website'), 'Website proposed');
        System.assert(byField.containsKey('SAM_Registration_Status__c'), 'Reg status proposed');
        System.assert(!byField.containsKey('Phone'), 'Null phone NOT proposed (no fabrication)');
        System.assertEquals('SAM', byField.get('UEI__c').sourceSystem, 'Source = SAM');
        System.assertEquals('HIGH', byField.get('UEI__c').confidenceBand, 'Confidence propagated');
    }

    @isTest
    static void testNullAndEmptyOrg() {
        System.assertEquals(0, new OA_SAM_Mapper().toLeadProposals(null).size(), 'Null org -> empty');
        System.assertEquals(0, new OA_SAM_Mapper().toLeadProposals(new OA_CanonicalOrg()).size(),
            'Empty org -> nothing to propose');
    }
}