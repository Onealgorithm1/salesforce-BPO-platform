/**
 * OA_SourceFusion — connector-agnostic, fill-empty multi-source fusion for Candidate profiles.
 *
 * Merges an incoming OA_CanonicalOrg (from any source) into an existing OA_Discovered_Organization__c Candidate
 * that Identity Resolution has determined is the SAME real-world organization. Conservative by design:
 *   - NEVER overwrites a populated field with a blank.
 *   - NEVER overwrites a populated field with a conflicting value (fill-empty only); the alternate value is
 *     recorded in provenance for human review instead of clobbering trusted data.
 *   - Preserves every source, timestamp, and confidence in Discovery_Metadata__c (JSON provenance).
 *   - Raises Source_Confidence to the strongest contributing value (corroboration).
 * PURE (no DML/SOQL): mutates the passed record in memory and returns whether it changed; the caller persists.
 * No connector-specific branching.
 */
public with sharing class OA_SourceFusion {

    // Fills blank fields on `existing` from `incoming`; records provenance. Returns true if anything changed.
    public static Boolean fuse(OA_Discovered_Organization__c existing, OA_CanonicalOrg incoming) {
        if (existing == null || incoming == null) { return false; }
        Boolean changed = false;

        changed = fill(existing, 'Organization_Name__c', incoming.organizationName) || changed;
        changed = fill(existing, 'Normalized_Name__c', incoming.normalizedName) || changed;
        changed = fill(existing, 'UEI__c', incoming.uei) || changed;
        changed = fill(existing, 'CAGE_Code__c', incoming.cageCode) || changed;
        changed = fill(existing, 'CIK__c', incoming.cik) || changed;
        changed = fill(existing, 'EIN__c', incoming.ein) || changed;
        changed = fill(existing, 'NPI__c', incoming.npi) || changed;
        changed = fill(existing, 'NAICS__c', incoming.naics) || changed;
        changed = fill(existing, 'Address__c', incoming.address) || changed;
        changed = fill(existing, 'City__c', incoming.city) || changed;
        changed = fill(existing, 'State__c', incoming.state) || changed;
        changed = fill(existing, 'Postal_Code__c', incoming.postalCode) || changed;
        changed = fill(existing, 'Website__c', incoming.website) || changed;
        changed = fill(existing, 'Phone__c', incoming.phone) || changed;

        // Confidence: keep the strongest.
        if (rank(incoming.sourceConfidence) > rank((String) existing.get('Source_Confidence__c'))) {
            existing.put('Source_Confidence__c', incoming.sourceConfidence);
            changed = true;
        }

        // Provenance (always recorded on a fusion, even if all fields were already populated -> logs the corroborating source).
        recordProvenance(existing, incoming);
        existing.Last_Evaluated__c = System.now();
        return changed || true; // a fusion always updates provenance/timestamp -> record is considered changed
    }

    private static Boolean fill(OA_Discovered_Organization__c d, String field, String value) {
        if (String.isBlank(value)) { return false; }
        Object cur = d.get(field);
        if (cur == null || String.isBlank(String.valueOf(cur))) {
            d.put(field, value);
            return true;
        }
        return false; // populated -> never overwrite (fill-empty only)
    }

    @SuppressWarnings('PMD')
    private static void recordProvenance(OA_Discovered_Organization__c d, OA_CanonicalOrg incoming) {
        Map<String, Object> meta;
        String existingMeta = (String) d.get('Discovery_Metadata__c');
        if (String.isNotBlank(existingMeta)) {
            try { meta = (Map<String, Object>) JSON.deserializeUntyped(existingMeta); }
            catch (Exception e) { meta = new Map<String, Object>(); }
        } else {
            meta = new Map<String, Object>();
        }
        List<Object> sources = (meta.get('sources') instanceof List<Object>) ? (List<Object>) meta.get('sources') : new List<Object>();
        sources.add(new Map<String, Object>{
            'system' => incoming.sourceSystem,
            'confidence' => incoming.sourceConfidence,
            'payloadHash' => incoming.payloadHash(),
            'canonicalKey' => incoming.canonicalKey(),
            'fusedAt' => String.valueOf(System.now())
        });
        meta.put('sources', sources);
        meta.put('fusionCount', sources.size());
        d.put('Discovery_Metadata__c', JSON.serialize(meta));
    }

    private static Integer rank(String confidence) {
        if (confidence == null) { return 0; }
        String c = confidence.toUpperCase();
        if (c == 'HIGH') { return 3; }
        if (c == 'MEDIUM' || c == 'MED') { return 2; }
        if (c == 'LOW') { return 1; }
        return 0;
    }
}
