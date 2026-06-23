public class OA_ReplayBookingService {

    // ── Reset a Lead's booking fields to allow BookingPoller re-processing ────────
    // Meeting_Booked_Date__c is the idempotency guard used by OA_BookingPoller.
    // Clearing it allows the poller to re-stamp the Lead on the next poll cycle
    // when a matching Event is found in the lookback window. Always logs what it
    // clears for auditability. Does not bulk-update; operates on one Lead by ID.
    public static void resetLeadForBookingReplay(Id leadId) {
        Lead before = [
            SELECT Id, Meeting_Booked_Date__c, Teams_Meeting_Id__c,
                   Recording_Id__c, Recording_Retrieved__c
            FROM Lead WHERE Id = :leadId LIMIT 1
        ];

        System.debug('[OA_ReplayBookingService] resetLeadForBookingReplay — Lead ' + leadId
            + ' — clearing: Meeting_Booked_Date__c=' + before.Meeting_Booked_Date__c
            + ', Teams_Meeting_Id__c='    + before.Teams_Meeting_Id__c
            + ', Recording_Id__c='        + before.Recording_Id__c
            + ', Recording_Retrieved__c=' + before.Recording_Retrieved__c);

        update new Lead(
            Id                     = leadId,
            Meeting_Booked_Date__c = null,
            Teams_Meeting_Id__c    = null,
            Recording_Id__c        = null,
            Recording_Retrieved__c = false
        );

        System.debug('[OA_ReplayBookingService] Lead ' + leadId
            + ' reset complete — BookingPoller will re-process on the next poll cycle.');
    }

    // ── Reprocess booking pipeline for a known Event and Lead pair ────────────────
    // Runs Steps 1, 2, 3, and 4 of the OA_BookingPoller pipeline without Graph callouts.
    // Step 1.5 (Teams PATCH for auto-recording) is intentionally omitted — the meeting
    // has already occurred by the time recovery is needed.
    // Requires an unconverted Lead and a valid Event with StartDateTime.
    // Logs every field change for auditability.
    public static void reprocessBookingForEvent(Id eventId, Id leadId) {
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        String campaignId   = (cfg != null) ? cfg.Campaign_Id__c   : null;
        String alertOwnerId = (cfg != null) ? cfg.Alert_Owner_Id__c : UserInfo.getUserId();

        Event ev = [
            SELECT Id, Subject, StartDateTime, WhoId
            FROM Event WHERE Id = :eventId LIMIT 1
        ];

        Lead l = [
            SELECT Id, FirstName, LastName, Email, Meeting_Booked_Date__c
            FROM Lead WHERE Id = :leadId AND IsConverted = false LIMIT 1
        ];

        System.debug('[OA_ReplayBookingService] reprocessBookingForEvent — Event ' + eventId
            + ', Lead ' + leadId + ' (' + l.FirstName + ' ' + l.LastName + ')'
            + ', Meeting_Booked_Date__c (before): ' + l.Meeting_Booked_Date__c);

        // Step 1: Link Event to Lead if not already linked
        if (ev.WhoId != leadId) {
            ev.WhoId = leadId;
            update ev;
            System.debug('[OA_ReplayBookingService] Event ' + eventId + ' linked to Lead ' + leadId);
        }

        // Step 2: Update CampaignMember to Meeting Booked
        if (campaignId != null) {
            List<CampaignMember> cms = [
                SELECT Id, Status FROM CampaignMember
                WHERE LeadId = :leadId AND CampaignId = :campaignId LIMIT 1
            ];
            if (!cms.isEmpty() && cms[0].Status != 'Meeting Booked') {
                cms[0].Status = 'Meeting Booked';
                update cms[0];
                System.debug('[OA_ReplayBookingService] CampaignMember ' + cms[0].Id + ' → Meeting Booked');
            }
        }

        // Step 3: Stamp Lead fields
        update new Lead(
            Id                     = leadId,
            Meeting_Booked_Date__c = ev.StartDateTime.date(),
            Relationship_Status__c = 'Meeting Booked'
        );
        System.debug('[OA_ReplayBookingService] Lead ' + leadId
            + ' — Meeting_Booked_Date__c=' + ev.StartDateTime.date()
            + ', Relationship_Status__c=Meeting Booked');

        // Step 4: Create PREP task if not already present
        Integer existingPrep = [SELECT COUNT() FROM Task WHERE WhoId = :leadId AND Subject LIKE 'PREP:%'];
        if (existingPrep == 0) {
            Date meetingDate = ev.StartDateTime.date();
            Date taskDueDate = meetingDate.addDays(-1);
            if (taskDueDate <= Date.today()) taskDueDate = Date.today();

            insert new Task(
                Subject      = 'PREP: Review prospect before intro call — ' + l.FirstName + ' ' + l.LastName,
                WhoId        = leadId,
                OwnerId      = alertOwnerId,
                Status       = 'Not Started',
                Priority     = 'High',
                ActivityDate = taskDueDate,
                Description  = '[Recovery reprocess] Meeting: ' + ev.Subject
                               + '\nDate: ' + ev.StartDateTime.format()
            );
            System.debug('[OA_ReplayBookingService] PREP Task created for Lead ' + leadId + ', due ' + taskDueDate);
        } else {
            System.debug('[OA_ReplayBookingService] PREP Task already exists for Lead ' + leadId + ' — skipping duplicate.');
        }
    }
}
