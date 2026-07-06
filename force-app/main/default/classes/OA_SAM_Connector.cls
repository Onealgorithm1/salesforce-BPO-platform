/**
 * OA_SAM_Connector — the SAM.gov Entity connector on the Lead Enrichment platform (dormant).
 *
 * Orchestrates request -> send -> parse into canonical organizations, reading its endpoint /
 * Named Credential from OA_Connector_Registry__mdt (metadata-driven; no hardcoded registration).
 * Wires ONLY SAM-specific classes (OA_SAM_Request / OA_SAM_ResponseParser); it does not modify
 * or contain any platform (policy / qualification / writer) logic.
 *
 * DORMANT: nothing schedules or invokes it; live callouts are gated behind External Credential
 * principal access which is granted separately. In tests the send path is mocked; no live call.
 *
 * RAW PAYLOAD: disabled by default (debugStoreRawPayload = false). It is populated only when a
 * debug configuration turns it on and is NEVER enabled automatically.
 */
public with sharing class OA_SAM_Connector {

    public static final String SOURCE_KEY = 'SAM';

    /** Debug-only raw payload capture for troubleshooting. OFF by default; never auto-enabled. */
    @TestVisible
    private static Boolean debugStoreRawPayload = false;

    /** Test injection of the registry config (avoids depending on deployed CMDT records). */
    @TestVisible
    private static List<OA_Connector_Registry__mdt> registryOverride;

    public class Result {
        public String sourceKey = SOURCE_KEY;
        public Integer requested = 0;
        public Integer parsed = 0;
        public Integer httpErrors = 0;
        public Integer parseErrors = 0;
        public Integer lastStatus;
        public List<OA_CanonicalOrg> organizations = new List<OA_CanonicalOrg>();
        public List<String> messages = new List<String>();
        public String rawPayload;   // populated only when debugStoreRawPayload = true
    }

    /** Fetch + parse one entity (by UEI or legal name) into canonical organizations. */
    public Result fetch(String input) {
        Result res = new Result();
        res.requested = 1;
        OA_Connector_Registry__mdt cfg = config();
        HttpRequest req = new OA_SAM_Request().build(input, cfg);

        try {
            HttpResponse http = new Http().send(req);
            res.lastStatus = http.getStatusCode();
            String body = http.getBody();
            if (debugStoreRawPayload) {
                res.rawPayload = body;
            }
            if (res.lastStatus < 200 || res.lastStatus >= 300) {
                res.httpErrors++;
                res.messages.add('HTTP ' + res.lastStatus + ' from SAM (endpoint retained; no data mapped).');
                return res;
            }
            List<OA_CanonicalOrg> orgs = new OA_SAM_ResponseParser().parse(body);
            res.parsed = orgs.size();
            res.organizations = orgs;
        } catch (OA_SAM_ResponseParser.ParseException pe) {
            res.parseErrors++;
            res.messages.add('Parse error: ' + pe.getMessage());
        } catch (Exception e) {
            // Callout/credential/other failure — recorded, never swallowed.
            res.httpErrors++;
            res.messages.add(e.getTypeName() + ': ' + e.getMessage());
        }
        return res;
    }

    /** SAM registry declaration (metadata-driven). Injected in tests; queried at runtime. */
    private OA_Connector_Registry__mdt config() {
        if (registryOverride != null) {
            for (OA_Connector_Registry__mdt r : registryOverride) {
                if (SOURCE_KEY.equalsIgnoreCase(r.Source_System__c)) {
                    return r;
                }
            }
            return null;
        }
        List<OA_Connector_Registry__mdt> rs = [
            SELECT Source_System__c, Named_Credential__c, Endpoint_Path__c, Connector_Class__c,
                   Parser_Class__c, Mapper_Class__c, Enabled__c, Status__c
            FROM OA_Connector_Registry__mdt
            WHERE Source_System__c = :SOURCE_KEY
            LIMIT 1
        ];
        return rs.isEmpty() ? null : rs[0];
    }
}
