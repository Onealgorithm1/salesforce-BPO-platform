/**
 * OA_EngagementResolverTest
 * Verifies ERE Phase 1 matching hierarchy AND the observe-only guarantee:
 * the resolver writes ONLY OA_Engagement_Resolution__c and never mutates
 * Lead / Contact / CampaignMember / Event data.
 */
@IsTest(SeeAllData=false)
private class OA_EngagementResolverTest {

    private static Campaign camp;
    private static Lead exactLead;

    private static void seed() {
        camp = new Campaign(Name = 'ERE Test Campaign', IsActive = true);
        insert camp;

        exactLead = new Lead(FirstName = 'Sti', LastName = 'Prime', Company = 'Stragistics',
                             Email = 'sti@stragistics.com');
        Lead corpSingle = new Lead(FirstName = 'CEO', LastName = 'Acme', Company = 'Acme',
                                   Email = 'ceo@acme.com');
        Lead multiA = new Lead(FirstName = 'A', LastName = 'Multi', Company = 'Multi',
                               Email = 'a@multi.com');
        Lead multiB = new Lead(FirstName = 'B', LastName = 'Multi', Company = 'Multi',
                               Email = 'b@multi.com');
        insert new List<Lead>{ exactLead, corpSingle, multiA, multiB };

        insert new Contact(FirstName = 'Only', LastName = 'Contact', Email = 'person@contactonly.com');
        insert new CampaignMember(CampaignId = camp.Id, LeadId = exactLead.Id, Status = 'Day 5 Sent');
    }

    private static void injectConfig() {
        OA_EngagementResolver.overrideCfg = new OA_Engagement_Config__mdt(
            Active__c = true, Observe_Only__c = true,
            Enable_L1__c = true, Enable_L2__c = true, Enable_L3__c = true, Enable_L6_Review__c = true,
            Free_Domains__c = 'gmail.com,yahoo.com,hotmail.com',
            Internal_Domain__c = 'onealgorithm.com',
            Campaign_Id__c = camp.Id
        );
    }

    private static OA_EngagementSignal emailSignal(String fromAddr) {
        OA_EngagementSignal s = new OA_EngagementSignal();
        s.signalType = 'Email Reply';
        s.direction = 'Inbound';
        s.partyEmail = fromAddr;
        s.partyDomain = OA_EngagementSignal.domainOf(fromAddr);
        return s;
    }

    @IsTest
    static void testMatchingHierarchy() {
        seed();
        injectConfig();

        List<OA_EngagementSignal> sigs = new List<OA_EngagementSignal>{
            emailSignal('sti@stragistics.com'),      // L1 exact lead
            emailSignal('person@contactonly.com'),   // L2 contact
            emailSignal('contracts@acme.com'),       // L3 single corporate-domain lead
            emailSignal('contracts@multi.com'),      // L3 ambiguous -> review
            emailSignal('random@gmail.com')          // free domain -> no match
        };

        Test.startTest();
        Integer logged = new OA_EngagementResolver().observeAndLog(sigs);
        Test.stopTest();

        System.assertEquals(5, logged, 'all five signals should be logged (never dropped silently)');

        Map<String, OA_Engagement_Resolution__c> byEmail = new Map<String, OA_Engagement_Resolution__c>();
        for (OA_Engagement_Resolution__c r : [
                SELECT Party_Email__c, Matched_Level__c, Status__c, Confidence__c,
                       Resolved_Lead__c, Resolved_Contact__c, Resolved_CampaignMember__c
                FROM OA_Engagement_Resolution__c]) {
            byEmail.put(r.Party_Email__c, r);
        }

        System.assertEquals('L1', byEmail.get('sti@stragistics.com').Matched_Level__c);
        System.assertEquals(exactLead.Id, byEmail.get('sti@stragistics.com').Resolved_Lead__c);
        System.assertNotEquals(null, byEmail.get('sti@stragistics.com').Resolved_CampaignMember__c,
            'L1 lead in the configured campaign should map to a CampaignMember');

        System.assertEquals('L2', byEmail.get('person@contactonly.com').Matched_Level__c);
        System.assertNotEquals(null, byEmail.get('person@contactonly.com').Resolved_Contact__c);

        System.assertEquals('L3', byEmail.get('contracts@acme.com').Matched_Level__c);
        System.assertEquals('Needs Review', byEmail.get('contracts@acme.com').Status__c);

        System.assertEquals('Ambiguous', byEmail.get('contracts@multi.com').Status__c);
        System.assertEquals('L6', byEmail.get('contracts@multi.com').Matched_Level__c);

        System.assertEquals('No Match', byEmail.get('random@gmail.com').Status__c);
    }

    @IsTest
    static void testObserveOnlyNoProspectWrites() {
        seed();
        injectConfig();

        Integer leadsBefore = [SELECT COUNT() FROM Lead];
        Integer contactsBefore = [SELECT COUNT() FROM Contact];
        Integer cmBefore = [SELECT COUNT() FROM CampaignMember];
        String leadEmailBefore = [SELECT Email FROM Lead WHERE Id = :exactLead.Id].Email;

        Test.startTest();
        new OA_EngagementResolver().observeAndLog(new List<OA_EngagementSignal>{
            emailSignal('sti@stragistics.com')
        });
        Test.stopTest();

        System.assertEquals(leadsBefore, [SELECT COUNT() FROM Lead], 'no Lead create/delete');
        System.assertEquals(contactsBefore, [SELECT COUNT() FROM Contact], 'no Contact create/delete');
        System.assertEquals(cmBefore, [SELECT COUNT() FROM CampaignMember], 'no CampaignMember create/delete');
        System.assertEquals(leadEmailBefore, [SELECT Email FROM Lead WHERE Id = :exactLead.Id].Email,
            'Lead fields must be unchanged');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Engagement_Resolution__c],
            'only the shadow log is written');
    }

    @IsTest
    static void testObserveEmailsInMemory() {
        seed();
        injectConfig();

        List<EmailMessage> ems = new List<EmailMessage>{
            new EmailMessage(Incoming = true, FromAddress = 'sti@stragistics.com',
                             Subject = 'Re: Teaming', MessageDate = System.now()),
            new EmailMessage(Incoming = false, FromAddress = 'noreply@onealgorithm.com',
                             Subject = 'Outbound', MessageDate = System.now())
        };

        Test.startTest();
        Integer logged = new OA_EngagementResolver().observeEmails(ems);
        Test.stopTest();

        System.assertEquals(1, logged, 'only the inbound email is observed');
    }

    @IsTest
    static void testObserveEventsInternalMislink() {
        seed();
        injectConfig();

        Account acct = new Account(Name = 'Ref Account');
        insert acct;
        Contact internalC = new Contact(FirstName = 'Sreeni', LastName = 'Internal',
                                        Email = 'samirisetti@onealgorithm.com');
        insert internalC;

        List<Event> evs = new List<Event>{
            new Event(Subject = 'Teams Discussion', DurationInMinutes = 30,
                      ActivityDateTime = System.now()),                                  // WhatId null -> mislink
            new Event(Subject = 'Teams w/ internal', DurationInMinutes = 30,
                      ActivityDateTime = System.now(), WhoId = internalC.Id, WhatId = acct.Id) // internal domain -> mislink
        };
        insert evs;

        Test.startTest();
        Integer logged = new OA_EngagementResolver().observeEvents(evs);
        Test.stopTest();

        System.assertEquals(2, logged);
        Integer mislinks = [SELECT COUNT() FROM OA_Engagement_Resolution__c WHERE Internal_Mislink__c = true];
        System.assertEquals(2, mislinks, 'both events flagged as internal mislinks for review');
    }

    @IsTest
    static void testQueueableAndBatch() {
        seed();
        injectConfig();

        Test.startTest();
        // Queueable: fake id resolves to zero rows -> exercises execute() safely.
        System.enqueueJob(new OA_EngagementResolverQueueable(new List<Id>{ '02s000000000000AAA' }));

        // Batch: direct execute() with in-memory scope for coverage + start/finish via framework.
        OA_EngagementResolverBatch b = new OA_EngagementResolverBatch(Datetime.newInstance(2000, 1, 1, 0, 0, 0));
        b.execute(null, new List<EmailMessage>{
            new EmailMessage(Incoming = true, FromAddress = 'sti@stragistics.com',
                             Subject = 'Re', MessageDate = System.now())
        });
        Database.executeBatch(new OA_EngagementResolverBatch(), 200);
        Test.stopTest();

        System.assert([SELECT COUNT() FROM OA_Engagement_Resolution__c] >= 1,
            'batch execute logged the in-memory inbound email');
    }

    @IsTest
    static void testDefaultConfigFallback() {
        // No override, no assertion on data - just exercise loadConfig() default path.
        OA_EngagementResolver.overrideCfg = null;
        Test.startTest();
        Integer logged = new OA_EngagementResolver().observeAndLog(new List<OA_EngagementSignal>{
            emailSignal('nobody@example.com')
        });
        Test.stopTest();
        System.assertEquals(1, logged, 'signal logged even with fallback config');
    }
}
