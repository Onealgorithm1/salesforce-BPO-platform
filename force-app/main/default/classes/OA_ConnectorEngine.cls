/**
 * OA_ConnectorEngine — orchestrates the enrichment lifecycle for any connector.
 *
 * Part of the Connector SDK foundation (Sprint 1B). For each input it:
 *   build request  ->  send (via mockable OA_ConnectorHttp)  ->  parse  ->  map (in memory)
 * and returns an OA_ConnectorRunResult with counts, diagnostics, and the mapped
 * staging records.
 *
 * SAFETY / SCOPE (1B):
 *   - Performs NO DML. Mapped staging records are returned in memory only;
 *     persistence (idempotent upsert) is a Sprint 1C concern.
 *   - Never calls a live endpoint in tests — the send path is intercepted by
 *     HttpCalloutMock (OA_ConnectorMock).
 *   - Source-agnostic: references no USASpending field or object.
 *   - A non-2xx response is RECORDED (not thrown); a parse/map failure is caught
 *     and recorded as a parse error so one bad input never aborts the whole run.
 */
public with sharing class OA_ConnectorEngine {

    private final OA_ConnectorHttp http;

    /** Default engine — uses the standard HTTP wrapper. */
    public OA_ConnectorEngine() {
        this(new OA_ConnectorHttp());
    }

    /** Injectable HTTP wrapper (tests can pass a subclass; the mock still intercepts send). */
    public OA_ConnectorEngine(OA_ConnectorHttp http) {
        this.http = http != null ? http : new OA_ConnectorHttp();
    }

    /**
     * Run the lifecycle for a connector across a list of inputs.
     * @param connector the source connector (must not be null)
     * @param ctx       run-scoped context (must not be null)
     * @param inputs    per-record inputs (null treated as empty)
     * @return an OA_ConnectorRunResult (mapped records are in memory, NOT saved)
     */
    public OA_ConnectorRunResult run(OA_IConnector connector, OA_ConnectorContext ctx, List<Object> inputs) {
        if (connector == null) {
            throw new OA_ConnectorException('OA_ConnectorEngine.run requires a non-null connector.');
        }
        if (ctx == null) {
            throw new OA_ConnectorException('OA_ConnectorEngine.run requires a non-null context.');
        }

        List<Object> work = inputs != null ? inputs : new List<Object>();
        OA_ConnectorRunResult result = new OA_ConnectorRunResult(ctx.runId);
        result.requested = work.size();

        OA_IConnectorRequest requestBuilder = connector.requestBuilder();
        OA_IConnectorParser parser = connector.parser();
        OA_IConnectorMapper mapper = connector.mapper();

        for (Object input : work) {
            try {
                HttpRequest req = requestBuilder.build(ctx, input);
                ctx.lastEndpoint = req != null ? req.getEndpoint() : null;

                HttpResponse res = http.send(req);
                Integer status = res.getStatusCode();
                ctx.lastHttpStatus = status;

                if (status < 200 || status >= 300) {
                    result.httpErrors++;
                    result.addMessage('HTTP ' + status + ' for source ' + connector.sourceKey()
                        + ' (endpoint ' + ctx.lastEndpoint + '); row retained for diagnosis.');
                    continue;
                }

                List<OA_ConnectorRow> rows = parser.parse(res.getBody());
                if (rows == null) {
                    rows = new List<OA_ConnectorRow>();
                }
                result.parsed += rows.size();

                for (OA_ConnectorRow row : rows) {
                    SObject staging = mapper.toStaging(row, ctx);
                    if (staging != null) {
                        result.addStaging(staging); // in-memory only; increments 'mapped'
                    }
                }
            } catch (Exception e) {
                // One bad input must not abort the run — record and continue.
                result.parseErrors++;
                result.addMessage('Parse/map error for source ' + connector.sourceKey()
                    + ': ' + e.getMessage());
            }
        }

        return result;
    }
}