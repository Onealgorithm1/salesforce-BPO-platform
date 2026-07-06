/**
 * OA_IEnrichmentConnector — the source-agnostic contract every enrichment connector implements.
 *
 * A connector's ONLY job is: given an input, return canonical organizations (OA_CanonicalOrg)
 * plus lightweight fetch telemetry (OA_ConnectorResult). It exposes NO source-specific concept —
 * the platform (registry, dispatcher, policy/qualification/writer) never needs to know which
 * source it is talking to.
 *
 * Implementations must be default-constructible (a no-arg constructor) so OA_ConnectorRunner can
 * instantiate them dynamically from OA_Connector_Registry__mdt via Type.forName(...).newInstance().
 */
public interface OA_IEnrichmentConnector {

    /** Stable source key (e.g. 'SAM', 'USASpending') — matches OA_Connector_Registry__mdt.Source_System__c. */
    String sourceKey();

    /**
     * Execute one fetch for the given input, using the supplied registry configuration
     * (endpoint path, Named Credential, etc.). Returns canonical organizations + fetch counts.
     * Must NOT throw for expected failures (non-2xx, parse error) — record them on the result.
     *
     * @param input a per-record input (e.g. a UEI or a name); connector-defined semantics
     * @param cfg   the connector's registry record (may be null -> the connector uses its defaults)
     */
    OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg);
}
