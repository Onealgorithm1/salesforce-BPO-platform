/**
 * OA_EnrichmentOrchestrator — the production execution layer for Lead Enrichment Platform v1.0.
 *
 * Batchable (+ a Queueable sibling, OA_EnrichmentQueueable) that drives enrichment over a scope of
 * Leads by calling the EXISTING platform: OA_ConnectorRunner (fetch/parse/qualify + telemetry) →
 * OA_ProposalAdapter (existing per-source mapper) → OA_EnrichmentWriter (per-field policy + audit).
 * It adds NO enrichment logic of its own and bypasses NO engine.
 *
 * Operational guarantees:
 *  - configurable batch size (scope chunking) and target scope (SOQL) — governor-safe per chunk
 *  - transient-failure retry (per record, capped)
 *  - stop-on-unrecoverable (a connector Status = Failed aborts the run)
 *  - telemetry captured to OA_Connector_Run__c (existing fields only)
 *  - SAFE BY DEFAULT: commitWrites defaults to false (preview/dry-run, no Lead DML) — the caller
 *    must explicitly opt into commit. Nothing here schedules itself.
 */
public with sharing class OA_EnrichmentOrchestrator
        implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    public static final Integer DEFAULT_BATCH_SIZE = 20;
    public static final String ORIGIN = 'OA_EnrichmentOrchestrator';

    // ---- configuration (per run) ----
    public String source;         // connector source key (e.g. 'SAM'); matches the registry
    public String ruleset;        // optional ICP ruleset for qualification (nullable)
    public String scopeQuery;     // optional SOQL returning target Leads; null -> defaultScope()
    public Boolean commitWrites;  // false (default) = preview only, no Lead DML
    public Integer maxRetries;    // transient retry attempts per record
    public String runId;

    // ---- stateful roll-up ----
    private Metrics totals = new Metrics();
    private Datetime startedAt;

    public OA_EnrichmentOrchestrator(String source, String ruleset, String scopeQuery, Boolean commitWrites) {
        this.source = source;
        this.ruleset = ruleset;
        this.scopeQuery = scopeQuery;
        this.commitWrites = (commitWrites == true);
        this.maxRetries = 1;
        this.runId = ('ORCH-' + source + '-' + String.valueOf(Datetime.now().getTime())).abbreviate(80);
    }

    // ---------------- Batchable ----------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.startedAt = Datetime.now();
        return Database.getQueryLocator(String.isNotBlank(scopeQuery) ? scopeQuery : defaultScope());
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (totals.aborted) { return; }           // stop-on-unrecoverable: skip remaining chunks
        List<Lead> leads = (List<Lead>) scope;
        List<OA_Connector_Run__c> telemetry = new List<OA_Connector_Run__c>();
        Metrics m = processScope(leads, source, ruleset, commitWrites, maxRetries, telemetry);
        totals.add(m);
        if (!telemetry.isEmpty()) {
            Database.insert(telemetry, false, AccessLevel.USER_MODE);
        }
    }

    public void finish(Database.BatchableContext bc) {
        Database.insert(
            new List<OA_Connector_Run__c>{ buildSummary(runId, source, startedAt, totals) },
            false, AccessLevel.USER_MODE);
    }

    // ---------------- shared execution core (reused by the Queueable) ----------------

    /** Roll-up counters for one scope. */
    public class Metrics {
        public Integer leadsProcessed = 0;
        public Integer recordsEnriched = 0;   // fields written (in-memory count; DML gated by commit)
        public Integer conflicts = 0;
        public Integer qualified = 0;
        public Integer exceptionsRaised = 0;
        public Integer httpErrors = 0;
        public Integer retriesUsed = 0;
        public Boolean aborted = false;
        public Boolean committed = false;
        public void add(Metrics o) {
            leadsProcessed += o.leadsProcessed;   recordsEnriched += o.recordsEnriched;
            conflicts += o.conflicts;             qualified += o.qualified;
            exceptionsRaised += o.exceptionsRaised; httpErrors += o.httpErrors;
            retriesUsed += o.retriesUsed;
            aborted = aborted || o.aborted;       committed = committed || o.committed;
        }
    }

    /** Test hook: force a runner outcome so the map/write/telemetry path is covered without callouts. */
    @TestVisible private static OA_ConnectorRunner.RunOutcome runOutcomeOverride;

    /**
     * Process a scope of Leads through the existing platform. No DML to Leads unless commit = true.
     * telemetryOut (nullable) collects the per-run OA_Connector_Run__c records for the caller to persist.
     */
    public static Metrics processScope(List<Lead> leads, String source, String ruleset,
                                       Boolean doCommit, Integer maxRetries,
                                       List<OA_Connector_Run__c> telemetryOut) {
        Metrics m = new Metrics();
        m.committed = (doCommit == true);
        if (leads == null || leads.isEmpty()) { return m; }
        OA_ConnectorRunner runner = new OA_ConnectorRunner();

        // ---- Phase 1: ALL callouts first (no Lead DML) ----
        // The writer's commit path performs DML; interleaving fetch->enrich per Lead used to make the
        // second Lead's callout throw "uncommitted work pending". Fetch every Lead's connector result
        // BEFORE any write, mirroring the proven manual callout-before-DML pattern.
        List<Lead> fetchedLeads = new List<Lead>();
        List<OA_ConnectorRunner.RunOutcome> outcomes = new List<OA_ConnectorRunner.RunOutcome>();
        for (Lead ld : leads) {
            String input = deriveInput(ld);
            if (String.isBlank(input)) { continue; }
            OA_ConnectorRunner.RunOutcome o = runWithRetry(runner, source, input, ruleset, maxRetries, m);
            m.leadsProcessed++;
            if (o == null) { continue; }
            m.httpErrors += nz(o.httpErrors);
            m.qualified  += nz(o.recordsQualified);
            fetchedLeads.add(ld);
            outcomes.add(o);
            if (OA_ConnectorRunner.STATUS_FAILED.equals(o.status)) {
                m.aborted = true;   // unrecoverable — stop fetching further; the write phase still runs
                break;
            }
        }

        // ---- Phase 2: ALL writes after every callout is complete ----
        for (Integer i = 0; i < outcomes.size(); i++) {
            Lead ld = fetchedLeads[i];
            OA_ConnectorRunner.RunOutcome o = outcomes[i];
            Integer enrichedThisLead = 0;
            if (o.organizations != null) {
                for (OA_CanonicalOrg org : o.organizations) {
                    List<OA_EnrichmentWriter.FieldProposal> proposals =
                        OA_ProposalAdapter.toLeadProposals(source, org);
                    if (proposals == null || proposals.isEmpty()) { continue; }
                    OA_EnrichmentWriter.Result wr =
                        OA_EnrichmentWriter.enrich(ld, proposals, null, doCommit == true);
                    m.recordsEnriched += nz(wr.written);
                    enrichedThisLead  += nz(wr.written);
                    m.conflicts       += nz(wr.conflicts);
                    m.exceptionsRaised += (wr.exceptions == null ? 0 : wr.exceptions.size());
                }
            }
            if (telemetryOut != null && o.runRecord != null) {
                o.runRecord.Records_Enriched__c = enrichedThisLead;
                o.runRecord.Initiated_By__c = UserInfo.getUserId();
                telemetryOut.add(o.runRecord);
            }
        }
        return m;
    }

    /** Build the run-level summary telemetry record (existing OA_Connector_Run__c fields only). */
    public static OA_Connector_Run__c buildSummary(String runId, String source, Datetime startedAt, Metrics m) {
        return new OA_Connector_Run__c(
            Run_ID__c = (String.isBlank(runId) ? ('ORCH-' + source) : runId).abbreviate(80),
            Source_System__c = source,
            Started__c = startedAt,
            Ended__c = Datetime.now(),
            Status__c = m.aborted ? OA_ConnectorRunner.STATUS_FAILED
                        : (m.exceptionsRaised > 0 ? OA_ConnectorRunner.STATUS_PARTIAL
                                                  : OA_ConnectorRunner.STATUS_SUCCEEDED),
            Requested__c = m.leadsProcessed,
            Records_Enriched__c = m.recordsEnriched,
            Exceptions_Raised__c = m.exceptionsRaised,
            HTTP_Errors__c = m.httpErrors,
            Initiated_By__c = UserInfo.getUserId(),
            Messages__c = ('origin=' + ORIGIN + '; leads=' + m.leadsProcessed + '; enriched=' + m.recordsEnriched
                + '; conflicts=' + m.conflicts + '; qualified=' + m.qualified
                + '; retries=' + m.retriesUsed + '; commit=' + m.committed
                + (m.aborted ? '; ABORTED' : '')).abbreviate(32768)
        );
    }

    /** Convenience: kick off the batch. Returns the AsyncApexJob Id. Does NOT schedule anything. */
    public static Id enqueueBatch(String source, String ruleset, String scopeQuery,
                                  Boolean commitWrites, Integer batchSize) {
        Integer bs = (batchSize == null || batchSize <= 0) ? DEFAULT_BATCH_SIZE : batchSize;
        return Database.executeBatch(
            new OA_EnrichmentOrchestrator(source, ruleset, scopeQuery, commitWrites), bs);
    }

    // ---------------- helpers ----------------

    private static OA_ConnectorRunner.RunOutcome runWithRetry(OA_ConnectorRunner runner, String source,
            String input, String ruleset, Integer maxRetries, Metrics m) {
        if (Test.isRunningTest() && runOutcomeOverride != null) { return runOutcomeOverride; }
        Integer cap = (maxRetries == null || maxRetries < 0) ? 0 : maxRetries;
        OA_ConnectorRunner.RunOutcome o = runner.run(source, input, ruleset);
        Integer attempt = 0;
        while (attempt < cap) {
            Boolean transientFail =
                OA_ConnectorRunner.STATUS_PARTIAL.equals(o.status) && nz(o.httpErrors) > 0;
            if (!transientFail) { return o; }
            attempt++;
            m.retriesUsed++;
            o = runner.run(source, input, ruleset);
        }
        return o;
    }

    /** Pick the connector input for a Lead: strongest identifier (UEI) else company name. */
    private static String deriveInput(Lead ld) {
        Object uei = safeGet(ld, 'UEI__c');
        if (uei != null && String.isNotBlank(String.valueOf(uei))) { return String.valueOf(uei); }
        String company = (String) safeGet(ld, 'Company');
        return String.isNotBlank(company) ? company : null;
    }

    private static Object safeGet(SObject r, String field) {
        try { return r.get(field); } catch (Exception e) { return null; }
    }

    private static Integer nz(Integer i) { return i == null ? 0 : i; }

    private static String defaultScope() {
        return 'SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead '
             + 'WHERE UEI__c = null AND Company != null ORDER BY CreatedDate DESC LIMIT 200';
    }
}
