/**
 * OA_KnowledgeIntelligence — Enterprise Knowledge Foundation service (Program 021).
 *
 * Builds/refreshes the canonical living intelligence profile (OA_Company_Profile__c) for an
 * organization by reusing identity from Account + OA_Discovered_Organization__c, computing a
 * deterministic knowledge-completeness score, and generating AI narrative (company summary,
 * strengths, weaknesses, gaps) through the certified OA_AI_Gateway (OpenRouter default, logged).
 *
 * GOVERNANCE: writes exactly ONE OA_Company_Profile__c (upsert by Account). Never writes Account,
 * Opportunity, or anything external. AI produces narrative + confidence only — never business facts
 * it cannot ground. One gateway call per transaction (gateway logs after its callout).
 */
public with sharing class OA_KnowledgeIntelligence {

    public class KnowledgeException extends Exception {}

    /** Build or refresh the Company Profile for a CRM Account. Returns the upserted profile. */
    public static OA_Company_Profile__c profile(Id accountId) {
        if (accountId == null) throw new KnowledgeException('accountId is required');

        Account acc = [SELECT Id, Name, Industry, BillingState, BillingCity FROM Account WHERE Id = :accountId LIMIT 1];

        // Reuse identity/enrichment from a matched discovered organization, if any
        List<OA_Discovered_Organization__c> discs = [
            SELECT Id, Organization_Name__c, NAICS__c, UEI__c, CAGE_Code__c, State__c, City__c, Website__c, Confidence_Score__c
            FROM OA_Discovered_Organization__c WHERE Matched_Account__c = :accountId
            ORDER BY LastModifiedDate DESC LIMIT 1
        ];
        OA_Discovered_Organization__c disc = discs.isEmpty() ? null : discs[0];

        // Existing profile? (upsert one per account)
        List<OA_Company_Profile__c> existing = [
            SELECT Id, Capabilities__c, Technology_Stack__c, NAICS_Codes__c, PSC_Codes__c, Socioeconomic_Status__c,
                   Certifications__c, Past_Performance__c, Agencies_Served__c, Contract_Vehicles__c, Prime_Experience__c,
                   Industries__c, Profile_Type__c, Organization_Name__c, Status__c
            FROM OA_Company_Profile__c WHERE Account__c = :accountId LIMIT 1
        ];
        OA_Company_Profile__c p = existing.isEmpty() ? new OA_Company_Profile__c(Account__c = accountId) : existing[0];

        // Identity (reuse; do not fabricate)
        p.Organization_Name__c = acc.Name;
        if (disc != null) {
            p.Discovered_Organization__c = disc.Id;
            if (String.isBlank(p.NAICS_Codes__c)) p.NAICS_Codes__c = disc.NAICS__c;
        }
        if (String.isBlank(p.Industries__c) && String.isNotBlank(acc.Industry)) p.Industries__c = acc.Industry;
        if (String.isBlank(p.Profile_Type__c)) {
            p.Profile_Type__c = (acc.Name != null && acc.Name.toLowerCase().contains('one algorithm')) ? 'Self' : 'Partner';
        }

        // ---- deterministic knowledge completeness (auditable) ----
        List<String> present = new List<String>();
        Integer have = 0, total = 9;
        if (String.isNotBlank(p.Capabilities__c)) { have++; present.add('capabilities'); }
        if (String.isNotBlank(p.Technology_Stack__c)) { have++; present.add('tech stack'); }
        if (String.isNotBlank(p.NAICS_Codes__c)) { have++; present.add('NAICS'); }
        if (String.isNotBlank(p.Socioeconomic_Status__c)) { have++; present.add('socioeconomic'); }
        if (String.isNotBlank(p.Certifications__c)) { have++; present.add('certifications'); }
        if (String.isNotBlank(p.Past_Performance__c)) { have++; present.add('past performance'); }
        if (String.isNotBlank(p.Agencies_Served__c)) { have++; present.add('agencies'); }
        if (String.isNotBlank(p.Contract_Vehicles__c)) { have++; present.add('vehicles'); }
        if (String.isNotBlank(p.Prime_Experience__c)) { have++; present.add('prime experience'); }
        Decimal completeness = ((Decimal.valueOf(have) / total) * 100).setScale(1);
        p.Knowledge_Completeness__c = completeness;
        p.Knowledge_Confidence__c = completeness >= 60 ? 'High' : (completeness >= 30 ? 'Medium' : 'Low');

        // ---- AI narrative via gateway (grounded; one call) ----
        String facts = String.join(new List<String>{
            'ORGANIZATION KNOWLEDGE FACTS (source of truth; may be sparse):',
            '- Name: ' + acc.Name,
            '- Profile type: ' + p.Profile_Type__c,
            '- Industry: ' + (acc.Industry != null ? acc.Industry : 'unknown'),
            '- NAICS: ' + (p.NAICS_Codes__c != null ? p.NAICS_Codes__c : 'unknown'),
            '- Socioeconomic status: ' + (p.Socioeconomic_Status__c != null ? p.Socioeconomic_Status__c : 'unknown'),
            '- Capabilities on file: ' + (p.Capabilities__c != null ? p.Capabilities__c.abbreviate(500) : 'none recorded'),
            '- Past performance on file: ' + (p.Past_Performance__c != null ? p.Past_Performance__c.abbreviate(500) : 'none recorded'),
            '- Certifications on file: ' + (p.Certifications__c != null ? p.Certifications__c.abbreviate(300) : 'none recorded'),
            '- Identity enrichment present: ' + (disc != null ? ('UEI/CAGE/NAICS from discovery, confidence ' + disc.Confidence_Score__c) : 'none'),
            '- Knowledge completeness: ' + completeness + '% (' + have + '/' + total + ' knowledge dimensions populated)'
        }, '\n');

        String prompt = 'You are a federal capture/knowledge analyst building a living company intelligence profile. '
            + 'Using ONLY the facts below, produce EXACTLY these four sections, each starting with its marker on its own line:\n'
            + '===SUMMARY=== a 3-5 sentence profile of the organization for business-development use\n'
            + '===STRENGTHS=== bullet the credible strengths supported by the facts\n'
            + '===WEAKNESSES=== bullet weaknesses/limitations evident from the facts\n'
            + '===GAPS=== bullet the MISSING knowledge that should be collected to make this profile decision-grade (be specific: which capabilities, past performance, certs, resumes, vehicles are absent)\n'
            + 'Do not invent capabilities or past performance that are not in the facts; when data is missing, say so and put it under GAPS.\n\n' + facts;

        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Knowledge_Company_Summary', prompt, 'Knowledge_Foundation', accountId);
        Map<String, String> sec = parseSections(r.text);
        p.AI_Company_Summary__c = section(sec, 'SUMMARY', r);
        p.AI_Strengths__c = section(sec, 'STRENGTHS', r);
        p.AI_Weaknesses__c = section(sec, 'WEAKNESSES', r);
        p.AI_Gaps__c = section(sec, 'GAPS', r);
        p.AI_Provider__c = r.provider;
        p.AI_Model__c = r.model;
        p.AI_Total_Tokens__c = r.totalTokens;
        p.AI_Estimated_Cost__c = r.estimatedCost;
        p.Last_AI_Refresh__c = System.now();
        if (String.isBlank(p.Status__c)) p.Status__c = 'Active';

        upsert p;   // exactly one profile per account
        return p;
    }

    private static String section(Map<String, String> sec, String key, OA_AI_Gateway.GatewayResult r) {
        String v = sec.get(key);
        if (String.isNotBlank(v)) return v;
        if (!r.success) return '[AI unavailable: ' + (r.failureReason != null ? r.failureReason.abbreviate(160) : 'unknown') + ']';
        return null;
    }

    private static Map<String, String> parseSections(String raw) {
        Map<String, String> out = new Map<String, String>{ 'SUMMARY' => null, 'STRENGTHS' => null, 'WEAKNESSES' => null, 'GAPS' => null };
        if (String.isBlank(raw)) return out;
        List<String> keys = new List<String>{ 'SUMMARY', 'STRENGTHS', 'WEAKNESSES', 'GAPS' };
        Boolean anyMarker = false;
        for (String k : keys) if (raw.contains('===' + k + '===')) anyMarker = true;
        if (!anyMarker) { out.put('SUMMARY', raw.trim()); return out; }
        for (Integer i = 0; i < keys.size(); i++) {
            String marker = '===' + keys[i] + '===';
            Integer start = raw.indexOf(marker);
            if (start < 0) continue;
            start += marker.length();
            Integer endIdx = raw.length();
            for (Integer j = 0; j < keys.size(); j++) {
                Integer n = raw.indexOf('===' + keys[j] + '===', start);
                if (n >= 0 && n < endIdx) endIdx = n;
            }
            out.put(keys[i], raw.substring(start, endIdx).trim());
        }
        return out;
    }
}
