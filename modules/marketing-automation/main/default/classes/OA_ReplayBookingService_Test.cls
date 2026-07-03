@isTest(SeeAllData=false)
private class OA_ReplayBookingService_Test {

    @TestSetup
    static void makeData() {
        insert new Lead(
            FirstName              = 'Jane',
            LastName               = 'Smith',
            Company                = 'Prime Contractor LLC',
            Email                  = 'jane.smith@primecontractor.com',
            LeadSource             = 'SAM.gov',
            Meeting_Booked_Date__c = Date.today().addDays(-3),
            Teams_Meeting_Id__c    = 'ms-meeting-replay-001',
            Recording_Id__c        = 'rec-replay-001',
            Recording_Retrieved__c = true
        );

        Campaign c = new Campaign(Name = 'OA Replay Test Campaign', IsActive = true);
        insert c;

        try {
            insert new CampaignMemberStatus(
                CampaignId   = c.Id,
                Label        = 'Meeting Booked',
                IsDefault    = false,
                HasResponded = true,
                SortOrder    = 10
            );
        } catch (DmlException e) { }

        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Sent');

        insert new Event(
            Subject           = 'Jane Smith - 30 Min. Subcontracting Introduction',
            StartDateTime     = Datetime.now().addDays(-2),
            EndDateTime       = Datetime.now().addDays(-2).addMinutes(30),
            DurationInMinutes = 30,
            OwnerId           = UserInfo.getUserId(),
            Description       = 'Recovery test event'
        );
    }

    // ── resetLeadForBookingReplay ─────────────────────────────────────────────────

    @isTest
    static void testResetLeadClearsBookingFields() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        Test.startTest();
        OA_ReplayBookingService.resetLeadForBookingReplay(l.Id);
        Test.stopTest();

        Lead updated = [
            SELECT Meeting_Booked_Date__c, Teams_Meeting_Id__c, Recording_Id__c, Recording_Retrieved__c
            FROM Lead WHERE Id = :l.Id
        ];
        System.assertEquals(null,  updated.Meeting_Booked_Date__c, 'Meeting_Booked_Date__c should be cleared');
        System.assertEquals(null,  updated.Teams_Meeting_Id__c,    'Teams_Meeting_Id__c should be cleared');
        System.assertEquals(null,  updated.Recording_Id__c,        'Recording_Id__c should be cleared');
        System.assertEquals(false, updated.Recording_Retrieved__c,  'Recording_Retrieved__c should be reset to false');
    }

    // Verifies that resetLeadForBookingReplay only modifies the targeted Lead and
    // does not affect any other records.
    @isTest
    static void testResetLeadDoesNotModifyOtherLeads() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];

        Lead bystander = new Lead(
            FirstName              = 'Bob', LastName = 'Jones',
            Company                = 'Other Corp',
            Email                  = 'bob@other.com',
            LeadSource             = 'SAM.gov',
            Meeting_Booked_Date__c = Date.today(),
            Recording_Retrieved__c = true
        );
        insert bystander;

        Test.startTest();
        OA_ReplayBookingService.resetLeadForBookingReplay(l.Id);
        Test.stopTest();

        Lead unchanged = [
            SELECT Meeting_Booked_Date__c, Recording_Retrieved__c FROM Lead WHERE Id = :bystander.Id
        ];
        System.assertNotEquals(null, unchanged.Meeting_Booked_Date__c,
            'Bystander Lead Meeting_Booked_Date__c must be unchanged');
        System.assertEquals(true, unchanged.Recording_Retrieved__c,
            'Bystander Lead Recording_Retrieved__c must be unchanged');
    }

    // ── reprocessBookingForEvent ──────────────────────────────────────────────────

    // Verifies the full pipeline: Event linked, Lead fields stamped, PREP task created.
    @isTest
    static void testReprocessStampsLeadAndCreatesPrepTask() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        update new Lead(Id = l.Id, Meeting_Booked_Date__c = null);

        Test.startTest();
        OA_ReplayBookingService.reprocessBookingForEvent(ev.Id, l.Id);
        Test.stopTest();

        Lead updated = [SELECT Meeting_Booked_Date__c, Relationship_Status__c FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, updated.Meeting_Booked_Date__c,
            'Meeting_Booked_Date__c should be stamped after reprocess');
        System.assertEquals('Meeting Booked', updated.Relationship_Status__c,
            'Relationship_Status__c should be set to Meeting Booked');

        List<Task> prepTasks = [SELECT Subject, Priority FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(), 'PREP task should be created during reprocess');
        System.assertEquals('High', prepTasks[0].Priority, 'PREP task priority should be High');
    }

    // Verifies that reprocessBookingForEvent links the Event to the Lead when WhoId is null.
    @isTest
    static void testReprocessLinksEventToLead() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id, WhoId FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        System.assertEquals(null, ev.WhoId, 'Precondition: Event WhoId should be null before reprocess');

        Test.startTest();
        OA_ReplayBookingService.reprocessBookingForEvent(ev.Id, l.Id);
        Test.stopTest();

        Event updated = [SELECT WhoId FROM Event WHERE Id = :ev.Id];
        System.assertEquals(l.Id, updated.WhoId, 'Event WhoId should be set to the Lead after reprocess');
    }

    // Verifies idempotency: reprocessing when a PREP task already exists must not create a duplicate.
    @isTest
    static void testReprocessDoesNotDuplicatePrepTask() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        insert new Task(
            Subject      = 'PREP: Existing prep task for Jane Smith',
            WhoId        = l.Id,
            OwnerId      = UserInfo.getUserId(),
            Status       = 'Not Started',
            Priority     = 'High',
            ActivityDate = Date.today()
        );

        Test.startTest();
        OA_ReplayBookingService.reprocessBookingForEvent(ev.Id, l.Id);
        Test.stopTest();

        List<Task> prepTasks = [SELECT Id FROM Task WHERE WhoId = :l.Id AND Subject LIKE 'PREP:%'];
        System.assertEquals(1, prepTasks.size(),
            'No duplicate PREP task should be created when one already exists');
    }

    // Verifies that when the Event is already linked to the correct Lead, no DML error
    // occurs and the Lead fields are still stamped correctly.
    @isTest
    static void testReprocessWhenEventAlreadyLinked() {
        Lead l = [SELECT Id FROM Lead WHERE Email = 'jane.smith@primecontractor.com' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject LIKE 'Jane Smith%' LIMIT 1];

        update new Event(Id = ev.Id, WhoId = l.Id);
        update new Lead(Id = l.Id, Meeting_Booked_Date__c = null);

        Test.startTest();
        OA_ReplayBookingService.reprocessBookingForEvent(ev.Id, l.Id);
        Test.stopTest();

        Event updated = [SELECT WhoId FROM Event WHERE Id = :ev.Id];
        System.assertEquals(l.Id, updated.WhoId,
            'Event WhoId should remain linked to the Lead');

        Lead updatedLead = [SELECT Meeting_Booked_Date__c FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, updatedLead.Meeting_Booked_Date__c,
            'Lead fields should be stamped even when Event was already linked');
    }
}
