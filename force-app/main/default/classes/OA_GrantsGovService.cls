/**
 * OA_GrantsGovService — controlled orchestrator for the Grants.gov opportunity slice.
 *
 * Reuses the certified SDK end-to-end: OA_ConnectorEngine (build->send->parse->map,
 * NO DML), OA_ConnectorPersistence (idempotent staging upsert on Canonical_Key__c),
 * OA_Connector_Run__c (telemetry), OA_ExceptionRoutingService (human-review routing).
 *
 * SAFETY GUARANTEES (Phase 1):
 *   - preview() performs ZERO DML — proposed signals are returned in memory only.
 *   - run(commit=true) writes to STAGING ONLY: OA_Opportunity_Signal__c (upsert),
 *     OA_Connector_Run__c (telemetry), OA_Enrichment_Exception__c (anomalies).
 *   - It NEVER writes to Lead, Account, Contact, Campaign, Opportunity, or any
 *     Lead-Enrichment/ERE/Analytics object. No automation is enabled or scheduled.
 *   - Every signal lands Review_Status__c = 'Pending' (the human gate).
 */
public with sharing class OA_GrantsGovService {

    public static final String SOURCE = 'GrantsGov';
    public static final String CATEGORY = 'Opportunity';
    public static final String TARGET_OBJECT = 'OA_Opportunity_Signal__c';

    /** Outcome of one Grants.gov run (preview or committed). */
    public class Outcome {
        public String runId;
        public Boolean committed = false;
        public Integer requested = 0;
        public Integer parsed = 0;
        public Integer mapped = 0;
        public Integer persisted = 0;
        public Integer httpErrors = 0;
        public Integer parseErrors = 0;
        public Integer exceptions = 0;
        public List<String> messages = new List<String>();
        public List<OA_Opportunity_Signal__c> signals = new List<OA_Opportunity_Signal__c>();
        public OA_Connector_Run__c telemetry;
    }

    /** Preview: fetch + normalize into in-memory signals. NEVER persists (0 DML). */
    public static Outcome preview(List<String> keywords, Map<String, Object> config) {
        return execute(keywords, config, false);
    }

    /** Controlled run: persists to STAGING ONLY when commit = true. */
    public static Outcome run(List<String> keywords, Map<String, Object> config, Boolean commitToStaging) {
        return execute(keywords, config, commitToStaging == true);
    }

    private static Outcome execute(List<String> keywords, Map<String, Object> config, Boolean commitToStaging) {
        Datetime startedAt = Datetime.now();
        String runId = SOURCE + '-' + String.valueOf(startedAt.getTime());

        Map<String, Object> cfg = (config != null) ? config : new Map<String, Object>();
        if (!cfg.containsKey('namedCredential')) { cfg.put('namedCredential', 'OA_GrantsGov'); }
        if (!cfg.containsKey('endpointPath')) { cfg.put('endpointPath', '/v1/api/search2'); }
        OA_ConnectorContext ctx = new OA_ConnectorContext(runId, cfg);

        List<Object> inputs = new List<Object>();
        if (keywords != null) {
            for (String k : keywords) { inputs.add(k); }
        }
        if (inputs.isEmpty()) { inputs.add(''); } // one broad query

        OA_ConnectorRunResult r = new OA_ConnectorEngine().run(new OA_GrantsGovConnector(), ctx, inputs);

        Outcome out = new Outcome();
        out.runId = runId;
        out.requested = r.requested;
        out.parsed = r.parsed;
        out.mapped = r.mapped;
        out.httpErrors = r.httpErrors;
        out.parseErrors = r.parseErrors;
        out.messages = r.messages;
        for (SObject s : r.stagingRecords) {
            out.signals.add((OA_Opportunity_Signal__c) s);
        }

        // Build anomaly exceptions (HTTP / parse failures) for human review.
        List<OA_Enrichment_Exception__c> exceptions = new List<OA_Enrichment_Exception__c>();
        if (r.httpErrors > 0 || r.parseErrors > 0) {
            String details = 'Grants.gov run ' + runId + ': httpErrors=' + r.httpErrors
                + ', parseErrors=' + r.parseErrors + '. '
                + String.join(r.messages, ' | ').abbreviate(500);
            exceptions.add(OA_ExceptionRoutingService.policyException(
                TARGET_OBJECT, null, null, SOURCE, details, null));
        }
        out.exceptions = exceptions.size();

        if (commitToStaging) {
            // STAGING-ONLY writes: idempotent upsert of signals + telemetry + anomalies.
            OA_ConnectorPersistence.PersistResult pr = new OA_ConnectorPersistence()
                .upsertStaging(r.stagingRecords, OA_Opportunity_Signal__c.Canonical_Key__c);
            out.persisted = pr.upserted;
            out.committed = true;
            if (!exceptions.isEmpty()) {
                OA_ExceptionRoutingService.commitExceptions(exceptions);
            }
        }

        OA_Connector_Run__c telemetry = new OA_Connector_Run__c(
            Run_ID__c            = runId,
            Source_System__c     = SOURCE,
            Category__c          = CATEGORY,
            Status__c            = r.isClean() ? 'Succeeded' : 'PartialErrors',
            Requested__c         = r.requested,
            Parsed__c            = r.parsed,
            Mapped__c            = r.mapped,
            Persisted__c         = out.persisted,
            HTTP_Errors__c       = r.httpErrors,
            Parse_Errors__c      = r.parseErrors,
            Exceptions_Raised__c = out.exceptions,
            Endpoint__c          = String.valueOf(ctx.lastEndpoint),
            Started__c           = startedAt,
            Ended__c             = Datetime.now(),
            Initiated_By__c      = UserInfo.getUserId(),
            Messages__c          = String.join(r.messages, '\n').abbreviate(32000)
        );
        // Telemetry is persisted only for a committed run (audit of the write).
        // Preview stays strictly 0-DML.
        if (commitToStaging) {
            insert telemetry;
        }
        out.telemetry = telemetry;
        return out;
    }
}
