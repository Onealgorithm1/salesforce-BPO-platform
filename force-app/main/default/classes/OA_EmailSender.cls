public class OA_EmailSender {

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
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (EmailRequest req : requests) {
            List<EmailTemplate> templates = [
                SELECT Id FROM EmailTemplate
                WHERE DeveloperName = :req.templateApiName
                LIMIT 1
            ];
            if (templates.isEmpty()) continue;

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(req.leadId);
            email.setTemplateId(templates[0].Id);
            email.setOrgWideEmailAddressId(req.orgWideEmailAddressId);
            email.setTreatTargetObjectAsRecipient(true);
            email.setSaveAsActivity(true);
            emails.add(email);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}