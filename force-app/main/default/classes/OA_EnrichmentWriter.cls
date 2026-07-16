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

    /** One target record + the proposals to evaluate against it (one connector match). */
    public class WorkItem {
        public SObject target;
        public List<FieldProposal> proposals;
        public WorkItem(SObject target, List<FieldProposal> proposals) {
            this.target = target;
            this.proposals = proposals;
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
     * Thin wrapper over {@link #enrichAll} — preserved for existing callers/tests.
     * @param commitWrites false = preview (NO DML); true = apply writes with FLS + audit.
     */
    public static Result enrich(SObject target, List<FieldProposal> proposals, Id runId, Boolean commitWrites) {
        if (target == null || proposals == null) {
            Result r = new Result();
            r.messages.add('No target or proposals supplied.');
            return r;
        }
        return enrichAll(new List<WorkItem>{ new WorkItem(target, proposals) }, runId, commitWrites);
    }

    /** Org-level kill switch for committed writes. Default (no setting record) = disabled. */
    private static Boolean isCommitEnabled() {
        OA_Enrichment_Settings__c cfg = OA_Enrichment_Settings__c.getOrgDefaults();
        return cfg != null && cfg.Writer_Commit_Enabled__c == true;
    }

    /**
     * Evaluate (and optionally commit) enrichment for MANY (target, proposals) work items,
     * committing with BULK DML: exactly one Lead update + one change-log insert + one exception
     * insert for the whole scope, regardless of how many Leads or connector matches are supplied.
     *
     * This is the scalability-safe write path: the per-field policy/audit/exception logic is
     * identical to the single-record path; only the DML is deferred and batched so DML-statement
     * consumption is O(1) instead of O(Leads x matches). A target that appears in several work items
     * (one per connector match) is written in-memory across items and updated once — so FillEmptyOnly
     * still fills from the first match and routes later differing matches to the conflict queue.
     */
    public static Result enrichAll(List<WorkItem> items, Id runId, Boolean commitWrites) {
        Result r = new Result();
        if (items == null || items.isEmpty()) { return r; }

        // Kill switch (2026-07-16): commitWrites=true is inert unless the org-level
        // OA_Enrichment_Settings__c.Writer_Commit_Enabled__c flag is explicitly set.
        // Closes the "ungated Path B write" tech debt: an anonymous-Apex commit call
        // can no longer write Leads without a deliberate, auditable config change.
        if (commitWrites == true && !isCommitEnabled()) {
            commitWrites = false;
            r.messages.add('COMMIT SUPPRESSED: OA_Enrichment_Settings__c.Writer_Commit_Enabled__c is not enabled; ran as preview.');
        }

        // ---- Evaluate every item in memory (NO DML). Track the distinct targets that got a write. ----
        Map<Id, SObject> targetsToUpdate = new Map<Id, SObject>();
        for (WorkItem wi : items) {
            if (wi == null || wi.target == null || wi.proposals == null) { continue; }
            SObject target = wi.target;
            String obj = target.getSObjectType().getDescribe().getName();
            Id targetId = (Id) target.get('Id');

            for (FieldProposal fp : wi.proposals) {
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
                    r.written++;
                    targetsToUpdate.put(targetId, target);
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
        }

        // ---- Single bulk commit for the whole scope ----
        if (commitWrites == true) {
            r.committed = true;
            Set<String> failedIds = new Set<String>();
            List<SObject> toUpdate = targetsToUpdate.values();
            if (!toUpdate.isEmpty()) {
                // Sprint 25 Defect #2 (preserved, now per-target within one bulk call): inspect every
                // SaveResult. A failed CRM write must NOT leave misleading audit — discard that target's
                // change logs, route an exception, and reflect that nothing persisted for it.
                List<Database.SaveResult> srs =
                    Database.update(toUpdate, false, AccessLevel.USER_MODE);
                for (Integer i = 0; i < toUpdate.size(); i++) {
                    if (srs[i].isSuccess()) { continue; }
                    Id tid = (Id) toUpdate[i].get('Id');
                    failedIds.add(String.valueOf(tid));
                    String obj = toUpdate[i].getSObjectType().getDescribe().getName();
                    List<String> errs = new List<String>();
                    for (Database.Error e : srs[i].getErrors()) {
                        String flds = (e.getFields() != null && !e.getFields().isEmpty())
                            ? ' [' + String.join(e.getFields(), ',') + ']' : '';
                        errs.add(e.getStatusCode() + ': ' + e.getMessage() + flds);
                    }
                    String reason = String.join(errs, ' | ');
                    r.exceptions.add(OA_ExceptionRoutingService.policyException(
                        obj, tid, null, null,
                        'Enrichment write failed; no fields persisted: ' + reason, runId));
                    r.messages.add('Update failed — change logs discarded: ' + reason);
                }
            }
            if (!failedIds.isEmpty()) {
                List<OA_Enrichment_Change_Log__c> kept = new List<OA_Enrichment_Change_Log__c>();
                for (OA_Enrichment_Change_Log__c cl : r.changeLogs) {
                    if (failedIds.contains(cl.Target_Record_Id__c)) {
                        r.written--;                 // nothing actually persisted for this target
                        r.skipped++;
                    } else {
                        kept.add(cl);
                    }
                }
                r.changeLogs = kept;                 // do not persist misleading audit
            }
            OA_ChangeLogService.commitLogs(r.changeLogs);              // one insert
            OA_ExceptionRoutingService.commitExceptions(r.exceptions); // one insert
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