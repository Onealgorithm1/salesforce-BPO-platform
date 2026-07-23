/**
 * OA_AlertService — raises a VISIBLE alert, not just a Task.
 *
 * A Task sitting in "Not Started" is not a notification — nobody sees it unless they open a list
 * view. This sends a Salesforce Custom Notification (in-app bell + Salesforce mobile push) to the
 * alert owner, AND keeps a Task for the audit trail. The notification is the part the user
 * actually sees; the Task is the record of what happened.
 *
 * Recipient defaults to OA_Graph_Config__mdt.Default.Alert_Owner_Id__c (the same owner the booking
 * poller already alerts), falling back to the running user.
 */
public with sharing class OA_AlertService {

    private static final String NOTIF_TYPE = 'OA_Pipeline_Alert';

    @TestVisible private static Id testRecipientOverride;

    /** Raise a visible alert. targetId deep-links the notification (a CampaignMember/Lead when known). */
    public static void raise(String title, String body, Id targetId) {
        Id recipient = resolveRecipient();

        // Audit Task — preserves the existing paper trail.
        insert new Task(
            Subject     = title.left(255),
            OwnerId     = recipient,
            Status      = 'Not Started',
            Priority    = 'High',
            ActivityDate = Date.today(),
            Description = body
        );

        // The actual notification (bell + mobile).
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = :NOTIF_TYPE LIMIT 1
        ];
        if (types.isEmpty()) return;   // type not deployed yet — Task still recorded the alert

        Id linkId = (targetId != null) ? targetId : recipient;
        try {
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setTitle(title.left(100));
            n.setBody(body.abbreviate(750));
            n.setNotificationTypeId(types[0].Id);
            n.setTargetId(linkId);
            n.send(new Set<String>{ String.valueOf(recipient) });
        } catch (Exception e) {
            // Never let a notification failure break the caller's pipeline.
            System.debug('[OA_AlertService] CustomNotification send failed: ' + e.getMessage());
        }
    }

    private static Id resolveRecipient() {
        if (testRecipientOverride != null) return testRecipientOverride;
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        if (cfg != null && cfg.Alert_Owner_Id__c != null) return cfg.Alert_Owner_Id__c;
        return UserInfo.getUserId();
    }
}
