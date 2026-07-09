/**
 * OA_USASpendingEnrichment — free authoritative award-history enrichment (Program 024).
 * Resolves a candidate's agency against USASpending toptier agencies (proves the buyer + unlocks
 * award-history/incumbent lookups). Reuses the OA_USASpending Named Credential. Callout-only, never throws.
 */
public with sharing class OA_USASpendingEnrichment implements OA_IEnrichmentProvider {
    public String providerName() { return 'USASpending.gov'; }
    public Boolean isFree() { return true; }
    public Boolean isAuthoritative() { return true; }

    public String enrich(OA_Opportunity_Signal__c sig) {
        if (sig == null || String.isBlank(sig.Agency__c)) return '[USASpending: no agency on candidate]';
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:OA_USASpending/api/v2/references/toptier_agencies/');
            req.setMethod('GET'); req.setTimeout(60000);
            req.setHeader('Accept', 'application/json');   // USASpending returns an HTML interstitial without this
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) return '[USASpending HTTP ' + res.getStatusCode() + ']';
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> agencies = (List<Object>) root.get('results');
            if (agencies == null) return '[USASpending: unexpected response]';
            String needle = sig.Agency__c.toLowerCase();
            for (Object o : agencies) {
                Map<String, Object> a = (Map<String, Object>) o;
                String name = String.valueOf(a.get('agency_name'));
                if (name != null && (needle.contains(name.toLowerCase()) || name.toLowerCase().contains(needle))) {
                    Object budget = a.get('current_total_budget_authority_amount');
                    return 'USASpending: buyer matched to toptier agency "' + name + '" (code ' + a.get('toptier_code')
                        + (budget != null ? ', budget authority $' + budget : '') + '). Award-history / incumbent lookup available.';
                }
            }
            return 'USASpending: no toptier match for "' + sig.Agency__c + '" (likely a sub-agency or grant-making office; deeper lookup available).';
        } catch (Exception e) {
            return '[USASpending unavailable: ' + e.getMessage() + ']';
        }
    }
}