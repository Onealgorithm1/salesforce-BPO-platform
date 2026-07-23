/**
 * OA_MatchFallback — shared domain-fallback matching for reply detection (OA_ReplyStatusService)
 * and booking-attendee matching (OA_BookingPoller).
 *
 * Both paths first try an EXACT address match against a campaign Lead. When that misses — a
 * colleague replying from a different mailbox, or a prospect booking from a shared company
 * address (it happened: info@sulphoor.com vs a gmail lead) — this helper attempts a DOMAIN
 * match instead, but never auto-confirms. A single sendable candidate is flagged
 * 'Reply - Unverified' (a stop status) for human confirmation; anything ambiguous is alert-only.
 *
 * ponytail: the freemail/ISP blocklist is a static Set, edited-and-redeployed. Ceiling — if ops
 * need to change it without a deploy, promote to a custom metadata type (OA_Freemail_Domain__mdt).
 */
public with sharing class OA_MatchFallback {

    // Status set on a single domain-only match. Added to every STOP_STATUSES set so the
    // sequence halts the moment a member is flagged, pending human verification.
    public static final String UNVERIFIED_STATUS = 'Reply - Unverified';

    // Consumer/ISP domains where a shared domain does NOT imply the same organization.
    // gmail is here on purpose: Pheelamillo's lead is gmail, so his class of case can never be
    // auto-matched by domain — it must go to the visible alert path.
    public static final Set<String> FREEMAIL = new Set<String>{
        'gmail.com', 'googlemail.com', 'yahoo.com', 'ymail.com', 'yahoo.co.uk',
        'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'aol.com',
        'icloud.com', 'me.com', 'mac.com', 'comcast.net', 'verizon.net',
        'att.net', 'sbcglobal.net', 'bellsouth.net', 'cox.net', 'charter.net',
        'gmx.com', 'protonmail.com', 'proton.me', 'zoho.com', 'zoominternet.net',
        'mail.com', 'ymail.com', 'pm.me', 'hotmail.co.uk', 'outlook.co.uk'
    };

    /** Lowercased domain after the last '@', or null when the input is not an address. */
    public static String domainOf(String email) {
        if (String.isBlank(email) || !email.contains('@')) return null;
        return email.substringAfterLast('@').trim().toLowerCase();
    }

    /** True when the address is on a shared consumer/ISP domain (no org can be inferred). */
    public static Boolean isFreemail(String email) {
        String d = domainOf(email);
        return d != null && FREEMAIL.contains(d);
    }

    /**
     * Sendable CampaignMembers in `campaignId` whose Lead email shares the domain of `email`,
     * EXCLUDING the exact address itself (handled by the exact path) and freemail domains.
     * Returns empty for blank/freemail input so callers fall through to the alert-only path.
     */
    public static List<CampaignMember> candidatesByDomain(String email, Id campaignId, Set<String> stopStatuses) {
        String dom = domainOf(email);
        if (dom == null || FREEMAIL.contains(dom)) return new List<CampaignMember>();

        String likeDomain = '%@' + dom;
        String lowerEmail  = email.toLowerCase();
        List<CampaignMember> out = new List<CampaignMember>();
        for (CampaignMember cm : [
            SELECT Id, Status, LeadId, Lead.Email
            FROM CampaignMember
            WHERE CampaignId = :campaignId
              AND LeadId != null
              AND Status NOT IN :stopStatuses
              AND Lead.Email LIKE :likeDomain
        ]) {
            if (cm.Lead.Email != null && cm.Lead.Email.toLowerCase() != lowerEmail) {
                out.add(cm);
            }
        }
        return out;
    }
}
