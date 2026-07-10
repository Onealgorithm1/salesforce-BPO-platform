/**
 * OA_ConnectorMock — fixture-driven HttpCalloutMock for connector tests.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Register it via
 * Test.setMock(HttpCalloutMock.class, ...) so the engine's send path returns a
 * canned status + body. Guarantees NO live callout is ever made in tests.
 *
 * Test-only (@isTest) — not shipped as production code and needs no coverage.
 */
@isTest
public class OA_ConnectorMock implements HttpCalloutMock {

    private final Integer statusCode;
    private final String body;

    /** The most recent request the engine sent — available for assertions. */
    public HttpRequest lastRequest { get; private set; }

    public OA_ConnectorMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
        this.lastRequest = req;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setHeader('Content-Type', 'application/json');
        if (body != null) {
            res.setBody(body);
        }
        return res;
    }
}