/**
 * OA_NameNormalizer — deterministic organization-name normalization.
 *
 * Concept borrowed (not code) from open-source record-linkage practice (Splink / dedupe):
 * uppercase, strip punctuation, drop common legal-entity suffixes, collapse whitespace.
 * Pure and deterministic so the same input always yields the same normalized form — the
 * basis for a stable composite key and name comparison. No external dependency.
 */
public with sharing class OA_NameNormalizer {

    // Common legal-entity suffix tokens removed for comparison (kept minimal, extensible).
    private static final Set<String> SUFFIXES = new Set<String>{
        'INC', 'INCORPORATED', 'LLC', 'LLP', 'LP', 'LTD', 'CORP', 'CORPORATION',
        'CO', 'COMPANY', 'PLLC', 'PC', 'PA', 'GROUP', 'HOLDINGS'
    };

    public static String normalize(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String s = raw.toUpperCase();
        s = s.replaceAll('[^A-Z0-9 ]', ' ');   // strip punctuation/symbols
        s = s.replaceAll('\\s+', ' ').trim();   // collapse whitespace
        if (String.isBlank(s)) {
            return null;
        }
        List<String> kept = new List<String>();
        for (String token : s.split(' ')) {
            if (!SUFFIXES.contains(token)) {
                kept.add(token);
            }
        }
        String result = String.join(kept, ' ').trim();
        // If suffix-stripping emptied the string, fall back to the punctuation-stripped form.
        return String.isBlank(result) ? s : result;
    }

    /**
     * A crude, deterministic name similarity in [0,1] based on shared normalized tokens
     * (Jaccard over token sets). Intentionally simple; a probabilistic model can replace it
     * later (see docs/BUILD_VS_BORROW.md) without changing callers.
     */
    public static Decimal similarity(String a, String b) {
        String na = normalize(a);
        String nb = normalize(b);
        if (String.isBlank(na) || String.isBlank(nb)) {
            return 0;
        }
        if (na == nb) {
            return 1;
        }
        Set<String> ta = new Set<String>(na.split(' '));
        Set<String> tb = new Set<String>(nb.split(' '));
        Set<String> inter = ta.clone();
        inter.retainAll(tb);
        Set<String> uni = ta.clone();
        uni.addAll(tb);
        if (uni.isEmpty()) {
            return 0;
        }
        return ((Decimal) inter.size()) / uni.size();
    }
}