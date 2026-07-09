/**
 * OA_IConnectorRequest — builds the outbound HttpRequest for one source.
 *
 * Part of the Connector SDK foundation (Sprint 1B). The concrete implementation
 * sets the endpoint (typically 'callout:<NamedCredential>/...'), method, headers,
 * and body for a given input. The SDK foundation never calls a live endpoint —
 * requests are only ever sent through OA_ConnectorHttp, which is fully mocked in tests.
 */
public interface OA_IConnectorRequest {

    /**
     * Build the request for a single input (e.g. a search term or a Lead).
     * @param ctx   run-scoped context
     * @param input the per-record input (Object, so the SDK stays source-agnostic)
     * @return a fully-formed HttpRequest (not yet sent)
     */
    HttpRequest build(OA_ConnectorContext ctx, Object input);
}