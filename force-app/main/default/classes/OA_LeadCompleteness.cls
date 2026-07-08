/**
 * OA_LeadCompleteness — reusable, connector-agnostic Lead/Candidate completeness score (0-100).
 *
 * PURE computation: no DML, no SOQL, no callouts, no side effects. Scores an OA_CanonicalOrg (the canonical
 * organization profile produced by any connector, or a fused multi-source profile) against the weighted model
 * in docs/LEAD_ACQUISITION_LEAD_COMPLETENESS_MODEL.md. Bands: >=90 Campaign Ready, 70-89 Review, <70 Needs Enrichment.
 *
 * Design intent: acquisition establishes identity (typically scores < 70 -> Needs Enrichment); the Lead Enrichment
 * platform later fills contract/firmographic/contact fields, lifting the score toward Campaign Ready. This class does
 * NOT enrich, write, or automate anything — it only reports a number + rationale.
 */
public with sharing class OA_LeadCompleteness {

    // Dimension weights (sum = 100).
    public static final Integer W_IDENTITY = 10;
    public static final Integer W_GOV      = 20;   // UEI 10 + CAGE 5 + (EIN|CIK|NPI) 5
    public static final Integer W_LOCATION = 12;   // address/city/state/postal proportion
    public static final Integer W_WEBSITE  = 10;
    public static final Integer W_NAICS    = 10;
    public static final Integer W_PHONE    = 5;
    public static final Integer W_CONTRACT = 15;   // award/contract signal (attributes)
    public static final Integer W_PROFILE  = 13;   // business profile (attributes)
    public static final Integer W_EMAIL    = 5;    // enrichment-phase; ~0 at acquisition

    public class Result {
        public Integer score = 0;
        public String band;
        public Map<String, Integer> breakdown = new Map<String, Integer>();
    }

    public static Result evaluate(OA_CanonicalOrg c) {
        Result r = new Result();
        if (c == null) { r.band = band(0); return r; }

        Integer identity = String.isNotBlank(c.organizationName) ? W_IDENTITY : 0;

        Integer gov = 0;
        if (String.isNotBlank(c.uei))      { gov += 10; }
        if (String.isNotBlank(c.cageCode)) { gov += 5; }
        if (String.isNotBlank(c.ein) || String.isNotBlank(c.cik) || String.isNotBlank(c.npi)) { gov += 5; }

        Integer locParts = 0;
        if (String.isNotBlank(c.address))    { locParts++; }
        if (String.isNotBlank(c.city))       { locParts++; }
        if (String.isNotBlank(c.state))      { locParts++; }
        if (String.isNotBlank(c.postalCode)) { locParts++; }
        Integer location = (Integer) Math.floor((locParts / 4.0) * W_LOCATION);

        Integer website = String.isNotBlank(c.website) ? W_WEBSITE : 0;
        Integer naics   = String.isNotBlank(c.naics) ? W_NAICS : 0;
        Integer phone   = String.isNotBlank(c.phone) ? W_PHONE : 0;
        Integer contract = hasAttr(c, new Set<String>{'award', 'contract', 'obligat'}) ? W_CONTRACT : 0;
        Integer profile  = hasAttr(c, new Set<String>{'entity', 'socio', 'revenue', 'employee', 'business_type'}) ? W_PROFILE : 0;
        Integer email    = 0; // canonical orgs carry no email at acquisition; reserved for enrichment phase

        r.breakdown.put('identity', identity);
        r.breakdown.put('government', gov);
        r.breakdown.put('location', location);
        r.breakdown.put('website', website);
        r.breakdown.put('naics', naics);
        r.breakdown.put('phone', phone);
        r.breakdown.put('contract', contract);
        r.breakdown.put('businessProfile', profile);
        r.breakdown.put('email', email);

        r.score = identity + gov + location + website + naics + phone + contract + profile + email;
        if (r.score > 100) { r.score = 100; }
        r.band = band(r.score);
        return r;
    }

    public static String band(Integer score) {
        if (score >= 90) { return 'Campaign Ready'; }
        if (score >= 70) { return 'Review'; }
        return 'Needs Enrichment';
    }

    // True if any attributes key contains one of the given (lower-cased) fragments.
    private static Boolean hasAttr(OA_CanonicalOrg c, Set<String> fragments) {
        if (c == null || c.attributes == null || c.attributes.isEmpty()) { return false; }
        for (String k : c.attributes.keySet()) {
            if (k == null) { continue; }
            String lk = k.toLowerCase();
            for (String f : fragments) { if (lk.contains(f)) { return true; } }
        }
        return false;
    }
}
