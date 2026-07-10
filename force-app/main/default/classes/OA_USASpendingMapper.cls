/**
 * OA_USASpendingMapper — maps a normalized row to an OA_USASpending_Staging__c (Connector SDK).
 *
 * Sprint 1C-1: builds the staging record IN MEMORY ONLY (no DML here).
 * Sprint 1C-2: also stamps Dedupe_Key__c (run id + "|" + Award ID) so the
 * persistence layer can upsert idempotently. This class still performs NO DML —
 * saving is done by OA_ConnectorPersistence.
 *
 * Stamps the framework-managed fields from the run context and defaults the human
 * review gate (Review_Status__c = 'Pending') so nothing flows to a Lead without review.
 */
public class OA_USASpendingMapper implements OA_IConnectorMapper {

    public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
        OA_USASpending_Staging__c s = new OA_USASpending_Staging__c();

        // --- source-specific fields ---
        String awardId           = row.getString('awardId');
        s.Award_ID__c            = awardId;
        s.Recipient_Name__c      = row.getString('recipientName');
        s.Recipient_UEI__c       = row.getString('recipientUei');
        s.Award_Amount__c        = row.getDecimal('awardAmount');
        s.Awarding_Agency__c     = row.getString('awardingAgency');
        s.Awarding_Sub_Agency__c = row.getString('awardingSubAgency');
        s.Contract_Type__c       = row.getString('contractType');
        s.Performance_State__c   = row.getString('state');
        s.Award_Description__c   = row.getString('description');

        Object term = ctx.config.get('searchTerm');
        if (term != null) {
            s.Search_Term__c = String.valueOf(term).abbreviate(255);
        }

        // --- framework-managed fields ---
        if (String.isNotBlank(ctx.runId)) {
            s.Enrichment_Run_ID__c = ctx.runId.abbreviate(36);
        }
        // Idempotency key: run id + "|" + Award ID. Enables upsert (no duplicates on re-run).
        if (String.isNotBlank(ctx.runId) && String.isNotBlank(awardId)) {
            s.Dedupe_Key__c = (ctx.runId + '|' + awardId).abbreviate(90);
        }
        s.Source_Endpoint__c = ctx.lastEndpoint;
        if (ctx.lastHttpStatus != null) {
            s.HTTP_Status__c = ctx.lastHttpStatus;
        }
        if (ctx.queryDate != null) {
            s.Query_Date__c = ctx.queryDate.date();
        }

        // Human review gate — nothing is written back to a Lead until a reviewer advances this.
        s.Review_Status__c = 'Pending';

        return s; // in memory only — the SDK foundation never inserts this
    }
}