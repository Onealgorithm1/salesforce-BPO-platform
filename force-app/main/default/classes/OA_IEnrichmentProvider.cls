/**
 * OA_IEnrichmentProvider — the extensible enrichment registry contract (Program 024).
 * A provider ENRICHES a candidate; it never owns it. New providers (USASpending, Federal Register,
 * SBIR, GSA, SEC EDGAR, NIH, NSF, ...) plug in without changing the acquisition engine.
 * enrich() is CALLOUT-ONLY (no DML) and must NEVER throw — return a summary or a '[provider: reason]' note.
 */
public interface OA_IEnrichmentProvider {
    String providerName();      // e.g. 'USASpending.gov'
    Boolean isFree();           // free vs paid
    Boolean isAuthoritative();  // authoritative vs derived
    String enrich(OA_Opportunity_Signal__c signal);  // returns human-readable enrichment summary
}
