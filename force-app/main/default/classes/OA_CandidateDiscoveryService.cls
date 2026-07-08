/**
 * OA_CandidateDiscoveryService — Lead Acquisition candidate persistence + duplicate detection.
 *
 * Takes canonical organizations produced by any OA_IEnrichmentConnector (via OA_ConnectorResult.organizations)
 * and persists them as Candidate records in the EXISTING staging object OA_Discovered_Organization__c.
 *
 * SAFE BY DEFAULT: preview mode (commit == false) performs NO DML and returns the classification only.
 * DML runs only when the caller explicitly passes commit == true, and ONLY inserts OA_Discovered_Organization__c
 * (never Lead / Account / Contact). Duplicate detection runs BEFORE any insert:
 *   - idempotency: same Source_Payload_Hash__c already staged  -> Skipped (no duplicate Candidate)
 *   - existing Candidate with same Canonical_Key__c            -> Duplicate (linked, not re-inserted)
 *   - existing Lead by UEI / CAGE                              -> Duplicate (Matched_Lead__c set)
 *   - otherwise                                                -> Needs Review (eligible for human approval)
 *
 * Reuses OA_CanonicalOrg (canonicalKey(), payloadHash()). No new object/field; no scheduler; no Lead creation.
 * Human approval (Qualification_Status__c = 'Approved') and Lead creation remain separate, gated steps.
 */
public with sharing class OA_CandidateDiscoveryService {

    public class Outcome {
        public Integer evaluated = 0;
        public Integer wouldInsert = 0;    // Needs Review (new, unique)
        public Integer duplicates = 0;     // matched an existing Lead or Candidate
        public Integer skipped = 0;        // idempotent (same payload hash already staged)
        public Integer inserted = 0;       // actual DML rows (0 in preview)
        public Boolean committed = false;
        public List<OA_Discovered_Organization__c> staged = new List<OA_Discovered_Organization__c>();
    }

    // Preview: never writes.
    public static Outcome preview(List<OA_CanonicalOrg> orgs) {
        return run(orgs, false);
    }

    // Persist: inserts new, non-duplicate Candidates only when commitWrites == true.
    public static Outcome persist(List<OA_CanonicalOrg> orgs, Boolean commitWrites) {
        return run(orgs, commitWrites == true);
    }

    private static Outcome run(List<OA_CanonicalOrg> orgs, Boolean commitWrites) {
        Outcome o = new Outcome();
        o.committed = commitWrites;
        if (orgs == null || orgs.isEmpty()) { return o; }

        // Collect dedup keys.
        Set<String> hashes = new Set<String>();
        Set<String> keys = new Set<String>();
        Set<String> ueis = new Set<String>();
        Set<String> cages = new Set<String>();
        for (OA_CanonicalOrg c : orgs) {
            if (c == null) { continue; }
            String h = c.payloadHash();      if (String.isNotBlank(h)) { hashes.add(h); }
            String k = c.canonicalKey();     if (String.isNotBlank(k)) { keys.add(k); }
            if (String.isNotBlank(c.uei))      { ueis.add(c.uei); }
            if (String.isNotBlank(c.cageCode)) { cages.add(c.cageCode); }
        }

        // Existing staged candidates (idempotency + candidate-level dedup).
        Set<String> stagedHashes = new Set<String>();
        Set<String> stagedKeys = new Set<String>();
        for (OA_Discovered_Organization__c d : [
                SELECT Source_Payload_Hash__c, Canonical_Key__c
                FROM OA_Discovered_Organization__c
                WHERE Source_Payload_Hash__c IN :hashes OR Canonical_Key__c IN :keys
                WITH USER_MODE ]) {
            if (String.isNotBlank(d.Source_Payload_Hash__c)) { stagedHashes.add(d.Source_Payload_Hash__c); }
            if (String.isNotBlank(d.Canonical_Key__c)) { stagedKeys.add(d.Canonical_Key__c); }
        }

        // Existing Leads by deterministic id (read-only; never modified).
        Map<String, Id> leadByUei = new Map<String, Id>();
        Map<String, Id> leadByCage = new Map<String, Id>();
        for (Lead l : [
                SELECT Id, UEI__c, CAGE_Code__c FROM Lead
                WHERE UEI__c IN :ueis OR CAGE_Code__c IN :cages
                WITH USER_MODE ]) {
            if (String.isNotBlank(l.UEI__c)) { leadByUei.put(l.UEI__c, l.Id); }
            if (String.isNotBlank(l.CAGE_Code__c)) { leadByCage.put(l.CAGE_Code__c, l.Id); }
        }

        List<OA_Discovered_Organization__c> toInsert = new List<OA_Discovered_Organization__c>();
        Set<String> seenThisRun = new Set<String>();

        for (OA_CanonicalOrg c : orgs) {
            if (c == null) { continue; }
            o.evaluated++;
            String h = c.payloadHash();
            String k = c.canonicalKey();

            // Idempotency: already staged, or duplicated within this batch by payload hash.
            if ((String.isNotBlank(h) && (stagedHashes.contains(h) || seenThisRun.contains(h)))) {
                o.skipped++;
                continue;
            }
            if (String.isNotBlank(h)) { seenThisRun.add(h); }

            OA_Discovered_Organization__c d = toRecord(c);

            // Duplicate detection.
            Id matchLead = null;
            if (String.isNotBlank(c.uei) && leadByUei.containsKey(c.uei)) { matchLead = leadByUei.get(c.uei); }
            else if (String.isNotBlank(c.cageCode) && leadByCage.containsKey(c.cageCode)) { matchLead = leadByCage.get(c.cageCode); }

            if (matchLead != null) {
                d.Matched_Lead__c = matchLead;
                d.Qualification_Status__c = 'Duplicate';
                d.Recommended_Action__c = 'Link to existing Lead; do not create';
                o.duplicates++;
            } else if (String.isNotBlank(k) && stagedKeys.contains(k)) {
                d.Qualification_Status__c = 'Duplicate';
                d.Recommended_Action__c = 'Existing candidate with same canonical key';
                o.duplicates++;
            } else {
                d.Qualification_Status__c = 'Needs Review';
                d.Recommended_Action__c = 'Human review before Lead creation';
                o.wouldInsert++;
            }
            o.staged.add(d);
            toInsert.add(d);
        }

        if (commitWrites && !toInsert.isEmpty()) {
            insert as user toInsert;
            o.inserted = toInsert.size();
        }
        return o;
    }

    private static OA_Discovered_Organization__c toRecord(OA_CanonicalOrg c) {
        OA_Discovered_Organization__c d = new OA_Discovered_Organization__c();
        d.Organization_Name__c = c.organizationName;
        d.Normalized_Name__c   = c.normalizedName;
        d.UEI__c               = c.uei;
        d.CAGE_Code__c         = c.cageCode;
        d.EIN__c               = c.ein;
        d.CIK__c               = c.cik;
        d.NPI__c               = c.npi;
        d.NAICS__c             = c.naics;
        d.Address__c           = c.address;
        d.City__c              = c.city;
        d.State__c             = c.state;
        d.Postal_Code__c       = c.postalCode;
        d.Website__c           = c.website;
        d.Phone__c             = c.phone;
        d.Source_System__c     = c.sourceSystem;
        d.Source_Confidence__c = c.sourceConfidence;
        d.Source_Payload_Hash__c = c.payloadHash();
        d.Canonical_Key__c     = c.canonicalKey();
        d.Last_Evaluated__c    = System.now();
        return d;
    }
}
