/**
 * OA_LifecycleStates — the Business Lifecycle Orchestration (BLO) state model.
 *
 * Stateless, pure definition of the governed candidate lifecycle states and the ALLOWED transitions
 * between them. No DML, no SOQL. Reused by OA_CandidateApprovalService, OA_LeadCreationService, and
 * OA_BusinessLifecycleService so state rules live in ONE place. Candidate states are stored in the
 * existing free-text field OA_Discovered_Organization__c.Qualification_Status__c (Text 20) — no new
 * metadata is introduced.
 *
 * Downstream lifecycle stages (Enrichment, Campaign, Meeting, Opportunity, Customer) are tracked on the
 * Lead / CampaignMember / Event / Opportunity records by the already-deployed subsystems; this class
 * governs only the Candidate-side states up to CONVERTED (the acquisition→enrichment bridge).
 */
public with sharing class OA_LifecycleStates {

    // Candidate lifecycle states (<=20 chars to fit Qualification_Status__c).
    public static final String NEEDS_REVIEW = 'Needs Review';
    public static final String APPROVED     = 'Approved';
    public static final String REJECTED     = 'Rejected';
    public static final String DEFERRED     = 'Deferred';
    public static final String LEAD_READY   = 'Lead Ready';
    public static final String CONVERTED    = 'Converted';

    /**
     * Allowed transitions. CONVERTED is reachable ONLY from LEAD_READY/APPROVED and ONLY via
     * OA_LeadCreationService (the approval engine will refuse to set it directly) — no skipped states.
     */
    private static final Map<String, Set<String>> ALLOWED = new Map<String, Set<String>>{
        NEEDS_REVIEW => new Set<String>{ APPROVED, REJECTED, DEFERRED },
        DEFERRED     => new Set<String>{ NEEDS_REVIEW, APPROVED, REJECTED },
        APPROVED     => new Set<String>{ LEAD_READY, REJECTED, DEFERRED, CONVERTED },
        LEAD_READY   => new Set<String>{ CONVERTED, REJECTED },
        REJECTED     => new Set<String>{ NEEDS_REVIEW },
        CONVERTED    => new Set<String>{}
    };

    /** States from which a human-approved Lead creation may proceed. */
    public static final Set<String> CREATION_ELIGIBLE = new Set<String>{ APPROVED, LEAD_READY };

    /** Terminal states (no further transition except explicit reopen from REJECTED). */
    public static Boolean isTerminal(String state) {
        return CONVERTED.equals(state);
    }

    /** True if a candidate in fromState may move to toState. Null/blank fromState treated as NEEDS_REVIEW. */
    public static Boolean canTransition(String fromState, String toState) {
        String src = String.isBlank(fromState) ? NEEDS_REVIEW : fromState;
        Set<String> targets = ALLOWED.get(src);
        return targets != null && targets.contains(toState);
    }

    /** Normalizes a possibly-null status to the effective starting state. */
    public static String effective(String state) {
        return String.isBlank(state) ? NEEDS_REVIEW : state;
    }
}