/**
 * OA_DiscoveryQualificationEngine — recommendation logic for discovered organizations.
 *
 * Given a canonical organization, it produces a RECOMMENDATION only:
 *   - Qualified / NotQualified / NeedsData (from the metadata ICP ruleset)
 *   - a confidence score + band
 *   - reason codes
 *   - a matched Salesforce record if one exists (read-only lookup)
 *   - a recommended action
 *
 * It DOES NOT create Leads. Auto-create is deliberately dormant and can only ever be enabled
 * later through metadata + explicit activation — this class exposes `autoCreateEnabled` as a
 * signal but never acts on it (no insert anywhere in this class).
 */
public with sharing class OA_DiscoveryQualificationEngine {

    public static final String STATUS_QUALIFIED = 'Qualified';
    public static final String STATUS_NOT = 'NotQualified';
    public static final String STATUS_NEEDS_DATA = 'NeedsData';

    public static final String ACTION_ENRICH_EXISTING = 'ENRICH_EXISTING';
    public static final String ACTION_CREATE_CANDIDATE = 'CREATE_LEAD_CANDIDATE';
    public static final String ACTION_RETAIN = 'RETAIN_DISCOVERY';

    /** Test-only override of the (dormant) auto-create switch. Default is OFF. */
    @TestVisible
    private static Boolean autoCreateEnabledOverride;

    public class Recommendation {
        public String qualificationStatus;
        public Decimal confidenceScore;
        public String confidenceBand;
        public List<String> reasonCodes = new List<String>();
        public Id matchedRecordId;
        public String matchedObject;
        public String recommendedAction;
        public Boolean autoCreateEnabled = false;
        public Boolean wouldCreate = false;   // what WOULD happen if activation were on
    }

    public static Recommendation evaluate(OA_CanonicalOrg org, String ruleset) {
        Recommendation rec = new Recommendation();

        // 1. Qualification against the metadata ICP ruleset.
        OA_QualificationRuleEngine.Result qual = OA_QualificationRuleEngine.evaluate(ruleset, org);
        rec.reasonCodes = qual.reasons;
        if (qual.qualified) {
            rec.qualificationStatus = STATUS_QUALIFIED;
        } else if (qual.needsData) {
            rec.qualificationStatus = STATUS_NEEDS_DATA;
        } else {
            rec.qualificationStatus = STATUS_NOT;
        }

        // 2. Read-only CRM match (exact organization name on Lead.Company / Account.Name).
        //    No CRM identifier field exists yet, so a name match is MEDIUM at best (honest).
        matchCrm(org, rec);

        // 3. Confidence: identifier match would be HIGH once a CRM identity field exists; today
        //    an exact-name CRM match is a MEDIUM signal.
        Boolean exactIdMatch = false;
        Boolean nameMatch = rec.matchedRecordId != null;
        Decimal nameScore = nameMatch ? 1 : 0;
        OA_ConfidenceEvaluator.Result conf = OA_ConfidenceEvaluator.evaluate(exactIdMatch, nameMatch, nameScore);
        rec.confidenceBand = conf.band;
        rec.confidenceScore = conf.score;

        // 4. Recommended action (NO creation happens here).
        if (rec.matchedRecordId != null) {
            rec.recommendedAction = ACTION_ENRICH_EXISTING;
        } else if (STATUS_QUALIFIED.equals(rec.qualificationStatus)) {
            rec.recommendedAction = ACTION_CREATE_CANDIDATE;
        } else {
            rec.recommendedAction = ACTION_RETAIN;
        }

        rec.autoCreateEnabled = isAutoCreateEnabled();
        rec.wouldCreate = rec.autoCreateEnabled
            && ACTION_CREATE_CANDIDATE.equals(rec.recommendedAction);
        return rec;
    }

    /** Read-only lookup of an existing CRM record by exact organization name. */
    private static void matchCrm(OA_CanonicalOrg org, Recommendation rec) {
        if (org == null || String.isBlank(org.organizationName)) {
            return;
        }
        String name = org.organizationName;
        List<Lead> leads = [SELECT Id FROM Lead WHERE Company = :name LIMIT 1];
        if (!leads.isEmpty()) {
            rec.matchedRecordId = leads[0].Id;
            rec.matchedObject = 'Lead';
            return;
        }
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
        if (!accounts.isEmpty()) {
            rec.matchedRecordId = accounts[0].Id;
            rec.matchedObject = 'Account';
        }
    }

    /**
     * The auto-create gate. DORMANT: always false unless explicitly overridden in a test.
     * Production activation would read a metadata/setting flag AND require the six creation
     * gates — intentionally NOT wired here so no Lead can be auto-created by this foundation.
     */
    @TestVisible
    private static Boolean isAutoCreateEnabled() {
        return autoCreateEnabledOverride == true;
    }
}
