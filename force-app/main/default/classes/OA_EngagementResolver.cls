/**
 * OA_EngagementResolver
 * Engagement Resolution Engine (ERE) Phase 1 - OBSERVE / SHADOW LOG ONLY.
 *
 * Reads EmailMessage / Event / Lead / Contact / CampaignMember to classify each
 * engagement signal against a deterministic matching hierarchy (L1 exact Lead
 * email, L2 Contact email, L3 corporate domain, L6 human review), then writes an
 * auditable OA_Engagement_Resolution__c row.
 *
 * HARD GUARANTEE: the ONLY object this class ever writes is
 * OA_Engagement_Resolution__c. It never inserts/updates/deletes Lead, Contact,
 * CampaignMember, Event, EmailMessage, Task, or any campaign record. No auto-apply,
 * no Contact creation, no status changes to prospect records.
 */
public with sharing class OA_EngagementResolver {

    private final OA_Engagement_Config__mdt cfg;

    /** Test hook: set to inject a config without a deployed CMDT record. */
    @TestVisible private static OA_Engagement_Config__mdt overrideCfg;

    public OA_EngagementResolver() {
        this.cfg = loadConfig();
    }

    @TestVisible
    private OA_EngagementResolver(OA_Engagement_Config__mdt injected) {
        this.cfg = injected;
    }

    // ------------------------------------------------------------------ config
    private static OA_Engagement_Config__mdt loadConfig() {
        if (overrideCfg != null) return overrideCfg;
        for (OA_Engagement_Config__mdt c : OA_Engagement_Config__mdt.getAll().values()) {
            if (c.Active__c == true) return c;
        }
        // Safe built-in default (observe-only, all levels on) if no record is deployed.
        OA_Engagement_Config__mdt d = new OA_Engagement_Config__mdt();
        d.Observe_Only__c = true;
        d.Enable_L1__c = true; d.Enable_L2__c = true; d.Enable_L3__c = true; d.Enable_L6_Review__c = true;
        d.Free_Domains__c = 'gmail.com,yahoo.com,hotmail.com,outlook.com,aol.com,icloud.com';
        d.Internal_Domain__c = 'onealgorithm.com';
        return d;
    }

    // --------------------------------------------------------------- entry pts
    /** Observe inbound emails (reads fields only; safe with in-memory records). */
    public Integer observeEmails(List<EmailMessage> emails) {
        List<OA_EngagementSignal> sigs = new List<OA_EngagementSignal>();
        if (emails != null) {
            for (EmailMessage em : emails) {
                if (em.Incoming == true) sigs.add(OA_EngagementSignal.fromEmailMessage(em));
            }
        }
        return observeAndLog(sigs);
    }

    /** Observe meeting Events and flag internal mislinks. */
    public Integer observeEvents(List<Event> events) {
        List<OA_EngagementSignal> sigs = new List<OA_EngagementSignal>();
        if (events == null || events.isEmpty()) return observeAndLog(sigs);

        Set<Id> whoIds = new Set<Id>();
        for (Event ev : events) {
            if (ev.WhoId != null && ev.WhoId.getSobjectType() == Contact.SObjectType) whoIds.add(ev.WhoId);
        }
        Map<Id, Contact> whoContacts = whoIds.isEmpty()
            ? new Map<Id, Contact>()
            : new Map<Id, Contact>([SELECT Id, Email FROM Contact WHERE Id IN :whoIds]);

        String internalDomain = (cfg.Internal_Domain__c == null) ? '' : cfg.Internal_Domain__c.toLowerCase();

        for (Event ev : events) {
            OA_EngagementSignal s = OA_EngagementSignal.fromEvent(ev);
            Boolean internal = (ev.WhatId == null);
            if (ev.WhoId != null && whoContacts.containsKey(ev.WhoId)) {
                String cdom = OA_EngagementSignal.domainOf(whoContacts.get(ev.WhoId).Email);
                if (cdom != null && cdom == internalDomain) internal = true;
            }
            s.internalMislink = internal;
            sigs.add(s);
        }
        return observeAndLog(sigs);
    }

    /** Build resolutions and persist them to the shadow log ONLY. */
    public Integer observeAndLog(List<OA_EngagementSignal> signals) {
        List<OA_Engagement_Resolution__c> recs = buildResolutions(signals);
        if (!recs.isEmpty()) {
            insert recs; // <-- the ONLY DML in ERE Phase 1, on the shadow object only
        }
        return recs.size();
    }

    // -------------------------------------------------------------- resolution
    /** Pure classification: returns shadow-log rows, performs NO DML. */
    public List<OA_Engagement_Resolution__c> buildResolutions(List<OA_EngagementSignal> signals) {
        List<OA_Engagement_Resolution__c> out = new List<OA_Engagement_Resolution__c>();
        if (signals == null || signals.isEmpty()) return out;

        Set<String> emails = new Set<String>();
        Set<String> domains = new Set<String>();
        for (OA_EngagementSignal s : signals) {
            if (String.isNotBlank(s.partyEmail)) emails.add(s.partyEmail.toLowerCase());
            if (String.isNotBlank(s.partyDomain)) domains.add(s.partyDomain.toLowerCase());
        }

        Map<String, List<Lead>> leadsByEmail = new Map<String, List<Lead>>();
        Map<String, List<Contact>> contactsByEmail = new Map<String, List<Contact>>();
        Map<String, List<Lead>> leadsByDomain = new Map<String, List<Lead>>();

        if (!emails.isEmpty()) {
            for (Lead l : [SELECT Id, Email FROM Lead WHERE IsConverted = false AND Email IN :emails]) {
                addToList(leadsByEmail, l.Email.toLowerCase(), l);
            }
            for (Contact c : [SELECT Id, Email FROM Contact WHERE Email IN :emails]) {
                addToList(contactsByEmail, c.Email.toLowerCase(), c);
            }
        }
        if (!domains.isEmpty()) {
            List<String> ors = new List<String>();
            for (String d : domains) {
                String safe = d.replaceAll('[^a-z0-9.-]', '');
                if (String.isNotBlank(safe)) ors.add('Email LIKE \'%@' + safe + '\'');
            }
            if (!ors.isEmpty()) {
                String q = 'SELECT Id, Email FROM Lead WHERE IsConverted = false AND Email != null AND ('
                    + String.join(ors, ' OR ') + ')';
                for (Lead l : Database.query(q)) {
                    addToList(leadsByDomain, OA_EngagementSignal.domainOf(l.Email), l);
                }
            }
        }

        Set<String> freeDomains = splitLower(cfg.Free_Domains__c);

        for (OA_EngagementSignal s : signals) {
            OA_Engagement_Resolution__c r = new OA_Engagement_Resolution__c();
            r.Signal_Type__c = s.signalType;
            r.Direction__c = s.direction;
            r.Source_Record_Id__c = String.valueOf(s.sourceRecordId);
            r.Party_Email__c = s.partyEmail;
            r.Party_Domain__c = s.partyDomain;
            Map<String, Object> cand = new Map<String, Object>();

            if (s.signalType == 'Meeting Event') {
                r.Internal_Mislink__c = (s.internalMislink == true);
                r.Matched_Level__c = 'L6';
                r.Confidence__c = 0;
                r.Status__c = 'Needs Review';
                cand.put('reason', r.Internal_Mislink__c
                    ? 'Event linked to internal party / no prospect (systemic mislink)'
                    : 'Event needs prospect verification');
                r.Candidate_Json__c = JSON.serialize(cand);
                out.add(r);
                continue;
            }

            String email = String.isBlank(s.partyEmail) ? null : s.partyEmail.toLowerCase();
            String dom = String.isBlank(s.partyDomain) ? null : s.partyDomain.toLowerCase();

            if (cfg.Enable_L1__c == true && email != null
                    && leadsByEmail.containsKey(email) && leadsByEmail.get(email).size() == 1) {
                r.Resolved_Lead__c = leadsByEmail.get(email)[0].Id;
                r.Matched_Level__c = 'L1'; r.Confidence__c = 1.00; r.Status__c = 'Observed';
                cand.put('L1_lead', r.Resolved_Lead__c);

            } else if (cfg.Enable_L2__c == true && email != null
                    && contactsByEmail.containsKey(email) && contactsByEmail.get(email).size() == 1) {
                r.Resolved_Contact__c = contactsByEmail.get(email)[0].Id;
                r.Matched_Level__c = 'L2'; r.Confidence__c = 0.90; r.Status__c = 'Observed';
                cand.put('L2_contact', r.Resolved_Contact__c);

            } else if (cfg.Enable_L3__c == true && dom != null && !freeDomains.contains(dom)
                    && leadsByDomain.containsKey(dom)) {
                List<Lead> dl = leadsByDomain.get(dom);
                if (dl.size() == 1) {
                    r.Resolved_Lead__c = dl[0].Id;
                    r.Matched_Level__c = 'L3'; r.Confidence__c = 0.60; r.Status__c = 'Needs Review';
                    cand.put('L3_single_lead', r.Resolved_Lead__c);
                } else {
                    List<Id> ids = new List<Id>();
                    for (Lead x : dl) ids.add(x.Id);
                    r.Matched_Level__c = 'L6'; r.Confidence__c = 0.30; r.Status__c = 'Ambiguous';
                    cand.put('L3_ambiguous_leads', ids);
                }

            } else {
                r.Matched_Level__c = 'L6';
                r.Confidence__c = 0;
                r.Status__c = (email == null) ? 'Needs Review' : 'No Match';
                cand.put('reason', 'No confident match at L1/L2/L3');
            }

            r.Candidate_Json__c = JSON.serialize(cand);
            out.add(r);
        }

        mapCampaignMembers(out);
        return out;
    }

    /** Attach the matching CampaignMember id (read-only) for resolved leads. */
    private void mapCampaignMembers(List<OA_Engagement_Resolution__c> recs) {
        if (String.isBlank(cfg.Campaign_Id__c)) return;
        Set<Id> leadIds = new Set<Id>();
        for (OA_Engagement_Resolution__c r : recs) {
            if (r.Resolved_Lead__c != null) leadIds.add(r.Resolved_Lead__c);
        }
        if (leadIds.isEmpty()) return;
        String campId = cfg.Campaign_Id__c;
        Map<Id, Id> leadToCm = new Map<Id, Id>();
        for (CampaignMember cm : [SELECT Id, LeadId FROM CampaignMember
                                  WHERE LeadId IN :leadIds AND CampaignId = :campId]) {
            leadToCm.put(cm.LeadId, cm.Id);
        }
        for (OA_Engagement_Resolution__c r : recs) {
            if (r.Resolved_Lead__c != null && leadToCm.containsKey(r.Resolved_Lead__c)) {
                r.Resolved_CampaignMember__c = leadToCm.get(r.Resolved_Lead__c);
            }
        }
    }

    // ------------------------------------------------------------------ utils
    private static void addToList(Map<String, List<Lead>> m, String k, Lead v) {
        if (k == null) return;
        if (!m.containsKey(k)) m.put(k, new List<Lead>());
        m.get(k).add(v);
    }
    private static void addToList(Map<String, List<Contact>> m, String k, Contact v) {
        if (k == null) return;
        if (!m.containsKey(k)) m.put(k, new List<Contact>());
        m.get(k).add(v);
    }
    private static Set<String> splitLower(String csv) {
        Set<String> out = new Set<String>();
        if (String.isBlank(csv)) return out;
        for (String p : csv.split(',')) {
            String t = p.trim().toLowerCase();
            if (t != '') out.add(t);
        }
        return out;
    }
}
