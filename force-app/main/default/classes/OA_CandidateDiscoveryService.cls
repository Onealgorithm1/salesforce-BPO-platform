/**
 * OA_CandidateDiscoveryService — Lead Acquisition candidate persistence with Identity Resolution + multi-source fusion.
 *
 * Pipeline per incoming canonical org: OA_IdentityResolution.resolve -> decision -> fusion/insert.
 *   - EXACT_DUPLICATE (same payload hash already staged) -> Skipped (no change)
 *   - MATCH -> CANDIDATE  -> FUSE incoming into the existing Candidate (fill-empty + provenance); UPDATE (no new record)
 *   - MATCH -> LEAD/ACCOUNT -> mark Duplicate + link (Matched_Lead__c/Matched_Account__c); insert an auditable marker
 *   - REVIEW (ambiguous)  -> insert as Needs Review with the match rationale (never auto-merges)
 *   - NONE                -> insert as a new Needs Review Candidate
 *
 * SAFE BY DEFAULT: preview (commit == false) performs NO DML. Commit inserts/updates ONLY
 * OA_Discovered_Organization__c (never Lead / Account / Contact). Human approval + Lead creation remain gated.
 * Connector-agnostic (no source branching). NOTE: Identity Resolution runs per-org SOQL — intended for controlled/
 * pilot batches; bulk volume needs a batched resolver (documented limitation).
 */
public with sharing class OA_CandidateDiscoveryService {

    public class Outcome {
        public Integer evaluated = 0;
        public Integer wouldInsert = 0;    // new (NONE) -> Needs Review
        public Integer review = 0;         // ambiguous (REVIEW) -> Needs Review with rationale
        public Integer duplicates = 0;     // matched an existing Lead/Account
        public Integer fused = 0;          // merged into an existing Candidate
        public Integer skipped = 0;        // exact duplicate (idempotent)
        public Integer inserted = 0;       // actual insert DML rows (0 in preview)
        public Integer updated = 0;        // actual update DML rows from fusion (0 in preview)
        public Boolean committed = false;
        public List<OA_Discovered_Organization__c> staged = new List<OA_Discovered_Organization__c>();
    }

    public static Outcome preview(List<OA_CanonicalOrg> orgs) { return run(orgs, false); }
    public static Outcome persist(List<OA_CanonicalOrg> orgs, Boolean commitWrites) { return run(orgs, commitWrites == true); }

    private static Outcome run(List<OA_CanonicalOrg> orgs, Boolean commitWrites) {
        Outcome o = new Outcome();
        o.committed = commitWrites;
        if (orgs == null || orgs.isEmpty()) { return o; }

        List<OA_Discovered_Organization__c> toInsert = new List<OA_Discovered_Organization__c>();
        Map<Id, OA_Discovered_Organization__c> toUpdate = new Map<Id, OA_Discovered_Organization__c>();
        Set<String> seenThisRun = new Set<String>();

        // BULK: one identity-resolution pass for the whole batch (fixed SOQL, no per-record query).
        List<OA_IdentityResolution.MatchResult> results = OA_IdentityResolution.resolveAll(orgs);

        for (Integer i = 0; i < orgs.size(); i++) {
            OA_CanonicalOrg c = orgs[i];
            if (c == null) { continue; }
            o.evaluated++;
            String h = c.payloadHash();

            // Guard against processing the same incoming org twice within one batch.
            if (String.isNotBlank(h) && seenThisRun.contains(h)) { o.skipped++; continue; }
            if (String.isNotBlank(h)) { seenThisRun.add(h); }

            OA_IdentityResolution.MatchResult mr = results[i];

            if (mr.decision == OA_IdentityResolution.Decision.EXACT_DUPLICATE) {
                o.skipped++;
                continue;
            }

            if (mr.decision == OA_IdentityResolution.Decision.MATCH
                    && mr.matchedType == OA_IdentityResolution.MatchedType.CANDIDATE
                    && mr.matchedId != null) {
                // FUSION: merge into the existing candidate (fill-empty + provenance). The matched record is
                // carried by resolveAll (no extra query); reuse the in-progress copy if this candidate was already
                // matched earlier in the batch so multiple sources accumulate into one record.
                OA_Discovered_Organization__c existing = toUpdate.containsKey(mr.matchedId)
                    ? toUpdate.get(mr.matchedId)
                    : (mr.matchedCandidate != null ? mr.matchedCandidate : loadCandidate(mr.matchedId));
                if (existing != null) {
                    OA_SourceFusion.fuse(existing, c);
                    toUpdate.put(existing.Id, existing);
                    o.fused++;
                    o.staged.add(existing);
                    continue;
                }
                // fall through to insert if the record could not be loaded
            }

            OA_Discovered_Organization__c d = toRecord(c);

            if (mr.decision == OA_IdentityResolution.Decision.MATCH
                    && (mr.matchedType == OA_IdentityResolution.MatchedType.LEAD
                        || mr.matchedType == OA_IdentityResolution.MatchedType.ACCOUNT)) {
                if (mr.matchedType == OA_IdentityResolution.MatchedType.LEAD) { d.Matched_Lead__c = mr.matchedId; }
                else { d.Matched_Account__c = mr.matchedId; }
                d.Qualification_Status__c = 'Duplicate';
                d.Recommended_Action__c = 'Matches existing ' + mr.matchedType + ' (' + String.join(mr.matchedIdentifiers, '+') + '); do not create';
                o.duplicates++;
            } else if (mr.decision == OA_IdentityResolution.Decision.REVIEW) {
                d.Qualification_Status__c = 'Needs Review';
                d.Recommended_Action__c = 'Ambiguous match (' + mr.rationale + ') - human review before create/merge';
                o.review++;
            } else {
                d.Qualification_Status__c = 'Needs Review';
                d.Recommended_Action__c = 'New organization - human review before Lead creation';
                o.wouldInsert++;
            }
            o.staged.add(d);
            toInsert.add(d);
        }

        if (commitWrites) {
            if (!toInsert.isEmpty()) { insert as user toInsert; o.inserted = toInsert.size(); }
            if (!toUpdate.isEmpty()) { update as user toUpdate.values(); o.updated = toUpdate.size(); }
        }
        return o;
    }

    private static OA_Discovered_Organization__c loadCandidate(Id id) {
        List<OA_Discovered_Organization__c> rows = [
            SELECT Id, Organization_Name__c, Normalized_Name__c, UEI__c, CAGE_Code__c, CIK__c, EIN__c, NPI__c,
                   NAICS__c, Address__c, City__c, State__c, Postal_Code__c, Website__c, Phone__c,
                   Source_System__c, Source_Confidence__c, Source_Payload_Hash__c, Canonical_Key__c,
                   Discovery_Metadata__c, Last_Evaluated__c
            FROM OA_Discovered_Organization__c WHERE Id = :id WITH USER_MODE LIMIT 1 ];
        return rows.isEmpty() ? null : rows[0];
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
