/**
 * OA_ConnectorResult — the standard, source-agnostic result a connector's fetch() returns.
 *
 * Carries the canonical organizations plus lightweight fetch counts the dispatcher rolls up into
 * run telemetry. Replaces each connector's bespoke result type so the runner can treat every
 * connector identically.
 */
public class OA_ConnectorResult {

    public String sourceKey;
    public Integer requested = 0;
    public Integer parsed = 0;
    public Integer httpErrors = 0;
    public Integer parseErrors = 0;
    public Integer lastStatus;
    public List<OA_CanonicalOrg> organizations = new List<OA_CanonicalOrg>();
    public List<String> messages = new List<String>();
    /** Raw API payload — populated ONLY when a connector's debug flag is enabled; never by default. */
    public String rawPayload;

    public OA_ConnectorResult(String sourceKey) { this.sourceKey = sourceKey; }
}