/**
 * OA_USASpendingParser - parses a USASpending response into normalized rows (Connector SDK).
 *
 * Sprint 1C-1: re-homes the proven parse logic from OA_USASpendingClient onto the
 * SDK contract (OA_IConnectorParser), returning generic OA_ConnectorRow objects.
 *
 * IMPROVEMENT over the old client: guards against a MALFORMED response body by
 * throwing OA_ConnectorException (the engine records it as a parse error) rather
 * than letting a raw JSON exception propagate - retiring that known tech debt.
 */
public class OA_USASpendingParser implements OA_IConnectorParser {

    public List<OA_ConnectorRow> parse(String body) {
        List<OA_ConnectorRow> out = new List<OA_ConnectorRow>();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new OA_ConnectorException(
                'USASpending: malformed response body - ' + e.getMessage());
        }

        Object rowsObj = parsed.get('results');
        if (!(rowsObj instanceof List<Object>)) {
            // Missing or non-list 'results' -> no rows (a clean, empty outcome).
            return out;
        }

        for (Object o : (List<Object>) rowsObj) {
            Map<String, Object> row = (Map<String, Object>) o;
            OA_ConnectorRow r = new OA_ConnectorRow();
            r.put('awardId',          row.get('Award ID'));
            r.put('recipientName',    row.get('Recipient Name'));
            r.put('recipientUei',     row.get('recipient_uei'));
            r.put('awardAmount',      row.get('Award Amount'));
            r.put('awardingAgency',   row.get('Awarding Agency'));
            r.put('awardingSubAgency',row.get('Awarding Sub Agency'));
            r.put('contractType',     row.get('Contract Award Type'));
            r.put('state',            row.get('Place of Performance State Code'));

            String descText = (String) row.get('Description');
            if (descText != null) {
                descText = descText.abbreviate(500);
            }
            r.put('description', descText);

            out.add(r);
        }
        return out;
    }
}