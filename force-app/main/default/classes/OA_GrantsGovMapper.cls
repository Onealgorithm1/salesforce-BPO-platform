/**
 * OA_GrantsGovMapper — maps one normalized row to an OA_Opportunity_Signal__c (in memory).
 *
 * Implements the SDK foundation contract (OA_IConnectorMapper). Builds the staging
 * record IN MEMORY only — performs NO DML (persistence is the caller's controlled
 * step via OA_ConnectorPersistence). Sets Review_Status__c = 'Pending' so every
 * signal lands in the human-review queue. Never touches Lead/Account/CRM.
 */
public with sharing class OA_GrantsGovMapper implements OA_IConnectorMapper {

    public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
        if (row == null) {
            return null;
        }
        String oppNumber = row.getString('number');
        String extId = row.getString('id');
        if (String.isBlank(oppNumber) && String.isBlank(extId)) {
            return null; // no identity -> cannot dedupe, skip
        }
        String key = 'GRANTS:' + (String.isNotBlank(oppNumber) ? oppNumber : extId);

        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c();
        sig.Canonical_Key__c      = abbrev(key, 120);
        sig.Source__c             = 'Grants.gov';
        sig.Type__c               = 'Grant';
        sig.Title__c              = abbrev(row.getString('title'), 255);
        sig.Opportunity_Number__c = abbrev(oppNumber, 80);
        sig.Agency__c             = abbrev(row.getString('agency'), 255);
        sig.Agency_Code__c        = abbrev(row.getString('agencyCode'), 40);
        sig.Assistance_Listing__c = abbrev(row.getString('cfda'), 120);
        sig.Doc_Type__c           = abbrev(row.getString('docType'), 40);
        sig.Posted_Date__c        = parseUsDate(row.getString('openDate'));
        sig.Response_Deadline__c  = parseUsDate(row.getString('closeDate'));
        sig.URL__c                = String.isNotBlank(extId)
            ? ('https://www.grants.gov/search-results-detail/' + extId) : null;
        sig.Source_Status__c      = abbrev(row.getString('oppStatus'), 40);
        sig.Status__c             = deriveStatus(row.getString('oppStatus'));
        sig.Confidence__c         = 'High'; // structured, exact-field API
        sig.Review_Status__c      = 'Pending';
        sig.Source_Run_ID__c      = (ctx != null) ? abbrev(ctx.runId, 80) : null;
        sig.Raw_Payload_Ref__c    = abbrev('search2#' + extId, 255);
        return sig;
    }

    private String deriveStatus(String oppStatus) {
        if (String.isBlank(oppStatus)) {
            return 'New';
        }
        String s = oppStatus.toLowerCase();
        if (s == 'posted' || s == 'forecasted') { return 'Active'; }
        if (s == 'closed' || s == 'archived') { return 'Expired'; }
        return 'New';
    }

    /** Grants.gov dates are MM/DD/YYYY. Returns null on anything unparseable. */
    private Date parseUsDate(String mdY) {
        if (String.isBlank(mdY)) {
            return null;
        }
        try {
            List<String> p = mdY.split('/');
            if (p.size() == 3) {
                return Date.newInstance(
                    Integer.valueOf(p[2]), Integer.valueOf(p[0]), Integer.valueOf(p[1]));
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    private String abbrev(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }
}
