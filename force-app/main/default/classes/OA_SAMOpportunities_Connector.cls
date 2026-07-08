/**
 * OA_SAMOpportunities_Connector — the SAM Get Opportunities source's SDK contract.
 *
 * Implements OA_IConnector so the certified OA_ConnectorEngine runs the identical
 * lifecycle (build -> send -> parse -> map, in memory, no DML) it runs for every
 * source. Declares the Named Credential and the staging object. Targets
 * OA_Opportunity_Signal__c ONLY — never Lead/Account/CRM. Distinct from the SAM
 * Entity connector (OA_SAM_Connector): different API, endpoint, credential, grain.
 */
public with sharing class OA_SAMOpportunities_Connector implements OA_IConnector {

    public String sourceKey() {
        return 'SAMOpportunities';
    }

    public String namedCredential() {
        return 'callout:OA_SAM_Opportunities';
    }

    public Schema.SObjectType stagingType() {
        return OA_Opportunity_Signal__c.SObjectType;
    }

    public OA_IConnectorRequest requestBuilder() {
        return new OA_SAMOpportunities_Request();
    }

    public OA_IConnectorParser parser() {
        return new OA_SAMOpportunities_ResponseParser();
    }

    public OA_IConnectorMapper mapper() {
        return new OA_SAMOpportunities_Mapper();
    }
}
