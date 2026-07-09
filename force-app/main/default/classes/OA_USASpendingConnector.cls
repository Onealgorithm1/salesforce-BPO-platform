/**
 * OA_USASpendingConnector — the USASpending source on the Connector SDK.
 *
 * Sprint 1C-1: wires the four SDK responsibilities together for USASpending.
 * Behavior is exercised through OA_ConnectorEngine and is fully mockable.
 *
 * SCOPE (1C-1): in-memory mapping only, NO persistence, NO Named Credential in use.
 * namedCredential() returns the intended value for the SDK contract, but the request
 * builder still uses the public endpoint URL in 1C-1 — the credential swap and the
 * staging upsert are DEFERRED to Sprint 1C-2.
 */
public class OA_USASpendingConnector implements OA_IConnector {

    public String sourceKey() {
        return 'USASpending';
    }

    // Declared for the SDK contract; the live credential is created/used in Sprint 1C-2.
    public String namedCredential() {
        return 'callout:OA_USASpending';
    }

    public Schema.SObjectType stagingType() {
        return OA_USASpending_Staging__c.SObjectType;
    }

    public OA_IConnectorRequest requestBuilder() {
        return new OA_USASpendingRequest();
    }

    public OA_IConnectorParser parser() {
        return new OA_USASpendingParser();
    }

    public OA_IConnectorMapper mapper() {
        return new OA_USASpendingMapper();
    }
}