/**
 * OA_EnrichmentWriter — the dormant, metadata-governed enrichment writer.
 *
 * Applies proposed field values to a target SObject ONLY as permitted by the per-field write
 * policy (OA_FieldWritePolicyEngine), producing a before-snapshot + change log for every
 * write and routing conflicts to the exception queue. It is DORMANT: nothing schedules or
 * invokes it; it is callable only by tests or a controlled service call, and it performs NO
 * DML unless the caller explicitly passes commitWrites = true.
 *
 * Safe behaviors only: fill-empty, overwrite (by approved policy), never-write, route-to-
 * exception. No broad production write behavior.
 */
public with sharing class OA_EnrichmentWriter {

    /** One proposed field change from a source. */
    public class FieldProposal {
        public String fieldApiName;
        public Object newValue;
        public String sourceSystem;
        public String confidenceBand;   // HIGH / MEDIUM / LOW
        public FieldProposal(String field, Object newValue, String source, String band) {
            this.fieldApiName = field;
            this.newValue = newValue;
            this.sourceSystem = source;
            this.confidenceBand = band;
        }
    }

    public class Result {
        public Boolean committed = false;
        public Integer proposed = 0;
        public Integer written = 0;
        public Integer skipped = 0;
        public Integer conflicts = 0;
        public Integer noChange = 0;
        public List<OA_Enrichment_Change_Log__c> changeLogs = new List<OA_Enrichment_Change_Log__c>();
        public List<OA_Enrichment_Exception__c> exceptions = new List<OA_Enrichment_Exception__c>();
        public Map<String, String> outcomeByField = new Map<String, String>();
        public List<String> messages = new List<String>();
    }

    /** Preview convenience — never writes. */
    public static Result preview(SObject target, List<FieldProposal> proposals, Id runId) {
        return enrich(target, proposals, runId, false);
    }

    /**
     * Evaluate (and optionally commit) enrichment of one target record.
     * @param commitWrites false = preview (NO DML); true = apply writes with FLS + audit.
     */
    public static Result enrich(SObject target, List<FieldProposal> proposals, Id runId, Boolean commitWrites) {
        Result r = new Result();
        if (target == null || proposals == null) {
            r.messages.add('No target or proposals supplied.');
            return r;
        }
        String obj = target.getSObjectType().getDescribe().getName();
        Id targetId = (Id) target.get('Id');
        Boolean dirty = false;

        for (FieldProposal fp : proposals) {
            r.proposed++;
            Object currentValue = safeGet(target, fp.fieldApiName);
            OA_FieldWritePolicyEngine.Decision d = OA_FieldWritePolicyEngine.evaluate(
                obj, fp.fieldApiName, fp.sourceSystem, fp.confidenceBand, currentValue, fp.newValue);
            r.outcomeByField.put(fp.fieldApiName, d.outcome.name());

            if (d.outcome == OA_FieldWritePolicyEngine.Outcome.WRITE) {
                String snap = OA_ChangeLogService.snapshot(target, new Set<String>{ fp.fieldApiName });
                Boolean applied = safePut(target, fp.fieldApiName, fp.newValue);
                if (!applied) {
                    r.skipped++;
                    r.exceptions.add(OA_ExceptionRoutingService.policyException(
                        obj, targetId, fp.fieldApiName, fp.sourceSystem,
                        'Value could not be assigned to the field (type mismatch).', runId));
                    r.outcomeByField.put(fp.fieldApiName, 'SKIP_TYPE_ERROR');
                    continue;
                }
                dirty = true;
                r.written++;
                r.changeLogs.add(OA_ChangeLogService.buildLog(
                    obj, targetId, fp.fieldApiName, currentValue, fp.newValue, fp.sourceSystem,
                    d.policy != null ? d.policy.Write_Mode__c : null, fp.confidenceBand, runId,
                    snap, OA_ChangeLogService.TYPE_ENRICH));

            } else if (d.outcome == OA_FieldWritePolicyEngine.Outcome.ROUTE_CONFLICT) {
                r.conflicts++;
                r.exceptions.add(OA_ExceptionRoutingService.sourceConflict(
                    obj, targetId, fp.fieldApiName, fp.sourceSystem, fp.confidenceBand,
                    'FillEmptyOnly policy: target already holds a different value ('
                        + String.valueOf(currentValue) + ') than the source proposed ('
                        + String.valueOf(fp.newValue) + ').', runId));

            } else if (d.outcome == OA_FieldWritePolicyEngine.Outcome.NO_CHANGE) {
                r.noChange++;
            } else {
                r.skipped++;
                r.messages.add(fp.fieldApiName + ': ' + d.outcome.name() + ' — ' + d.reason);
            }
        }

        if (commitWrites == true) {
            if (dirty) {
                Database.update(new List<SObject>{ target }, false, AccessLevel.USER_MODE);
            }
            OA_ChangeLogService.commitLogs(r.changeLogs);
            OA_ExceptionRoutingService.commitExceptions(r.exceptions);
            r.committed = true;
        }
        return r;
    }

    private static Object safeGet(SObject rec, String field) {
        try { return rec.get(field); } catch (Exception e) { return null; }
    }

    private static Boolean safePut(SObject rec, String field, Object value) {
        try { rec.put(field, value); return true; } catch (Exception e) { return false; }
    }
}
