/**
 * OA_ConnectorContext — run-scoped values shared across one enrichment run.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Carries a correlation id
 * (the "run id"), the initiating user, a free-form config map, and per-run
 * metadata the engine stamps as it executes (endpoint, last HTTP status,
 * query date). The mapper reads these when building staging records in 1C.
 *
 * The caller supplies a runId — the SDK does not generate one internally so it
 * stays deterministic and test-friendly.
 */
public class OA_ConnectorContext {

    /** Correlation id tying all rows of one run together (idempotency key part 1). */
    public String runId { get; private set; }

    /** The user who initiated the run (defaults to the current user). */
    public Id initiatingUserId { get; private set; }

    /** Optional free-form configuration for the connector. */
    public Map<String, Object> config { get; private set; }

    /** Endpoint/path that produced the most recent response (audit). */
    public String lastEndpoint { get; set; }

    /** Most recent HTTP status code seen during the run. */
    public Integer lastHttpStatus { get; set; }

    /** When this run was executed. */
    public Datetime queryDate { get; private set; }

    public OA_ConnectorContext(String runId) {
        this(runId, null);
    }

    public OA_ConnectorContext(String runId, Map<String, Object> config) {
        if (String.isBlank(runId)) {
            throw new OA_ConnectorException('OA_ConnectorContext requires a non-blank runId.');
        }
        this.runId = runId;
        this.initiatingUserId = UserInfo.getUserId();
        this.config = config != null ? config : new Map<String, Object>();
        this.queryDate = Datetime.now();
    }
}
