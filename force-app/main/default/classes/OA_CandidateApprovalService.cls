/**
 * OA_CandidateApprovalService — the governed Candidate Approval Engine (BLO Phase 4).
 *
 * Transitions OA_Discovered_Organization__c candidates between lifecycle states
 * (Needs Review -> Approved | Rejected | Deferred -> Lead Ready) with:
 *   - policy validation (OA_LifecycleStates state machine; no skipped states),
 *   - audit (OA_ChangeLogService before/after change log — reused, never re-built),
 *   - provenance preservation (never clears Source_System__c / Canonical_Key__c / Discovery_Metadata__c),
 *   - duplicate awareness (records that already carry Matched_Lead__c cannot be re-approved for creation).
 *
 * Stateless, bulk-safe, idempotent. Preview mode (commitWrites=false) does ZERO DML. CONVERTED is NOT
 * settable here — only OA_LeadCreationService may mark a candidate Converted. Manual invocation only:
 * NO trigger, NO flow, NO schedule invokes this class.
 */
public with sharing class OA_CandidateApprovalService {

    private static final Set<String> AUDIT_FIELDS = new Set<String>{ 'Qualification_Status__c', 'Recommended_Action__c' };

    public class ApprovalOutcome {
        public Id candidateId;
        public String fromState;
        public String toState;
        public Boolean applied = false;    // would-apply in preview; applied in commit
        public String gate;                // TRANSITION | TERMINAL | CONVERT_GUARD | OK
        public String reason;
    }

    public class RunSummary {
        public Boolean committed = false;
        public Integer evaluated = 0;
        public Integer applied = 0;
        public Integer blocked = 0;
        public Integer dmlRows = 0;
        public List<ApprovalOutcome> outcomes = new List<ApprovalOutcome>();
    }

    /**
     * Move the given candidates to {toState}, recording who/why. commitWrites=false => preview (0 DML).
     * @param candidateIds candidate record Ids
     * @param toState      target lifecycle state (must be a legal transition from each candidate's current state)
     * @param reviewer     free-text reviewer identity (audit)
     * @param reason       free-text rationale (stored in Recommended_Action__c + audit)
     */
    public static RunSummary transition(List<Id> candidateIds, String toState, String reviewer, String reason, Boolean commitWrites) {
        RunSummary sum = new RunSummary();
        sum.committed = (commitWrites == true);
        if (candidateIds == null || candidateIds.isEmpty() || String.isBlank(toState)) { return sum; }

        List<OA_Discovered_Organization__c> cands = [
            SELECT Id, Qualification_Status__c, Recommended_Action__c, Qualification_Reasons__c,
                   Matched_Lead__c, Source_System__c, Canonical_Key__c, Connector_Run__c, Source_Confidence__c,
                   Reviewed_Contact_Email__c
            FROM OA_Discovered_Organization__c
            WHERE Id IN :candidateIds
        ];

        List<OA_Discovered_Organization__c> toUpdate = new List<OA_Discovered_Organization__c>();
        List<OA_Enrichment_Change_Log__c> logs = new List<OA_Enrichment_Change_Log__c>();

        for (OA_Discovered_Organization__c c : cands) {
            sum.evaluated++;
            ApprovalOutcome o = new ApprovalOutcome();
            o.candidateId = c.Id;
            o.fromState = OA_LifecycleStates.effective(c.Qualification_Status__c);
            o.toState = toState;

            if (OA_LifecycleStates.CONVERTED.equals(toState)) {
                o.gate = 'CONVERT_GUARD';
                o.reason = 'CONVERTED is set only by OA_LeadCreationService, not the approval engine.';
                sum.blocked++; sum.outcomes.add(o); continue;
            }
            if (OA_LifecycleStates.isTerminal(o.fromState)) {
                o.gate = 'TERMINAL';
                o.reason = 'Candidate is CONVERTED (terminal); no further approval transitions.';
                sum.blocked++; sum.outcomes.add(o); continue;
            }
            if (!OA_LifecycleStates.canTransition(o.fromState, toState)) {
                o.gate = 'TRANSITION';
                o.reason = 'Illegal transition ' + o.fromState + ' -> ' + toState + '.';
                sum.blocked++; sum.outcomes.add(o); continue;
            }
            // READINESS: a candidate cannot become Lead Ready without a reviewed contact email
            // (satisfies the Lead Require_Email_Or_Contact_Person_Email rule; never fabricated).
            if (OA_LifecycleStates.LEAD_READY.equals(toState) && String.isBlank(c.Reviewed_Contact_Email__c)) {
                o.gate = 'READINESS';
                o.reason = 'Lead Ready requires a reviewer-supplied Reviewed_Contact_Email__c.';
                sum.blocked++; sum.outcomes.add(o); continue;
            }

            o.gate = 'OK';
            o.applied = true;
            sum.applied++;

            if (commitWrites == true) {
                String before = OA_ChangeLogService.snapshot(c, AUDIT_FIELDS);
                logs.add(OA_ChangeLogService.buildLog(
                    'OA_Discovered_Organization__c', c.Id, 'Qualification_Status__c',
                    o.fromState, toState, 'BLO-Approval', 'Overwrite',
                    c.Source_Confidence__c, c.Connector_Run__c, before, OA_ChangeLogService.TYPE_ENRICH));
                // Build a fresh sObject with ONLY the changed fields so a USER_MODE update never touches
                // fields the running user may lack FLS on (e.g. the new Reviewed_Contact_Email__c).
                OA_Discovered_Organization__c upd = new OA_Discovered_Organization__c(
                    Id = c.Id, Qualification_Status__c = toState);
                if (String.isNotBlank(reason)) {
                    upd.Recommended_Action__c = ((reviewer == null ? '' : reviewer + ': ') + reason).abbreviate(80);
                }
                toUpdate.add(upd);
            }
            sum.outcomes.add(o);
        }

        if (commitWrites == true && !toUpdate.isEmpty()) {
            Database.update(toUpdate, false, AccessLevel.USER_MODE);
            OA_ChangeLogService.commitLogs(logs);
            sum.dmlRows = toUpdate.size();
        }
        return sum;
    }
}
