/**
 * OA_IdentityResolution — reusable, connector-agnostic identity resolution.
 *
 * Decides whether an incoming canonical organization (OA_CanonicalOrg, from ANY connector) is the same real-world
 * company as an existing Candidate (OA_Discovered_Organization__c), Lead, or Account. Solves the cross-identifier
 * problem: USASpending uses UEI, SEC uses CIK, SAM uses UEI/CAGE, IRS uses EIN — the same company must not become
 * separate unrelated Candidates just because the source uses a different identifier.
 *
 * READ-ONLY: performs SOQL only, never DML. No connector-specific branching. Ambiguous matches route to REVIEW
 * (never auto-merge). Provenance (matched identifiers + rationale) is always returned. Does NOT create/modify
 * Leads or Accounts.
 */
public with sharing class OA_IdentityResolution {

    public enum Decision { EXACT_DUPLICATE, MATCH, REVIEW, NONE }
    public enum MatchedType { CANDIDATE, LEAD, ACCOUNT, NONE }

    // Confidence thresholds.
    public static final Integer T_MATCH  = 85;   // >= auto-link to the matched record
    public static final Integer T_REVIEW = 55;   // >= route to human review (ambiguous)

    public class MatchResult {
        public Decision decision;
        public Integer confidence = 0;
        public MatchedType matchedType;
        public Id matchedId;
        public List<String> matchedIdentifiers = new List<String>();
        public String rationale = 'no match';
        public MatchResult() { decision = OA_IdentityResolution.Decision.NONE; matchedType = OA_IdentityResolution.MatchedType.NONE; }
    }

    public static MatchResult resolve(OA_CanonicalOrg org) {
        MatchResult best = new MatchResult();
        if (org == null) { return best; }

        String uei = blankToNull(org.uei);
        String cage = blankToNull(org.cageCode);
        String cik = blankToNull(org.cik);
        String ein = blankToNull(org.ein);
        String normName = blankToNull(org.normalizedName);
        String domain = domainOf(org.website);
        String hash = org.payloadHash();

        best = better(best, matchCandidates(uei, cage, cik, ein, normName, domain, org.address, org.state, hash));
        best = better(best, matchLeads(uei, cage, cik, ein, normName, domain, org.state));
        best = better(best, matchAccounts(normName, domain));

        best.decision = decide(best);
        return best;
    }

    // ---- Candidate matching (OA_Discovered_Organization__c) ----
    private static MatchResult matchCandidates(String uei, String cage, String cik, String ein,
            String normName, String domain, String address, String state, String hash) {
        List<String> ors = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        addEq(ors, binds, 'Source_Payload_Hash__c', 'hash', hash);
        addEq(ors, binds, 'UEI__c', 'uei', uei);
        addEq(ors, binds, 'CAGE_Code__c', 'cage', cage);
        addEq(ors, binds, 'CIK__c', 'cik', cik);
        addEq(ors, binds, 'EIN__c', 'ein', ein);
        addEq(ors, binds, 'Normalized_Name__c', 'nn', normName);
        if (String.isNotBlank(domain)) { ors.add('Website__c LIKE :domlike'); binds.put('domlike', '%' + domain + '%'); }
        if (ors.isEmpty()) { return new MatchResult(); }
        String q = 'SELECT Id, Source_Payload_Hash__c, UEI__c, CAGE_Code__c, CIK__c, EIN__c, Website__c, '
                 + 'Normalized_Name__c, Address__c, State__c FROM OA_Discovered_Organization__c WHERE '
                 + String.join(ors, ' OR ') + ' LIMIT 50';
        MatchResult best = new MatchResult();
        for (OA_Discovered_Organization__c d : (List<OA_Discovered_Organization__c>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE)) {
            MatchResult m = score(uei, cage, cik, ein, normName, domain, address, state, hash,
                d.UEI__c, d.CAGE_Code__c, d.CIK__c, d.EIN__c, d.Normalized_Name__c, domainOf(d.Website__c), d.Address__c, d.State__c, d.Source_Payload_Hash__c);
            m.matchedType = MatchedType.CANDIDATE; m.matchedId = d.Id;
            best = better(best, m);
        }
        return best;
    }

    // ---- Lead matching (Lead has UEI/CAGE/CIK/EIN + Website + Company) ----
    private static MatchResult matchLeads(String uei, String cage, String cik, String ein, String normName, String domain, String state) {
        List<String> ors = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        addEq(ors, binds, 'UEI__c', 'uei', uei);
        addEq(ors, binds, 'CAGE_Code__c', 'cage', cage);
        addEq(ors, binds, 'CIK__c', 'cik', cik);
        addEq(ors, binds, 'EIN__c', 'ein', ein);
        if (String.isNotBlank(domain)) { ors.add('Website LIKE :domlike'); binds.put('domlike', '%' + domain + '%'); }
        if (ors.isEmpty()) { return new MatchResult(); }  // Leads keyed by strong IDs / domain (no normalized-name field)
        String q = 'SELECT Id, UEI__c, CAGE_Code__c, CIK__c, EIN__c, Website, Company, State FROM Lead WHERE '
                 + String.join(ors, ' OR ') + ' LIMIT 50';
        MatchResult best = new MatchResult();
        for (Lead l : (List<Lead>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE)) {
            MatchResult m = score(uei, cage, cik, ein, normName, domain, (String) null, state, (String) null,
                l.UEI__c, l.CAGE_Code__c, l.CIK__c, l.EIN__c, (String) null, domainOf(l.Website), (String) null, l.State, (String) null);
            m.matchedType = MatchedType.LEAD; m.matchedId = l.Id;
            best = better(best, m);
        }
        return best;
    }

    // ---- Account matching (Account has NO gov identifiers — name/domain only; deliberately weak) ----
    private static MatchResult matchAccounts(String normName, String domain) {
        if (String.isBlank(domain) && String.isBlank(normName)) { return new MatchResult(); }
        List<String> ors = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        if (String.isNotBlank(normName)) { ors.add('Name = :nn'); binds.put('nn', normName); }
        if (ors.isEmpty()) { return new MatchResult(); }
        String q = 'SELECT Id, Name, Website FROM Account WHERE ' + String.join(ors, ' OR ') + ' LIMIT 50';
        MatchResult best = new MatchResult();
        for (Account a : (List<Account>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE)) {
            Integer conf = 0; List<String> ids = new List<String>();
            if (String.isNotBlank(domain) && domain == domainOf(a.Website)) { conf = 85; ids.add('domain'); }
            else if (String.isNotBlank(normName) && normName.equalsIgnoreCase(a.Name)) { conf = 55; ids.add('name'); }
            if (conf > best.confidence) {
                best = new MatchResult();
                best.confidence = conf; best.matchedType = MatchedType.ACCOUNT; best.matchedId = a.Id;
                best.matchedIdentifiers = ids; best.rationale = 'Account ' + String.join(ids, '+');
            }
        }
        return best;
    }

    // ---- Field-level scoring (highest single signal wins) ----
    private static MatchResult score(String uei, String cage, String cik, String ein, String normName, String domain,
            String address, String state, String hash,
            String xUei, String xCage, String xCik, String xEin, String xNorm, String xDomain, String xAddr, String xState, String xHash) {
        MatchResult r = new MatchResult();
        Integer conf = 0; List<String> ids = new List<String>(); String why = 'no match';
        if (String.isNotBlank(hash) && hash == xHash) { conf = 100; ids = new List<String>{'payloadHash'}; why = 'exact payload-hash duplicate'; }
        else if (eq(uei, xUei))  { conf = 99; ids = new List<String>{'UEI'};  why = 'shared UEI'; }
        else if (eq(cage, xCage)) { conf = 97; ids = new List<String>{'CAGE'}; why = 'shared CAGE'; }
        else if (eq(cik, xCik))  { conf = 96; ids = new List<String>{'CIK'};  why = 'shared CIK'; }
        else if (eq(ein, xEin))  { conf = 95; ids = new List<String>{'EIN'};  why = 'shared EIN'; }
        else if (String.isNotBlank(domain) && domain == xDomain) { conf = 85; ids = new List<String>{'domain'}; why = 'same website domain'; }
        else if (eqi(normName, xNorm) && eqi(address, xAddr) && String.isNotBlank(address)) { conf = 85; ids = new List<String>{'name','address'}; why = 'normalized name + address'; }
        else if (eqi(normName, xNorm) && eq(state, xState) && String.isNotBlank(state)) { conf = 65; ids = new List<String>{'name','state'}; why = 'normalized name + state (ambiguous)'; }
        else if (eqi(normName, xNorm)) { conf = 45; ids = new List<String>{'name'}; why = 'normalized name only (weak)'; }
        r.confidence = conf; r.matchedIdentifiers = ids; r.rationale = why;
        return r;
    }

    private static Decision decide(MatchResult r) {
        if (r.confidence >= 100 && r.matchedIdentifiers.contains('payloadHash')) { return Decision.EXACT_DUPLICATE; }
        if (r.confidence >= T_MATCH)  { return Decision.MATCH; }
        if (r.confidence >= T_REVIEW) { return Decision.REVIEW; }
        return Decision.NONE;
    }

    // ---- helpers ----
    private static MatchResult better(MatchResult a, MatchResult b) { return (b != null && b.confidence > a.confidence) ? b : a; }
    private static Boolean eq(String a, String b) { return String.isNotBlank(a) && a == b; }
    private static Boolean eqi(String a, String b) { return String.isNotBlank(a) && String.isNotBlank(b) && a.equalsIgnoreCase(b); }
    private static String blankToNull(String v) { return String.isBlank(v) ? null : v; }
    private static void addEq(List<String> ors, Map<String, Object> binds, String field, String key, String val) {
        if (String.isNotBlank(val)) { ors.add(field + ' = :' + key); binds.put(key, val); }
    }
    @TestVisible
    private static String domainOf(String website) {
        if (String.isBlank(website)) { return null; }
        String d = website.toLowerCase().trim();
        d = d.replaceFirst('^https?://', '').replaceFirst('^www\\.', '');
        Integer slash = d.indexOf('/');
        if (slash > 0) { d = d.substring(0, slash); }
        return String.isBlank(d) ? null : d;
    }
}
