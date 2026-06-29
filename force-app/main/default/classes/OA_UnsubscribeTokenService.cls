public with sharing class OA_UnsubscribeTokenService {
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

        String rawToken = generateRawToken();
        String tokenHash = hashToken(rawToken);

        OA_Communication_Preference_Token__c tokenRecord = new OA_Communication_Preference_Token__c(
            Token_Hash__c = tokenHash,
            Lead__c = leadId,
            Campaign__c = campaignId,
            CampaignMember__c = String.valueOf(campaignMemberId),
            Email__c = email,
            Normalized_Email__c = OA_CommPreferenceService.normalizeEmail(email),
            Action__c = ACTION_CAMPAIGN_UNSUBSCRIBE,
            Status__c = STATUS_ACTIVE,
            Created_At__c = System.now(),
            Expires_At__c = expiresAt,
            Use_Count__c = 0
        );
        insert tokenRecord;

        TokenCreationResult result = new TokenCreationResult();
        result.rawToken = rawToken;
        result.tokenId = tokenRecord.Id;
        result.tokenHash = tokenHash;
        return result;
    }

    public static TokenValidationResult validateToken(String rawToken) {
        TokenValidationResult result = new TokenValidationResult();
        if (String.isBlank(rawToken)) {
            result.message = 'Token is blank.';
            return result;
        }

        String tokenHash = hashToken(rawToken);
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
