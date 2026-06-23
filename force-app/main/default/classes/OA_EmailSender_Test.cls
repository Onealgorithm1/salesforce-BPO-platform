@isTest(SeeAllData=true)
private class OA_EmailSender_Test {

    @isTest
    static void testSendEmailToLead() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'testlead@example.com',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = 'lrubino@onealgorithm.com'
            LIMIT 1
        ];

        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName = 'EDWOSB_Sub_Prospect_Email_1'
            LIMIT 1
        ];

        if (owas.isEmpty() || templates.isEmpty()) return;

        OA_EmailSender.EmailRequest req = new OA_EmailSender.EmailRequest();
        req.leadId = testLead.Id;
        req.templateApiName = 'EDWOSB_Sub_Prospect_Email_1';
        req.orgWideEmailAddressId = owas[0].Id;

        Test.startTest();
        OA_EmailSender.sendEmailToLead(
            new List<OA_EmailSender.EmailRequest>{ req }
        );
        Test.stopTest();
    }
}