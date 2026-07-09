/**
 * OA_PartnerIntelligence — AI knowledge enrichment for PARTNER capability profiles (Program 024B).
 *
 * Reuses OA_AI_Gateway (OpenRouter, logged) + the OA_Company_Profile__c object (Knowledge Foundation) to
 * turn a partner into a living intelligence profile: AI summary / strengths / weaknesses / gaps. Keyed by
 * Company Profile Id (partners are not CRM Accounts, so this complements OA_KnowledgeIntelligence's
 * Account-keyed enrichment without duplicating the object). Grounded — never fabricates capabilities;
 * missing data goes under GAPS. Callout-before-DML, one gateway call per transaction. Governed: updates
 * only the partner profile; no Opportunity, no CRM writes.
 */
public with sharing class OA_PartnerIntelligence {

    public static OA_Company_Profile__c enrichProfile(Id profileId) {
        OA_Company_Profile__c p = [SELECT Id, Organization_Name__c, Profile_Type__c, Capabilities__c, Technology_Stack__c,
            NAICS_Codes__c, Socioeconomic_Status__c, Certifications__c, Past_Performance__c, Knowledge_Completeness__c
            FROM OA_Company_Profile__c WHERE Id = :profileId LIMIT 1];

        String facts = String.join(new List<String>{
            'PARTNER KNOWLEDGE FACTS (source of truth; may be sparse):',
            '- Name: ' + p.Organization_Name__c,
            '- Relationship: ' + p.Profile_Type__c,
            '- Capabilities on file: ' + (p.Capabilities__c != null ? p.Capabilities__c.abbreviate(600) : 'none recorded'),
            '- Technology stack: ' + (p.Technology_Stack__c != null ? p.Technology_Stack__c.abbreviate(300) : 'none recorded'),
            '- NAICS: ' + (p.NAICS_Codes__c != null ? p.NAICS_Codes__c : 'unknown'),
            '- Socioeconomic: ' + (p.Socioeconomic_Status__c != null ? p.Socioeconomic_Status__c : 'unknown'),
            '- Certifications: ' + (p.Certifications__c != null ? p.Certifications__c.abbreviate(300) : 'none recorded'),
            '- Past performance: ' + (p.Past_Performance__c != null ? p.Past_Performance__c.abbreviate(400) : 'none recorded')
        }, '\n');

        String prompt = 'You are a federal capture analyst assessing a TEAMING PARTNER for One Algorithm (an EDWOSB AI/BPO/Salesforce firm). '
            + 'Using ONLY the facts below, produce EXACTLY these four sections, each starting with its marker on its own line:\n'
            + '===SUMMARY=== a 2-4 sentence partner profile for teaming decisions\n'
            + '===STRENGTHS=== bullet the credible teaming strengths supported by the facts\n'
            + '===WEAKNESSES=== bullet limitations evident from the facts\n'
            + '===GAPS=== bullet the MISSING data to collect to make this partner decision-grade (capabilities, past performance, certs, vehicles, resumes, agency experience)\n'
            + 'Do not invent capabilities or past performance not in the facts; when unknown, say so under GAPS.\n\n' + facts;

        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Partner_Intelligence_Summary', prompt, 'Partner_Intelligence', null);
        Map<String, String> sec = parse(r.text);
        p.AI_Company_Summary__c = pick(sec, 'SUMMARY', r);
        p.AI_Strengths__c = pick(sec, 'STRENGTHS', r);
        p.AI_Weaknesses__c = pick(sec, 'WEAKNESSES', r);
        p.AI_Gaps__c = pick(sec, 'GAPS', r);
        p.AI_Provider__c = r.provider;
        p.AI_Model__c = r.model;
        p.AI_Total_Tokens__c = r.totalTokens;
        p.AI_Estimated_Cost__c = r.estimatedCost;
        p.Last_AI_Refresh__c = System.now();
        update p;   // partner profile only
        return p;
    }

    private static String pick(Map<String, String> sec, String key, OA_AI_Gateway.GatewayResult r) {
        String v = sec.get(key);
        if (String.isNotBlank(v)) return v;
        if (!r.success) return '[AI unavailable: ' + (r.failureReason != null ? r.failureReason.abbreviate(160) : 'unknown') + ']';
        return null;
    }
    private static Map<String, String> parse(String raw) {
        Map<String, String> out = new Map<String, String>{ 'SUMMARY'=>null,'STRENGTHS'=>null,'WEAKNESSES'=>null,'GAPS'=>null };
        if (String.isBlank(raw)) return out;
        List<String> keys = new List<String>{ 'SUMMARY','STRENGTHS','WEAKNESSES','GAPS' };
        Boolean anyMarker = false;
        for (String k : keys) if (raw.contains('===' + k + '===')) anyMarker = true;
        if (!anyMarker) { out.put('SUMMARY', raw.trim()); return out; }
        for (Integer i = 0; i < keys.size(); i++) {
            String m = '===' + keys[i] + '==='; Integer st = raw.indexOf(m);
            if (st < 0) continue; st += m.length();
            Integer en = raw.length();
            for (Integer j = 0; j < keys.size(); j++) { Integer n = raw.indexOf('===' + keys[j] + '===', st); if (n >= 0 && n < en) en = n; }
            out.put(keys[i], raw.substring(st, en).trim());
        }
        return out;
    }
}
