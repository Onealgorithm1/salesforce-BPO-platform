/**
 * OA_QualificationRuleEngine — metadata-driven ICP qualification.
 *
 * Evaluates a canonical organization against the ACTIVE OA_Qualification_Rule__mdt rows for a
 * named ruleset. All criteria, operators, weights, and the pass threshold come from metadata —
 * NO hardcoded business rules. A ruleset qualifies when every Required rule passes AND (if a
 * threshold is set) the summed weight of passing rules meets it.
 */
public with sharing class OA_QualificationRuleEngine {

    /** Test injection point — when non-null, used instead of querying the CMDT. */
    @TestVisible
    private static List<OA_Qualification_Rule__mdt> ruleOverride;

    public class Result {
        public Boolean qualified = false;
        public Boolean needsData = false;
        public Decimal score = 0;
        public Decimal threshold = 0;
        public List<String> reasons = new List<String>();
    }

    private static List<OA_Qualification_Rule__mdt> rules() {
        if (ruleOverride != null) {
            return ruleOverride;
        }
        return [
            SELECT Ruleset__c, Criterion_Type__c, Source_Field__c, Operator__c, Compare_Value__c,
                   Weight__c, Required__c, Ruleset_Threshold__c, Active__c
            FROM OA_Qualification_Rule__mdt
            WHERE Active__c = true
        ];
    }

    public static Result evaluate(String ruleset, OA_CanonicalOrg org) {
        Result res = new Result();
        List<OA_Qualification_Rule__mdt> applicable = new List<OA_Qualification_Rule__mdt>();
        for (OA_Qualification_Rule__mdt r : rules()) {
            if (r.Active__c == true && r.Ruleset__c != null
                    && r.Ruleset__c.equalsIgnoreCase(ruleset)) {
                applicable.add(r);
                if (r.Ruleset_Threshold__c != null && r.Ruleset_Threshold__c > res.threshold) {
                    res.threshold = r.Ruleset_Threshold__c;
                }
            }
        }
        if (applicable.isEmpty()) {
            res.reasons.add('No active qualification rules for ruleset: ' + ruleset);
            return res;
        }

        Boolean allRequiredPass = true;
        for (OA_Qualification_Rule__mdt r : applicable) {
            Object value = org == null ? null : org.getValue(r.Source_Field__c);
            Boolean valueMissing = (value == null || String.isBlank(String.valueOf(value)));
            Boolean pass = applyOperator(r.Operator__c, value, r.Compare_Value__c);
            String label = (r.Criterion_Type__c == null ? r.Source_Field__c : r.Criterion_Type__c);

            if (r.Required__c == true && valueMissing) {
                res.needsData = true;
            }
            if (pass) {
                Decimal w = r.Weight__c == null ? 0 : r.Weight__c;
                res.score += w;
                res.reasons.add('PASS ' + label + ' (weight ' + w + ')');
            } else {
                if (r.Required__c == true) {
                    allRequiredPass = false;
                    res.reasons.add('FAIL required ' + label);
                } else {
                    res.reasons.add('not met ' + label);
                }
            }
        }

        Boolean meetsThreshold = (res.threshold == null || res.threshold == 0) || (res.score >= res.threshold);
        res.qualified = allRequiredPass && meetsThreshold;
        return res;
    }

    /** Metadata-driven operators. */
    @TestVisible
    private static Boolean applyOperator(String op, Object value, String compare) {
        String o = op == null ? 'equals' : op.toLowerCase();
        String v = value == null ? null : String.valueOf(value);
        switch on o {
            when 'exists' {
                return String.isNotBlank(v);
            }
            when 'equals' {
                return v != null && compare != null && v.trim().equalsIgnoreCase(compare.trim());
            }
            when 'contains' {
                return v != null && compare != null && v.toLowerCase().contains(compare.toLowerCase());
            }
            when 'in' {
                if (v == null || compare == null) { return false; }
                for (String part : compare.split(',')) {
                    if (v.trim().equalsIgnoreCase(part.trim())) { return true; }
                }
                return false;
            }
            when 'gte' {
                Decimal dv = toDec(v); Decimal dc = toDec(compare);
                return dv != null && dc != null && dv >= dc;
            }
            when 'lte' {
                Decimal dv = toDec(v); Decimal dc = toDec(compare);
                return dv != null && dc != null && dv <= dc;
            }
            when 'between' {
                if (v == null || compare == null || !compare.contains(',')) { return false; }
                List<String> parts = compare.split(',');
                Decimal dv = toDec(v); Decimal lo = toDec(parts[0]); Decimal hi = toDec(parts[1]);
                return dv != null && lo != null && hi != null && dv >= lo && dv <= hi;
            }
            when else {
                return false;
            }
        }
    }

    private static Decimal toDec(String s) {
        if (String.isBlank(s)) { return null; }
        try { return Decimal.valueOf(s.trim()); } catch (Exception e) { return null; }
    }
}