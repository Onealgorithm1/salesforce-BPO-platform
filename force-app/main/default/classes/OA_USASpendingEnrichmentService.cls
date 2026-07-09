/**
 * OA_USASpendingEnrichmentService — controlled, admin/manual invocation surface
 * for the USASpending connector (Sprint 1C-3).
 *
 * A plain static service (NO trigger, flow, invocable, scheduler, or queueable
 * surface) intended to be called deliberately by an admin (e.g. via anonymous
 * Apex, or later a screen-flow button). It orchestrates the already-deployed
 * connector engine + persistence:
 *
 *   build request (callout:OA_USASpending) -> parse -> map -> optionally upsert staging
 *
 * SAFETY:
 *   - Never updates Lead, Campaign, or CampaignMember records (staging only).
 *   - persist=false maps in memory only (no DML).
 *   - persist=true idempotently UPSERTS into OA_USASpending_Staging__c on Dedupe_Key__c,
 *     with Review_Status__c = 'Pending' (human review gate; no Lead write-back).
 *   - Uses the Named Credential via the connector path — no direct URL, no secret.
 *   - Enforces a safe result cap (MAX_LIMIT).
 *   - Deterministic per-recipient run id makes re-running the same recipient a refresh
 *     (upsert), not a duplicate.
 */
public with sharing class OA_USASpendingEnrichmentService {

    public static final Integer DEFAULT_LIMIT = 5;
    public static final Integer MAX_LIMIT = 25;

    public class Result {
        public String runId;
        public Integer requested = 0;
        public Integer parsed = 0;
        public Integer mapped = 0;       // staging records built in memory
        public Integer persisted = 0;    // staging records upserted (0 when persist=false)
        public Boolean persistAttempted = false;
        public Integer httpErrors = 0;
        public Integer parseErrors = 0;
        public List<String> messages = new List<String>();
    }

    /**
     * Run a controlled enrichment for one recipient.
     * @param recipientName required search text (non-blank)
     * @param limitResults  optional cap; null -> DEFAULT_LIMIT; clamped to [1, MAX_LIMIT]
     * @param persist       true -> idempotent upsert into staging; false -> in-memory preview only
     */
    public static Result enrich(String recipientName, Integer limitResults, Boolean persist) {
        if (String.isBlank(recipientName)) {
            throw new OA_ConnectorException(
                'OA_USASpendingEnrichmentService.enrich requires a non-blank recipientName.');
        }

        Integer lim = (limitResults == null) ? DEFAULT_LIMIT : limitResults;
        if (lim < 1) { lim = DEFAULT_LIMIT; }
        if (lim > MAX_LIMIT) { lim = MAX_LIMIT; }

        // Deterministic per-recipient run id (bounded to 36) => re-running refreshes, not duplicates.
        String runId = ('USASP-' + recipientName).abbreviate(36);
        OA_ConnectorContext ctx = new OA_ConnectorContext(runId, new Map<String, Object>{ 'limit' => lim });

        OA_ConnectorRunResult run = new OA_ConnectorEngine().run(
            new OA_USASpendingConnector(), ctx, new List<Object>{ recipientName });

        Result res = new Result();
        res.runId       = runId;
        res.requested   = run.requested;
        res.parsed      = run.parsed;
        res.mapped      = run.mapped;
        res.httpErrors  = run.httpErrors;
        res.parseErrors = run.parseErrors;
        res.messages    = run.messages;

        if (persist == true && !run.stagingRecords.isEmpty()) {
            OA_ConnectorPersistence.PersistResult p = new OA_ConnectorPersistence()
                .upsertStaging(run.stagingRecords, OA_USASpending_Staging__c.Dedupe_Key__c);
            res.persisted = p.upserted;
            res.persistAttempted = true;
        }
        return res;
    }
}