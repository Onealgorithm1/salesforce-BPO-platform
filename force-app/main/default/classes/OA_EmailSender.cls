public class OA_EmailSender {

    private static final Integer MAX_INVOCABLE_REQUESTS = 50;

    // Transient unsubscribe injection (Option 1 — no persisted Lead field).
    private static final String  PLACEHOLDER   = '%%OA_UNSUBSCRIBE_URL%%';
    private static final String  UNSUB_BASE    =
        'https://onealgorithmllc.my.site.com/OAvforcesite/services/apexrest/oa/unsubscribe';
    private static final String  LEGACY_FALLBACK =
        'mailto:lrubino@onealgorithm.com?subject=UNSUBSCRIBE';
    private static final Integer TOKEN_TTL_DAYS = 90;

    @TestVisible private static Boolean bypassActualSendForTest = false;
    // Test seams so the render/inject/token path is covered without a stored template.
    @TestVisible private static String testSubjectOverride;
    @TestVisible private static String testHtmlOverride;
    @TestVisible private static String testTextOverride;
    @TestVisible private static List<Messaging.SingleEmailMessage> lastBuiltEmails;

    public class EmailSendException extends Exception {}

    public class EmailRequest {
        @InvocableVariable(required=true label='Lead Id')
        public String leadId;
        @InvocableVariable(required=true label='Email Template API Name')
        public String templateApiName;
        @InvocableVariable(required=true label='Org Wide Email Address Id')
        public String orgWideEmailAddressId;
        @InvocableVariable(required=true label='Campaign Id')
        public String campaignId;
        @InvocableVariable(required=true label='Campaign Member Id')
        public String campaignMemberId;
    }

    @InvocableMethod(
        label='OA Send Template Email to Lead'
        description='Renders a deployed HTML email template for a Lead, injects a tokenized HTTPS unsubscribe link, and sends it.'
    )
    public static void sendEmailToLead(List<EmailRequest> requests) {
        if (requests != null && requests.size() > MAX_INVOCABLE_REQUESTS) {
            throw new EmailSendException(
                'OA_EmailSender received ' + requests.size()
                + ' requests; max safe synchronous batch size is ' + MAX_INVOCABLE_REQUESTS + '.'
            );
        }

        Map<String, Boolean> results = sendEmailToLeadWithResults(requests);
        if (requests == null || requests.isEmpty()) return;

        Boolean allSent = results.size() == requests.size();
        for (Boolean sent : results.values()) {
            if (sent != true) { allSent = false; break; }
        }

        if (!allSent) {
            throw new EmailSendException(
                'OA_EmailSender could not send every requested email. CampaignMember status was not advanced.'
            );
        }
    }

    /**
     * Returns leadId -> true/false per-send result.
     * Called by OA_FollowUpScheduler so it can advance status only on success.
     */
    public static Map<String, Boolean> sendEmailToLeadWithResults(List<EmailRequest> requests) {
        Map<String, Boolean> results = new Map<String, Boolean>();
        if (requests == null || requests.isEmpty()) return results;

        for (EmailRequest req : requests) {
            if (req != null && String.isNotBlank(req.leadId)) results.put(req.leadId, false);
        }

        Integer allowed;
        try {
            allowed = OA_SendGovernor.checkAndReserve(requests.size());
        } catch (OA_SendGovernor.CapExceededException e) {
            System.debug('[OA_EmailSender] ' + e.getMessage());
            return results;
        }

        // Early test bypass: skip template/render/send entirely (used by scheduler/flow tests
        // that run SeeAllData=false and have no visible stored templates).
        if (Test.isRunningTest() && bypassActualSendForTest) {
            Integer marked = 0;
            for (EmailRequest req : requests) {
                if (req == null || String.isBlank(req.leadId)) continue;
                if (marked >= allowed) break;
                results.put(req.leadId, true);
                marked++;
            }
            return results;
        }

        // Resolve template ids (skipped in test-seam mode where no stored template exists).
        Map<String, Id> tplMap = new Map<String, Id>();
        if (testHtmlOverride == null) {
            Set<String> names = new Set<String>();
            for (EmailRequest req : requests) {
                if (req != null && String.isNotBlank(req.templateApiName)) names.add(req.templateApiName);
            }
            for (EmailTemplate t : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :names]) {
                tplMap.put(t.DeveloperName, t.Id);
            }
        }

        // One SOQL for recipient emails (needed to mint campaign-scoped tokens).
        Set<Id> leadIdSet = new Set<Id>();
        for (EmailRequest req : requests) {
            if (req != null && String.isNotBlank(req.leadId)) leadIdSet.add((Id) req.leadId);
        }
        Map<Id, String> emailByLead = new Map<Id, String>();
        for (Lead l : [SELECT Id, Email FROM Lead WHERE Id IN :leadIdSet]) {
            emailByLead.put(l.Id, l.Email);
        }

        List<Messaging.SingleEmailMessage> emails  = new List<Messaging.SingleEmailMessage>();
        List<String>                        leadIds = new List<String>();

        Integer count = 0;
        for (EmailRequest req : requests) {
            if (req == null || String.isBlank(req.leadId)) continue;
            if (count >= allowed) break;
            if (testHtmlOverride == null && !tplMap.containsKey(req.templateApiName)) {
                System.debug('[OA_EmailSender] Template not found: ' + req.templateApiName);
                continue;
            }

            Messaging.SingleEmailMessage rendered =
                renderTemplate(tplMap.get(req.templateApiName), req.leadId);

            String link = buildUnsubscribeLink(req, emailByLead.get((Id) req.leadId));
            String html = rendered.getHtmlBody();
            String text = rendered.getPlainTextBody();
            if (html != null) html = html.replace(PLACEHOLDER, link);
            if (text != null) text = text.replace(PLACEHOLDER, link);

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(req.leadId);
            msg.setOrgWideEmailAddressId(req.orgWideEmailAddressId);
            msg.setTreatTargetObjectAsRecipient(true);
            msg.setSaveAsActivity(true);
            if (rendered.getSubject() != null) msg.setSubject(rendered.getSubject());
            if (html != null) msg.setHtmlBody(html);
            if (text != null) msg.setPlainTextBody(text);

            emails.add(msg);
            leadIds.add(req.leadId);
            count++;
        }

        lastBuiltEmails = emails;
        if (emails.isEmpty()) return results;

        List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(emails, false);

        List<Task> failTasks = new List<Task>();
        for (Integer i = 0; i < sendResults.size(); i++) {
            String lid = leadIds[i];
            if (sendResults[i].isSuccess()) {
                results.put(lid, true);
            } else {
                String err = sendResults[i].getErrors().isEmpty()
                    ? 'Unknown error'
                    : sendResults[i].getErrors()[0].getMessage();
                System.debug('[OA_EmailSender] Send failed ' + lid + ': ' + err);
                results.put(lid, false);
                failTasks.add(new Task(
                    Subject = 'Email Send Failed', Description = err, WhoId = lid,
                    Status = 'Completed', Priority = 'High', ActivityDate = Date.today()
                ));
            }
        }
        if (!failTasks.isEmpty()) insert failTasks;

        return results;
    }

    /**
     * Builds the tokenized HTTPS unsubscribe URL using the existing token service.
     * Falls back to the legacy mailto link if campaign context or email is missing,
     * so a raw placeholder is never shipped.
     */
    private static String buildUnsubscribeLink(EmailRequest req, String email) {
        if (String.isBlank(req.campaignId) || String.isBlank(req.campaignMemberId) || String.isBlank(email)) {
            return LEGACY_FALLBACK;
        }
        try {
            OA_UnsubscribeTokenService.TokenCreationResult tok =
                OA_UnsubscribeTokenService.createCampaignUnsubscribeToken(
                    req.leadId, req.campaignId, req.campaignMemberId, email,
                    System.now().addDays(TOKEN_TTL_DAYS)
                );
            return UNSUB_BASE + '?t=' + EncodingUtil.urlEncode(tok.rawToken, 'UTF-8');
        } catch (Exception e) {
            System.debug('[OA_EmailSender] Token mint failed for ' + req.leadId + ': ' + e.getMessage());
            return LEGACY_FALLBACK;
        }
    }

    /** Renders a stored template; uses a test seam so the inject path is coverable. */
    private static Messaging.SingleEmailMessage renderTemplate(Id templateId, Id leadId) {
        if (Test.isRunningTest() && testHtmlOverride != null) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            if (testSubjectOverride != null) m.setSubject(testSubjectOverride);
            m.setHtmlBody(testHtmlOverride);
            if (testTextOverride != null) m.setPlainTextBody(testTextOverride);
            return m;
        }
        return Messaging.renderStoredEmailTemplate(templateId, leadId, null);
    }
}
