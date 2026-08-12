public inherited sharing class OA_UnsubscribeTokenService {
    public static final String ACTION_CAMPAIGN_UNSUBSCRIBE = 'Campaign Unsubscribe';
    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_USED = 'Used';
    public static final String STATUS_EXPIRED = 'Expired';
    public static final String STATUS_REVOKED = 'Revoked';

    public class TokenException extends Exception {}

    public class TokenCreationResult {
        public String rawToken;
        public Id tokenId;
        public String tokenHash;
    }

    public class TokenValidationResult {
        public Boolean isValid = false;
        public String eventType = 'Invalid Token';
        public String message;
        public OA_Communication_Preference_Token__c token;
    }

    /** One token to mint. Used by the bulk path so the send loop does no per-recipient DML. */
    public class TokenRequest {
        public Id leadId;
        public Id campaignId;
        public Id campaignMemberId;
        public String email;
        public Datetime expiresAt;

        public TokenRequest(Id leadId, Id campaignId, Id campaignMemberId, String email, Datetime expiresAt) {
            this.leadId           = leadId;
            this.campaignId       = campaignId;
            this.campaignMemberId = campaignMemberId;
            this.email            = email;
            this.expiresAt        = expiresAt;
        }

        public Boolean isComplete() {
            return leadId != null && campaignId != null && campaignMemberId != null
                   && String.isNotBlank(email);
        }
    }

    /**
     * Bulk mint — ONE insert for the whole batch, keyed by campaignMemberId.
     *
     * This exists because the single-record method was being called inside OA_EmailSender's
     * send loop, one insert per recipient. Apex caps DML at 150 statements per transaction, so
     * a batch above ~50 rolled the whole run back — a run that appeared to work and silently
     * sent nothing. That is the sole reason MAX_SYNC_BATCH was pinned at 50 in both schedulers.
     *
     * Incomplete requests are skipped rather than thrown, and partial-success insert means one
     * bad row cannot fail the batch. Either way the member is simply absent from the returned
     * map, and the caller already treats a missing token as "use the legacy fallback link" —
     * so a recipient never ships a raw placeholder.
     */
    public static Map<Id, TokenCreationResult> createCampaignUnsubscribeTokens(List<TokenRequest> reqs) {
        Map<Id, TokenCreationResult> out = new Map<Id, TokenCreationResult>();
        if (reqs == null || reqs.isEmpty()) return out;

        List<OA_Communication_Preference_Token__c> records = new List<OA_Communication_Preference_Token__c>();
        List<TokenCreationResult>                  pending = new List<TokenCreationResult>();
        List<Id>                                   keys    = new List<Id>();

        for (TokenRequest r : reqs) {
            if (r == null || !r.isComplete()) continue;

            String rawToken  = generateRawToken();
            String tokenHash = hashToken(rawToken);

            records.add(new OA_Communication_Preference_Token__c(
                Token_Hash__c       = tokenHash,
                Lead__c             = r.leadId,
                Campaign__c         = r.campaignId,
                CampaignMember__c   = String.valueOf(r.campaignMemberId),
                Email__c            = r.email,
                Normalized_Email__c = OA_CommPreferenceService.normalizeEmail(r.email),
                Action__c           = ACTION_CAMPAIGN_UNSUBSCRIBE,
                Status__c           = STATUS_ACTIVE,
                Created_At__c       = System.now(),
                Expires_At__c       = r.expiresAt,
                Use_Count__c        = 0
            ));

            TokenCreationResult res = new TokenCreationResult();
            res.rawToken  = rawToken;
            res.tokenHash = tokenHash;
            pending.add(res);
            keys.add(r.campaignMemberId);
        }
        if (records.isEmpty()) return out;

        List<Database.SaveResult> saves = Database.insert(records, false);
        for (Integer i = 0; i < saves.size(); i++) {
            if (!saves[i].isSuccess()) {
                System.debug('[OA_UnsubscribeTokenService] token insert failed for CampaignMember '
                    + keys[i] + ': ' + saves[i].getErrors()[0].getMessage());
                continue;
            }
            pending[i].tokenId = records[i].Id;
            out.put(keys[i], pending[i]);
        }
        return out;
    }

    public static TokenCreationResult createCampaignUnsubscribeToken(
        Id leadId,
        Id campaignId,
        Id campaignMemberId,
        String email,
        Datetime expiresAt
    ) {
        if (leadId == null) {
            throw new TokenException('LeadId is required for Phase 1 unsubscribe tokens.');
        }
        if (campaignId == null) {
            throw new TokenException('CampaignId is required for Phase 1 unsubscribe tokens.');
        }
        if (campaignMemberId == null) {
            throw new TokenException('CampaignMemberId is required for Phase 1 unsubscribe tokens.');
        }
        if (String.isBlank(email)) {
            throw new TokenException('Email is required for Phase 1 unsubscribe tokens.');
        }

        // Single-record convenience wrapper. Keeps the throwing contract its existing callers
        // rely on; the bulk path is where the work actually happens.
        Map<Id, TokenCreationResult> minted = createCampaignUnsubscribeTokens(
            new List<TokenRequest>{
                new TokenRequest(leadId, campaignId, campaignMemberId, email, expiresAt)
            }
        );
        TokenCreationResult result = minted.get(campaignMemberId);
        if (result == null) {
            throw new TokenException(
                'Unsubscribe token insert failed for CampaignMember ' + campaignMemberId + '.'
            );
        }
        return result;
    }

    public static TokenValidationResult validateToken(String rawToken) {
        if (String.isBlank(rawToken)) {
            TokenValidationResult blank = new TokenValidationResult();
            blank.message = 'Token is blank.';
            return blank;
        }
        return validateTokenByHash(hashToken(rawToken));
    }

    public static TokenValidationResult validateTokenByHash(String tokenHash) {
        TokenValidationResult result = new TokenValidationResult();
        if (String.isBlank(tokenHash)) {
            result.message = 'Token hash is blank.';
            return result;
        }

        List<OA_Communication_Preference_Token__c> tokens = [
            SELECT Id, Token_Hash__c, Lead__c, Campaign__c, CampaignMember__c,
                   Email__c, Normalized_Email__c, Action__c, Status__c,
                   Created_At__c, Expires_At__c, Last_Used_At__c, Use_Count__c,
                   Last_Audit__c
            FROM OA_Communication_Preference_Token__c
            WHERE Token_Hash__c = :tokenHash
            LIMIT 1
        ];

        if (tokens.isEmpty()) {
            result.message = 'No matching token was found.';
            return result;
        }

        OA_Communication_Preference_Token__c token = tokens[0];
        result.token = token;

        if (token.Status__c == STATUS_REVOKED) {
            result.eventType = 'Revoked Token';
            result.message = 'Token is revoked.';
            return result;
        }
        if (token.Status__c == STATUS_EXPIRED ||
            (token.Expires_At__c != null && token.Expires_At__c < System.now())) {
            result.eventType = 'Expired Token';
            result.message = 'Token is expired.';
            return result;
        }
        if (token.Action__c != ACTION_CAMPAIGN_UNSUBSCRIBE) {
            result.eventType = 'Invalid Token';
            result.message = 'Token action is not supported by Phase 1.';
            return result;
        }
        if (token.Lead__c == null || token.Campaign__c == null || String.isBlank(token.CampaignMember__c)) {
            result.eventType = 'Invalid Token';
            result.message = 'Token is missing required Phase 1 context.';
            return result;
        }
        if (token.Status__c != STATUS_ACTIVE && token.Status__c != STATUS_USED) {
            result.eventType = 'Invalid Token';
            result.message = 'Token status is not usable.';
            return result;
        }

        result.isValid = true;
        result.eventType = 'Unsubscribe Requested';
        result.message = 'Token is valid.';
        return result;
    }

    @TestVisible
    private static String generateRawToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256)).toLowerCase();
    }

    @TestVisible
    public static String hashToken(String rawToken) {
        if (String.isBlank(rawToken)) {
            return null;
        }
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(rawToken))
        ).toLowerCase();
    }
}