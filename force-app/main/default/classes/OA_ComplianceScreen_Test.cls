/**
 * OA_ComplianceScreen_Test — proves deterministic Go/No-Go outcomes for the EDWOSB prime.
 */
@IsTest
private class OA_ComplianceScreen_Test {

    @IsTest
    static void evaluatesSetAsideEligibility() {
        Set<String> mine = new Set<String>{ 'EDWOSB', 'WOSB', 'SB' };
        System.assertEquals('GO', OA_ComplianceScreen.evaluate('Women-Owned Small Business (WOSB)', '541511', 'US', mine).decision, 'WOSB set-aside -> GO');
        System.assertEquals('GO', OA_ComplianceScreen.evaluate('EDWOSB Set-Aside', '541512', 'US', mine).decision, 'EDWOSB -> GO');
        System.assertEquals('NO-GO', OA_ComplianceScreen.evaluate('Service-Disabled Veteran-Owned (SDVOSB)', '541511', 'US', mine).decision, 'SDVOSB -> NO-GO (teaming only)');
        System.assertEquals('NO-GO', OA_ComplianceScreen.evaluate('8(a) Set-Aside', '541511', 'US', mine).decision, '8(a) -> NO-GO');
        System.assertEquals('GO', OA_ComplianceScreen.evaluate('', '541511', 'US', mine).decision, 'full & open -> GO');
        System.assertEquals('REVIEW REQUIRED', OA_ComplianceScreen.evaluate('Some Unusual Restriction', '541511', 'US', mine).decision, 'unknown -> REVIEW');
        System.assert(OA_ComplianceScreen.evaluate('EDWOSB', null, 'US', mine).missing.contains('NAICS'), 'missing NAICS flagged');
    }

    @IsTest
    static void screensQueueInPlace() {
        insert new OA_Company_Profile__c(Organization_Name__c = 'One Algorithm LLC', Profile_Type__c = 'Self',
            Status__c = 'Active', Socioeconomic_Status__c = 'EDWOSB');
        OA_Opportunity_Signal__c s1 = new OA_Opportunity_Signal__c(Title__c = 'WOSB job', Set_Aside__c = 'WOSB Set-Aside', NAICS__c = '541511');
        OA_Opportunity_Signal__c s2 = new OA_Opportunity_Signal__c(Title__c = 'Vet job', Set_Aside__c = 'SDVOSB');
        insert new List<OA_Opportunity_Signal__c>{ s1, s2 };

        Test.startTest();
        OA_ComplianceScreen.screen(new List<Id>{ s1.Id, s2.Id });
        Test.stopTest();

        Map<Id, OA_Opportunity_Signal__c> m = new Map<Id, OA_Opportunity_Signal__c>([
            SELECT Compliance_Decision__c, Compliance_Rationale__c, Missing_Requirements__c
            FROM OA_Opportunity_Signal__c WHERE Id IN (:s1.Id, :s2.Id)
        ]);
        System.assertEquals('GO', m.get(s1.Id).Compliance_Decision__c, 'WOSB -> GO');
        System.assertEquals('NO-GO', m.get(s2.Id).Compliance_Decision__c, 'SDVOSB -> NO-GO');
        System.assertNotEquals(null, m.get(s1.Id).Compliance_Rationale__c, 'rationale written');
    }
}
