/**
 * OA_GrantsConnector — the Grants.gov Opportunity source on the Connector SDK (dormant).
 *
 * Wires the four SDK responsibilities together for the Grants.gov Search2 REST API.
 * Behavior is exercised through OA_ConnectorEngine and is FULLY MOCKED in tests —
 * this class never calls a live endpoint.
 *
 * WHAT THIS IS (and is NOT):
 *   Grants.gov returns FUNDING OPPORTUNITIES (NOFOs) — deadlines, agencies, CFDA/ALN
 *   numbers, status — NOT company/firmographic data. It is an OPPORTUNITY-SIGNAL source
 *   (outreach-timing intelligence), classified as such in
 *   docs/LEAD_GEN_ENRICHMENT_OPERATING_MODEL.md. Results land in the opportunity-signal
 *   staging object OA_Grants_Opportunity_Staging__c, NOT a Lead-firmographic object, and
 *   there is NO Lead write-back. Any Lead association is a later, reviewed, loose match.
 *
 * SCOPE (dormant foundation):
 *   - In-memory mapping only, NO persistence, NO scheduler, NO trigger, NO Lead writes.
 *   - namedCredential() returns 'callout:OA_Grants' for the SDK contract. The OA_Grants
 *     Named Credential is a PUBLIC, no-authentication endpoint — there is NO API key, NO
 *     External Credential, and NO secret anywhere in this connector or the repository.
 *   - Nothing invokes this connector; it is dormant until a separately-approved run.
 */
public class OA_GrantsConnector implements OA_IConnector {

    public String sourceKey() {
        return 'Grants';
    }

    // Public no-auth endpoint — the OA_Grants Named Credential carries no secret.
    public String namedCredential() {
        return 'callout:OA_Grants';
    }

    public Schema.SObjectType stagingType() {
        return OA_Grants_Opportunity_Staging__c.SObjectType;
    }

    public OA_IConnectorRequest requestBuilder() {
        return new OA_GrantsRequest();
    }

    public OA_IConnectorParser parser() {
        return new OA_GrantsParser();
    }

    public OA_IConnectorMapper mapper() {
        return new OA_GrantsMapper();
    }
}
