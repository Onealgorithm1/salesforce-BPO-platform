/**
 * OA_SAMConnector — the SAM.gov Entity source on the Connector SDK (Phase 2, dormant).
 *
 * Wires the four SDK responsibilities together for the SAM.gov Entity Management API.
 * Behavior is exercised through OA_ConnectorEngine and is FULLY MOCKED in tests —
 * this class never calls a live endpoint.
 *
 * SCOPE (Phase 2 — dormant foundation):
 *   - In-memory mapping only, NO persistence, NO scheduler, NO trigger, NO Lead writes.
 *   - namedCredential() returns 'callout:OA_SAM' for the SDK contract; the OA_SAM
 *     Named/External Credential is a secret-free SHELL — the real data.gov API key is
 *     entered by a custodian in Salesforce Setup later, NEVER in source control.
 *   - The API key is sent as an 'X-Api-Key' HEADER injected by the External Credential,
 *     so no key ever appears in a URL, request body, log, or this repository.
 *   - Nothing invokes this connector; it is dormant until a separately-approved run.
 */
public class OA_SAMConnector implements OA_IConnector {

    public String sourceKey() {
        return 'SAM';
    }

    // Declared for the SDK contract. The OA_SAM credential is a secret-free shell until
    // the key is provisioned in Setup; access is granted JIT via a permission set.
    public String namedCredential() {
        return 'callout:OA_SAM';
    }

    public Schema.SObjectType stagingType() {
        return OA_SAM_Entity_Staging__c.SObjectType;
    }

    public OA_IConnectorRequest requestBuilder() {
        return new OA_SAMRequest();
    }

    public OA_IConnectorParser parser() {
        return new OA_SAMParser();
    }

    public OA_IConnectorMapper mapper() {
        return new OA_SAMMapper();
    }
}
