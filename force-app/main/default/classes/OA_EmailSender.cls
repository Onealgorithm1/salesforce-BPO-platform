public class OA_EmailSender {

    private static final Integer MAX_INVOCABLE_REQUESTS = 50;
    @TestVisible private static Boolean bypassActualSendForTest = false;

    public class EmailSendException extends Exception {}

    public class EmailRequest {
        @InvocableVariable(required=true label='Lead Id')
        public String leadId;
        @InvocableVariable(required=true label='Email Template API Name')
        public String templateApiName;
        @InvocableVariable(required=true label='Org Wide Email Address Id')
        public String orgWideEmailAddressId;
    }

    @InvocableMethod(
        label='OA Send Template Email to Lead'
        description='Sends a deployed HTML email template to a Lead using the specified org-wide email address.'
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
            if (sent != true) {
                allSent = false;
                break;
            }
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
            if (req != null && String.isNotBlank(req.leadId)) {
                results.put(req.leadId, false);
            }
        }

        // Reserve capacity before building the send list.
        Integer allowed;
        try {
            allowed = OA_SendGovernor.checkAndReserve(requests.size());
        } catch (OA_SendGovernor.CapExceededException e) {
            System.debug('[OA_EmailSender] ' + e.getMessage());
            return results;
        }

        if (Test.isRunningTest() && bypassActualSendForTest) {
            Integer sent = 0;
            for (EmailRequest req : requests) {
                if (req == null || String.isBlank(req.leadId)) continue;
                if (sent >= allowed) break;
                results.put(req.leadId, true);
                sent++;
            }
            return results;
        }

        // One SOQL for all template names; avoids querying inside the request loop.
        Set<String> names = new Set<String>();
        for (EmailRequest req : requests) {
            if (req != null && String.isNotBlank(req.templateApiName)) names.add(req.templateApiName);
        }
        Map<String, Id> tplMap = new Map<String, Id>();
        for (EmailTemplate t : [
            SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :names
        ]) {
            tplMap.put(t.DeveloperName, t.Id);
        }

        List<Messaging.SingleEmailMessage> emails  = new List<Messaging.SingleEmailMessage>();
        List<String>                        leadIds = new List<String>();

        Integer count = 0;
        for (EmailRequest req : requests) {
            if (req == null || String.isBlank(req.leadId)) continue;
            if (count >= allowed) break;  // respect partial cap grant
            if (!tplMap.containsKey(req.templateApiName)) {
                System.debug('[OA_EmailSender] Template not found: ' + req.templateApiName);
                continue;
            }
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(req.leadId);
            msg.setTemplateId(tplMap.get(req.templateApiName));
            msg.setOrgWideEmailAddressId(req.orgWideEmailAddressId);
            msg.setTreatTargetObjectAsRecipient(true);
            msg.setSaveAsActivity(true);
            emails.add(msg);
            leadIds.add(req.leadId);
            count++;
        }

        if (emails.isEmpty()) return results;

        // allOrNone=false: one failure does not cancel the batch
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
                    Subject      = 'Email Send Failed',
                    Description  = err,
                    WhoId        = lid,
                    Status       = 'Completed',
                    Priority     = 'High',
                    ActivityDate = Date.today()
                ));
            }
        }
        if (!failTasks.isEmpty()) insert failTasks;

        return results;
    }
}
