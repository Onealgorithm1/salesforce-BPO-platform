/**
 * OA_EngagementResolverQueueable
 * Observe-only async wrapper. Given EmailMessage ids, it re-queries them and
 * routes them through OA_EngagementResolver, which writes only the shadow log.
 * Enqueue-only entry point; changes no prospect data.
 */
public with sharing class OA_EngagementResolverQueueable implements Queueable {

    private final List<Id> emailMessageIds;

    public OA_EngagementResolverQueueable(List<Id> emailMessageIds) {
        this.emailMessageIds = emailMessageIds;
    }

    public void execute(QueueableContext qc) {
        if (emailMessageIds == null || emailMessageIds.isEmpty()) return;
        List<EmailMessage> ems = [
            SELECT Id, Incoming, FromAddress, Subject, MessageDate
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ];
        new OA_EngagementResolver().observeEmails(ems);
    }
}
