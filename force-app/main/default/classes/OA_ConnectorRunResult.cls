/**
 * OA_ConnectorRunResult — the outcome summary of one enrichment run.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Holds aggregate counts, any
 * per-input diagnostics, and the staging records the engine mapped IN MEMORY.
 * The SDK foundation never persists these records — persistence is Sprint 1C.
 */
public class OA_ConnectorRunResult {

    /** The run's correlation id. */
    public String runId { get; private set; }

    /** How many inputs were submitted. */
    public Integer requested { get; set; }

    /** How many normalized rows were parsed across all inputs. */
    public Integer parsed { get; set; }

    /** How many staging records were mapped in memory. */
    public Integer mapped { get; set; }

    /** How many inputs returned a non-2xx HTTP status. */
    public Integer httpErrors { get; set; }

    /** How many inputs failed during parsing/mapping. */
    public Integer parseErrors { get; set; }

    /** Human-readable diagnostics (one per notable event). */
    public List<String> messages { get; private set; }

    /**
     * The mapped staging records — held in memory only, NEVER inserted by the SDK.
     * A caller (Sprint 1C connector/engine extension) is responsible for any DML.
     */
    public List<SObject> stagingRecords { get; private set; }

    public OA_ConnectorRunResult(String runId) {
        this.runId = runId;
        this.requested = 0;
        this.parsed = 0;
        this.mapped = 0;
        this.httpErrors = 0;
        this.parseErrors = 0;
        this.messages = new List<String>();
        this.stagingRecords = new List<SObject>();
    }

    public void addMessage(String msg) {
        messages.add(msg);
    }

    public void addStaging(SObject rec) {
        stagingRecords.add(rec);
        mapped++;
    }

    /** True when every requested input produced neither an HTTP nor a parse error. */
    public Boolean isClean() {
        return httpErrors == 0 && parseErrors == 0;
    }
}