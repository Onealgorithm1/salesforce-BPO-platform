@IsTest
private class OA_OpportunityQualification_Test {
    @IsTest
    static void producesRicherThanGoNoGo() {
        insert new OA_Company_Profile__c(Organization_Name__c='One Algorithm LLC', Profile_Type__c='Self', Status__c='Active',
            Socioeconomic_Status__c='EDWOSB', Capabilities__c='Salesforce platform automation; AI business process outsourcing; data enrichment');
        insert new OA_Company_Profile__c(Organization_Name__c='BuildCo', Profile_Type__c='Partner', Status__c='Active',
            Capabilities__c='construction bridge civil infrastructure engineering', Knowledge_Completeness__c=40);
        insert new OA_Company_Profile__c(Organization_Name__c='VetPrime', Profile_Type__c='Partner', Status__c='Active',
            Socioeconomic_Status__c='SDVOSB', Capabilities__c='logistics staffing');

        OA_Opportunity_Signal__c go = new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant', Review_Status__c='Pending',
            Title__c='Salesforce Automation Platform Data Integration', Response_Deadline__c=Date.today().addDays(20), Canonical_Key__c='q:go');
        OA_Opportunity_Signal__c partner = new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant', Review_Status__c='Pending',
            Title__c='Bridge Construction Civil Infrastructure', Response_Deadline__c=Date.today().addDays(40), Canonical_Key__c='q:partner');
        OA_Opportunity_Signal__c team = new OA_Opportunity_Signal__c(Source__c='SAM.gov', Type__c='Contract', Review_Status__c='Pending',
            Title__c='Salesforce Data Platform', Set_Aside__c='SDVOSB Set-Aside', Compliance_Decision__c='NO-GO', Canonical_Key__c='q:team');
        OA_Opportunity_Signal__c nogo = new OA_Opportunity_Signal__c(Source__c='Grants.gov', Type__c='Grant', Review_Status__c='Pending',
            Title__c='Lunar Payload Quantum Physics Research', Response_Deadline__c=Date.today().addDays(90), Canonical_Key__c='q:nogo');
        insert new List<OA_Opportunity_Signal__c>{ go, partner, team, nogo };

        Test.startTest();
        OA_OpportunityQualification.qualify(new List<Id>{ go.Id, partner.Id, team.Id, nogo.Id });
        Test.stopTest();

        Map<Id,OA_Opportunity_Signal__c> m = new Map<Id,OA_Opportunity_Signal__c>([SELECT Qualification_Decision__c,
            Recommended_Partner__c, Recommended_Role__c, Fit_Score__c, Urgency_Score__c, Qualification_Rationale__c, Review_Status__c
            FROM OA_Opportunity_Signal__c WHERE Id IN (:go.Id,:partner.Id,:team.Id,:nogo.Id)]);
        System.assertEquals('GO', m.get(go.Id).Qualification_Decision__c, 'strong self-fit -> GO prime');
        System.assertEquals('Prime', m.get(go.Id).Recommended_Role__c);
        System.assertEquals('GO WITH PARTNER', m.get(partner.Id).Qualification_Decision__c, 'out-of-domain but partner covers');
        System.assertEquals('BuildCo', m.get(partner.Id).Recommended_Partner__c, 'partner recommended');
        System.assertEquals('TEAMING', m.get(team.Id).Qualification_Decision__c, 'SDVOSB set-aside -> team under VetPrime');
        System.assertEquals('VetPrime', m.get(team.Id).Recommended_Partner__c);
        System.assertEquals('NO-GO', m.get(nogo.Id).Qualification_Decision__c, 'out of domain, no partner');
        System.assertNotEquals(null, m.get(go.Id).Fit_Score__c, 'scores computed');
        System.assertEquals('Pending', m.get(go.Id).Review_Status__c, 'advisory — stays human-gated');
    }
}