/**
 * OA_IRS_Connector — IRS Tax-Exempt (EO BMF) BULK connector on the generic framework (dormant).
 *
 * Proves the framework accommodates a NON-REST, bulk-oriented source through the SAME interface:
 * it implements OA_IEnrichmentConnector and is dispatched by OA_ConnectorRunner exactly like a REST
 * connector — but `fetch` performs NO HTTP callout. Instead `input` is a chunk of EO BMF CSV content
 * (header + rows) which the parser turns into canonical organizations. Retrieval/chunking of the
 * monthly bulk file is an operational step performed upstream (not built here; no scheduled jobs).
 */
public with sharing class OA_IRS_Connector implements OA_IEnrichmentConnector {

    public static final String SOURCE_KEY = 'IRS';

    public String sourceKey() { return SOURCE_KEY; }

    /**
     * @param input a chunk of EO BMF CSV (header + data rows). NO live callout is made.
     * @param cfg   registry record (unused for retrieval — bulk source); accepted for interface parity.
     */
    public OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg) {
        OA_ConnectorResult res = new OA_ConnectorResult(SOURCE_KEY);
        res.requested = 1;
        res.messages.add('IRS is a BULK source: parsing provided EO BMF content (no HTTP callout).');
        try {
            res.organizations = new OA_IRS_ResponseParser().parse(input);
            res.parsed = res.organizations.size();
            res.lastStatus = 200; // synthetic success marker for a bulk parse
        } catch (OA_IRS_ResponseParser.ParseException pe) {
            res.parseErrors++;
            res.messages.add('Parse error: ' + pe.getMessage());
        }
        // Unexpected exceptions propagate to OA_ConnectorRunner, which records them uniformly.
        return res;
    }
}
