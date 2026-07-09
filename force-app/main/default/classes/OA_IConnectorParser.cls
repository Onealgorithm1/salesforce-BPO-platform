/**
 * OA_IConnectorParser — turns a raw response body into normalized rows.
 *
 * Part of the Connector SDK foundation (Sprint 1B). The concrete implementation
 * owns all source-specific JSON/response shape knowledge and returns a list of
 * generic OA_ConnectorRow objects. It should throw OA_ConnectorException on a
 * body it cannot parse, so the engine can record a parse-error outcome.
 */
public interface OA_IConnectorParser {

    /**
     * Parse a successful (2xx) response body into normalized rows.
     * @param body the raw HTTP response body
     * @return normalized rows (empty list if the source returned no results)
     */
    List<OA_ConnectorRow> parse(String body);
}