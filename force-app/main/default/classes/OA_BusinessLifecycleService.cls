/**
 * OA_BusinessLifecycleService — the reusable Business Lifecycle Engine (BLO Phase 3).
 *
 * Single, connector-agnostic entry point that orchestrates the governed acquisition->enrichment bridge:
 * approval transitions (OA_CandidateApprovalService) and human-approved Lead creation
 * (OA_LeadCreationService). It adds NO new state or storage — it composes the reused approval, audit
 * (OA_ChangeLogService), and identity/dedup capabilities.
 *
 * Properties: STATELESS (all static), IDEMPOTENT (skips converted/linked candidates), BULK-SAFE
 * (batched queries + DML in the reused services), POLICY-DRIVEN (OA_LifecycleStates state machine),
 * AUDIT-FIRST (every applied transition writes a change log), ROLLBACK-AWARE (createdLeadIds +
 * OA_LeadCreationService.rollbackCreated), HUMAN-APPROVED (createLeads acts ONLY on APPROVED/LEAD_READY;
 * it will NOT convert Needs Review). NO direct automation: no trigger, flow, or schedule invokes this —
 * manual invocation only.
 */
public with sharing class OA_BusinessLifecycleService {

    public class LifecycleReport {
        public Boolean committed = false;
        public OA_CandidateApprovalService.RunSummary approval;
        public OA_LeadCreationService.RunSummary creation;
    }

    /**
     * Human-approved Lead creation for candidates already in APPROVED/LEAD_READY.
     * Preview (commitWrites=false) performs ZERO DML across the whole engine.
     */
    public static LifecycleReport createLeads(List<Id> candidateIds, Map<Id, String> contactEmailByCandidate, Boolean commitWrites) {
        LifecycleReport rep = new LifecycleReport();
        rep.committed = (commitWrites == true);
        rep.creation = OA_LeadCreationService.create(candidateIds, contactEmailByCandidate, commitWrites);
        return rep;
    }

    /**
     * Convenience: apply an approval transition then (optionally) create Leads in the same governed call.
     * The two steps are still individually gated + audited; nothing is skipped or auto-approved.
     */
    public static LifecycleReport advance(List<Id> candidateIds, String toState, String reviewer, String reason,
                                          Map<Id, String> contactEmailByCandidate, Boolean commitWrites) {
        LifecycleReport rep = new LifecycleReport();
        rep.committed = (commitWrites == true);
        rep.approval = OA_CandidateApprovalService.transition(candidateIds, toState, reviewer, reason, commitWrites);
        if (OA_LifecycleStates.CREATION_ELIGIBLE.contains(toState)) {
            rep.creation = OA_LeadCreationService.create(candidateIds, contactEmailByCandidate, commitWrites);
        }
        return rep;
    }

    /** Read-only lifecycle preview (0 DML) for a set of candidates. */
    public static LifecycleReport preview(List<Id> candidateIds) {
        return createLeads(candidateIds, null, false);
    }
}
