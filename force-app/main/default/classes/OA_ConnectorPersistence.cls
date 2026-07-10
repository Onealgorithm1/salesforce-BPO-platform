/**
 * OA_ConnectorPersistence — idempotent staging writer for the Connector SDK.
 *
 * Sprint 1C-2: the ONE auditable place that performs DML for enrichment. Takes the
 * in-memory staging records produced by the engine/mapper and upserts them on a
 * caller-supplied External Id field, so re-running an enrichment run UPDATES rather
 * than DUPLICATES rows (idempotency).
 *
 * Generic — contains NO source-specific logic. It does not read or write Lead
 * records, and it does not change Review_Status__c (the human review gate set by
 * the mapper is preserved as-is).
 */
public with sharing class OA_ConnectorPersistence {

    public class PersistResult {
        public Integer requested = 0;   // records handed in
        public Integer upserted  = 0;   // successful upserts
        public Integer failed    = 0;   // failed rows (allOrNone = false)
        public List<Database.UpsertResult> results = new List<Database.UpsertResult>();
    }

    /**
     * Idempotently upsert staging records on an External Id field.
     * @param records          in-memory staging records (from the mapper); null/empty = no-op
     * @param externalIdField  the External Id field to match on (e.g. Dedupe_Key__c)
     * @return per-run counts + raw results
     */
    public PersistResult upsertStaging(List<SObject> records, Schema.SObjectField externalIdField) {
        PersistResult out = new PersistResult();
        if (records == null || records.isEmpty()) {
            return out; // safe no-op
        }
        if (externalIdField == null) {
            throw new OA_ConnectorException(
                'OA_ConnectorPersistence.upsertStaging requires an External Id field for idempotent upsert.');
        }

        out.requested = records.size();
        out.results = Database.upsert(records, externalIdField, false); // allOrNone = false
        for (Database.UpsertResult r : out.results) {
            if (r.isSuccess()) { out.upserted++; } else { out.failed++; }
        }
        return out;
    }
}