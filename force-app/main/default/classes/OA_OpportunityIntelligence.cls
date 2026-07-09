/**
 * OA_OpportunityIntelligence — Enterprise Opportunity Intelligence engine (Program 020).
 *
 * Produces a governed, explainable pursuit assessment for ONE CRM Opportunity:
 *   - DETERMINISTIC scores (0-100) computed from Salesforce data only — auditable, no AI decisioning.
 *   - AI NARRATIVE (executive brief, next best action, capability gap, partner rec, risk) via the
 *     certified OA_AI_Gateway (OpenRouter default, Anthropic fallback) — every call logged with
 *     tokens/cost/latency to OA_AI_Request_Log__c. The model EXPLAINS; it never sets the scores.
 *
 * GOVERNANCE (ADR-018): recommend-only. Writes exactly ONE OA_Opportunity_Intelligence__c record in
 * Status 'Draft'. NEVER writes to Opportunity/Account/Campaign, never creates Opportunities, never
 * sends anything external. A human reviews the Draft and decides. Callout-before-DML.
 */
public with sharing class OA_OpportunityIntelligence {

    public class OIException extends Exception {}

    /** Generate + persist a Draft assessment for one Opportunity. Returns the inserted record. */
    public static OA_Opportunity_Intelligence__c generate(Id opportunityId) {
        if (opportunityId == null) throw new OIException('opportunityId is required');

        // ---- 1. Gather Opportunity + lineage (read-only) ----
        Opportunity opp = [
            SELECT Id, Name, StageName, Amount, Probability, CloseDate, LeadSource, IsClosed, IsWon,
                   AccountId, Account.Name, Account.Industry, CampaignId, Campaign.Name, Description
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];

        Integer contactRoles = [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :opportunityId];
        Integer events = 0, openTasks = 0, closedTasks = 0;
        Set<Id> whatIds = new Set<Id>{ opportunityId };
        if (opp.AccountId != null) whatIds.add(opp.AccountId);
        for (AggregateResult ar : [SELECT COUNT(Id) c FROM Event WHERE WhatId IN :whatIds]) events = (Integer) ar.get('c');
        for (Task t : [SELECT IsClosed FROM Task WHERE WhatId IN :whatIds]) { if (t.IsClosed) closedTasks++; else openTasks++; }

        Integer campaignResponded = 0, campaignMeetings = 0;
        if (opp.CampaignId != null) {
            for (CampaignMember cm : [SELECT Status, HasResponded FROM CampaignMember WHERE CampaignId = :opp.CampaignId]) {
                if (cm.HasResponded == true) campaignResponded++;
                if (cm.Status == 'Meeting Booked') campaignMeetings++;
            }
        }

        // ---- 2. Deterministic scores (auditable; AI never sets these) ----
        List<String> audit = new List<String>();
        Decimal sourceQ = scoreSource(opp.LeadSource, audit);
        Decimal campaignSig = clamp((opp.CampaignId != null ? 40 : 0) + Math.min(campaignMeetings * 12, 40) + Math.min(campaignResponded, 20));
        audit.add('Campaign Signal=' + campaignSig + ' (campaign linked=' + (opp.CampaignId != null) + ', meetings=' + campaignMeetings + ', responded=' + campaignResponded + ')');
        Decimal meetingSig = clamp(Math.min(events * 25, 70) + Math.min((closedTasks + openTasks) * 3, 30));
        audit.add('Meeting Signal=' + meetingSig + ' (events=' + events + ', tasks=' + (openTasks + closedTasks) + ')');
        Decimal relStrength = clamp(Math.min(contactRoles * 30, 60) + Math.min(events * 8, 20) + (opp.AccountId != null ? 20 : 0));
        audit.add('Relationship Strength=' + relStrength + ' (contactRoles=' + contactRoles + ', events=' + events + ', account=' + (opp.AccountId != null) + ')');

        // Data completeness across the fields that matter to a pursuit decision
        Integer haveCount = 0, totalCount = 6;
        if (opp.Amount != null) haveCount++;
        if (opp.CloseDate != null) haveCount++;
        if (contactRoles > 0) haveCount++;
        if (opp.CampaignId != null) haveCount++;
        if (events > 0) haveCount++;
        if (String.isNotBlank(opp.LeadSource)) haveCount++;
        Decimal completeness = clamp((Decimal.valueOf(haveCount) / totalCount) * 100);
        audit.add('Data Completeness=' + completeness + '% (' + haveCount + '/' + totalCount + ' key fields)');

        Decimal urgency = scoreUrgency(opp.CloseDate, opp.StageName, audit);
        Decimal winProb = clamp((opp.Probability != null ? opp.Probability : 10) * 0.6 + (relStrength * 0.2) + (campaignSig * 0.2));
        audit.add('Win Probability=' + winProb + ' (native prob=' + opp.Probability + ', relationship+campaign adjusted)');

        Boolean teaming = (opp.Name != null && opp.Name.toLowerCase().contains('teaming'))
            || (opp.LeadSource == 'SAM.gov');

        // Consume the Enterprise Knowledge Foundation (Program 021): our own (Self) capability profile
        // and the counterparty's partner profile drive Capability/Partner Match when they exist.
        List<OA_Company_Profile__c> selfP = [
            SELECT Capabilities__c, Socioeconomic_Status__c, Knowledge_Completeness__c
            FROM OA_Company_Profile__c WHERE Profile_Type__c = 'Self' AND Status__c = 'Active'
            ORDER BY Knowledge_Completeness__c DESC NULLS LAST LIMIT 1
        ];
        OA_Company_Profile__c selfProfile = selfP.isEmpty() ? null : selfP[0];
        List<OA_Company_Profile__c> partP = (opp.AccountId == null) ? new List<OA_Company_Profile__c>() : [
            SELECT Capabilities__c, Past_Performance__c, Knowledge_Completeness__c
            FROM OA_Company_Profile__c WHERE Account__c = :opp.AccountId LIMIT 1
        ];
        OA_Company_Profile__c partnerProfile = partP.isEmpty() ? null : partP[0];

        Decimal capabilityMatch;
        if (selfProfile != null && String.isNotBlank(selfProfile.Capabilities__c)) {
            Decimal comp = selfProfile.Knowledge_Completeness__c != null ? selfProfile.Knowledge_Completeness__c : 0;
            capabilityMatch = clamp(50 + comp * 0.4);
            audit.add('Capability Match=' + capabilityMatch + ' (Knowledge Foundation: Self capability profile on file, completeness ' + comp + '%)');
        } else {
            capabilityMatch = clamp(teaming ? 55 : 60);
            audit.add('Capability Match=' + capabilityMatch + ' (heuristic — no Self company profile yet)');
        }
        Decimal partnerMatch;
        if (partnerProfile != null) {
            Decimal comp = partnerProfile.Knowledge_Completeness__c != null ? partnerProfile.Knowledge_Completeness__c : 0;
            partnerMatch = clamp(45 + comp * 0.4);
            audit.add('Partner Match=' + partnerMatch + ' (Knowledge Foundation: partner profile linked, completeness ' + comp + '%)');
        } else {
            partnerMatch = clamp(teaming ? 50 : 40);
            audit.add('Partner Match=' + partnerMatch + ' (heuristic — no partner company profile yet)');
        }

        Decimal pursuitFit = clamp(sourceQ * 0.30 + campaignSig * 0.25 + relStrength * 0.20 + meetingSig * 0.15 + capabilityMatch * 0.10);
        audit.add('Pursuit Fit=' + pursuitFit + ' (weighted: source .30, campaign .25, relationship .20, meeting .15, capability .10)');

        // Risk rises with missing data, no contact role, no amount, stalled early stage
        Decimal risk = clamp((100 - completeness) * 0.5 + (contactRoles == 0 ? 20 : 0) + (opp.Amount == null ? 15 : 0) + (events == 0 ? 15 : 0));
        audit.add('Risk=' + risk + ' (incompleteness, missing contact role/amount/meetings)');

        Decimal composite = clamp(pursuitFit * 0.45 + winProb * 0.25 + urgency * 0.15 + (100 - risk) * 0.15);
        audit.add('Composite=' + composite + ' (pursuitFit .45, winProb .25, urgency .15, inverse-risk .15)');

        String confidence = completeness >= 70 ? 'High' : (completeness >= 40 ? 'Medium' : 'Low');
        String effort = (capabilityMatch >= 70 && risk < 40) ? 'Low' : (risk >= 60 ? 'High' : 'Medium');
        String action = recommendAction(composite, urgency, completeness, risk);

        // ---- 3. AI narrative via the certified gateway (grounded in the facts above) ----
        String facts = buildFacts(opp, contactRoles, events, openTasks + closedTasks, campaignMeetings, campaignResponded,
            pursuitFit, winProb, composite, risk, urgency, completeness, teaming);
        // Ground the narrative in the Knowledge Foundation when profiles exist
        if (selfProfile != null && String.isNotBlank(selfProfile.Capabilities__c)) {
            facts += '\n- OUR (One Algorithm) capabilities on file: ' + selfProfile.Capabilities__c.abbreviate(400);
            if (String.isNotBlank(selfProfile.Socioeconomic_Status__c)) facts += '\n- OUR socioeconomic status: ' + selfProfile.Socioeconomic_Status__c;
        }
        if (partnerProfile != null && String.isNotBlank(partnerProfile.Capabilities__c)) {
            facts += '\n- Counterparty capabilities on file: ' + partnerProfile.Capabilities__c.abbreviate(400);
        }

        // ONE gateway call (callout-before-DML: the gateway logs after its callout, so a single call
        // per transaction is required). Structured multi-section response, parsed by markers.
        AiAgg ai = new AiAgg();
        String prompt = 'You are a federal business-development strategist. Using ONLY the facts below, produce a pursuit '
            + 'assessment with EXACTLY these five sections, each starting with its marker on its own line:\n'
            + '===BRIEF=== a 4-6 sentence executive brief (what it is, why it matters, overall recommendation)\n'
            + '===NBA=== the single most valuable next best action (1-3 concrete steps for this week)\n'
            + '===GAP=== likely capability gaps and what evidence (past performance, certs, resumes) is missing\n'
            + '===PARTNER=== should One Algorithm prime or sub, and the ideal partner profile (capabilities/socioeconomic)\n'
            + '===RISK=== top 2-3 risks and how to mitigate them\n'
            + 'Do not invent facts; if something is unknown, say so.\n\n' + facts;
        String raw = ask(ai, 'Opportunity_Intelligence', prompt, opportunityId);
        Map<String, String> sec = parseSections(raw);
        String brief   = sec.get('BRIEF');
        String nba     = sec.get('NBA');
        String gap     = sec.get('GAP');
        String partner = sec.get('PARTNER');
        String riskN   = sec.get('RISK');

        // ---- 4. Assemble ONE Draft record (governance: no Opportunity write) ----
        OA_Opportunity_Intelligence__c oi = new OA_Opportunity_Intelligence__c(
            Opportunity__c = opportunityId,
            Status__c = 'Draft',
            Generated_Date__c = System.now(),
            Pursuit_Fit_Score__c = pursuitFit,
            Win_Probability_Score__c = winProb,
            Capability_Match__c = capabilityMatch,
            Partner_Match__c = partnerMatch,
            Relationship_Strength__c = relStrength,
            Campaign_Signal__c = campaignSig,
            Meeting_Signal__c = meetingSig,
            Source_Quality__c = sourceQ,
            Risk_Score__c = risk,
            Urgency_Score__c = urgency,
            Composite_Score__c = composite,
            Data_Completeness__c = completeness,
            Revenue_Potential__c = opp.Amount,
            Effort_Estimate__c = effort,
            Confidence__c = confidence,
            Recommended_Action__c = action,
            Score_Rationale__c = String.join(audit, '\n'),
            AI_Executive_Brief__c = brief,
            AI_Next_Best_Action__c = nba,
            AI_Capability_Gap__c = gap,
            AI_Partner_Recommendation__c = partner,
            AI_Risk_Assessment__c = riskN,
            AI_Provider__c = ai.provider,
            AI_Model__c = ai.model,
            AI_Total_Tokens__c = ai.tokens,
            AI_Estimated_Cost__c = ai.cost,
            AI_Latency_Ms__c = ai.latency
        );
        insert oi;   // exactly one record, Draft; human reviews
        return oi;
    }

    // ----- AI helper (routes through the gateway, aggregates telemetry, never fails silently) -----
    private class AiAgg { String provider; String model; Decimal tokens = 0; Decimal cost = 0; Decimal latency = 0; Integer calls = 0; }

    private static String ask(AiAgg agg, String workflow, String prompt, Id recordId) {
        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete(workflow, prompt, 'Opportunity_Intelligence', recordId);
        agg.calls++;
        if (r.provider != null) agg.provider = r.provider;
        if (r.model != null) agg.model = r.model;
        agg.tokens += (r.totalTokens != null ? r.totalTokens : 0);
        agg.cost += (r.estimatedCost != null ? r.estimatedCost : 0);
        agg.latency += (r.latencyMs != null ? r.latencyMs : 0);
        if (!r.success) {
            return '[AI unavailable for ' + workflow + ': ' + (r.failureReason != null ? r.failureReason.abbreviate(160) : 'unknown') + ']';
        }
        return r.text;
    }

    /** Split the single AI response into its five marked sections; whole text falls back to BRIEF. */
    private static Map<String, String> parseSections(String raw) {
        Map<String, String> out = new Map<String, String>{ 'BRIEF' => null, 'NBA' => null, 'GAP' => null, 'PARTNER' => null, 'RISK' => null };
        if (String.isBlank(raw)) return out;
        List<String> keys = new List<String>{ 'BRIEF', 'NBA', 'GAP', 'PARTNER', 'RISK' };
        Boolean anyMarker = false;
        for (String k : keys) if (raw.contains('===' + k + '===')) anyMarker = true;
        if (!anyMarker) { out.put('BRIEF', raw.trim()); return out; }
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

    private static String buildFacts(Opportunity o, Integer contactRoles, Integer events, Integer tasks,
            Integer campMeetings, Integer campResponded, Decimal fit, Decimal win, Decimal comp,
            Decimal risk, Decimal urgency, Decimal completeness, Boolean teaming) {
        return String.join(new List<String>{
            'OPPORTUNITY FACTS (source of truth):',
            '- Name: ' + o.Name,
            '- Account: ' + (o.Account != null ? o.Account.Name : 'none') + (o.Account != null && o.Account.Industry != null ? ' (industry ' + o.Account.Industry + ')' : ''),
            '- Stage: ' + o.StageName + ' | Native probability: ' + o.Probability + '%',
            '- Amount: ' + (o.Amount != null ? '$' + o.Amount : 'not set'),
            '- Close date: ' + o.CloseDate,
            '- Lead source: ' + o.LeadSource + (teaming ? ' (federal/teaming context)' : ''),
            '- Campaign: ' + (o.Campaign != null ? o.Campaign.Name : 'none') + ' | campaign meetings booked: ' + campMeetings + ' | responders: ' + campResponded,
            '- Contact roles: ' + contactRoles + ' | meetings/events: ' + events + ' | activities/tasks: ' + tasks,
            'DETERMINISTIC SCORES (0-100, computed from the above): pursuitFit=' + fit + ', winProbability=' + win + ', composite=' + comp + ', risk=' + risk + ', urgency=' + urgency + ', dataCompleteness=' + completeness + '%'
        }, '\n');
    }

    // ----- deterministic scoring helpers -----
    private static Decimal scoreSource(String src, List<String> audit) {
        Decimal s;
        if (src == null) s = 30;
        else if (src == 'SAM.gov' || src == 'Grants.gov') s = 88;          // governed federal signal
        else if (src == 'Referral' || src == 'Partner') s = 80;
        else if (src == 'Web' || src == 'Website') s = 50;
        else s = 45;
        audit.add('Source Quality=' + s + ' (LeadSource=' + src + ')');
        return s;
    }

    private static Decimal scoreUrgency(Date closeDate, String stage, List<String> audit) {
        Decimal u = 50;
        if (closeDate != null) {
            Integer days = Date.today().daysBetween(closeDate);
            if (days <= 0) u = 90;
            else if (days <= 30) u = 85;
            else if (days <= 60) u = 70;
            else if (days <= 90) u = 55;
            else u = 35;
        }
        audit.add('Urgency=' + u + ' (closeDate=' + closeDate + ', stage=' + stage + ')');
        return u;
    }

    private static String recommendAction(Decimal composite, Decimal urgency, Decimal completeness, Decimal risk) {
        if (completeness < 40) return 'Qualify Further';
        if (composite >= 65 && urgency >= 60) return 'Pursue Now';
        if (composite >= 65) return 'Pursue Now';
        if (risk >= 65) return 'Escalate to Human';
        if (composite >= 45) return 'Nurture';
        return 'Deprioritize';
    }

    private static Decimal clamp(Decimal v) {
        if (v == null) return 0;
        if (v < 0) return 0;
        if (v > 100) return 100;
        return v.setScale(1);
    }
}