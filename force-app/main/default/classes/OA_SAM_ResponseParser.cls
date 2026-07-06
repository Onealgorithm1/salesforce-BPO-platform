/**
 * OA_SAM_ResponseParser — parses a SAM.gov Entity API response into canonical organizations.
 *
 * Owns ALL SAM.gov response-shape knowledge and produces source-neutral OA_CanonicalOrg
 * objects for the enrichment platform. Tolerant of additive API changes (unknown fields are
 * ignored) and fails GRACEFULLY: a malformed body throws OA_SAM_ResponseParser.ParseException
 * rather than a raw JSON error, and a missing/empty entityData yields an empty list.
 *
 * Expected shape (subset — entityRegistration + coreData sections):
 *   { "totalRecords": N, "entityData": [ {
 *       "entityRegistration": { ueiSAM, cageCode, legalBusinessName, dbaName,
 *                               registrationStatus, registrationExpirationDate },
 *       "coreData": { entityInformation:{ entityURL, entityStructureDesc },
 *                     physicalAddress:{ addressLine1, city, stateOrProvinceCode, zipCode },
 *                     businessTypes:{ businessTypeList:[ {businessTypeCode} ],
 *                                     sbaBusinessTypeList:[ {sbaBusinessTypeDesc} ] } } } ] }
 *
 * FIELD AVAILABILITY (documented, never fabricated):
 *   - NAICS, Exclusion Status, and Phone are NOT returned by the entityRegistration/coreData
 *     sections; they require additional sections (e.g. assertions) or a different endpoint.
 *     They are left null and flagged rather than invented.
 */
public with sharing class OA_SAM_ResponseParser {

    public class ParseException extends Exception {}

    public List<OA_CanonicalOrg> parse(String body) {
        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();

        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new ParseException('SAM: malformed response body — ' + e.getMessage());
        }

        Object entitiesObj = root.get('entityData');
        if (!(entitiesObj instanceof List<Object>)) {
            return out; // missing/empty entityData -> clean empty result
        }

        for (Object o : (List<Object>) entitiesObj) {
            if (!(o instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> entity = (Map<String, Object>) o;
            Map<String, Object> reg = asMap(entity.get('entityRegistration'));
            Map<String, Object> core = asMap(entity.get('coreData'));

            OA_CanonicalOrg org = new OA_CanonicalOrg();
            org.sourceSystem = 'SAM';
            org.uei = str(reg.get('ueiSAM'));
            org.cageCode = str(reg.get('cageCode'));
            org.organizationName = str(reg.get('legalBusinessName'));
            org.normalizedName = OA_NameNormalizer.normalize(org.organizationName);

            putIf(org, 'DBA', str(reg.get('dbaName')));
            putIf(org, 'Registration_Status', str(reg.get('registrationStatus')));
            putIf(org, 'Registration_Expiration', str(reg.get('registrationExpirationDate')));

            Map<String, Object> entInfo = asMap(core.get('entityInformation'));
            org.website = str(entInfo.get('entityURL'));
            putIf(org, 'Entity_Type', str(entInfo.get('entityStructureDesc')));

            Map<String, Object> addr = asMap(core.get('physicalAddress'));
            org.address = str(addr.get('addressLine1'));
            org.city = str(addr.get('city'));
            org.state = str(addr.get('stateOrProvinceCode'));
            org.postalCode = str(addr.get('zipCode'));

            putIf(org, 'Business_Types', joinCodes(core, 'businessTypeList', 'businessTypeCode'));
            putIf(org, 'Socioeconomic_Certifications',
                  joinCodes(core, 'sbaBusinessTypeList', 'sbaBusinessTypeDesc'));

            // NAICS / Exclusion Status / Phone are not in these sections -> left null (unavailable).
            org.phone = null;

            // Confidence: a UEI is a deterministic identifier -> HIGH; name-only -> MEDIUM.
            org.sourceConfidence = org.hasDeterministicId()
                ? OA_ConfidenceEvaluator.HIGH
                : (String.isNotBlank(org.organizationName) ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW);
            org.sourcePayloadHash = org.payloadHash();

            out.add(org);
        }
        return out;
    }

    /** Join codes/descriptions from coreData.businessTypes.<listKey>[].<valueKey> into a CSV. */
    private String joinCodes(Map<String, Object> core, String listKey, String valueKey) {
        Map<String, Object> bt = asMap(core.get('businessTypes'));
        Object listObj = bt.get(listKey);
        if (!(listObj instanceof List<Object>)) {
            return null;
        }
        List<String> vals = new List<String>();
        for (Object item : (List<Object>) listObj) {
            String v = str(asMap(item).get(valueKey));
            if (String.isNotBlank(v)) {
                vals.add(v);
            }
        }
        return vals.isEmpty() ? null : String.join(vals, ',');
    }

    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) {
            org.attributes.put(key, value);
        }
    }

    private static Map<String, Object> asMap(Object o) {
        return (o instanceof Map<String, Object>) ? (Map<String, Object>) o : new Map<String, Object>();
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
