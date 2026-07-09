/**
 * OA_PursuitInvestment — Pursuit Investment Intelligence (Program 024B).
 *
 * A SECOND, distinct decision layer. Compliance asks "are we eligible?"; Qualification asks "can we win?";
 * Investment asks "should we spend BD resources?". Reads the qualification outputs (Program 024A) + value +
 * effort + urgency + set-aside advantage + (staged) incumbent strength, and emits HIGH / MEDIUM / LOW with a
 * win-probability estimate and rationale. Deterministic + auditable; NEVER merged with Compliance or
 * Qualification; writes only investment fields; never an Opportunity; advisory (Review_Status stays Pending).
 */
public with sharing class OA_PursuitInvestment {

    public static void evaluate(List<Id> signalIds) {
        if (signalIds == null || signalIds.isEmpty()) return;
        Boolean selfEdwosb = false;
        for (OA_Company_Profile__c p : [SELECT Socioeconomic_Status__c FROM OA_Company_Profile__c WHERE Profile_Type__c='Self' AND Status__c='Active' LIMIT 1]) {
            selfEdwosb = (p.Socioeconomic_Status__c != null && p.Socioeconomic_Status__c.toUpperCase().contains('EDWOSB'));
        }

        List<OA_Opportunity_Signal__c> sigs = [SELECT Id, Qualification_Decision__c, Fit_Score__c, Effort_Score__c, Urgency_Score__c,
            Estimated_Value__c, Set_Aside__c, Agency__c, Compliance_Decision__c FROM OA_Opportunity_Signal__c WHERE Id IN :signalIds];

        for (OA_Opportunity_Signal__c s : sigs) {
            Decimal fit = s.Fit_Score__c != null ? s.Fit_Score__c : 0;
            Decimal effort = s.Effort_Score__c != null ? s.Effort_Score__c : 60;
            Decimal urgency = s.Urgency_Score__c != null ? s.Urgency_Score__c : 50;
            String q = s.Qualification_Decision__c;

            // Win probability: base by qualification stance, adjusted by fit / effort / set-aside advantage.
            Decimal base = q == 'GO' ? 55 : q == 'GO WITH PARTNER' ? 45 : q == 'TEAMING' ? 40 : q == 'MONITOR' ? 22 : q == 'REVIEW REQUIRED' ? 20 : 5; // NO-GO
            Decimal setAsideEdge = (selfEdwosb && s.Set_Aside__c != null && (s.Set_Aside__c.toUpperCase().contains('WOSB') || s.Set_Aside__c.toUpperCase().contains('SMALL'))) ? 15 : 0;
            Decimal winProb = clamp(base + fit * 0.2 - effort * 0.1 + setAsideEdge);

            // Revenue signal (log-ish buckets); grants often omit value -> neutral.
            Decimal rev = s.Estimated_Value__c;
            Decimal revScore = rev == null ? 45 : rev >= 5000000 ? 90 : rev >= 1000000 ? 75 : rev >= 250000 ? 55 : rev >= 50000 ? 40 : 25;
            // Strategic: federal + EDWOSB positioning
            Decimal strategic = (selfEdwosb ? 55 : 45) + (s.Agency__c != null && s.Agency__c.toLowerCase().contains('defense') ? 10 : 0);

            Decimal invScore = clamp(winProb * 0.40 + revScore * 0.30 + strategic * 0.20 + (100 - effort) * 0.10);

            String level; List<String> why = new List<String>();
            if (q == 'NO-GO') { level = 'LOW'; why.add('Qualification NO-GO — not feasible; do not invest BD resources.'); }
            else if (q == 'REVIEW REQUIRED') { level = 'MEDIUM'; why.add('Qualification unresolved — light triage before investing.'); }
            else if (invScore >= 60) { level = 'HIGH'; why.add('Strong win probability (' + winProb + '%), revenue signal, and strategic fit — worth full pursuit investment.'); }
            else if (invScore >= 42) { level = 'MEDIUM'; why.add('Moderate win/revenue/effort profile — invest selectively, confirm partner + value.'); }
            else { level = 'LOW'; why.add('Low expected return (score ' + invScore.setScale(0) + '); monitor or defer.'); }

            s.Win_Probability__c = winProb;
            s.Investment_Level__c = level;
            s.Investment_Rationale__c = (String.join(why, ' ') + ' [winProb ' + winProb + '%, revScore ' + revScore
                + ', strategic ' + strategic.setScale(0) + ', effort ' + effort + ', invScore ' + invScore.setScale(0)
                + '; advisory — human approves BD spend]').abbreviate(32000);
        }
        update sigs;   // investment fields only — never an Opportunity; Pending untouched
    }

    private static Decimal clamp(Decimal v) { if (v == null || v < 0) return 0; if (v > 100) return 100; return v.setScale(1); }
}
