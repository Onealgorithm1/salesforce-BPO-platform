public with sharing class OA_CommPreferenceService {
    public static final String CHANNEL_EMAIL = 'Email';
    public static final String SCOPE_CAMPAIGN = 'Campaign';
    public static final String STATUS_UNSUBSCRIBED = 'Unsubscribed';
    public static final String SOURCE_HTTPS_LINK = 'HTTPS Link';
    public static final String RESULT_SUCCESS = 'Success';
    public static final String RESULT_NO_CHANGE = 'No Change';
    public static final String RESULT_REJECTED = 'Rejected';
    public static final String RESULT_ERROR = 'Error';

    public class UnsubscribeResult {
        public Boolean success = false;
        public Boolean noChange = false;
        public Id auditId;
        public Id preferenceId;
        public Id tokenId;
        public Id leadId;
        public Id campaignMemberId;
        public String message;
    }

    public static UnsubscribeResult unsubscribeByToken(String rawToken, String requestMetadata) {
        OA_UnsubscribeTokenService.TokenValidationResult validation =
            OA_UnsubscribeTokenService.validateToken(rawToken);

        if (!validation.isValid) {
            return recordRejectedAttempt(validation, requestMetadata);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            return applyValidUnsubscribe(validation.token, requestMetadata);
        } catch (Exception e) {
            Database.rollback(sp);
            return recordProcessingError(validation.token, requestMetadata, e);
        }
    }

    private static UnsubscribeResult applyValidUnsubscribe(
        OA_Communication_Preference_Token__c token,
        String requestMetadata
    ) {
        Datetime nowValue = System.now();
        Lead lead = [
            SELECT Id, Email, HasOptedOutOfEmail
            FROM Lead
            WHERE Id = :token.Lead__c
            LIMIT 1
        ];
        CampaignMember cm = [
            SELECT Id, Status, LeadId, CampaignId
            FROM CampaignMember
            WHERE Id = :token.CampaignMember__c
            LIMIT 1
        ];

        Boolean priorLeadOptOut = lead.HasOptedOutOfEmail;
        String priorCmStatus = cm.Status;
        Boolean changedLead = false;
        Boolean changedCampaignMember = false;

        if (!lead.HasOptedOutOfEmail) {
            update new Lead(Id = lead.Id, HasOptedOutOfEmail = true);
            changedLead = true;
        }

        if (cm.Status != STATUS_UNSUBSCRIBED) {
            update new CampaignMember(Id = cm.Id, Status = STATUS_UNSUBSCRIBED);
            changedCampaignMember = true;
        }

        String email = String.isNotBlank(token.Email__c) ? token.Email__c : lead.Email;
        String normalizedEmail = normalizeEmail(
            String.isNotBlank(token.Normalized_Email__c) ? token.Normalized_Email__c : email
        );
        String preferenceKey = buildPreferenceKey(lead.Id, normalizedEmail, token.Campaign__c);

        OA_Communication_Preference__c preference = new OA_Communication_Preference__c(
            Preference_Key__c = preferenceKey,
            Lead__c = lead.Id,
            Campaign__c = token.Campaign__c,
            CampaignMember__c = String.valueOf(cm.Id),
            Email__c = email,
            Normalized_Email__c = normalizedEmail,
            Channel__c = CHANNEL_EMAIL,
            Scope__c = SCOPE_CAMPAIGN,
            Preference_Status__c = STATUS_UNSUBSCRIBED,
            Source__c = SOURCE_HTTPS_LINK,
            Effective_At__c = nowValue,
            Last_Event_At__c = nowValue
        );
        Database.upsert(
            new List<OA_Communication_Preference__c>{ preference },
            OA_Communication_Preference__c.Preference_Key__c,
            true
        );

        Boolean noChange = !changedLead && !changedCampaignMember;
        OA_Communication_Preference_Audit__c audit = new OA_Communication_Preference_Audit__c(
            Preference__c = preference.Id,
            Token__c = token.Id,
            Lead__c = lead.Id,
            Campaign__c = token.Campaign__c,
            CampaignMember__c = String.valueOf(cm.Id),
            Email__c = email,
            Normalized_Email__c = normalizedEmail,
            Channel__c = CHANNEL_EMAIL,
            Event_Type__c = noChange ? 'Already Unsubscribed' : 'Unsubscribe Requested',
            Prior_Lead_Opt_Out__c = priorLeadOptOut,
            New_Lead_Opt_Out__c = true,
            Prior_CampaignMember_Status__c = priorCmStatus,
            New_CampaignMember_Status__c = STATUS_UNSUBSCRIBED,
            Source__c = SOURCE_HTTPS_LINK,
            Result__c = noChange ? RESULT_NO_CHANGE : RESULT_SUCCESS,
            Occurred_At__c = nowValue,
            Message__c = noChange ? 'Unsubscribe request was already applied.' : 'Unsubscribe request applied.',
            Request_Metadata__c = limitLongText(requestMetadata)
        );
        insert audit;

        stampTokenAttempt(token, audit.Id, true, false);

        UnsubscribeResult result = new UnsubscribeResult();
        result.success = true;
        result.noChange = noChange;
        result.auditId = audit.Id;
        result.preferenceId = preference.Id;
        result.tokenId = token.Id;
        result.leadId = lead.Id;
        result.campaignMemberId = cm.Id;
        result.message = audit.Message__c;
        return result;
    }

    private static UnsubscribeResult recordRejectedAttempt(
        OA_UnsubscribeTokenService.TokenValidationResult validation,
        String requestMetadata
    ) {
        Datetime nowValue = System.now();
        OA_Communication_Preference_Token__c token = validation.token;

        OA_Communication_Preference_Audit__c audit = new OA_Communication_Preference_Audit__c(
            Token__c = token != null ? token.Id : null,
            Lead__c = token != null ? token.Lead__c : null,
            Campaign__c = token != null ? token.Campaign__c : null,
            CampaignMember__c = token != null ? token.CampaignMember__c : null,
            Email__c = token != null ? token.Email__c : null,
            Normalized_Email__c = token != null ? token.Normalized_Email__c : null,
            Channel__c = CHANNEL_EMAIL,
            Event_Type__c = validation.eventType,
            Source__c = SOURCE_HTTPS_LINK,
            Result__c = RESULT_REJECTED,
            Occurred_At__c = nowValue,
            Message__c = limitLongText(validation.message),
            Request_Metadata__c = limitLongText(requestMetadata)
        );
        insert audit;

        if (token != null) {
            stampTokenAttempt(token, audit.Id, false, validation.eventType == 'Expired Token');
        }

        UnsubscribeResult result = new UnsubscribeResult();
        result.success = false;
        result.noChange = true;
        result.auditId = audit.Id;
        result.tokenId = token != null ? token.Id : null;
        result.leadId = token != null ? token.Lead__c : null;
        result.campaignMemberId = token != null ? toId(token.CampaignMember__c) : null;
        result.message = validation.message;
        return result;
    }

    private static UnsubscribeResult recordProcessingError(
        OA_Communication_Preference_Token__c token,
        String requestMetadata,
        Exception e
    ) {
        OA_Communication_Preference_Audit__c audit = new OA_Communication_Preference_Audit__c(
            Token__c = token != null ? token.Id : null,
            Lead__c = token != null ? token.Lead__c : null,
            Campaign__c = token != null ? token.Campaign__c : null,
            CampaignMember__c = token != null ? token.CampaignMember__c : null,
            Email__c = token != null ? token.Email__c : null,
            Normalized_Email__c = token != null ? token.Normalized_Email__c : null,
            Channel__c = CHANNEL_EMAIL,
            Event_Type__c = 'Error',
            Source__c = SOURCE_HTTPS_LINK,
            Result__c = RESULT_ERROR,
            Occurred_At__c = System.now(),
            Message__c = limitLongText(e.getMessage()),
            Request_Metadata__c = limitLongText(requestMetadata)
        );
        insert audit;

        if (token != null) {
            stampTokenAttempt(token, audit.Id, false, false);
        }

        UnsubscribeResult result = new UnsubscribeResult();
        result.success = false;
        result.noChange = true;
        result.auditId = audit.Id;
        result.tokenId = token != null ? token.Id : null;
        result.leadId = token != null ? token.Lead__c : null;
        result.campaignMemberId = token != null ? toId(token.CampaignMember__c) : null;
        result.message = e.getMessage();
        return result;
    }

    private static void stampTokenAttempt(
        OA_Communication_Preference_Token__c token,
        Id auditId,
        Boolean markUsed,
        Boolean markExpired
    ) {
        Decimal priorUseCount = token.Use_Count__c == null ? 0 : token.Use_Count__c;
        OA_Communication_Preference_Token__c updateToken =
            new OA_Communication_Preference_Token__c(
                Id = token.Id,
                Last_Used_At__c = System.now(),
                Use_Count__c = priorUseCount + 1,
                Last_Audit__c = auditId
            );
        if (markUsed) {
            updateToken.Status__c = OA_UnsubscribeTokenService.STATUS_USED;
        } else if (markExpired) {
            updateToken.Status__c = OA_UnsubscribeTokenService.STATUS_EXPIRED;
        }
        update updateToken;
    }

    @TestVisible
    public static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    @TestVisible
    public static String buildPreferenceKey(Id leadId, String normalizedEmail, Id campaignId) {
        String rawKey = String.valueOf(leadId) + '|' +
            normalizeEmail(normalizedEmail) + '|Email|' +
            (campaignId == null ? 'GLOBAL' : String.valueOf(campaignId));
        return 'EMAIL-' + EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(rawKey))
        ).toLowerCase();
    }

    private static String limitLongText(String value) {
        if (value == null) {
            return null;
        }
        return value.length() > 32768 ? value.left(32768) : value;
    }

    private static Id toId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception e) {
            return null;
        }
    }
}
