/**
 * OA_IdentityResolution — reusable, connector-agnostic identity resolution (BULK-SAFE).
 *
 * Decides whether incoming canonical organizations (OA_CanonicalOrg, from ANY connector) are the same real-world
 * company as an existing Candidate (OA_Discovered_Organization__c), Lead, or Account. Solves the cross-identifier
 * problem (UEI vs CIK vs EIN vs CAGE).
 *
 * BULK-SAFE: resolveAll(list) issues a FIXED number of SOQL queries (candidates, leads, accounts) regardless of
 * batch size — NO per-record SOQL. resolve(single) delegates to resolveAll (one code path). READ-ONLY (SOQL only,
 * never DML). Ambiguous matches route to REVIEW (never auto-merge). MATCH-to-Candidate carries the matched record
 * so fusion needs no extra query. No connector-specific branching.
 */
public with sharing class OA_IdentityResolution {

    public enum Decision { EXACT_DUPLICATE, MATCH, REVIEW, NONE }
    public enum MatchedType { CANDIDATE, LEAD, ACCOUNT, NONE }

    public static final Integer T_MATCH  = 85;
    public static final Integer T_REVIEW = 55;

    public class MatchResult {
        public Decision decision;
        public Integer confidence = 0;
        public MatchedType matchedType;
        public Id matchedId;
        public List<String> matchedIdentifiers = new List<String>();
        public String rationale = 'no match';
        public OA_Discovered_Organization__c matchedCandidate; // populated for CANDIDATE matches (for fusion; no re-query)
        public MatchResult() {
            decision = OA_IdentityResolution.Decision.NONE;
            matchedType = OA_IdentityResolution.MatchedType.NONE;
        }
    }

    public static MatchResult resolve(OA_CanonicalOrg org) {
        List<MatchResult> r = resolveAll(new List<OA_CanonicalOrg>{ org });
        return r.isEmpty() ? new MatchResult() : r[0];
    }

    /** Bulk resolver: a fixed number of queries for the whole batch. Returns one MatchResult per input (aligned). */
    public static List<MatchResult> resolveAll(List<OA_CanonicalOrg> orgs) {
        List<MatchResult> out = new List<MatchResult>();
        if (orgs == null || orgs.isEmpty()) { return out; }

        // ---- Collect all identifiers across the batch ----
        Set<String> ueis = new Set<String>(), cages = new Set<String>(), ciks = new Set<String>(),
                    eins = new Set<String>(), names = new Set<String>(), hashes = new Set<String>();
        Set<String> domains = new Set<String>();
        for (OA_CanonicalOrg c : orgs) {
            if (c == null) { continue; }
            addIf(ueis, c.uei); addIf(cages, c.cageCode); addIf(ciks, c.cik); addIf(eins, c.ein);
            addIf(names, c.normalizedName); addIf(hashes, c.payloadHash()); addIf(domains, domainOf(c.website));
        }

        // ---- Query candidates ONCE ----
        Map<String, OA_Discovered_Organization__c> candByUei = new Map<String, OA_Discovered_Organization__c>(),
            candByCage = new Map<String, OA_Discovered_Organization__c>(), candByCik = new Map<String, OA_Discovered_Organization__c>(),
            candByEin = new Map<String, OA_Discovered_Organization__c>(), candByHash = new Map<String, OA_Discovered_Organization__c>(),
            candByDomain = new Map<String, OA_Discovered_Organization__c>();
        Map<String, List<OA_Discovered_Organization__c>> candByName = new Map<String, List<OA_Discovered_Organization__c>>();
        for (OA_Discovered_Organization__c d : queryCandidates(ueis, cages, ciks, eins, names, hashes, domains)) {
            putIf(candByUei, d.UEI__c, d); putIf(candByCage, d.CAGE_Code__c, d); putIf(candByCik, d.CIK__c, d);
            putIf(candByEin, d.EIN__c, d); putIf(candByHash, d.Source_Payload_Hash__c, d);
            putIf(candByDomain, domainOf(d.Website__c), d);
            if (String.isNotBlank(d.Normalized_Name__c)) {
                String k = d.Normalized_Name__c.toUpperCase();
                if (!candByName.containsKey(k)) { candByName.put(k, new List<OA_Discovered_Organization__c>()); }
                candByName.get(k).add(d);
            }
        }

        // ---- Query leads ONCE ----
        Map<String, Lead> leadByUei = new Map<String, Lead>(), leadByCage = new Map<String, Lead>(),
            leadByCik = new Map<String, Lead>(), leadByEin = new Map<String, Lead>(), leadByDomain = new Map<String, Lead>();
        for (Lead l : queryLeads(ueis, cages, ciks, eins, domains)) {
            putIf(leadByUei, l.UEI__c, l); putIf(leadByCage, l.CAGE_Code__c, l); putIf(leadByCik, l.CIK__c, l);
            putIf(leadByEin, l.EIN__c, l); putIf(leadByDomain, domainOf(l.Website), l);
        }

        // ---- Query accounts ONCE ----
        Map<String, Account> acctByName = new Map<String, Account>(), acctByDomain = new Map<String, Account>();
        for (Account a : queryAccounts(names)) {
            if (String.isNotBlank(a.Name)) { acctByName.put(a.Name.toUpperCase(), a); }
            putIf(acctByDomain, domainOf(a.Website), a);
        }

        // ---- Score each org in memory (no SOQL) ----
        for (OA_CanonicalOrg c : orgs) {
            MatchResult r = new MatchResult();
            if (c == null) { out.add(r); continue; }
            String uei = c.uei, cage = c.cageCode, cik = c.cik, ein = c.ein, hash = c.payloadHash();
            String nn = String.isBlank(c.normalizedName) ? null : c.normalizedName.toUpperCase();
            String dom = domainOf(c.website);

            // Candidate signals (highest first).
            if (hit(candByHash, hash)) { setCand(r, 100, candByHash.get(hash), new List<String>{'payloadHash'}, 'exact payload-hash duplicate'); }
            else if (hit(candByUei, uei)) { setCand(r, 99, candByUei.get(uei), new List<String>{'UEI'}, 'shared UEI'); }
            else if (hit(candByCage, cage)) { setCand(r, 97, candByCage.get(cage), new List<String>{'CAGE'}, 'shared CAGE'); }
            else if (hit(candByCik, cik)) { setCand(r, 96, candByCik.get(cik), new List<String>{'CIK'}, 'shared CIK'); }
            else if (hit(candByEin, ein)) { setCand(r, 95, candByEin.get(ein), new List<String>{'EIN'}, 'shared EIN'); }
            else if (hit(candByDomain, dom)) { setCand(r, 85, candByDomain.get(dom), new List<String>{'domain'}, 'same website domain'); }
            else if (nn != null && candByName.containsKey(nn)) {
                for (OA_Discovered_Organization__c d : candByName.get(nn)) {
                    if (String.isNotBlank(c.address) && eqi(c.address, d.Address__c)) { setCand(r, 85, d, new List<String>{'name','address'}, 'normalized name + address'); break; }
                }
                if (r.confidence < 85) {
                    for (OA_Discovered_Organization__c d : candByName.get(nn)) {
                        if (String.isNotBlank(c.state) && c.state == d.State__c) { setCand(r, 65, d, new List<String>{'name','state'}, 'normalized name + state (ambiguous)'); break; }
                    }
                }
                if (r.confidence == 0) { setCand(r, 45, candByName.get(nn)[0], new List<String>{'name'}, 'normalized name only (weak)'); }
            }

            // Lead signals (can only raise confidence; strong IDs + domain).
            considerLead(r, 99, leadByUei, uei, 'UEI');
            considerLead(r, 97, leadByCage, cage, 'CAGE');
            considerLead(r, 96, leadByCik, cik, 'CIK');
            considerLead(r, 95, leadByEin, ein, 'EIN');
            considerLead(r, 85, leadByDomain, dom, 'domain');

            // Account signals (weak: domain, then exact name).
            if (hit(acctByDomain, dom) && 85 > r.confidence) { setAcct(r, 85, acctByDomain.get(dom).Id, new List<String>{'domain'}); }
            else if (nn != null && acctByName.containsKey(nn) && 55 > r.confidence) { setAcct(r, 55, acctByName.get(nn).Id, new List<String>{'name'}); }

            r.decision = decide(r);
            out.add(r);
        }
        return out;
    }

    // ---- queries (each runs once per batch) ----
    private static List<OA_Discovered_Organization__c> queryCandidates(Set<String> ueis, Set<String> cages, Set<String> ciks,
            Set<String> eins, Set<String> names, Set<String> hashes, Set<String> domains) {
        List<String> ors = new List<String>();
        Map<String, Object> binds = new Map<String, Object>{
            'ueis'=>ueis, 'cages'=>cages, 'ciks'=>ciks, 'eins'=>eins, 'names'=>names, 'hashes'=>hashes };
        if (!hashes.isEmpty()) { ors.add('Source_Payload_Hash__c IN :hashes'); }
        if (!ueis.isEmpty())   { ors.add('UEI__c IN :ueis'); }
        if (!cages.isEmpty())  { ors.add('CAGE_Code__c IN :cages'); }
        if (!ciks.isEmpty())   { ors.add('CIK__c IN :ciks'); }
        if (!eins.isEmpty())   { ors.add('EIN__c IN :eins'); }
        if (!names.isEmpty())  { ors.add('Normalized_Name__c IN :names'); }
        addDomainOrs(ors, binds, 'Website__c', domains);
        if (ors.isEmpty()) { return new List<OA_Discovered_Organization__c>(); }
        String q = 'SELECT Id, Organization_Name__c, Normalized_Name__c, UEI__c, CAGE_Code__c, CIK__c, EIN__c, NPI__c, '
                 + 'NAICS__c, Address__c, City__c, State__c, Postal_Code__c, Website__c, Phone__c, Source_System__c, '
                 + 'Source_Confidence__c, Source_Payload_Hash__c, Canonical_Key__c, Discovery_Metadata__c, Last_Evaluated__c '
                 + 'FROM OA_Discovered_Organization__c WHERE ' + String.join(ors, ' OR ') + ' LIMIT 2000';
        return (List<OA_Discovered_Organization__c>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE);
    }

    private static List<Lead> queryLeads(Set<String> ueis, Set<String> cages, Set<String> ciks, Set<String> eins, Set<String> domains) {
        List<String> ors = new List<String>();
        Map<String, Object> binds = new Map<String, Object>{ 'ueis'=>ueis, 'cages'=>cages, 'ciks'=>ciks, 'eins'=>eins };
        if (!ueis.isEmpty())  { ors.add('UEI__c IN :ueis'); }
        if (!cages.isEmpty()) { ors.add('CAGE_Code__c IN :cages'); }
        if (!ciks.isEmpty())  { ors.add('CIK__c IN :ciks'); }
        if (!eins.isEmpty())  { ors.add('EIN__c IN :eins'); }
        addDomainOrs(ors, binds, 'Website', domains);
        if (ors.isEmpty()) { return new List<Lead>(); }
        String q = 'SELECT Id, UEI__c, CAGE_Code__c, CIK__c, EIN__c, Website, Company, State FROM Lead WHERE '
                 + String.join(ors, ' OR ') + ' LIMIT 2000';
        return (List<Lead>) Database.queryWithBinds(q, binds, AccessLevel.USER_MODE);
    }

    private static List<Account> queryAccounts(Set<String> names) {
        if (names.isEmpty()) { return new List<Account>(); }
        Map<String, Object> binds = new Map<String, Object>{ 'names'=>names };
        return (List<Account>) Database.queryWithBinds(
            'SELECT Id, Name, Website FROM Account WHERE Name IN :names LIMIT 2000', binds, AccessLevel.USER_MODE);
    }

    // Adds "field LIKE '%domain%'" clauses (one per domain) to the OR list.
    private static void addDomainOrs(List<String> ors, Map<String, Object> binds, String field, Set<String> domains) {
        Integer i = 0;
        for (String dom : domains) {
            if (String.isBlank(dom)) { continue; }
            String key = 'dom' + i;
            ors.add(field + ' LIKE :' + key);
            binds.put(key, '%' + dom + '%');
            i++;
        }
    }

    // ---- scoring helpers ----
    private static void setCand(MatchResult r, Integer conf, OA_Discovered_Organization__c d, List<String> ids, String why) {
        if (conf <= r.confidence) { return; }
        r.confidence = conf; r.matchedType = MatchedType.CANDIDATE; r.matchedId = d.Id;
        r.matchedCandidate = d; r.matchedIdentifiers = ids; r.rationale = why;
    }
    private static void considerLead(MatchResult r, Integer conf, Map<String, Lead> idx, String key, String label) {
        if (conf <= r.confidence || !hit(idx, key)) { return; }
        r.confidence = conf; r.matchedType = MatchedType.LEAD; r.matchedId = idx.get(key).Id;
        r.matchedCandidate = null; r.matchedIdentifiers = new List<String>{ label };
        r.rationale = 'shared ' + label + ' with existing Lead';
    }
    private static void setAcct(MatchResult r, Integer conf, Id acctId, List<String> ids) {
        r.confidence = conf; r.matchedType = MatchedType.ACCOUNT; r.matchedId = acctId;
        r.matchedCandidate = null; r.matchedIdentifiers = ids; r.rationale = 'Account ' + String.join(ids, '+');
    }
    private static Decision decide(MatchResult r) {
        if (r.confidence >= 100 && r.matchedIdentifiers.contains('payloadHash')) { return Decision.EXACT_DUPLICATE; }
        if (r.confidence >= T_MATCH)  { return Decision.MATCH; }
        if (r.confidence >= T_REVIEW) { return Decision.REVIEW; }
        return Decision.NONE;
    }

    private static Boolean hit(Map<String, OA_Discovered_Organization__c> m, String k) { return String.isNotBlank(k) && m.containsKey(k); }
    private static Boolean hit(Map<String, Lead> m, String k) { return String.isNotBlank(k) && m.containsKey(k); }
    private static Boolean hit(Map<String, Account> m, String k) { return String.isNotBlank(k) && m.containsKey(k); }
    private static Boolean eqi(String a, String b) { return String.isNotBlank(a) && String.isNotBlank(b) && a.equalsIgnoreCase(b); }
    private static void addIf(Set<String> s, String v) { if (String.isNotBlank(v)) { s.add(v); } }
    private static void putIf(Map<String, OA_Discovered_Organization__c> m, String k, OA_Discovered_Organization__c v) { if (String.isNotBlank(k) && !m.containsKey(k)) { m.put(k, v); } }
    private static void putIf(Map<String, Lead> m, String k, Lead v) { if (String.isNotBlank(k) && !m.containsKey(k)) { m.put(k, v); } }
    private static void putIf(Map<String, Account> m, String k, Account v) { if (String.isNotBlank(k) && !m.containsKey(k)) { m.put(k, v); } }
    @TestVisible
    private static String domainOf(String website) {
        if (String.isBlank(website)) { return null; }
        String d = website.toLowerCase().trim().replaceFirst('^https?://', '').replaceFirst('^www\\.', '');
        Integer slash = d.indexOf('/');
        if (slash > 0) { d = d.substring(0, slash); }
        return String.isBlank(d) ? null : d;
    }
}