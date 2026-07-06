/**
 * OA_ConnectorRunner — the generic, registry-driven connector dispatcher.
 *
 * Reads OA_Connector_Registry__mdt, resolves the connector class dynamically (Type.forName), and
 * runs the identical lifecycle for EVERY connector:
 *
 *   Initialize -> Execute Request -> Receive Response -> Parse -> Map ->
 *   Return Canonical Organizations -> Invoke existing platform -> Collect metrics -> Complete
 *
 * It knows NOTHING about any specific source (no `if source == 'SAM'`, no switch). Disabled
 * connectors are skipped; unresolvable/unknown connectors fail gracefully (recorded, never thrown).
 * Timing + telemetry are captured on the RunOutcome and rolled into an in-memory OA_Connector_Run__c
 * (persistence uses only existing fields and is opt-in — the runner performs no DML by default).
 */
public with sharing class OA_ConnectorRunner {

    public static final String STATUS_SUCCEEDED = 'Succeeded';
    public static final String STATUS_PARTIAL = 'PartialErrors';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_SKIPPED = 'Skipped';
    public static final String STATUS_UNRESOLVED = 'Unresolved';

    /** Test injection of the registry (avoids depending on deployed CMDT records). */
    @TestVisible
    private static List<OA_Connector_Registry__mdt> registryOverride;

    /** Full telemetry for one connector execution. */
    public class RunOutcome {
        public String sourceKey;
        public String status;
        public Boolean executed = false;
        public Boolean skipped = false;
        public Datetime startedAt;
        public Datetime finishedAt;
        public Long durationMs;
        public Integer requested = 0;
        public Integer recordsProcessed = 0;   // canonical orgs parsed
        public Integer recordsQualified = 0;
        public Integer recordsRejected = 0;
        public Integer exceptions = 0;
        public Integer httpErrors = 0;
        public Integer parseErrors = 0;
        public String connectorVersion;
        public List<OA_CanonicalOrg> organizations = new List<OA_CanonicalOrg>();
        public List<String> messages = new List<String>();
        public OA_Connector_Run__c runRecord;   // in-memory telemetry (not inserted by default)
    }

    /** Run one connector by source key (no qualification). */
    public RunOutcome run(String sourceKey, String input) {
        return run(sourceKey, input, null);
    }

    /**
     * Run one connector by source key, optionally qualifying each canonical org against an ICP
     * ruleset (invokes the existing platform qualification engine — no source-specific logic here).
     */
    public RunOutcome run(String sourceKey, String input, String ruleset) {
        RunOutcome o = new RunOutcome();
        o.sourceKey = sourceKey;

        // --- Initialize ---
        OA_Connector_Registry__mdt cfg = config(sourceKey);
        if (cfg == null) {
            o.status = STATUS_UNRESOLVED;
            o.messages.add('No registry entry for source: ' + sourceKey);
            return finalize(o, null);
        }
        if (cfg.Enabled__c != true) {
            o.skipped = true;
            o.status = STATUS_SKIPPED;
            o.messages.add('Connector disabled in registry: ' + sourceKey);
            return finalize(o, cfg);
        }
        o.connectorVersion = cfg.Version__c;

        OA_IEnrichmentConnector connector = resolve(cfg, o);
        if (connector == null) {
            o.status = STATUS_UNRESOLVED;
            return finalize(o, cfg);
        }

        // --- Execute -> Receive -> Parse -> Map -> Return canonical ---
        o.startedAt = Datetime.now();
        OA_ConnectorResult res;
        try {
            res = connector.fetch(input, cfg);
        } catch (Exception e) {
            o.exceptions++;
            o.messages.add('Connector threw: ' + e.getTypeName() + ': ' + e.getMessage());
        }
        o.finishedAt = Datetime.now();
        o.durationMs = o.finishedAt.getTime() - o.startedAt.getTime();

        if (res != null) {
            o.requested = res.requested;
            o.recordsProcessed = res.parsed;
            o.httpErrors = res.httpErrors;
            o.parseErrors = res.parseErrors;
            o.organizations = res.organizations != null ? res.organizations : new List<OA_CanonicalOrg>();
            if (res.messages != null) { o.messages.addAll(res.messages); }
        }
        o.executed = true;

        // --- Invoke existing platform (qualification) — generic, uses the platform engine ---
        if (String.isNotBlank(ruleset)) {
            for (OA_CanonicalOrg org : o.organizations) {
                OA_DiscoveryQualificationEngine.Recommendation rec =
                    OA_DiscoveryQualificationEngine.evaluate(org, ruleset);
                if (OA_DiscoveryQualificationEngine.STATUS_QUALIFIED.equals(rec.qualificationStatus)) {
                    o.recordsQualified++;
                } else {
                    o.recordsRejected++;
                }
            }
        }

        // --- Complete ---
        Boolean clean = (o.httpErrors == 0 && o.parseErrors == 0 && o.exceptions == 0);
        o.status = clean ? STATUS_SUCCEEDED : STATUS_PARTIAL;
        return finalize(o, cfg);
    }

    /** Run every ENABLED connector in the registry against the same input. */
    public List<RunOutcome> runAll(String input, String ruleset) {
        List<RunOutcome> outcomes = new List<RunOutcome>();
        for (OA_Connector_Registry__mdt cfg : registry()) {
            if (cfg.Enabled__c == true && String.isNotBlank(cfg.Source_System__c)) {
                outcomes.add(run(cfg.Source_System__c, input, ruleset));
            }
        }
        return outcomes;
    }

    /** Dynamic resolution from metadata — the whole point: no hardcoded connector mapping. */
    @TestVisible
    private OA_IEnrichmentConnector resolve(OA_Connector_Registry__mdt cfg, RunOutcome o) {
        String className = cfg == null ? null : cfg.Connector_Class__c;
        if (String.isBlank(className)) {
            o.messages.add('Registry record has no Connector_Class__c');
            return null;
        }
        Type t = Type.forName(className);
        if (t == null) {
            o.messages.add('Connector class not found: ' + className);
            return null;
        }
        Object inst;
        try {
            inst = t.newInstance();
        } catch (Exception e) {
            o.messages.add('Could not instantiate ' + className + ': ' + e.getMessage());
            return null;
        }
        if (!(inst instanceof OA_IEnrichmentConnector)) {
            o.messages.add('Class does not implement OA_IEnrichmentConnector: ' + className);
            return null;
        }
        return (OA_IEnrichmentConnector) inst;
    }

    /** Build the in-memory telemetry record from existing OA_Connector_Run__c fields only. */
    private RunOutcome finalize(RunOutcome o, OA_Connector_Registry__mdt cfg) {
        OA_Connector_Run__c rec = new OA_Connector_Run__c(
            Run_ID__c = (o.sourceKey + '-' + (o.startedAt != null ? String.valueOf(o.startedAt.getTime()) : 'norun')).abbreviate(80),
            Source_System__c = o.sourceKey,
            Category__c = cfg != null ? cfg.Category__c : null,
            Started__c = o.startedAt,
            Ended__c = o.finishedAt,
            Status__c = o.status,
            Requested__c = o.requested,
            Parsed__c = o.recordsProcessed,
            HTTP_Errors__c = o.httpErrors,
            Parse_Errors__c = o.parseErrors,
            Exceptions_Raised__c = o.exceptions,
            Messages__c = buildMessage(o)
        );
        o.runRecord = rec;
        return o;
    }

    private static String buildMessage(RunOutcome o) {
        List<String> parts = new List<String>{
            'duration_ms=' + o.durationMs,
            'processed=' + o.recordsProcessed,
            'qualified=' + o.recordsQualified,
            'rejected=' + o.recordsRejected,
            'version=' + o.connectorVersion
        };
        if (!o.messages.isEmpty()) {
            parts.add('notes=' + String.join(o.messages, ' | '));
        }
        return String.join(parts, '; ').abbreviate(32768);
    }

    private OA_Connector_Registry__mdt config(String sourceKey) {
        for (OA_Connector_Registry__mdt r : registry()) {
            if (sourceKey != null && sourceKey.equalsIgnoreCase(r.Source_System__c)) {
                return r;
            }
        }
        return null;
    }

    private List<OA_Connector_Registry__mdt> registry() {
        if (registryOverride != null) {
            return registryOverride;
        }
        return [
            SELECT Source_System__c, Connector_Class__c, Parser_Class__c, Mapper_Class__c,
                   Named_Credential__c, Endpoint_Path__c, Category__c, Enabled__c, Status__c, Version__c
            FROM OA_Connector_Registry__mdt
        ];
    }
}
