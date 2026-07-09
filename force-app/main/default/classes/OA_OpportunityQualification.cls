/**
 * OA_OpportunityQualification — business-feasibility qualification intelligence (Program 024A).
 *
 * Upgrades eligibility (OA_ComplianceScreen) to a WINNABILITY decision: matches an opportunity's domain
 * against One Algorithm's capability profile and against partner capability profiles (Knowledge
 * Foundation), then decides GO / GO WITH PARTNER / TEAMING / MONITOR / REVIEW REQUIRED / NO-GO with a
 * recommended partner + role + fit/effort/urgency scores + capability gaps. Deterministic + auditable
 * (no AI in the decision). Writes only qualification fields on the review-queue candidate; never an
 * Opportunity; all outputs remain advisory (Review_Status stays Pending).
 */
public with sharing class OA_OpportunityQualification {

    // One Algorithm capability domain (from the Self profile + defensible synonyms).
    private static final Set<String> SELF_DOMAIN = new Set<String>{
        'ai','artificial','intelligence','bpo','business','process','outsourcing','salesforce','crm',
        'platform','engineering','automation','software','technology','tech','digital','it','information',
        'data','analytics','enrichment','systems','cloud','integration','application','portal','innovation',
        'federal','development','lead','entity','resolution','cx','support','helpdesk','servicenow'
    };
    private static final Set<String> STOP = new Set<String>{
        'the','and','for','of','to','a','an','in','on','with','by','or','at','from','program','services',
        'service','grant','opportunity','annual','fy','2026','2027','2025','statement','notice','request',
        'inc','llc','department','u','s'
    };

    public class PartnerCap { public String name; public Set<String> keywords; public String socio; public Decimal completeness; }

    public static void qualify(List<Id> signalIds) {
        if (signalIds == null || signalIds.isEmpty()) return;

        // Self capability keywords
        Set<String> selfKw = new Set<String>(SELF_DOMAIN);
        Set<String> selfSocio = new Set<String>();
        for (OA_Company_Profile__c p : [SELECT Capabilities__c, Technology_Stack__c, Socioeconomic_Status__c
                FROM OA_Company_Profile__c WHERE Profile_Type__c='Self' AND Status__c='Active' LIMIT 1]) {
            selfKw.addAll(tokens(p.Capabilities__c));
            selfKw.addAll(tokens(p.Technology_Stack__c));
            if (String.isNotBlank(p.Socioeconomic_Status__c))
                for (String s : p.Socioeconomic_Status__c.split('[,;/]')) selfSocio.add(s.trim().toUpperCase());
        }

        // Partner capability profiles
        List<PartnerCap> partners = new List<PartnerCap>();
        for (OA_Company_Profile__c p : [SELECT Organization_Name__c, Capabilities__c, Socioeconomic_Status__c, Knowledge_Completeness__c
                FROM OA_Company_Profile__c WHERE Profile_Type__c != 'Self' AND Status__c='Active']) {
            PartnerCap pc = new PartnerCap();
            pc.name = p.Organization_Name__c;
            pc.keywords = tokens(p.Capabilities__c);
            pc.socio = (p.Socioeconomic_Status__c == null) ? '' : p.Socioeconomic_Status__c.toUpperCase();
            pc.completeness = p.Knowledge_Completeness__c;
            partners.add(pc);
        }

        List<OA_Opportunity_Signal__c> sigs = [SELECT Id, Title__c, Agency__c, NAICS__c, Set_Aside__c, Response_Deadline__c,
            Estimated_Value__c, Compliance_Decision__c FROM OA_Opportunity_Signal__c WHERE Id IN :signalIds];

        for (OA_Opportunity_Signal__c s : sigs) {
            Set<String> oppKw = tokens((s.Title__c == null ? '' : s.Title__c) + ' ' + (s.Agency__c == null ? '' : s.Agency__c));
            oppKw.removeAll(STOP);

            // capability fit = share of opportunity keywords One Algorithm covers
            Integer covered = 0; List<String> gaps = new List<String>();
            for (String k : oppKw) { if (selfKw.contains(k)) covered++; else gaps.add(k); }
            Decimal selfFit = oppKw.isEmpty() ? 0 : clamp((Decimal.valueOf(covered) / oppKw.size()) * 100);

            // best partner covering the gaps (or providing a needed set-aside)
            String recPartner = null; Decimal bestGapCover = 0; String neededSocio = requiredSocio(s.Set_Aside__c);
            String socioPartner = null;
            for (PartnerCap pc : partners) {
                Integer g = 0; for (String k : gaps) if (pc.keywords.contains(k)) g++;
                Decimal cover = gaps.isEmpty() ? 0 : (Decimal.valueOf(g) / gaps.size()) * 100;
                if (cover > bestGapCover) { bestGapCover = cover; recPartner = pc.name; }
                if (neededSocio != null && pc.socio != null && pc.socio.contains(neededSocio)) socioPartner = pc.name;
            }

            // urgency from deadline
            Decimal urgency = 50;
            if (s.Response_Deadline__c != null) {
                Integer d = Date.today().daysBetween(s.Response_Deadline__c);
                urgency = d <= 0 ? 95 : d <= 14 ? 90 : d <= 30 ? 80 : d <= 60 ? 60 : d <= 90 ? 45 : 30;
            }

            String decision, role; List<String> why = new List<String>();
            Boolean eligible = (s.Compliance_Decision__c == null || s.Compliance_Decision__c == 'GO' || s.Compliance_Decision__c == 'CONDITIONAL GO');

            if (oppKw.isEmpty()) {
                decision = 'REVIEW REQUIRED'; role = 'N/A'; why.add('Insufficient opportunity text to qualify.');
            } else if (!eligible && s.Compliance_Decision__c == 'NO-GO') {
                if (socioPartner != null) { decision='TEAMING'; role='Subcontractor'; recPartner=socioPartner;
                    why.add('Set-aside "'+s.Set_Aside__c+'" requires a status One Algorithm lacks; team under qualifying partner '+socioPartner+'.'); }
                else { decision='NO-GO'; role='N/A';
                    why.add('Set-aside "'+s.Set_Aside__c+'" is ineligible and no qualifying teaming partner is on file.'); }
            } else if (selfFit >= 55) {
                decision='GO'; role='Prime';
                why.add('Strong capability match ('+selfFit+'%) to One Algorithm'+(selfSocio.contains('EDWOSB')?' (EDWOSB)':'')+'; pursue as prime.');
            } else if (selfFit < 25) {
                if (bestGapCover >= 50 && recPartner != null) { decision='GO WITH PARTNER'; role='Teaming';
                    why.add('Outside One Algorithm core capability ('+selfFit+'%); partner '+recPartner+' covers ~'+bestGapCover.setScale(0)+'% of the domain — pursue jointly.'); }
                else { decision='NO-GO'; role='N/A';
                    why.add('Outside One Algorithm capability ('+selfFit+'%) and no partner covers the domain.'); }
            } else { // 25..55 marginal
                if (bestGapCover >= 40 && recPartner != null) { decision='GO WITH PARTNER'; role='Teaming';
                    why.add('Marginal self-fit ('+selfFit+'%); partner '+recPartner+' strengthens the bid.'); }
                else { decision='MONITOR'; role='Monitor';
                    why.add('Marginal capability fit ('+selfFit+'%); monitor for a stronger match or partner.'); }
            }

            Decimal fit = clamp(Math.max(selfFit, bestGapCover));
            Decimal effort = clamp(100 - fit + (s.Estimated_Value__c != null && s.Estimated_Value__c > 1000000 ? 15 : 0));

            s.Qualification_Decision__c = decision;
            s.Recommended_Role__c = role;
            s.Recommended_Partner__c = recPartner;
            s.Fit_Score__c = fit;
            s.Effort_Score__c = effort;
            s.Urgency_Score__c = urgency;
            s.Capability_Gaps__c = gaps.isEmpty() ? 'none (fully covered)' : String.join(gaps, ', ').abbreviate(32000);
            s.Qualification_Rationale__c = (String.join(why, ' ')
                + ' [self-fit '+selfFit+'%, partner-gap-cover '+bestGapCover.setScale(0)+'%, urgency '+urgency+'; advisory — human decides]').abbreviate(32000);
        }
        update sigs;   // qualification fields only — never an Opportunity; Review_Status untouched (Pending)
    }

    // ----- helpers -----
    private static Set<String> tokens(String s) {
        Set<String> out = new Set<String>();
        if (String.isBlank(s)) return out;
        for (String t : s.toLowerCase().split('[^a-z0-9]+')) { if (t.length() >= 2 && !STOP.contains(t)) out.add(t); }
        return out;
    }
    private static String requiredSocio(String setAside) {
        if (String.isBlank(setAside)) return null;
        String u = setAside.toUpperCase();
        if (u.contains('SDVOSB') || u.contains('SERVICE-DISABLED')) return 'SDVOSB';
        if (u.contains('8(A)') || u.contains('8A')) return '8(A)';
        if (u.contains('HUBZONE')) return 'HUBZONE';
        return null;
    }
    private static Decimal clamp(Decimal v) { if (v == null || v < 0) return 0; if (v > 100) return 100; return v.setScale(1); }
}
