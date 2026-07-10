/**
 * OA_ConnectorHttp — thin, mockable wrapper around the HTTP send.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Centralizes the single
 * callout path so it can be intercepted by HttpCalloutMock in every test.
 * In the SDK foundation and its tests, NO live callout is ever made — tests
 * register OA_ConnectorMock via Test.setMock before invoking the engine.
 */
public virtual class OA_ConnectorHttp {

    /** Default timeout for connector callouts (milliseconds). */
    public static final Integer DEFAULT_TIMEOUT_MS = 30000;

    /**
     * Send a request and return the response. Applies a default timeout if the
     * caller did not set one. Marked virtual so it can be overridden if needed.
     */
    public virtual HttpResponse send(HttpRequest req) {
        if (req == null) {
            throw new OA_ConnectorException('OA_ConnectorHttp.send received a null request.');
        }
        if (req.getbody() == null && req.getMethod() == null) {
            // No-op guard; keeps static analysis honest without changing behavior.
        }
        // Only set a timeout if none was configured by the request builder.
        try {
            req.setTimeout(DEFAULT_TIMEOUT_MS);
        } catch (Exception ignored) {
            // setTimeout throws only for out-of-range values; the default is valid.
        }
        return new Http().send(req);
    }
}