/**
 * OA_DocumentIntelligence — Enterprise Evidence & Document Intelligence (Program 024C).
 *
 * Turns a Salesforce File (ContentVersion) into structured, traceable, confidence-scored evidence
 * (OA_Knowledge_Document__c) that feeds the decision engines. NEVER duplicates storage — points to the
 * ContentDocument. Ingest = checksum + dedupe + provenance + linkage. Extract = AI-Gateway structured
 * extraction (text files; binary flagged for an OCR/parser sidecar). AI summarizes evidence; it never
 * replaces it — every field is traceable to source + document + checksum + confidence. Governed: creates
 * only evidence records; never an Opportunity; human review remains.
 */
public with sharing class OA_DocumentIntelligence {

    /** Ingest a Salesforce File as evidence (idempotent by SHA-256 checksum). */
    public static OA_Knowledge_Document__c ingest(Id contentVersionId, Id signalId, Id profileId, String source, String docType, String url) {
        ContentVersion cv = [SELECT Id, ContentDocumentId, Title, VersionData, VersionNumber, FileType
            FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        String checksum = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', cv.VersionData));
        List<OA_Knowledge_Document__c> dup = [SELECT Id FROM OA_Knowledge_Document__c WHERE Checksum__c = :checksum LIMIT 1];
        if (!dup.isEmpty()) return dup[0];   // no duplicate documents
        OA_Knowledge_Document__c d = new OA_Knowledge_Document__c(
            Source__c = source,
            Document_Type__c = String.isBlank(docType) ? 'Other' : docType,
            Content_Document_Id__c = cv.ContentDocumentId,
            Checksum__c = checksum,
            Version__c = (cv.VersionNumber != null ? Integer.valueOf(cv.VersionNumber) : 1),
            Opportunity_Signal__c = signalId,
            Company_Profile__c = profileId,
            Extraction_Status__c = 'Pending',
            Review_Status__c = 'Pending',
            Confidence__c = 'LOW',
            Provenance__c = ('file=' + cv.Title + ' | type=' + cv.FileType + ' | source=' + source
                + ' | checksum=' + checksum + (String.isNotBlank(url) ? ' | url=' + url : '') + ' | ingested ' + System.now()).abbreviate(32000)
        );
        insert d;
        return d;
    }

    /** Extract structured evidence via the AI Gateway (text-extractable files only). */
    public static OA_Knowledge_Document__c extract(Id evidenceId) {
        OA_Knowledge_Document__c d = [SELECT Id, Content_Document_Id__c, Source__c, Document_Type__c, Opportunity_Signal__c
            FROM OA_Knowledge_Document__c WHERE Id = :evidenceId LIMIT 1];
        ContentVersion cv = [SELECT VersionData, FileType, Title FROM ContentVersion
            WHERE ContentDocumentId = :d.Content_Document_Id__c ORDER BY VersionNumber DESC LIMIT 1];

        String text;
        try { text = cv.VersionData.toString(); } catch (Exception e) { text = null; }
        if (String.isBlank(text) || !isTextType(cv.FileType)) {
            d.Extraction_Status__c = 'Manual Review';
            d.AI_Summary__c = '[binary/' + cv.FileType + ' — text not extractable in Apex; route to an Apache-2.0 OCR/parser sidecar (Tika/Unstructured) then re-extract]';
            d.Confidence__c = 'LOW';
            update d;
            return d;
        }
        if (text.length() > 12000) text = text.substring(0, 12000);   // token guard

        String prompt = 'You are a federal capture analyst extracting STRUCTURED EVIDENCE from a procurement or capability document. '
            + 'Return ONLY compact JSON (no prose, no code fences) with these keys, using null when absent (do NOT invent): '
            + 'title, agency, opportunityNumber, deadline, setAside, naics, psc, contractVehicles, certifications, '
            + 'evaluationCriteria, submissionInstructions, keyPersonnel, technologies, securityRequirements, laborCategories, '
            + 'pricingReferences, summary.\n\nDOCUMENT TEXT:\n' + text;

        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Document_Extraction', prompt, 'Document_Intelligence', d.Opportunity_Signal__c);
        Map<String, Object> ex = parseJson(r.text);

        d.AI_Summary__c = abv(coalesce(strOf(ex.get('summary')), r.text), 32000);
        d.Extracted_Certifications__c = abv(joinAny(ex.get('certifications')), 255);
        d.Extracted_Technologies__c = abv(joinAny(ex.get('technologies')), 255);
        d.Extracted_NAICS__c = abv(joinAny(ex.get('naics')), 255);
        d.Extracted_PSC__c = abv(joinAny(ex.get('psc')), 255);
        d.Extracted_Agencies__c = abv(strOf(ex.get('agency')), 255);
        d.Extracted_Dates__c = abv(strOf(ex.get('deadline')), 255);
        d.Extracted_Requirements__c = abv(joinAny(ex.get('evaluationCriteria')) + '\n' + joinAny(ex.get('submissionInstructions')), 32000);
        d.Extracted_Clauses__c = abv(joinAny(ex.get('securityRequirements')) + '\n' + joinAny(ex.get('contractVehicles')), 32000);
        d.Confidence__c = confidenceFor(d.Source__c, r.success);
        d.Extraction_Status__c = r.success ? 'Extracted' : 'Failed';
        d.AI_Provider__c = r.provider; d.AI_Model__c = r.model;
        d.AI_Total_Tokens__c = r.totalTokens; d.AI_Estimated_Cost__c = r.estimatedCost;
        update d;
        return d;
    }

    /** Confidence model: verified gov doc = HIGH, company/partner doc = MEDIUM, AI-only/failed = LOW. */
    private static String confidenceFor(String source, Boolean success) {
        if (!success) return 'LOW';
        if (source == 'SAM.gov' || source == 'Grants.gov') return 'HIGH';   // verified government document
        if (source == 'Company' || source == 'Partner') return 'MEDIUM';    // verified but claimant-supplied
        return 'LOW';
    }

    // ----- helpers -----
    private static Boolean isTextType(String ft) {
        if (ft == null) return false;
        String f = ft.toUpperCase();
        return f == 'TEXT' || f == 'TXT' || f == 'CSV' || f == 'XML' || f == 'JSON' || f == 'HTM' || f == 'HTML' || f == 'MD';
    }
    private static Map<String, Object> parseJson(String raw) {
        if (String.isBlank(raw)) return new Map<String, Object>();
        String s = raw.trim();
        if (s.startsWith('```')) { s = s.replaceFirst('```(json)?', '').trim(); if (s.endsWith('```')) s = s.substring(0, s.length() - 3); }
        Integer a = s.indexOf('{'); Integer b = s.lastIndexOf('}');
        if (a >= 0 && b > a) s = s.substring(a, b + 1);
        try { return (Map<String, Object>) JSON.deserializeUntyped(s); } catch (Exception e) { return new Map<String, Object>(); }
    }
    private static String strOf(Object o) { return o == null ? null : String.valueOf(o); }
    private static String coalesce(String a, String b) { return String.isNotBlank(a) ? a : b; }
    private static String abv(String s, Integer n) { return s == null ? null : s.abbreviate(n); }
    private static String joinAny(Object o) {
        if (o == null) return null;
        if (o instanceof List<Object>) { List<String> p = new List<String>(); for (Object x : (List<Object>) o) p.add(String.valueOf(x)); return String.join(p, ', '); }
        return String.valueOf(o);
    }
}
