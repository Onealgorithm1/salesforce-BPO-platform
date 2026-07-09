/**
 * OA_EngagementResolverBatch
 * Observe-only backfill. Streams inbound EmailMessages since a cutoff date into
 * the shadow log via OA_EngagementResolver. Writes only OA_Engagement_Resolution__c.
 *
 * This is the SAFE MINIMAL ENTRY POINT for Phase 1: it is DORMANT until an admin
 * explicitly runs Database.executeBatch(new OA_EngagementResolverBatch()). There is
 * no active trigger or flow, so nothing fires automatically on prospect activity.
 */
public with sharing class OA_EngagementResolverBatch implements Database.Batchable<SObject> {

    private final Datetime sinceDt;

    public OA_EngagementResolverBatch() {
        // Default backfill window start: 2026-07-01.
        this.sinceDt = Datetime.newInstance(2026, 7, 1, 0, 0, 0);
    }

    public OA_EngagementResolverBatch(Datetime since) {
        this.sinceDt = since;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Incoming, FromAddress, Subject, MessageDate
            FROM EmailMessage
            WHERE Incoming = true AND MessageDate >= :sinceDt
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EmailMessage> scope) {
        new OA_EngagementResolver().observeEmails(scope);
    }

    public void finish(Database.BatchableContext bc) {
        // No-op. Observe-only; no follow-on action on prospect data.
    }
}