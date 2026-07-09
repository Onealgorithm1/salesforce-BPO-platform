/**
 * OA_SAMParser — parses a SAM.gov Entity API response into normalized rows (Connector SDK).
 *
 * Owns the SAM.gov response-shape knowledge and returns generic OA_ConnectorRow objects.
 * Guards a malformed body by throwing OA_ConnectorException (the engine records a parse
 * error) rather than letting a raw JSON exception propagate.
 *
 * Expected shape (subset): { "totalRecords": N, "entityData": [ {
 *     "entityRegistration": { ueiSAM, cageCode, legalBusinessName, registrationStatus,
 *                             registrationExpirationDate },
 *     "coreData": { physicalAddress:{ stateOrProvinceCode }, entityInformation:{ entityURL },
 *                   businessTypes:{ businessTypeList:[ { businessTypeCode } ] } } } ] }
 */
public class OA_SAMParser implements OA_IConnectorParser {

    public List<OA_ConnectorRow> parse(String body) {
        List<OA_ConnectorRow> out = new List<OA_ConnectorRow>();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new OA_ConnectorException('SAM: malformed response body — ' + e.getMessage());
        }

        Object entitiesObj = parsed.get('entityData');
        if (!(entitiesObj instanceof List<Object>)) {
            // Missing or non-list 'entityData' -> no rows (clean, empty outcome).
            return out;
        }

        for (Object o : (List<Object>) entitiesObj) {
            if (!(o instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> entity = (Map<String, Object>) o;
            Map<String, Object> reg  = asMap(entity.get('entityRegistration'));
            Map<String, Object> core = asMap(entity.get('coreData'));

            OA_ConnectorRow r = new OA_ConnectorRow();
            r.put('uei',                str(reg.get('ueiSAM')));
            r.put('cageCode',           str(reg.get('cageCode')));
            r.put('legalBusinessName',  str(reg.get('legalBusinessName')));
            r.put('registrationStatus', str(reg.get('registrationStatus')));
            r.put('registrationExpirationDate', str(reg.get('registrationExpirationDate')));

            Map<String, Object> addr = asMap(core.get('physicalAddress'));
            r.put('state', str(addr.get('stateOrProvinceCode')));

            Map<String, Object> entInfo = asMap(core.get('entityInformation'));
            r.put('entityUrl', str(entInfo.get('entityURL')));

            r.put('businessTypes', extractBusinessTypes(core));

            out.add(r);
        }
        return out;
    }

    /** Join business-type codes into a compact, staging-friendly string (certs/socioeconomic). */
    private String extractBusinessTypes(Map<String, Object> core) {
        Map<String, Object> bt = asMap(core.get('businessTypes'));
        Object listObj = bt.get('businessTypeList');
        if (!(listObj instanceof List<Object>)) {
            return null;
        }
        List<String> codes = new List<String>();
        for (Object item : (List<Object>) listObj) {
            Map<String, Object> m = asMap(item);
            String code = str(m.get('businessTypeCode'));
            if (String.isNotBlank(code)) {
                codes.add(code);
            }
        }
        return codes.isEmpty() ? null : String.join(codes, ',');
    }

    private static Map<String, Object> asMap(Object o) {
        return (o instanceof Map<String, Object>)
            ? (Map<String, Object>) o
            : new Map<String, Object>();
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}