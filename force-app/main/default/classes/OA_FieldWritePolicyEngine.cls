/**
 * OA_FieldWritePolicyEngine — metadata-driven, per-field write decisions.
 *
 * For one proposed change (object, field, source, confidence, current value, new value) it
 * consults OA_Field_Write_Policy__mdt and returns a Decision. All behavior comes from
 * metadata; there are NO hardcoded field rules. Only ACTIVE + TRUSTED policies can produce a
 * write, so the dormant sample records (Active=false) never cause a write.
 *
 * Write modes: FillEmptyOnly, Overwrite, Never.
 */
public with sharing class OA_FieldWritePolicyEngine {

    public enum Outcome {
        WRITE,              // apply the new value
        NO_CHANGE,          // new value equals current value
        SKIP_NO_POLICY,     // no active policy governs this field
        SKIP_NOT_TRUSTED,   // policy exists but is not Trusted
        SKIP_NEVER,         // Write_Mode = Never
        SKIP_BELOW_FLOOR,   // confidence band below the policy floor
        SKIP_FILLED,        // FillEmptyOnly and target already populated (value equal)
        ROUTE_CONFLICT      // FillEmptyOnly and target populated with a DIFFERENT value
    }

    public static final String MODE_FILL_EMPTY = 'FillEmptyOnly';
    public static final String MODE_OVERWRITE  = 'Overwrite';
    public static final String MODE_NEVER      = 'Never';

    public class Decision {
        public Outcome outcome;
        public String reason;
        public OA_Field_Write_Policy__mdt policy;
        public Boolean shouldWrite() { return outcome == OA_FieldWritePolicyEngine.Outcome.WRITE; }
        public Boolean isConflict()  { return outcome == OA_FieldWritePolicyEngine.Outcome.ROUTE_CONFLICT; }
        public Decision(Outcome o, String reason, OA_Field_Write_Policy__mdt p) {
            this.outcome = o; this.reason = reason; this.policy = p;
        }
    }

    /** Test injection point — when non-null, used instead of querying the CMDT. */
    @TestVisible
    private static List<OA_Field_Write_Policy__mdt> policyOverride;

    private static List<OA_Field_Write_Policy__mdt> policies() {
        if (policyOverride != null) {
            return policyOverride;
        }
        return [
            SELECT Target_Object__c, Target_Field__c, Source_System__c, Write_Mode__c,
                   Confidence_Floor__c, Conflict_Behavior__c, Trusted__c, Active__c
            FROM OA_Field_Write_Policy__mdt
            WHERE Active__c = true
        ];
    }

    /** Find the active policy for (object, field, source). Source-specific match preferred. */
    @TestVisible
    private static OA_Field_Write_Policy__mdt findPolicy(String obj, String field, String source) {
        OA_Field_Write_Policy__mdt anySource;
        for (OA_Field_Write_Policy__mdt p : policies()) {
            if (p.Active__c != true) { continue; }
            if (!eq(p.Target_Object__c, obj) || !eq(p.Target_Field__c, field)) { continue; }
            if (source != null && eq(p.Source_System__c, source)) {
                return p; // exact source match wins
            }
            if (String.isBlank(p.Source_System__c)) {
                anySource = p; // policy that applies to any source
            }
        }
        return anySource;
    }

    public static Decision evaluate(String obj, String field, String source,
                                    String confidenceBand, Object currentValue, Object newValue) {
        OA_Field_Write_Policy__mdt p = findPolicy(obj, field, source);
        if (p == null) {
            return new Decision(Outcome.SKIP_NO_POLICY, 'No active write policy for ' + obj + '.' + field, null);
        }
        if (p.Trusted__c != true) {
            return new Decision(Outcome.SKIP_NOT_TRUSTED, 'Policy not marked Trusted', p);
        }
        String mode = p.Write_Mode__c;
        if (MODE_NEVER.equalsIgnoreCase(mode)) {
            return new Decision(Outcome.SKIP_NEVER, 'Write_Mode = Never', p);
        }
        if (!OA_ConfidenceEvaluator.meetsFloor(confidenceBand, p.Confidence_Floor__c)) {
            return new Decision(Outcome.SKIP_BELOW_FLOOR,
                'Confidence ' + confidenceBand + ' below floor ' + p.Confidence_Floor__c, p);
        }

        Boolean sameValue = valuesEqual(currentValue, newValue);
        Boolean currentBlank = isBlank(currentValue);

        if (MODE_FILL_EMPTY.equalsIgnoreCase(mode)) {
            if (currentBlank) {
                return new Decision(Outcome.WRITE, 'FillEmptyOnly: target blank', p);
            }
            if (sameValue) {
                return new Decision(Outcome.SKIP_FILLED, 'FillEmptyOnly: already same value', p);
            }
            return new Decision(Outcome.ROUTE_CONFLICT,
                'FillEmptyOnly: target populated with a different value', p);
        }
        if (MODE_OVERWRITE.equalsIgnoreCase(mode)) {
            if (sameValue) {
                return new Decision(Outcome.NO_CHANGE, 'Overwrite: value unchanged', p);
            }
            return new Decision(Outcome.WRITE, 'Overwrite: source is authoritative', p);
        }
        return new Decision(Outcome.SKIP_NO_POLICY, 'Unknown Write_Mode: ' + mode, p);
    }

    private static Boolean valuesEqual(Object a, Object b) {
        String sa = a == null ? '' : String.valueOf(a).trim();
        String sb = b == null ? '' : String.valueOf(b).trim();
        return sa == sb;
    }

    private static Boolean isBlank(Object v) {
        return v == null || String.isBlank(String.valueOf(v));
    }

    private static Boolean eq(String a, String b) {
        return a != null && b != null && a.equalsIgnoreCase(b);
    }
}
