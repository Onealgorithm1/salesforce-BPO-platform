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
    // Count of requests dropped by the opt-out guard on the last call, so the invocable
    // can tell "deliberately suppressed" apart from "failed to send".
    @TestVisible private static Integer lastSuppressedCount = 0;
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

        // Opt-out suppression is a deliberate skip, not a failure — excluding it here keeps a
        // single opted-out Lead from throwing and blocking the rest of a legitimate batch.
        Integer expected = requests.size() - lastSuppressedCount;
        Boolean allSent  = results.size() == expected;
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
        lastSuppressedCount = 0;
        if (requests == null || requests.isEmpty()) return results;

        for (EmailRequest req : requests) {
            if (req != null && String.isNotBlank(req.leadId)) results.put(req.leadId, false);
        }

        // One SOQL for recipient emails (needed to mint campaign-scoped tokens) AND the
        // opt-out flag. The guard lives here because this is the shared choke point every
        // send path funnels through: OA_DripScheduler's own HasOptedOutOfEmail filter only
        // ever covered enrollment into its single campaign, and OA_FollowUpScheduler never
        // checked the flag at all. Checking here means no caller — including a future
        // campaign — can bypass it.
        Set<Id> leadIdSet = new Set<Id>();
        for (EmailRequest req : requests) {
            if (req != null && String.isNotBlank(req.leadId)) leadIdSet.add((Id) req.leadId);
        }
        Map<Id, String> emailByLead = new Map<Id, String>();
        Set<Id>         optedOut    = new Set<Id>();
        for (Lead l : [SELECT Id, Email, HasOptedOutOfEmail FROM Lead WHERE Id IN :leadIdSet]) {
            emailByLead.put(l.Id, l.Email);
            if (l.HasOptedOutOfEmail == true) optedOut.add(l.Id);
        }

        // Suppressed leads are dropped from the result map entirely. Reporting false would
        // strand the CampaignMember at its current status and re-send-attempt it every
        // business day forever; reporting true would fabricate a "Day N Sent" status for an
        // email that was never sent — misleading in a compliance record.
        // ponytail: suppressed members are simply left untouched, so the follow-up scheduler
        // re-reads them each run (a few SOQL rows, no send, no daily cap consumed). Upgrade
        // path — move their CampaignMember to 'Unsubscribed' so they drop out of the funnel
        // query; that is a data write and needs its own approval, not a guard.
        List<EmailRequest> sendable = new List<EmailRequest>();
        for (EmailRequest req : requests) {
            if (req == null || String.isBlank(req.leadId)) continue;
            if (optedOut.contains((Id) req.leadId)) {
                results.remove(req.leadId);
                lastSuppressedCount++;
                System.debug('[OA_EmailSender] SUPPRESSED — Lead has opted out of email: ' + req.leadId);
                continue;
            }
            sendable.add(req);
        }
        if (sendable.isEmpty()) return results;

        Integer allowed;
        try {
            allowed = OA_SendGovernor.checkAndReserve(sendable.size());
        } catch (OA_SendGovernor.CapExceededException e) {
            System.debug('[OA_EmailSender] ' + e.getMessage());
            return results;
        }

        // Early test bypass: skip template/render/send entirely (used by scheduler/flow tests
        // that run SeeAllData=false and have no visible stored templates).
        if (Test.isRunningTest() && bypassActualSendForTest) {
            Integer marked = 0;
            for (EmailRequest req : sendable) {
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
            for (EmailRequest req : sendable) {
                if (req != null && String.isNotBlank(req.templateApiName)) names.add(req.templateApiName);
            }
            for (EmailTemplate t : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :names]) {
                tplMap.put(t.DeveloperName, t.Id);
            }
        }

        List<Messaging.SingleEmailMessage> emails  = new List<Messaging.SingleEmailMessage>();
        List<String>                        leadIds = new List<String>();

        // Pass 1 — settle exactly who is being sent to, honoring the reserved cap and template
        // availability, so unsubscribe tokens are minted for those recipients and nobody else.
        // (Minting for the whole sendable list would leave orphan tokens for emails never sent,
        // and these records are a compliance trail.)
        List<EmailRequest> toSend = new List<EmailRequest>();
        for (EmailRequest req : sendable) {
            if (req == null || String.isBlank(req.leadId)) continue;
            if (toSend.size() >= allowed) break;
            if (testHtmlOverride == null && !tplMap.containsKey(req.templateApiName)) {
                System.debug('[OA_EmailSender] Template not found: ' + req.templateApiName);
                continue;
            }
            toSend.add(req);
        }
        if (toSend.isEmpty()) return results;

        // ONE insert for every unsubscribe token in this batch. This used to be one insert per
        // recipient inside the loop below, which is what pinned the safe batch size at 50 —
        // above that the 150-DML cap rolled the run back and it silently sent nothing.
        Map<Id, OA_UnsubscribeTokenService.TokenCreationResult> tokens = mintTokens(toSend, emailByLead);

        // Pass 2 — render and build.
        for (EmailRequest req : toSend) {
            Messaging.SingleEmailMessage rendered =
                renderTemplate(tplMap.get(req.templateApiName), req.leadId);

            String link = unsubscribeLink(req, emailByLead.get((Id) req.leadId), tokens);
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
     * Mints every unsubscribe token for the batch in a single DML statement.
     * A total failure returns an empty map, which degrades the whole batch to the legacy
     * mailto link rather than shipping a raw placeholder or blocking the send.
     */
    private static Map<Id, OA_UnsubscribeTokenService.TokenCreationResult> mintTokens(
        List<EmailRequest> toSend, Map<Id, String> emailByLead
    ) {
        List<OA_UnsubscribeTokenService.TokenRequest> reqs =
            new List<OA_UnsubscribeTokenService.TokenRequest>();
        Datetime expiresAt = System.now().addDays(TOKEN_TTL_DAYS);

        for (EmailRequest req : toSend) {
            String email = emailByLead.get((Id) req.leadId);
            if (String.isBlank(req.campaignId) || String.isBlank(req.campaignMemberId)
                || String.isBlank(email)) {
                continue;   // no campaign context — legacy fallback, same as before
            }
            reqs.add(new OA_UnsubscribeTokenService.TokenRequest(
                (Id) req.leadId, (Id) req.campaignId, (Id) req.campaignMemberId, email, expiresAt
            ));
        }
        if (reqs.isEmpty()) return new Map<Id, OA_UnsubscribeTokenService.TokenCreationResult>();

        try {
            return OA_UnsubscribeTokenService.createCampaignUnsubscribeTokens(reqs);
        } catch (Exception e) {
            System.debug('[OA_EmailSender] Bulk token mint failed: ' + e.getMessage());
            return new Map<Id, OA_UnsubscribeTokenService.TokenCreationResult>();
        }
    }

    /**
     * Builds the tokenized HTTPS unsubscribe URL from the pre-minted batch.
     * Falls back to the legacy mailto link if campaign context, email, or the token is
     * missing, so a raw placeholder is never shipped.
     */
    private static String unsubscribeLink(
        EmailRequest req, String email,
        Map<Id, OA_UnsubscribeTokenService.TokenCreationResult> tokens
    ) {
        if (String.isBlank(req.campaignId) || String.isBlank(req.campaignMemberId) || String.isBlank(email)) {
            return LEGACY_FALLBACK;
        }
        OA_UnsubscribeTokenService.TokenCreationResult tok = tokens.get((Id) req.campaignMemberId);
        if (tok == null || String.isBlank(tok.rawToken)) {
            System.debug('[OA_EmailSender] No token minted for ' + req.leadId + '; using legacy link.');
            return LEGACY_FALLBACK;
        }
        return UNSUB_BASE + '?t=' + EncodingUtil.urlEncode(tok.rawToken, 'UTF-8');
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