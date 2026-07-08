/**
 * OA_SAMOpportunities_Mapper — maps one normalized row to OA_Opportunity_Signal__c (in memory).
 *
 * Implements the SDK foundation contract (OA_IConnectorMapper). Builds the staging
 * record IN MEMORY only — no DML (persistence is the caller's controlled step via
 * OA_ConnectorPersistence). Sets Review_Status__c='Pending' so every signal lands
 * in the human-review queue. Never touches Lead/Account/CRM. Absent fields -> null
 * (never fabricated).
 */
public with sharing class OA_SAMOpportunities_Mapper implements OA_IConnectorMapper {

    public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
        if (row == null) {
            return null;
        }
        String noticeId = row.getString('noticeId');
        if (String.isBlank(noticeId)) {
            return null; // no dedupe identity -> skip
        }

        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c();
        sig.Canonical_Key__c        = abbrev('SAM:' + noticeId, 120);
        sig.Source__c               = 'SAM.gov';
        sig.Type__c                 = 'Contract';
        sig.Title__c                = abbrev(row.getString('title'), 255);
        sig.Opportunity_Number__c   = abbrev(row.getString('solicitationNumber'), 80);
        sig.Agency__c               = abbrev(row.getString('agency'), 255);
        sig.NAICS__c                = abbrev(row.getString('naics'), 255);
        sig.PSC__c                  = abbrev(row.getString('psc'), 40);
        sig.Set_Aside__c            = abbrev(row.getString('setAside'), 80);
        sig.Place_of_Performance__c = abbrev(row.getString('placeOfPerformance'), 255);
        sig.Posted_Date__c          = parseIsoDate(row.getString('postedDate'));
        sig.Response_Deadline__c    = parseIsoDate(row.getString('responseDeadLine'));
        sig.Estimated_Value__c      = parseAmount(row.getString('value'));
        sig.URL__c                  = row.getString('uiLink');
        sig.Source_Status__c        = abbrev(row.getString('active'), 40);
        sig.Status__c               = deriveStatus(row.getString('active'));
        sig.Confidence__c           = 'High'; // structured, exact-field API
        sig.Review_Status__c        = 'Pending';
        sig.Source_Run_ID__c        = (ctx != null) ? abbrev(ctx.runId, 80) : null;
        sig.Raw_Payload_Ref__c      = abbrev('opportunities/v2#' + noticeId, 255);
        return sig;
    }

    /** SAM `active` is 'Yes'/'No'; derive the normalized posting lifecycle. */
    private String deriveStatus(String active) {
        if (String.isBlank(active)) {
            return 'New';
        }
        return active.equalsIgnoreCase('Yes') ? 'Active' : 'Expired';
    }

    /** SAM dates are ISO-ish (YYYY-MM-DD or YYYY-MM-DDThh:mm:ss...). Take the date part. */
    private Date parseIsoDate(String iso) {
        if (String.isBlank(iso)) {
            return null;
        }
        try {
            String datePart = iso.length() >= 10 ? iso.substring(0, 10) : iso;
            List<String> p = datePart.split('-');
            if (p.size() == 3) {
                return Date.newInstance(
                    Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    private Decimal parseAmount(String v) {
        if (String.isBlank(v)) {
            return null;
        }
        try {
            return Decimal.valueOf(v);
        } catch (Exception e) {
            return null;
        }
    }

    private String abbrev(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }
}
