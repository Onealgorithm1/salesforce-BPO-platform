/**
 * OA_FederalOpportunityAcquisition — free authoritative federal opportunity intake (Program 024).
 *
 * Discovers federal opportunities from FREE authoritative APIs, normalizes them to an OCDS-aligned
 * canonical candidate on OA_Opportunity_Signal__c, dedupes by Canonical_Key, publishes to the human
 * review queue (Review_Status='Pending'), and runs the deterministic compliance go/no-go screen.
 *
 * GOVERNANCE: creates ONLY review-queue candidates (never an Opportunity). Callout-before-DML.
 * Every run is capped, attributed, and screened. Grants.gov needs no credential (public API);
 * SAM.gov is gated on a data.gov key (see OA_SAM_Opportunities skeleton / docs).
 */
public with sharing class OA_FederalOpportunityAcquisition {

    public class Result {
        public String source;
        public Integer fetched = 0;
        public Integer inserted = 0;
        public Integer duplicates = 0;
        public List<Id> signalIds = new List<Id>();
        public String error;
    }

    /** Pilot/production intake from Grants.gov search2 (public, no credential). maxRows capped at 10. */
    public static Result grantsGov(String keyword, Integer maxRows) {
        Result r = new Result();
        r.source = 'Grants.gov';
        Integer rows = (maxRows == null || maxRows > 10 || maxRows < 1) ? 10 : maxRows;

        // ---- callout (before any DML) ----
        HttpResponse resp;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.grants.gov/v1/api/search2');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            Map<String, Object> body = new Map<String, Object>{ 'rows' => rows, 'oppStatuses' => 'posted' };
            if (String.isNotBlank(keyword)) body.put('keyword', keyword);
            req.setBody(JSON.serialize(body));
            resp = new Http().send(req);
        } catch (Exception e) {
            r.error = 'callout: ' + e.getTypeName() + ' ' + e.getMessage();
            return r;
        }
        if (resp.getStatusCode() < 200 || resp.getStatusCode() >= 300) {
            r.error = 'Grants.gov HTTP ' + resp.getStatusCode() + ': ' + abbreviate(resp.getBody(), 160);
            return r;
        }

        // ---- parse + normalize (OCDS-aligned) ----
        List<Object> hits;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            Map<String, Object> data = (Map<String, Object>) root.get('data');
            hits = (data == null) ? null : (List<Object>) data.get('oppHits');
        } catch (Exception e) {
            r.error = 'parse: ' + e.getMessage();
            return r;
        }
        if (hits == null || hits.isEmpty()) return r;
        r.fetched = hits.size();

        Map<String, OA_Opportunity_Signal__c> byKey = new Map<String, OA_Opportunity_Signal__c>();
        for (Object o : hits) {
            Map<String, Object> h = (Map<String, Object>) o;
            String gid = String.valueOf(h.get('id'));
            if (String.isBlank(gid) || gid == 'null') continue;
            String ck = 'grants:' + gid;
            OA_Opportunity_Signal__c s = new OA_Opportunity_Signal__c(
                Canonical_Key__c = ck,
                Source__c = 'Grants.gov',
                Type__c = 'Grant',
                Status__c = 'New',
                Review_Status__c = 'Pending',
                Confidence__c = 'High',                       // authoritative federal source
                Opportunity_Number__c = abbreviate(str(h.get('number')), 255),
                Title__c = abbreviate(str(h.get('title')), 255),
                Agency__c = abbreviate(str(h.get('agency')), 255),
                Agency_Code__c = abbreviate(str(h.get('agencyCode')), 255),
                Assistance_Listing__c = abbreviate(joinList(h.get('cfdaList')), 255),
                Posted_Date__c = parseDate(h.get('openDate')),
                Response_Deadline__c = parseDate(h.get('closeDate')),
                URL__c = 'https://grants.gov/search-results-detail/' + gid,
                Raw_Payload_Ref__c = abbreviate(JSON.serialize(h), 255)   // provenance pointer (full JSON abbreviated)
            );
            byKey.put(ck, s);
        }

        // ---- dedupe against existing candidates (idempotent) ----
        Set<String> existing = new Set<String>();
        for (OA_Opportunity_Signal__c e : [SELECT Canonical_Key__c FROM OA_Opportunity_Signal__c WHERE Canonical_Key__c IN :byKey.keySet()]) {
            existing.add(e.Canonical_Key__c);
        }
        List<OA_Opportunity_Signal__c> toInsert = new List<OA_Opportunity_Signal__c>();
        for (String k : byKey.keySet()) if (!existing.contains(k)) toInsert.add(byKey.get(k));
        r.duplicates = r.fetched - toInsert.size();

        if (!toInsert.isEmpty()) {
            insert toInsert;                               // review-queue candidates only — NEVER an Opportunity
            for (OA_Opportunity_Signal__c s : toInsert) r.signalIds.add(s.Id);
            OA_ComplianceScreen.screen(r.signalIds);       // deterministic go/no-go, no callout
        }
        r.inserted = toInsert.size();
        return r;
    }

    // ----- helpers -----
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
    private static String abbreviate(String s, Integer n) { return s == null ? null : s.abbreviate(n); }
    private static String joinList(Object o) {
        if (o == null) return null;
        if (o instanceof List<Object>) {
            List<String> parts = new List<String>();
            for (Object x : (List<Object>) o) parts.add(String.valueOf(x));
            return String.join(parts, ', ');
        }
        return String.valueOf(o);
    }
    /** Grants.gov dates are MM/dd/yyyy strings; parse defensively. */
    private static Date parseDate(Object o) {
        if (o == null) return null;
        String v = String.valueOf(o).trim();
        if (String.isBlank(v)) return null;
        try {
            if (v.contains('/')) {
                List<String> p = v.split('/');
                if (p.size() == 3) return Date.newInstance(Integer.valueOf(p[2]), Integer.valueOf(p[0]), Integer.valueOf(p[1]));
            }
            return Date.valueOf(v.substringBefore('T'));
        } catch (Exception e) { return null; }
    }
}