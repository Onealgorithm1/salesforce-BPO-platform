/**
 * OA_AlertService — raises a VISIBLE alert through THREE channels so nothing is missed:
 *   1. Salesforce Custom Notification (in-app bell + mobile push) — the desktop bell is confirmed
 *      working; mobile depends on device/push config.
 *   2. Email to the alert owner — arrives regardless of bell, push, or which app/org the phone is
 *      logged into. Subject carries the prospect + company so it is actionable without opening
 *      Salesforce; body carries a direct link to the CampaignMember/Lead.
 *   3. Audit Task — the record of what happened.
 *
 * Recipient defaults to OA_Graph_Config__mdt.Default.Alert_Owner_Id__c, falling back to the running
 * user. The email goes to that user's Email address.
 */
public with sharing class OA_AlertService {

    private static final String NOTIF_TYPE = 'OA_Pipeline_Alert';

    @TestVisible private static Id testRecipientOverride;

    /** Raise a visible alert. targetId deep-links the alert (a CampaignMember/Lead when known). */
    public static void raise(String title, String body, Id targetId) {
        Id recipient = resolveRecipient();

        // Audit Task — preserves the existing paper trail.
        insert new Task(
            Subject      = title.left(255),
            OwnerId      = recipient,
            Status       = 'Not Started',
            Priority     = 'High',
            ActivityDate = Date.today(),
            Description  = body
        );

        sendCustomNotification(title, body, targetId, recipient);
        sendEmail(title, body, targetId, recipient);
    }

    // ── Channel 1: in-app bell + mobile push ─────────────────────────────────────
    private static void sendCustomNotification(String title, String body, Id targetId, Id recipient) {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = :NOTIF_TYPE LIMIT 1
        ];
        if (types.isEmpty()) return;   // type not deployed — Task + email still fire
        Id linkId = (targetId != null) ? targetId : recipient;
        try {
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setTitle(title.left(100));
            n.setBody(body.abbreviate(750));
            n.setNotificationTypeId(types[0].Id);
            n.setTargetId(linkId);
            n.send(new Set<String>{ String.valueOf(recipient) });
        } catch (Exception e) {
            System.debug('[OA_AlertService] CustomNotification send failed: ' + e.getMessage());
        }
    }

    // ── Channel 2: email fallback (device/push-independent) ──────────────────────
    private static void sendEmail(String title, String body, Id targetId, Id recipient) {
        try {
            String toAddress;
            for (User u : [SELECT Email FROM User WHERE Id = :recipient LIMIT 1]) toAddress = u.Email;
            if (String.isBlank(toAddress)) return;

            String prospect  = prospectLabel(targetId);   // "Name (Company)" or ''
            String recordUrl = (targetId != null)
                ? URL.getOrgDomainUrl().toExternalForm() + '/' + targetId
                : null;

            String subject = '[OA Alert] '
                + (String.isNotBlank(prospect) ? prospect + ' — ' : '')
                + title;
            String emailBody = body
                + (recordUrl != null ? '\n\nOpen the record: ' + recordUrl : '')
                + '\n\n(Automated alert from the EDWOSB outreach pipeline.)';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ toAddress });
            msg.setSubject(subject.abbreviate(255));
            msg.setPlainTextBody(emailBody);
            msg.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
        } catch (Exception e) {
            // Never let an email failure break the caller's pipeline.
            System.debug('[OA_AlertService] email fallback failed: ' + e.getMessage());
        }
    }

    /** Resolve "Name (Company)" from a CampaignMember (00v) or Lead (00Q) targetId; '' otherwise. */
    private static String prospectLabel(Id targetId) {
        if (targetId == null) return '';
        String prefix = String.valueOf(targetId).substring(0, 3);
        if (prefix == '00v') {
            for (CampaignMember cm : [SELECT Lead.Name, Lead.Company FROM CampaignMember WHERE Id = :targetId LIMIT 1]) {
                if (cm.Lead != null && cm.Lead.Name != null) {
                    return cm.Lead.Name + (String.isNotBlank(cm.Lead.Company) ? ' (' + cm.Lead.Company + ')' : '');
                }
            }
        } else if (prefix == '00Q') {
            for (Lead ld : [SELECT Name, Company FROM Lead WHERE Id = :targetId LIMIT 1]) {
                return ld.Name + (String.isNotBlank(ld.Company) ? ' (' + ld.Company + ')' : '');
            }
        }
        return '';
    }

    private static Id resolveRecipient() {
        if (testRecipientOverride != null) return testRecipientOverride;
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        if (cfg != null && cfg.Alert_Owner_Id__c != null) return cfg.Alert_Owner_Id__c;
        return UserInfo.getUserId();
    }
}
