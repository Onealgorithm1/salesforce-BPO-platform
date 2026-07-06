/**
 * OA_GrantsMapper — maps a normalized Grants.gov row to an OA_Grants_Opportunity_Staging__c
 * (Connector SDK).
 *
 * Builds the staging record IN MEMORY ONLY (no DML here; persistence is a later concern).
 * Stamps framework-managed fields from the run context and defaults the human review gate
 * (Review_Status__c = 'Pending') so nothing is acted on without review.
 *
 * This is an OPPORTUNITY-SIGNAL row (funding opportunity intelligence), NOT a Lead
 * firmographic record. There is no Lead write-back; Lead__c stays blank in this dormant
 * foundation and would only be set later by a reviewed, loose association.
 *
 * Idempotency key: run id + "|" + opportunity number (falls back to opportunity id), so a
 * re-run upserts rather than duplicating. No secret is ever read or written (public API).
 */
public class OA_GrantsMapper implements OA_IConnectorMapper {

    public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
        OA_Grants_Opportunity_Staging__c s = new OA_Grants_Opportunity_Staging__c();

        // --- source-specific opportunity fields ---
        String oppNumber            = row.getString('opportunityNumber');
        s.Opportunity_Number__c     = safe(oppNumber, 40);
        s.Opportunity_Title__c      = safe(row.getString('title'), 255);
        s.Agency_Code__c            = safe(row.getString('agencyCode'), 40);
        s.Agency_Name__c            = safe(row.getString('agencyName'), 255);
        s.Opportunity_Status__c     = safe(row.getString('oppStatus'), 40);
        s.Doc_Type__c               = safe(row.getString('docType'), 40);
        s.CFDA_Numbers__c           = safe(row.getString('cfdaNumbers'), 255);
        s.Opportunity_URL__c        = safe(row.getString('opportunityUrl'), 255);

        Date openD = parseDate(row.getString('openDate'));
        if (openD != null) {
            s.Open_Date__c = openD;
        }
        Date closeD = parseDate(row.getString('closeDate'));
        if (closeD != null) {
            s.Close_Date__c = closeD;
        }

        Object term = ctx.config.get('searchTerm');
        if (term != null) {
            s.Search_Term__c = String.valueOf(term).abbreviate(255);
        }

        // Source payload reference: a SHA-256 hash of identity fields (traceability,
        // NOT the raw payload — avoids storing bulk response text).
        String idKey = String.isNotBlank(oppNumber) ? oppNumber : row.getString('oppId');
        s.Source_Payload_Ref__c = hashRef(idKey, s.Opportunity_Title__c, ctx.runId);

        // --- framework-managed fields ---
        if (String.isNotBlank(ctx.runId)) {
            s.Source_Run_ID__c = ctx.runId.abbreviate(36);
        }
        if (String.isNotBlank(ctx.runId) && String.isNotBlank(idKey)) {
            s.Dedupe_Key__c = (ctx.runId + '|' + idKey).abbreviate(90);
        }
        s.Source_Endpoint__c = ctx.lastEndpoint;
        if (ctx.lastHttpStatus != null) {
            s.HTTP_Status__c = ctx.lastHttpStatus;
        }
        if (ctx.queryDate != null) {
            s.Query_Date__c = ctx.queryDate.date();
            s.Last_Fetched__c = ctx.queryDate;
        }

        // Human review gate — nothing is acted on until a reviewer advances this.
        s.Review_Status__c = 'Pending';

        return s; // in memory only — the SDK foundation never inserts this
    }

    private static String safe(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }

    /** Grants.gov Search2 returns dates as MM/DD/YYYY; also tolerates ISO yyyy-MM-dd. */
    private static Date parseDate(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        String v = s.trim();
        try {
            if (v.contains('/')) {
                List<String> parts = v.split('/');
                if (parts.size() == 3) {
                    Integer mm = Integer.valueOf(parts[0]);
                    Integer dd = Integer.valueOf(parts[1]);
                    Integer yyyy = Integer.valueOf(parts[2]);
                    return Date.newInstance(yyyy, mm, dd);
                }
                return null;
            }
            return Date.valueOf(v.substringBefore('T').trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String hashRef(String idKey, String title, String runId) {
        String basis = String.valueOf(idKey) + '|' + String.valueOf(title) + '|' + String.valueOf(runId);
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(basis));
        return EncodingUtil.convertToHex(digest).abbreviate(64);
    }
}
