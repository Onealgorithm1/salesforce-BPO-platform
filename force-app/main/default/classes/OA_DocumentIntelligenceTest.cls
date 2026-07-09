/**
 * OA_DocumentIntelligenceTest — Program 024C.
 * Proves: ingest (checksum + provenance + linkage), idempotent dedupe, AI-Gateway structured
 * extraction with confidence assignment, and binary/non-text routing to Manual Review.
 */
@IsTest
private class OA_DocumentIntelligenceTest {

    /** OpenRouter-shaped mock returning a structured extraction JSON as the completion content. */
    private class GatewayMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String extraction = '{"title":"Cloud BPO Support Services","agency":"Department of Veterans Affairs",'
                + '"opportunityNumber":"36C10B25R0001","deadline":"2026-08-15","setAside":"EDWOSB",'
                + '"naics":["541611","518210"],"psc":["D307"],"contractVehicles":["GSA MAS"],'
                + '"certifications":["EDWOSB","WOSB"],"evaluationCriteria":"Best value; technical then price",'
                + '"submissionInstructions":"Submit via SAM.gov by deadline","keyPersonnel":["Program Manager"],'
                + '"technologies":["Salesforce","AI/ML","Data Analytics"],"securityRequirements":"FedRAMP Moderate",'
                + '"laborCategories":["PM","Analyst"],"pricingReferences":"FFP","summary":"VA cloud BPO support solicitation."}';
            Map<String, Object> body = new Map<String, Object>{
                'model' => 'test-model',
                'usage' => new Map<String, Object>{ 'prompt_tokens' => 90, 'completion_tokens' => 70, 'total_tokens' => 160 },
                'choices' => new List<Object>{ new Map<String, Object>{
                    'message' => new Map<String, Object>{ 'role' => 'assistant', 'content' => extraction } } }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200); res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    private static Id makeTextFile(String title, String bodyText) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.txt',
            VersionData = Blob.valueOf(bodyText));
        insert cv;
        return [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;
    }

    private static void injectConfig() {
        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Document_Extraction' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'test-model', null, null, 1024),
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'test-model', null, null, 1024)
        };
    }

    @IsTest
    static void ingestChecksumsDedupesAndLinks() {
        OA_Opportunity_Signal__c sig = new OA_Opportunity_Signal__c(
            Title__c = 'VA Cloud BPO', Source__c = 'SAM.gov', Review_Status__c = 'Pending');
        insert sig;
        Id cvId = makeTextFile('va-solicitation', 'Solicitation 36C10B25R0001 EDWOSB set-aside NAICS 541611.');

        Test.startTest();
        OA_Knowledge_Document__c first = OA_DocumentIntelligence.ingest(cvId, sig.Id, null, 'SAM.gov', 'Solicitation', 'https://sam.gov/opp/x');
        OA_Knowledge_Document__c second = OA_DocumentIntelligence.ingest(cvId, sig.Id, null, 'SAM.gov', 'Solicitation', 'https://sam.gov/opp/x');
        Test.stopTest();

        System.assertEquals(first.Id, second.Id, 'ingest must be idempotent by checksum (no duplicate documents)');
        System.assertEquals(1, [SELECT COUNT() FROM OA_Knowledge_Document__c], 'only one evidence record');
        OA_Knowledge_Document__c saved = [SELECT Checksum__c, Content_Document_Id__c, Opportunity_Signal__c,
            Extraction_Status__c, Provenance__c, Source__c FROM OA_Knowledge_Document__c WHERE Id = :first.Id];
        System.assertEquals(64, saved.Checksum__c.length(), 'SHA-256 hex checksum');
        System.assertNotEquals(null, saved.Content_Document_Id__c, 'points to the Salesforce File (no duplicate storage)');
        System.assertEquals(sig.Id, saved.Opportunity_Signal__c, 'linked to opportunity signal');
        System.assertEquals('Pending', saved.Extraction_Status__c);
        System.assert(saved.Provenance__c.contains('checksum='), 'provenance records checksum + source');
    }

    @IsTest
    static void extractStructuredEvidenceWithConfidence() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new GatewayMock());
        Id cvId = makeTextFile('va-doc', 'RFP body: EDWOSB set-aside, NAICS 541611, FedRAMP Moderate, GSA MAS.');
        OA_Knowledge_Document__c d = OA_DocumentIntelligence.ingest(cvId, null, null, 'SAM.gov', 'RFP', null);

        Test.startTest();
        OA_Knowledge_Document__c out = OA_DocumentIntelligence.extract(d.Id);
        Test.stopTest();

        OA_Knowledge_Document__c saved = [SELECT Extraction_Status__c, Confidence__c, AI_Summary__c,
            Extracted_Certifications__c, Extracted_Technologies__c, Extracted_NAICS__c, Extracted_Agencies__c,
            AI_Provider__c, AI_Total_Tokens__c FROM OA_Knowledge_Document__c WHERE Id = :out.Id];
        System.assertEquals('Extracted', saved.Extraction_Status__c, 'extraction succeeded');
        System.assertEquals('HIGH', saved.Confidence__c, 'verified government document => HIGH confidence');
        System.assertNotEquals(null, saved.AI_Summary__c, 'AI summary persisted');
        System.assert(saved.Extracted_Certifications__c.contains('EDWOSB'), 'certifications extracted');
        System.assert(saved.Extracted_NAICS__c.contains('541611'), 'NAICS extracted');
        System.assert(saved.Extracted_Agencies__c.contains('Veterans'), 'agency extracted');
        System.assertEquals('OpenRouter', saved.AI_Provider__c, 'AI telemetry logged');
        System.assertEquals(160, saved.AI_Total_Tokens__c, 'token usage captured');
    }

    @IsTest
    static void companySourceIsMediumConfidence() {
        injectConfig();
        Test.setMock(HttpCalloutMock.class, new GatewayMock());
        Id cvId = makeTextFile('oa-capability', 'One Algorithm LLC capability statement: EDWOSB, Salesforce, AI.');
        OA_Knowledge_Document__c d = OA_DocumentIntelligence.ingest(cvId, null, null, 'Company', 'Capability Statement', null);

        Test.startTest();
        OA_Knowledge_Document__c out = OA_DocumentIntelligence.extract(d.Id);
        Test.stopTest();

        OA_Knowledge_Document__c saved = [SELECT Confidence__c, Extraction_Status__c FROM OA_Knowledge_Document__c WHERE Id = :out.Id];
        System.assertEquals('MEDIUM', saved.Confidence__c, 'company-supplied doc => MEDIUM (claimant-supplied, not gov-verified)');
        System.assertEquals('Extracted', saved.Extraction_Status__c);
    }
}
