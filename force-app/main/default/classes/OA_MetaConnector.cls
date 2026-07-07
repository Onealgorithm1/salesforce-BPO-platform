/**
 * OA_MetaConnector — DORMANT skeleton for the Meta Marketing API connector (INT-011).
 *
 * Status: dormant foundation ONLY. It performs NO authentication, holds NO token, and makes
 * NO Meta API call. Registered in OA_Connector_Registry__mdt (Source_System 'Meta') with
 * Enabled__c = false, so the dispatcher skips it.
 *
 * Reuse: it uses the existing Connector SDK (OA_ConnectorContext, OA_ConnectorException; and,
 * in a future sprint, OA_ConnectorHttp for the single callout path). It deliberately does NOT
 * implement OA_IEnrichmentConnector — Meta returns advertising performance data, not canonical
 * organizations, so it is not an enrichment connector (see docs/META_MARKETING_INTEGRATION_PLAN.md).
 *
 * Every operational method throws OA_ConnectorException until a future, separately-approved
 * authentication + sync sprint replaces these placeholders.
 */
public with sharing class OA_MetaConnector {

    @TestVisible private static final String SOURCE_KEY = 'Meta';
    @TestVisible private static final String NAMED_CREDENTIAL = 'OA_Meta';

    /** Stable source key used by the connector registry and the future dispatcher. */
    public String sourceKey() {
        return SOURCE_KEY;
    }

    /** The Named Credential this connector will call through once activated (dormant today). */
    public String namedCredential() {
        return NAMED_CREDENTIAL;
    }

    /** Always false in the dormant foundation; a future sprint flips this when sync is built. */
    public Boolean isImplemented() {
        return false;
    }

    /**
     * Builds a run-scoped SDK context. Provided so the skeleton demonstrably reuses the
     * Connector SDK and can be unit-tested without performing any I/O.
     */
    public OA_ConnectorContext buildContext(String runId) {
        return new OA_ConnectorContext(runId);
    }

    /**
     * Placeholder for the future ad-account / campaign / ad-set / ad / insights sync.
     * Intentionally unimplemented: performs NO authentication and NO Meta API call.
     */
    public void sync(OA_ConnectorContext ctx) {
        throw new OA_ConnectorException(
            'OA_MetaConnector is a dormant foundation (INT-011). Authentication and Meta API sync ' +
            'are not implemented and must not run until a future approved sprint.');
    }
}
