/**
 * OA_SAMOpportunitiesService — controlled orchestrator for the SAM Opportunities slice.
 *
 * Reuses the certified SDK end-to-end: OA_ConnectorEngine (build->send->parse->map,
 * NO DML), OA_ConnectorPersistence (idempotent staging upsert on Canonical_Key__c),
 * OA_Connector_Run__c (telemetry), OA_ExceptionRoutingService (human-review routing).
 * Adds SAM pagination: fetches pages (offset/limit) with ALL callouts BEFORE any DML,
 * capped by maxPages, stopping at the first short page.
 *
 * SAFETY GUARANTEES (Phase 2):
 *   - preview() performs ZERO DML — proposed signals returned in memory only.
 *   - run(commit=true) writes STAGING ONLY: OA_Opportunity_Signal__c (upsert),
 *     OA_Connector_Run__c (telemetry), OA_Enrichment_Exception__c (anomalies).
 *   - NEVER writes Lead/Account/Contact/Campaign/Opportunity or any Lead-Enrichment/
 *     ERE/Analytics object. No automation is enabled or scheduled.
 *   - Every signal lands Review_Status__c='Pending' (the human gate).
 */
public with sharing class OA_SAMOpportunitiesService {

    public static final String SOURCE = 'SAMOpportunities';
    public static final String CATEGORY = 'Opportunity';
    public static final String TARGET_OBJECT = 'OA_Opportunity_Signal__c';
    public static final Integer DEFAULT_LIMIT = 100;
    public static final Integer DEFAULT_MAX_PAGES = 5;

    public class Outcome {
        public String runId;
        public Boolean committed = false;
        public Integer pages = 0;
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

    /** Preview: fetch + paginate + normalize into memory. NEVER persists (0 DML). */
    public static Outcome preview(Map<String, Object> config) {
        return execute(config, false);
    }

    /** Controlled run: persists to STAGING ONLY when commit = true. */
    public static Outcome run(Map<String, Object> config, Boolean commitToStaging) {
        return execute(config, commitToStaging == true);
    }

    private static Outcome execute(Map<String, Object> config, Boolean commitToStaging) {
        Datetime startedAt = Datetime.now();
        String runId = SOURCE + '-' + String.valueOf(startedAt.getTime());

        Map<String, Object> cfg = (config != null) ? config : new Map<String, Object>();
        if (!cfg.containsKey('namedCredential')) { cfg.put('namedCredential', 'OA_SAM_Opportunities'); }
        if (!cfg.containsKey('endpointPath')) { cfg.put('endpointPath', '/opportunities/v2/search'); }
        Integer limitSize = Math.min(intOf(cfg.get('limit'), DEFAULT_LIMIT), 1000);
        Integer maxPages = intOf(cfg.get('maxPages'), DEFAULT_MAX_PAGES);
        cfg.put('limit', limitSize);

        OA_ConnectorContext ctx = new OA_ConnectorContext(runId, cfg);
        OA_ConnectorEngine engine = new OA_ConnectorEngine();
        OA_SAMOpportunities_Connector connector = new OA_SAMOpportunities_Connector();

        Outcome out = new Outcome();
        out.runId = runId;
        List<SObject> allSignals = new List<SObject>();

        // Pagination: ALL callouts happen here, BEFORE any DML (callout-before-DML).
        Integer offset = intOf(cfg.get('offset'), 0);
        for (Integer page = 0; page < maxPages; page++) {
            cfg.put('offset', offset);
            OA_ConnectorRunResult r = engine.run(connector, ctx, new List<Object>{ offset });
            out.pages++;
            out.parsed += r.parsed;
            out.httpErrors += r.httpErrors;
            out.parseErrors += r.parseErrors;
            out.messages.addAll(r.messages);
            allSignals.addAll(r.stagingRecords);

            Integer pageMapped = r.stagingRecords.size();
            // stop on a short page (last page), an error, or empty result
            if (pageMapped < limitSize || r.httpErrors > 0 || r.parseErrors > 0) {
                break;
            }
            offset += limitSize;
        }
        out.mapped = allSignals.size();
        for (SObject s : allSignals) {
            out.signals.add((OA_Opportunity_Signal__c) s);
        }

        // Build anomaly exceptions for human review (HTTP / parse failures).
        List<OA_Enrichment_Exception__c> exceptions = new List<OA_Enrichment_Exception__c>();
        if (out.httpErrors > 0 || out.parseErrors > 0) {
            String details = 'SAM Opportunities run ' + runId + ': httpErrors=' + out.httpErrors
                + ', parseErrors=' + out.parseErrors + '. '
                + String.join(out.messages, ' | ').abbreviate(500);
            exceptions.add(OA_ExceptionRoutingService.policyException(
                TARGET_OBJECT, null, null, SOURCE, details, null));
        }
        out.exceptions = exceptions.size();

        if (commitToStaging) {
            // STAGING-ONLY writes: idempotent upsert + telemetry + anomalies.
            OA_ConnectorPersistence.PersistResult pr = new OA_ConnectorPersistence()
                .upsertStaging(allSignals, OA_Opportunity_Signal__c.Canonical_Key__c);
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
            Status__c            = (out.httpErrors == 0 && out.parseErrors == 0) ? 'Succeeded' : 'PartialErrors',
            Requested__c         = out.pages,
            Parsed__c            = out.parsed,
            Mapped__c            = out.mapped,
            Persisted__c         = out.persisted,
            HTTP_Errors__c       = out.httpErrors,
            Parse_Errors__c      = out.parseErrors,
            Exceptions_Raised__c = out.exceptions,
            Endpoint__c          = String.valueOf(ctx.lastEndpoint),
            Started__c           = startedAt,
            Ended__c             = Datetime.now(),
            Initiated_By__c      = UserInfo.getUserId(),
            Messages__c          = String.join(out.messages, '\n').abbreviate(32000)
        );
        // Telemetry persisted only for a committed run; preview stays strictly 0-DML.
        if (commitToStaging) {
            insert telemetry;
        }
        out.telemetry = telemetry;
        return out;
    }

    private static Integer intOf(Object v, Integer dflt) {
        return v == null ? dflt : Integer.valueOf(String.valueOf(v));
    }
}
