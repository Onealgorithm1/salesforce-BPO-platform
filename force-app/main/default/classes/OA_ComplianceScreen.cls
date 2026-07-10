/**
 * OA_ComplianceScreen — deterministic Go/No-Go eligibility screen (Program 023).
 *
 * Screens an acquisition candidate (OA_Opportunity_Signal__c) for eligibility using One Algorithm's
 * Self Company Profile (socioeconomic status from Program 021) vs. the solicitation's set-aside/NAICS.
 * DETERMINISTIC + auditable — no AI decisioning (AI explains elsewhere). Outputs GO / CONDITIONAL GO /
 * NO-GO / REVIEW REQUIRED + rationale + missing requirements onto the review-queue record. Never creates
 * a CRM Opportunity; a human still decides.
 */
public with sharing class OA_ComplianceScreen {

    public class Result {
        public String decision;      // GO | CONDITIONAL GO | NO-GO | REVIEW REQUIRED
        public String rationale;
        public String missing;
    }

    // Set-asides One Algorithm (EDWOSB) can pursue as prime; EDWOSB implies WOSB + small business.
    // Precise tokens only (avoid loose 'SB' which is a substring of SDVOSB/VOSB).
    private static final Set<String> SELF_EQUIV = new Set<String>{
        'EDWOSB', 'WOSB', 'WOMEN-OWNED', 'WOMAN-OWNED', 'SMALL BUSINESS', 'TOTAL SMALL BUSINESS'
    };
    // Set-asides requiring a status One Algorithm lacks -> prime ineligible (teaming path only).
    private static final Set<String> OTHER_SETASIDE = new Set<String>{
        'SDVOSB', 'VOSB', '8(A)', '8A', 'HUBZONE', 'HUB ZONE', 'SERVICE-DISABLED'
    };

    /** Eligibility snapshot from the Self profile. */
    public static Set<String> selfStatuses() {
        Set<String> out = new Set<String>();
        for (OA_Company_Profile__c p : [
            SELECT Socioeconomic_Status__c FROM OA_Company_Profile__c
            WHERE Profile_Type__c = 'Self' AND Status__c = 'Active' LIMIT 1
        ]) {
            if (String.isNotBlank(p.Socioeconomic_Status__c)) {
                for (String s : p.Socioeconomic_Status__c.split('[,;/]')) out.add(s.trim().toUpperCase());
            }
        }
        return out;
    }

    /** Pure evaluation (no DML/SOQL) — unit-testable. */
    public static Result evaluate(String setAside, String naics, String placeOfPerf, Set<String> mine) {
        Result r = new Result();
        List<String> missing = new List<String>();
        Boolean edwosb = mine.contains('EDWOSB') || mine.contains('WOSB');

        String sa = (setAside == null) ? '' : setAside.trim().toUpperCase();
        Boolean selfMatch = false, otherMatch = false;
        for (String k : SELF_EQUIV) if (sa.contains(k)) selfMatch = true;
        for (String k : OTHER_SETASIDE) if (sa.contains(k)) otherMatch = true;

        if (String.isBlank(sa)) {
            // Full & open or unspecified: eligible, but competitive; confirm registration.
            r.decision = mine.isEmpty() ? 'REVIEW REQUIRED' : 'GO';
            r.rationale = 'No set-aside detected (full & open or unspecified). One Algorithm is eligible to bid'
                + (edwosb ? ' and may claim EDWOSB/WOSB status where evaluated.' : '.')
                + ' Competition is open; win depends on capability + price.';
        } else if (otherMatch && !anyOther(mine)) {
            // Restrictive set-aside for a status we lack — check FIRST (prime ineligible).
            r.decision = 'NO-GO';
            r.rationale = 'Set-aside "' + setAside + '" requires a status One Algorithm does not hold (e.g. SDVOSB/8(a)/HUBZone). '
                + 'Prime bid ineligible; pursue only by TEAMING with a qualifying prime.';
            missing.add('Qualifying prime/partner for ' + setAside + ' (see Partner Intelligence)');
        } else if (selfMatch && edwosb) {
            r.decision = 'GO';
            r.rationale = 'Set-aside "' + setAside + '" matches One Algorithm\'s EDWOSB/WOSB/small-business status — eligible to prime.';
        } else if (selfMatch && !edwosb) {
            r.decision = 'CONDITIONAL GO';
            r.rationale = 'Set-aside "' + setAside + '" appears small-business oriented but One Algorithm\'s EDWOSB/WOSB status is not on file — verify.';
            missing.add('Confirm EDWOSB/WOSB certification on the Self company profile');
        } else {
            r.decision = 'REVIEW REQUIRED';
            r.rationale = 'Set-aside "' + setAside + '" could not be automatically matched to One Algorithm\'s status — human review.';
        }

        // Registration / certification prerequisites (advisory)
        if (edwosb) {
            missing.add('Verify active SAM.gov registration + current EDWOSB/WOSB certification (renewal risk)');
        } else {
            missing.add('Confirm active SAM.gov registration before bid');
        }
        if (String.isBlank(naics)) missing.add('NAICS not captured — confirm size standard eligibility');

        r.missing = String.join(missing, '\n');
        return r;
    }

    private static Boolean anyOther(Set<String> mine) {
        for (String k : OTHER_SETASIDE) if (mine.contains(k)) return true;
        return false;
    }

    /** Screen review-queue candidates in place (bulk-safe, no callout). */
    public static void screen(List<Id> signalIds) {
        if (signalIds == null || signalIds.isEmpty()) return;
        Set<String> mine = selfStatuses();
        List<OA_Opportunity_Signal__c> sigs = [
            SELECT Id, Set_Aside__c, NAICS__c, Place_of_Performance__c
            FROM OA_Opportunity_Signal__c WHERE Id IN :signalIds
        ];
        for (OA_Opportunity_Signal__c s : sigs) {
            Result r = evaluate(s.Set_Aside__c, s.NAICS__c, s.Place_of_Performance__c, mine);
            s.Compliance_Decision__c = r.decision;
            s.Compliance_Rationale__c = r.rationale;
            s.Missing_Requirements__c = r.missing;
        }
        update sigs;
    }
}