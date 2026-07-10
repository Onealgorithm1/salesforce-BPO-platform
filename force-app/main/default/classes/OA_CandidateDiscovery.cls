/**
 * OA_CandidateDiscovery — the single, reusable execution driver for Candidate Discovery.
 *
 * Runs ANY approved acquisition connector (any class implementing OA_IEnrichmentConnector) through one common path:
 *   registry lookup (by connector name) -> instantiate -> fetch -> cap to maxResults -> OA_CandidateDiscoveryService.
 * Contains NO connector-specific branching: every source is resolved from OA_Connector_Registry__mdt and executed via
 * the shared interface. Reuses OA_ConnectorResult (telemetry), OA_CandidateDiscoveryService (persist + duplicate
 * detection), OA_Discovered_Organization__c (staging) — no new object, no scheduler, no Lead/Account writes.
 *
 * Preview mode (commit == false) performs ZERO DML. Commit mode inserts new, non-duplicate Candidates only.
 */
public with sharing class OA_CandidateDiscovery {

    public class DiscoveryException extends Exception {}

    public class Result {
        public String connectorName;
        public Integer requested = 0;
        public Integer parsed = 0;
        public Integer httpErrors = 0;
        public Integer lastStatus;
        public Integer capped = 0;                 // orgs passed to the service after maxResults cap
        public List<String> messages = new List<String>();
        public OA_CandidateDiscoveryService.Outcome candidates;
    }

    /**
     * Public entry point. Resolves the connector by its registry DeveloperName, executes it, and routes the
     * canonical organizations through duplicate detection + Candidate persistence.
     * @param connectorName registry DeveloperName (e.g. 'USASpending', 'SAM')
     * @param input         source query/search input passed to the connector
     * @param commitWrites   false = preview (0 DML); true = insert Candidates
     * @param maxResults     cap on organizations processed (null = all)
     */
    public static Result run(String connectorName, String input, Boolean commitWrites, Integer maxResults) {
        OA_Connector_Registry__mdt cfg = lookup(connectorName);
        OA_IEnrichmentConnector conn = instantiate(cfg);
        return run(conn, cfg, input, commitWrites, maxResults);
    }

    /**
     * Execution core (connector injected). @TestVisible so the generic path can be unit-tested with a fake
     * connector and no live callout. Identical behavior for every connector — no source-specific logic.
     */
    @TestVisible
    private static Result run(OA_IEnrichmentConnector conn, OA_Connector_Registry__mdt cfg, String input, Boolean commitWrites, Integer maxResults) {
        if (conn == null) { throw new DiscoveryException('connector is null'); }
        Result r = new Result();
        r.connectorName = (cfg != null) ? cfg.DeveloperName : conn.sourceKey();

        OA_ConnectorResult cr = conn.fetch(input, cfg);   // may be a live callout at runtime; mocked/faked in tests
        if (cr == null) { throw new DiscoveryException('connector returned null result'); }
        r.requested = cr.requested;
        r.parsed = cr.parsed;
        r.httpErrors = cr.httpErrors;
        r.lastStatus = cr.lastStatus;
        if (cr.messages != null) { r.messages = cr.messages; }

        List<OA_CanonicalOrg> orgs = (cr.organizations == null) ? new List<OA_CanonicalOrg>() : cr.organizations;
        Integer cap = (maxResults == null || maxResults < 0) ? orgs.size() : maxResults;
        List<OA_CanonicalOrg> scoped = new List<OA_CanonicalOrg>();
        for (Integer i = 0; i < orgs.size() && i < cap; i++) { scoped.add(orgs[i]); }
        r.capped = scoped.size();

        // Preview (commit=false) does zero DML; commit inserts only OA_Discovered_Organization__c Candidates.
        r.candidates = OA_CandidateDiscoveryService.persist(scoped, commitWrites == true);
        return r;
    }

    private static OA_Connector_Registry__mdt lookup(String connectorName) {
        if (String.isBlank(connectorName)) { throw new DiscoveryException('connectorName is required'); }
        List<OA_Connector_Registry__mdt> rows = [
            SELECT DeveloperName, Connector_Class__c, Named_Credential__c, Endpoint_Path__c, Enabled__c
            FROM OA_Connector_Registry__mdt WHERE DeveloperName = :connectorName LIMIT 1 ];
        if (rows.isEmpty()) { throw new DiscoveryException('No connector registry entry named: ' + connectorName); }
        return rows[0];
    }

    private static OA_IEnrichmentConnector instantiate(OA_Connector_Registry__mdt cfg) {
        if (cfg == null || String.isBlank(cfg.Connector_Class__c)) { throw new DiscoveryException('registry row missing Connector_Class__c'); }
        Type t = Type.forName(cfg.Connector_Class__c);
        if (t == null) { throw new DiscoveryException('Connector class not found: ' + cfg.Connector_Class__c); }
        Object o = t.newInstance();
        if (!(o instanceof OA_IEnrichmentConnector)) {
            throw new DiscoveryException(cfg.Connector_Class__c + ' does not implement OA_IEnrichmentConnector');
        }
        return (OA_IEnrichmentConnector) o;
    }
}