/**
 * OA_SAMMapper — maps a normalized SAM.gov row to an OA_SAM_Entity_Staging__c (Connector SDK).
 *
 * Builds the staging record IN MEMORY ONLY (no DML here; persistence is a later concern).
 * Stamps framework-managed fields from the run context and defaults the human review gate
 * (Review_Status__c = 'Pending') so nothing flows to a Lead without review.
 *
 * Idempotency key: run id + "|" + UEI, so a re-run upserts rather than duplicating.
 * No secret is read or written — the API key lives only in the External Credential.
 */
public class OA_SAMMapper implements OA_IConnectorMapper {

    public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
        OA_SAM_Entity_Staging__c s = new OA_SAM_Entity_Staging__c();

        // --- source-specific identity + certification fields ---
        String uei                = row.getString('uei');
        s.UEI__c                  = safe(uei, 12);
        s.CAGE_Code__c            = safe(row.getString('cageCode'), 10);
        s.Legal_Business_Name__c  = safe(row.getString('legalBusinessName'), 255);
        s.Registration_Status__c  = safe(row.getString('registrationStatus'), 40);
        s.Physical_State__c       = safe(row.getString('state'), 10);
        s.Entity_URL__c           = safe(row.getString('entityUrl'), 255);
        s.Business_Types__c       = safe(row.getString('businessTypes'), 5000);

        Date regExp = parseDate(row.getString('registrationExpirationDate'));
        if (regExp != null) {
            s.Registration_Expiration_Date__c = regExp;
        }

        Object term = ctx.config.get('searchTerm');
        if (term != null) {
            s.Search_Term__c = String.valueOf(term).abbreviate(255);
        }

        // Source payload reference: a SHA-256 hash of the identity fields (traceability,
        // NOT the raw payload — avoids storing PII/bulk response text).
        s.Source_Payload_Ref__c = hashRef(uei, s.Legal_Business_Name__c, ctx.runId);

        // --- framework-managed fields ---
        if (String.isNotBlank(ctx.runId)) {
            s.Source_Run_ID__c = ctx.runId.abbreviate(36);
        }
        if (String.isNotBlank(ctx.runId) && String.isNotBlank(uei)) {
            s.Dedupe_Key__c = (ctx.runId + '|' + uei).abbreviate(90);
        }
        s.Source_Endpoint__c = ctx.lastEndpoint;
        if (ctx.lastHttpStatus != null) {
            s.HTTP_Status__c = ctx.lastHttpStatus;
        }
        if (ctx.queryDate != null) {
            s.Query_Date__c = ctx.queryDate.date();
            s.Last_Fetched__c = ctx.queryDate;
        }

        // Human review gate — nothing is written back to a Lead until a reviewer advances this.
        s.Review_Status__c = 'Pending';

        return s; // in memory only — the SDK foundation never inserts this
    }

    private static String safe(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }

    private static Date parseDate(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        try {
            // SAM.gov returns ISO dates (yyyy-MM-dd or full timestamp).
            return Date.valueOf(s.substringBefore('T').trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String hashRef(String uei, String name, String runId) {
        String basis = String.valueOf(uei) + '|' + String.valueOf(name) + '|' + String.valueOf(runId);
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(basis));
        return EncodingUtil.convertToHex(digest).abbreviate(64);
    }
}
