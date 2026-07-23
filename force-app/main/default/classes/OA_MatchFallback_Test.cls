@isTest(SeeAllData=false)
private class OA_MatchFallback_Test {

    private static Campaign makeCampaign() {
        Campaign c = new Campaign(Name = 'MF Test', IsActive = true, Status = 'Planning');
        insert c;
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Day 1 Sent', HasResponded = false, SortOrder = 3);
        return c;
    }

    private static Lead makeLead(String email) {
        Lead l = new Lead(FirstName = 'T', LastName = 'L', Company = 'Co', Email = email, LeadSource = 'SAM.gov');
        insert l;
        return l;
    }

    @isTest
    static void testDomainOfAndFreemail() {
        System.assertEquals('example.com', OA_MatchFallback.domainOf('Person@Example.COM'));
        System.assertEquals(null, OA_MatchFallback.domainOf('not-an-email'));
        System.assertEquals(null, OA_MatchFallback.domainOf(null));
        System.assert(OA_MatchFallback.isFreemail('x@gmail.com'), 'gmail must be freemail');
        System.assert(!OA_MatchFallback.isFreemail('x@acmecorp.com'), 'a company domain is not freemail');
    }

    @isTest
    static void testSingleDomainCandidate() {
        Campaign c = makeCampaign();
        Lead l = makeLead('named.person@acmecorp.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        List<CampaignMember> r = OA_MatchFallback.candidatesByDomain(
            'info@acmecorp.com', c.Id, new Set<String>{ 'Replied' });
        System.assertEquals(1, r.size(), 'A different mailbox at the same company domain must match');
    }

    @isTest
    static void testFreemailReturnsEmpty() {
        Campaign c = makeCampaign();
        Lead l = makeLead('person@gmail.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Day 1 Sent');

        List<CampaignMember> r = OA_MatchFallback.candidatesByDomain(
            'someone.else@gmail.com', c.Id, new Set<String>{ 'Replied' });
        System.assertEquals(0, r.size(), 'A shared consumer domain must never produce a candidate');
    }

    @isTest
    static void testExactAddressAndStopStatusExcluded() {
        Campaign c = makeCampaign();
        insert new CampaignMemberStatus(CampaignId = c.Id, Label = 'Replied', HasResponded = true, SortOrder = 4);
        Lead same = makeLead('info@acmecorp.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = same.Id, Status = 'Day 1 Sent');
        Lead stopped = makeLead('other@acmecorp.com');
        insert new CampaignMember(CampaignId = c.Id, LeadId = stopped.Id, Status = 'Replied');

        // Exact address is excluded (handled by the exact path); the stopped member is excluded too.
        List<CampaignMember> r = OA_MatchFallback.candidatesByDomain(
            'info@acmecorp.com', c.Id, new Set<String>{ 'Replied' });
        System.assertEquals(0, r.size(), 'Exact-address and stop-status members must be excluded');
    }
}
