/**
 * OA_GrantsGovConnector — the Grants.gov source's SDK identity/capability contract.
 *
 * Implements OA_IConnector so the certified OA_ConnectorEngine can run the identical
 * lifecycle (build request -> send -> parse -> map, in memory, no DML) it runs for
 * every other source. Declares the Named Credential and the staging object; owns no
 * transport, DML, or credential logic. Targets OA_Opportunity_Signal__c ONLY —
 * never Lead/Account/CRM.
 */
public with sharing class OA_GrantsGovConnector implements OA_IConnector {

    public String sourceKey() {
        return 'GrantsGov';
    }

    public String namedCredential() {
        return 'callout:OA_GrantsGov';
    }

    public Schema.SObjectType stagingType() {
        return OA_Opportunity_Signal__c.SObjectType;
    }

    public OA_IConnectorRequest requestBuilder() {
        return new OA_GrantsGovRequest();
    }

    public OA_IConnectorParser parser() {
        return new OA_GrantsGovParser();
    }

    public OA_IConnectorMapper mapper() {
        return new OA_GrantsGovMapper();
    }
}
