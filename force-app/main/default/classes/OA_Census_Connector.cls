/**
 * OA_Census_Connector — Census connector on the generic framework (dormant).
 * Implements OA_IEnrichmentConnector; dispatched by OA_ConnectorRunner. Public API. Produces
 * CONTEXT canonical records (no identity). Raw payload OFF by default. Send path mocked in tests.
 */
public with sharing class OA_Census_Connector implements OA_IEnrichmentConnector {

    public static final String SOURCE_KEY = 'Census';

    @TestVisible
    private static Boolean debugStoreRawPayload = false;

    public String sourceKey() { return SOURCE_KEY; }

    public OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg) {
        OA_ConnectorResult res = new OA_ConnectorResult(SOURCE_KEY);
        res.requested = 1;
        HttpRequest req = new OA_Census_Request().build(input, cfg);
        try {
            HttpResponse http = new Http().send(req);
            res.lastStatus = http.getStatusCode();
            String body = http.getBody();
            if (debugStoreRawPayload) { res.rawPayload = body; }
            if (res.lastStatus < 200 || res.lastStatus >= 300) {
                res.httpErrors++;
                res.messages.add('HTTP ' + res.lastStatus + ' from Census.');
                return res;
            }
            res.organizations = new OA_Census_ResponseParser().parse(body);
            res.parsed = res.organizations.size();
        } catch (OA_Census_ResponseParser.ParseException pe) {
            res.parseErrors++;
            res.messages.add('Parse error: ' + pe.getMessage());
        } catch (Exception e) {
            res.httpErrors++;
            res.messages.add(e.getTypeName() + ': ' + e.getMessage());
        }
        return res;
    }
}
