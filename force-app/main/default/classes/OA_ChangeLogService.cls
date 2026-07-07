/**
 * OA_ChangeLogService — before/after audit logging + rollback snapshots.
 *
 * Builds OA_Enrichment_Change_Log__c rows (in memory) capturing old and new values plus a
 * JSON before-snapshot, so every field change made by the enrichment writer is auditable and
 * reversible. Persisting the logs is a deliberate, caller-controlled step (no DML unless
 * commitLogs is called) — the writer stays dormant/preview-safe by default.
 */
public with sharing class OA_ChangeLogService {

    public static final String TYPE_ENRICH   = 'Enrich';
    public static final String TYPE_CREATE    = 'Create';
    public static final String TYPE_ROLLBACK  = 'Rollback';

    /** JSON snapshot of the given fields on a record (for rollback). */
    public static String snapshot(SObject record, Set<String> fields) {
        Map<String, Object> snap = new Map<String, Object>();
        if (record != null && fields != null) {
            for (String f : fields) {
                snap.put(f, safeGet(record, f));
            }
        }
        return JSON.serialize(snap);
    }

    /** Build (do not insert) a change-log row for one field change. */
    public static OA_Enrichment_Change_Log__c buildLog(
            String targetObject, Id targetId, String field,
            Object oldValue, Object newValue, String source, String writeMode,
            String confidence, Id runId, String beforeSnapshot, String changeType) {
        return new OA_Enrichment_Change_Log__c(
            Target_Object__c   = abbrev(targetObject, 80),
            Target_Record_Id__c = targetId == null ? null : String.valueOf(targetId),
            Field_API_Name__c  = abbrev(field, 80),
            Old_Value__c       = str(oldValue),
            New_Value__c       = str(newValue),
            Source_System__c   = abbrev(source, 40),
            Write_Mode__c      = abbrev(writeMode, 20),
            Confidence__c      = abbrev(confidence, 10),
            Connector_Run__c   = runId,
            Before_Snapshot__c = beforeSnapshot,
            Change_Type__c     = abbrev(changeType, 20),
            Reversible__c      = String.isNotBlank(beforeSnapshot),
            Changed_At__c      = Datetime.now()
        );
    }

    /**
     * Persist change-log rows. These are internal framework audit records (not a CRM write),
     * so they insert in system mode; the FLS guardrail applies to the CRM write in the writer.
     */
    public static List<Database.SaveResult> commitLogs(List<OA_Enrichment_Change_Log__c> logs) {
        if (logs == null || logs.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        return Database.insert(logs, false);
    }

    /**
     * Rollback: restore each reversible log's Before_Snapshot onto its target record.
     * Explicit, caller-invoked only — never scheduled. Returns the restored records.
     */
    public static List<SObject> rollback(List<OA_Enrichment_Change_Log__c> logs) {
        List<SObject> restored = new List<SObject>();
        if (logs == null) {
            return restored;
        }
        // group snapshots by target record id
        Map<String, Map<String, Object>> byRecord = new Map<String, Map<String, Object>>();
        Map<String, String> objOf = new Map<String, String>();
        for (OA_Enrichment_Change_Log__c log : logs) {
            if (log.Reversible__c != true || String.isBlank(log.Before_Snapshot__c)
                    || String.isBlank(log.Target_Record_Id__c)) {
                continue;
            }
            Map<String, Object> snap = (Map<String, Object>) JSON.deserializeUntyped(log.Before_Snapshot__c);
            // Each change log carries a single-field snapshot; MERGE all of a record's field
            // snapshots so every field is restored (previously this put() overwrote the map,
            // restoring only the last field per record — the multi-field rollback defect).
            Map<String, Object> merged = byRecord.get(log.Target_Record_Id__c);
            if (merged == null) {
                merged = new Map<String, Object>();
                byRecord.put(log.Target_Record_Id__c, merged);
            }
            merged.putAll(snap);
            objOf.put(log.Target_Record_Id__c, log.Target_Object__c);
        }
        for (String recId : byRecord.keySet()) {
            SObjectType t = Id.valueOf(recId).getSObjectType();
            SObject rec = t.newSObject(Id.valueOf(recId));
            Map<String, Object> snap = byRecord.get(recId);
            for (String f : snap.keySet()) {
                rec.put(f, snap.get(f));
            }
            restored.add(rec);
        }
        if (!restored.isEmpty()) {
            Database.update(restored, false, AccessLevel.USER_MODE);
        }
        return restored;
    }

    private static Object safeGet(SObject rec, String field) {
        try {
            return rec.get(field);
        } catch (Exception e) {
            return null;
        }
    }

    private static String str(Object v) {
        return v == null ? null : String.valueOf(v);
    }

    private static String abbrev(String v, Integer len) {
        return v == null ? null : v.abbreviate(len);
    }
}
