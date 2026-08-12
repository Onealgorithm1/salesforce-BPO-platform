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
 *
 * Bulk contract: raiseAll() is the real entry point — ONE Task insert, ONE email invocation and a
 * fixed number of queries regardless of how many alerts are raised. raise() is the single-alert
 * convenience wrapper. Callers in a trigger context (OA_ReplyStatusService) must use raiseAll,
 * because Messaging.sendEmail is capped at 10 invocations per transaction and a per-alert call
 * would blow that on any bulk EmailMessage load.
 *
 * Failure contract: alerting NEVER rolls back its caller. A reply that is correctly detected but
 * fails to alert is a missed notification; a reply that is detected and then rolled back because
 * the alert failed is a prospect the sequence keeps emailing mid-conversation. The second is worse,
 * so every channel — including the audit Task insert — is caught and logged.
 */
public with sharing class OA_AlertService {

    private static final String NOTIF_TYPE = 'OA_Pipeline_Alert';

    @TestVisible private static Id testRecipientOverride;
    @TestVisible private static Boolean lastTaskInsertFailed = false;

    /** One alert to raise. */
    public class Alert {
        public String title;
        public String body;
        public Id     targetId;
        public Alert(String title, String body, Id targetId) {
            this.title    = title;
            this.body     = body;
            this.targetId = targetId;
        }
    }

    /** Raise a visible alert. targetId deep-links the alert (a CampaignMember/Lead when known). */
    public static void raise(String title, String body, Id targetId) {
        raiseAll(new List<Alert>{ new Alert(title, body, targetId) });
    }

    /** Bulk entry point — fixed query/DML/email cost regardless of list size. */
    public static void raiseAll(List<Alert> alerts) {
        if (alerts == null || alerts.isEmpty()) return;

        Id recipient = resolveRecipient();

        insertAuditTasks(alerts, recipient);

        Map<Id, String> labels = prospectLabels(alerts);
        sendCustomNotifications(alerts, recipient);
        sendEmails(alerts, recipient, labels);
    }

    // ── Channel 3: audit Tasks (one DML for the whole batch) ─────────────────────
    private static void insertAuditTasks(List<Alert> alerts, Id recipient) {
        List<Task> tasks = new List<Task>();
        for (Alert a : alerts) {
            tasks.add(new Task(
                Subject      = a.title.left(255),
                OwnerId      = recipient,
                Status       = 'Not Started',
                Priority     = 'High',
                ActivityDate = Date.today(),
                Description  = a.body
            ));
        }
        lastTaskInsertFailed = false;
        try {
            insert tasks;
        } catch (Exception e) {
            // Deliberately swallowed — see the failure contract in the class header.
            lastTaskInsertFailed = true;
            System.debug('[OA_AlertService] audit Task insert failed: ' + e.getMessage());
        }
    }

    // ── Channel 1: in-app bell + mobile push ─────────────────────────────────────
    private static void sendCustomNotifications(List<Alert> alerts, Id recipient) {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = :NOTIF_TYPE LIMIT 1
        ];
        if (types.isEmpty()) return;   // type not deployed — Task + email still fire

        Set<String> recipients = new Set<String>{ String.valueOf(recipient) };
        for (Alert a : alerts) {
            Id linkId = (a.targetId != null) ? a.targetId : recipient;
            try {
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setTitle(a.title.left(100));
                n.setBody(a.body.abbreviate(750));
                n.setNotificationTypeId(types[0].Id);
                n.setTargetId(linkId);
                n.send(recipients);
            } catch (Exception e) {
                System.debug('[OA_AlertService] CustomNotification send failed: ' + e.getMessage());
            }
        }
    }

    // ── Channel 2: email fallback (device/push-independent) ──────────────────────
    private static void sendEmails(List<Alert> alerts, Id recipient, Map<Id, String> labels) {
        try {
            String toAddress;
            for (User u : [SELECT Email FROM User WHERE Id = :recipient LIMIT 1]) toAddress = u.Email;
            if (String.isBlank(toAddress)) return;

            String orgUrl = URL.getOrgDomainUrl().toExternalForm();

            List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
            for (Alert a : alerts) {
                String prospect = (a.targetId != null && labels.containsKey(a.targetId))
                    ? labels.get(a.targetId) : '';

                String subject = '[OA Alert] '
                    + (String.isNotBlank(prospect) ? prospect + ' — ' : '')
                    + a.title;
                String emailBody = a.body
                    + (a.targetId != null ? '\n\nOpen the record: ' + orgUrl + '/' + a.targetId : '')
                    + '\n\n(Automated alert from the EDWOSB outreach pipeline.)';

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new List<String>{ toAddress });
                msg.setSubject(subject.abbreviate(255));
                msg.setPlainTextBody(emailBody);
                msg.setSaveAsActivity(false);
                msgs.add(msg);
            }
            // ONE invocation for the whole batch — the 10-per-transaction cap counts invocations.
            if (!msgs.isEmpty()) Messaging.sendEmail(msgs);
        } catch (Exception e) {
            // Never let an email failure break the caller's pipeline.
            System.debug('[OA_AlertService] email fallback failed: ' + e.getMessage());
        }
    }

    /** Resolve "Name (Company)" for every CampaignMember (00v) / Lead (00Q) target, in 2 queries. */
    private static Map<Id, String> prospectLabels(List<Alert> alerts) {
        Map<Id, String> out = new Map<Id, String>();
        Set<Id> cmIds   = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();

        for (Alert a : alerts) {
            if (a.targetId == null) continue;
            String prefix = String.valueOf(a.targetId).substring(0, 3);
            if (prefix == '00v')      cmIds.add(a.targetId);
            else if (prefix == '00Q') leadIds.add(a.targetId);
        }

        if (!cmIds.isEmpty()) {
            for (CampaignMember cm : [
                SELECT Id, Lead.Name, Lead.Company FROM CampaignMember WHERE Id IN :cmIds
            ]) {
                if (cm.Lead != null && cm.Lead.Name != null) out.put(cm.Id, label(cm.Lead.Name, cm.Lead.Company));
            }
        }
        if (!leadIds.isEmpty()) {
            for (Lead ld : [SELECT Id, Name, Company FROM Lead WHERE Id IN :leadIds]) {
                out.put(ld.Id, label(ld.Name, ld.Company));
            }
        }
        return out;
    }

    private static String label(String name, String company) {
        return name + (String.isNotBlank(company) ? ' (' + company + ')' : '');
    }

    private static Id resolveRecipient() {
        if (testRecipientOverride != null) return testRecipientOverride;
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        if (cfg != null && cfg.Alert_Owner_Id__c != null) return cfg.Alert_Owner_Id__c;
        return UserInfo.getUserId();
    }
}
