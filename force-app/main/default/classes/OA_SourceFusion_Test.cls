@isTest
private class OA_SourceFusion_Test {
    private static OA_CanonicalOrg org() {
        OA_CanonicalOrg c = new OA_CanonicalOrg();
        c.organizationName = 'Co'; c.normalizedName = 'CO'; c.uei = 'U1'; c.sourceSystem = 'SAM'; c.sourceConfidence = 'HIGH';
        return c;
    }

    @isTest static void fills_blank_only() {
        OA_Discovered_Organization__c d = new OA_Discovered_Organization__c(
            Source_System__c = 'USASPENDING', Source_Confidence__c = 'MEDIUM');
        OA_CanonicalOrg c = org(); c.website = 'https://co.example'; c.cageCode = 'CG1';
        Boolean changed = OA_SourceFusion.fuse(d, c);
        System.assertEquals(true, changed);
        System.assertEquals('https://co.example', d.Website__c);
        System.assertEquals('CG1', d.CAGE_Code__c);
        System.assertEquals('HIGH', d.Source_Confidence__c, 'confidence upgraded MEDIUM->HIGH');
        System.assert(d.Discovery_Metadata__c != null && d.Discovery_Metadata__c.contains('sources'), 'provenance recorded');
    }

    @isTest static void never_overwrites_populated() {
        OA_Discovered_Organization__c d = new OA_Discovered_Organization__c(
            Website__c = 'https://original.example', Source_Confidence__c = 'HIGH');
        OA_CanonicalOrg c = org(); c.website = 'https://different.example';
        OA_SourceFusion.fuse(d, c);
        System.assertEquals('https://original.example', d.Website__c, 'populated field never overwritten');
    }

    @isTest static void null_safe() {
        System.assertEquals(false, OA_SourceFusion.fuse(null, org()));
        System.assertEquals(false, OA_SourceFusion.fuse(new OA_Discovered_Organization__c(), null));
    }

    @isTest static void provenance_appends_across_fusions() {
        OA_Discovered_Organization__c d = new OA_Discovered_Organization__c(Source_System__c = 'USASPENDING');
        OA_SourceFusion.fuse(d, org());
        OA_CanonicalOrg c2 = org(); c2.sourceSystem = 'SEC';
        OA_SourceFusion.fuse(d, c2);
        Map<String, Object> meta = (Map<String, Object>) JSON.deserializeUntyped(d.Discovery_Metadata__c);
        System.assertEquals(2, ((List<Object>) meta.get('sources')).size(), 'both sources retained');
    }
}
