/**
 * OA_IConnector — identity + capability contract for one external-data source.
 *
 * Part of the Connector SDK foundation (Sprint 1B). A concrete connector
 * (e.g. OA_USASpendingConnector, added later in Sprint 1C) declares who it is,
 * which Named Credential it will use, and which staging object it targets.
 *
 * The SDK foundation is generic: it references NO source-specific field or object.
 */
public interface OA_IConnector {

    /** Stable key for the source, e.g. 'USASpending', 'Census'. */
    String sourceKey();

    /**
     * The Named Credential callout prefix the connector will use, e.g.
     * 'callout:OA_USASpending'. Returned as data only — the SDK foundation
     * does NOT create, resolve, or authenticate any credential (deferred to 1C).
     */
    String namedCredential();

    /** The staging SObjectType this source persists to (persistence is a 1C concern). */
    Schema.SObjectType stagingType();

    /** Request builder for this source. */
    OA_IConnectorRequest requestBuilder();

    /** Response parser for this source. */
    OA_IConnectorParser parser();

    /** Row→staging mapper for this source. */
    OA_IConnectorMapper mapper();
}
