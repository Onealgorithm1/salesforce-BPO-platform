/**
 * OA_CanonicalOrg — the Salesforce-native canonical organization model (in-memory DTO).
 *
 * A small, source-neutral representation of one organization used internally by the
 * enrichment foundation services. Kept Apex-native (not an object) so it is cheap to build
 * and pass around; it can be persisted to OA_Discovered_Organization__c when needed.
 *
 * `attributes` is a generic bag of source-provided values (keys are source field names,
 * e.g. 'Registration_Status', 'Business_Types') so metadata-driven qualification rules can
 * reference fields that are not first-class properties here — no hardcoding.
 */
public class OA_CanonicalOrg {

    public String organizationName;
    public String normalizedName;
    public String uei;
    public String cageCode;
    public String ein;
    public String cik;
    public String npi;
    public String naics;
    public String address;
    public String city;
    public String state;
    public String postalCode;
    public String website;
    public String phone;
    public String sourceSystem;
    public String sourceConfidence;   // HIGH / MEDIUM / LOW
    public String sourcePayloadHash;
    public Map<String, Object> attributes = new Map<String, Object>();
    public Map<String, Object> discoveryMetadata = new Map<String, Object>();

    public OA_CanonicalOrg() {}

    /** Case-insensitive lookup: attributes first, then known identity/firmographic properties. */
    public Object getValue(String field) {
        if (String.isBlank(field)) {
            return null;
        }
        // exact then case-insensitive attribute match
        if (attributes.containsKey(field)) {
            return attributes.get(field);
        }
        for (String k : attributes.keySet()) {
            if (k != null && k.equalsIgnoreCase(field)) {
                return attributes.get(k);
            }
        }
        switch on field.toLowerCase() {
            when 'organizationname', 'name', 'company' { return organizationName; }
            when 'normalizedname'                      { return normalizedName; }
            when 'uei'                                 { return uei; }
            when 'cage', 'cagecode', 'cage_code'       { return cageCode; }
            when 'ein'                                 { return ein; }
            when 'cik'                                 { return cik; }
            when 'npi'                                 { return npi; }
            when 'naics'                               { return naics; }
            when 'state'                               { return state; }
            when 'city'                                { return city; }
            when 'website'                             { return website; }
            when 'phone'                               { return phone; }
            when 'sourcesystem', 'source_system'       { return sourceSystem; }
            when else                                  { return null; }
        }
    }

    /**
     * Stable dedupe identity: strongest available identifier, else a normalized-name+state hash.
     * Deterministic — never random — so re-discovery collapses to one record.
     */
    public String canonicalKey() {
        if (String.isNotBlank(uei))  { return 'UEI:'  + uei.trim().toUpperCase(); }
        if (String.isNotBlank(ein))  { return 'EIN:'  + ein.trim(); }
        if (String.isNotBlank(npi))  { return 'NPI:'  + npi.trim(); }
        if (String.isNotBlank(cik))  { return 'CIK:'  + cik.trim(); }
        if (String.isNotBlank(cageCode)) { return 'CAGE:' + cageCode.trim().toUpperCase(); }
        String basis = String.valueOf(normalizedName) + '|' + String.valueOf(state);
        return 'NAME:' + shortHash(basis);
    }

    /** True when we have at least one strong deterministic identifier. */
    public Boolean hasDeterministicId() {
        return String.isNotBlank(uei) || String.isNotBlank(ein)
            || String.isNotBlank(npi) || String.isNotBlank(cik) || String.isNotBlank(cageCode);
    }

    /** SHA-256 (hex) of the identity fields — traceability, not the raw payload. */
    public String payloadHash() {
        String basis = String.join(new List<String>{
            s(organizationName), s(uei), s(cageCode), s(ein), s(cik), s(npi),
            s(naics), s(state), s(sourceSystem) }, '|');
        return shortHash(basis);
    }

    private static String shortHash(String basis) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(basis)));
        return EncodingUtil.convertToHex(digest).abbreviate(64);
    }

    private static String s(String v) {
        return v == null ? '' : v;
    }
}
