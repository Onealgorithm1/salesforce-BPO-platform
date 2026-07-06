/**
 * OA_ConfidenceEvaluator — turns match signals into a confidence band + score.
 *
 * Deterministic-first: an exact strong-identifier match is HIGH (the only band the writer
 * treats as auto-eligible). A normalized name+state match above a threshold is MEDIUM; any
 * weaker name similarity is LOW; nothing is NONE. Band structure is platform logic; the
 * MEDIUM name-score threshold is a caller-supplied parameter (defaulted, not a hardcoded
 * business rule) so it can be sourced from configuration later.
 */
public with sharing class OA_ConfidenceEvaluator {

    public static final String HIGH = 'HIGH';
    public static final String MEDIUM = 'MEDIUM';
    public static final String LOW = 'LOW';
    public static final String NONE = 'NONE';

    /** Default MEDIUM cutoff for name similarity in [0,1]; overridable per call. */
    public static final Decimal DEFAULT_MEDIUM_THRESHOLD = 0.85;

    public class Result {
        public String band;
        public Decimal score;   // 0..100
        public Result(String band, Decimal score) { this.band = band; this.score = score; }
    }

    public static Result evaluate(Boolean exactIdMatch, Boolean nameStateMatch, Decimal nameScore) {
        return evaluate(exactIdMatch, nameStateMatch, nameScore, DEFAULT_MEDIUM_THRESHOLD);
    }

    public static Result evaluate(Boolean exactIdMatch, Boolean nameStateMatch,
                                  Decimal nameScore, Decimal mediumThreshold) {
        Decimal ns = nameScore == null ? 0 : nameScore;
        Decimal thr = mediumThreshold == null ? DEFAULT_MEDIUM_THRESHOLD : mediumThreshold;

        if (exactIdMatch == true) {
            return new Result(HIGH, 100);
        }
        if (nameStateMatch == true && ns >= thr) {
            // scale name score into the MEDIUM range [50,90]
            return new Result(MEDIUM, (50 + (ns * 40)).setScale(2));
        }
        if (ns > 0) {
            return new Result(LOW, (ns * 40).setScale(2));
        }
        return new Result(NONE, 0);
    }

    /** Ordinal for band comparison (HIGH highest). */
    public static Integer rank(String band) {
        if (HIGH.equalsIgnoreCase(band))   { return 3; }
        if (MEDIUM.equalsIgnoreCase(band)) { return 2; }
        if (LOW.equalsIgnoreCase(band))    { return 1; }
        return 0;
    }

    /** True when `band` is at least as strong as `floor`. */
    public static Boolean meetsFloor(String band, String floor) {
        String f = String.isBlank(floor) ? HIGH : floor;
        return rank(band) >= rank(f);
    }

    public static Boolean isHigh(String band) {
        return HIGH.equalsIgnoreCase(band);
    }
}
