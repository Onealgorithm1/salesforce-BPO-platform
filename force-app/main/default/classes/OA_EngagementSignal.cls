/**
 * OA_EngagementSignal
 * Engagement Resolution Engine (ERE) Phase 1 - normalized, source-agnostic
 * representation of a single engagement signal (inbound email reply, meeting event).
 * Pure value object: NO DML, NO SOQL. Never mutates any Salesforce record.
 */
public with sharing class OA_EngagementSignal {

    public String signalType;        // 'Email Reply' | 'Meeting Event'
    public String direction;         // 'Inbound' | 'Outbound'
    public Id sourceRecordId;        // originating EmailMessage.Id or Event.Id
    public String partyEmail;        // external counterpart email (if known)
    public String partyDomain;       // domain of partyEmail
    public String subject;
    public Datetime occurredAt;
    public Boolean internalMislink;  // Event linked only to an internal party / no prospect

    public OA_EngagementSignal() {
        this.internalMislink = false;
    }

    /** Extract lowercase domain from an email address, or null. */
    public static String domainOf(String email) {
        if (String.isBlank(email) || !email.contains('@')) return null;
        return email.substringAfterLast('@').trim().toLowerCase();
    }

    /** Build a signal from an EmailMessage (reads fields only). */
    public static OA_EngagementSignal fromEmailMessage(EmailMessage em) {
        OA_EngagementSignal s = new OA_EngagementSignal();
        s.signalType = 'Email Reply';
        s.direction = (em.Incoming == true) ? 'Inbound' : 'Outbound';
        s.sourceRecordId = em.Id;
        s.partyEmail = em.FromAddress;
        s.partyDomain = domainOf(em.FromAddress);
        s.subject = em.Subject;
        s.occurredAt = em.MessageDate;
        return s;
    }

    /** Build a signal from an Event (reads fields only). */
    public static OA_EngagementSignal fromEvent(Event ev) {
        OA_EngagementSignal s = new OA_EngagementSignal();
        s.signalType = 'Meeting Event';
        s.direction = 'Inbound';
        s.sourceRecordId = ev.Id;
        s.subject = ev.Subject;
        s.occurredAt = ev.ActivityDateTime;
        return s;
    }
}