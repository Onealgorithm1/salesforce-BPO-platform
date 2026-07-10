@IsTest
private class OA_FederalOpportunityAcquisition_Test {

    private class MultiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse(); res.setStatusCode(200);
            if (req.getEndpoint().contains('grants.gov')) {
                res.setBody('{"data":{"oppHits":[' +
                    '{"id":"777001","number":"HHS-26-001","title":"Community Health Grant","agency":"Department of Health and Human Services","agencyCode":"HHS","openDate":"01/15/2026","closeDate":"12/31/2026","cfdaList":["93.123"]},' +
                    '{"id":"777002","number":"NSF-26-002","title":"STEM Education Program","agency":"National Science Foundation","agencyCode":"NSF","openDate":"02/01/2026","closeDate":"11/30/2026","cfdaList":["47.076"]}]}}');
            } else { // USASpending toptier
                res.setBody('{"results":[{"agency_name":"Department of Health and Human Services","toptier_code":"075","current_total_budget_authority_amount":1000000}]}');
            }
            return res;
        }
    }

    @IsTest
    static void grantsGovIntakeIsGovernedAndScreened() {
        insert new OA_Company_Profile__c(Organization_Name__c='One Algorithm LLC', Profile_Type__c='Self', Status__c='Active', Socioeconomic_Status__c='EDWOSB');
        Test.setMock(HttpCalloutMock.class, new MultiMock());

        Test.startTest();
        OA_FederalOpportunityAcquisition.Result r = OA_FederalOpportunityAcquisition.grantsGov('health', 10);
        Test.stopTest();

        System.assertEquals(2, r.fetched, 'both hits fetched');
        System.assertEquals(2, r.inserted, 'both inserted as candidates');
        System.assertEquals(0, r.duplicates, 'none pre-existing');
        List<OA_Opportunity_Signal__c> sigs = [SELECT Source__c, Type__c, Review_Status__c, Title__c, Agency__c, Posted_Date__c,
            Response_Deadline__c, Canonical_Key__c, Compliance_Decision__c FROM OA_Opportunity_Signal__c WHERE Canonical_Key__c LIKE 'grants:7770%'];
        System.assertEquals(2, sigs.size(), 'two candidates persisted');
        for (OA_Opportunity_Signal__c s : sigs) {
            System.assertEquals('Grants.gov', s.Source__c);
            System.assertEquals('Grant', s.Type__c);
            System.assertEquals('Pending', s.Review_Status__c, 'human-gated');
            System.assertNotEquals(null, s.Posted_Date__c, 'posted date normalized');
            System.assertNotEquals(null, s.Response_Deadline__c, 'deadline normalized');
            System.assertNotEquals(null, s.Compliance_Decision__c, 'compliance screen ran');
        }
        // Governance: NO Opportunities created
        System.assertEquals(0, [SELECT COUNT() FROM Opportunity WHERE Name LIKE '%Community Health%'], 'never auto-creates Opportunity');
    }

    @IsTest
    static void idempotentDedup() {
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        insert new OA_Company_Profile__c(Organization_Name__c='One Algorithm LLC', Profile_Type__c='Self', Status__c='Active', Socioeconomic_Status__c='EDWOSB');
        // one candidate already exists -> that hit must dedupe (one connector run per transaction: callout-before-DML)
        insert new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant', Review_Status__c='Pending', Canonical_Key__c='grants:777001', Title__c='pre-existing');
        Test.startTest();
        OA_FederalOpportunityAcquisition.Result r = OA_FederalOpportunityAcquisition.grantsGov('health', 10);
        Test.stopTest();
        System.assertEquals(2, r.fetched, 'both fetched');
        System.assertEquals(1, r.duplicates, 'pre-existing canonical key deduped');
        System.assertEquals(1, r.inserted, 'only the new one inserted');
    }

    @IsTest
    static void usaspendingEnrichmentResolvesAgency() {
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant',
            Review_Status__c='Pending', Agency__c='Department of Health and Human Services', Canonical_Key__c='grants:enrich1');
        insert sig;
        Test.startTest();
        String summary = new OA_USASpendingEnrichment().enrich(sig);
        Test.stopTest();
        System.assert(summary.contains('toptier'), 'agency resolved via USASpending: ' + summary);
        System.assert(new OA_USASpendingEnrichment().isFree() && new OA_USASpendingEnrichment().isAuthoritative(), 'free authoritative provider');
    }

    @IsTest
    static void schedulerRunsDormant() {
        Test.setMock(HttpCalloutMock.class, new MultiMock());
        insert new OA_Company_Profile__c(Organization_Name__c='One Algorithm LLC', Profile_Type__c='Self', Status__c='Active', Socioeconomic_Status__c='EDWOSB');
        Test.startTest();
        new OA_FederalAcquisitionScheduler('health').execute(null);
        Test.stopTest();
        System.assert([SELECT COUNT() FROM OA_Opportunity_Signal__c WHERE Source__c='Grants.gov'] >= 2, 'scheduler intake works');
    }
}