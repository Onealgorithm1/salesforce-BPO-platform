/**
 * OA_IConnectorMapper — maps one normalized row to a staging SObject.
 *
 * Part of the Connector SDK foundation (Sprint 1B). The concrete implementation
 * builds the staging record IN MEMORY only. The SDK foundation performs NO DML —
 * persistence (idempotent upsert into the staging object) is a Sprint 1C concern.
 */
public interface OA_IConnectorMapper {

    /**
     * Map one normalized row to an unsaved staging SObject.
     * @param row the normalized row
     * @param ctx run-scoped context (carries run id, endpoint, status, query date)
     * @return an in-memory SObject (NOT inserted by the SDK foundation)
     */
    SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx);
}
