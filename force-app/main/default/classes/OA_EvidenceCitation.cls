/**
 * OA_EvidenceCitation — Evidence-Backed Decisioning (Program 024D).
 *
 * A single, reusable citation layer that makes the platform EXPLAINABLE without forking the five
 * decision engines (Compliance, Qualification, Pursuit Investment, Partner Intelligence, Opportunity
 * Intelligence — each on its own unmerged branch). Any engine gains evidence-backing by calling one
 * method: the service reads the evidence layer (OA_Knowledge_Document__c) linked to a signal or partner,
 * assembles a traceable citation (supporting documents + confidence + provenance + extraction date +
 * source links), and rolls a human-readable summary onto the record so every recommendation that reads
 * that record is backed by traceable evidence. Superseded/Withdrawn/Duplicate evidence is excluded.
 * Governed: updates only evidence-rollup fields on staged review-queue records; never Lead/Campaign/
 * Opportunity; never creates Opportunities.
 */
public with sharing class OA_EvidenceCitation {

    private static final Set<String> CONFIDENCE_RANK = new Set<String>{ 'HIGH', 'MEDIUM', 'LOW' };

    public class DocRef {
        public Id evidenceId;
        public String name;
        public String documentType;
        public String source;
        public String confidence;
        public String provenance;
        public Datetime extractedDate;
        public Id contentDocumentId;
    }

    public class Citation {
        public Id recordId;
        public Integer evidenceCount = 0;
        public String highestConfidence = 'None';
        public List<DocRef> documents = new List<DocRef>();
        public String summary = '';
        public Boolean evidenceBacked = false;
    }

    /** Cite the evidence supporting an opportunity signal and roll a summary onto it. */
    public static Citation cite(Id signalId) {
        Citation c = build(signalId, [
            SELECT Id, Name, Document_Type__c, Source__c, Confidence__c, Provenance__c,
                   LastModifiedDate, Content_Document_Id__c, Extraction_Status__c, Document_Status__c
            FROM OA_Knowledge_Document__c
            WHERE Opportunity_Signal__c = :signalId
              AND Extraction_Status__c = 'Extracted'
              AND (Document_Status__c = null OR Document_Status__c IN ('Original','Revision','Amendment'))
            ORDER BY Confidence__c, LastModifiedDate DESC
        ]);
        update new OA_Opportunity_Signal__c(
            Id = signalId,
            Evidence_Count__c = c.evidenceCount,
            Evidence_Confidence__c = c.highestConfidence,
            Evidence_Summary__c = c.summary.abbreviate(32000),
            Evidence_Backed__c = c.evidenceBacked,
            Last_Evidence_Date__c = latestDate(c)
        );
        return c;
    }

    /** Cite the evidence supporting a partner/company profile and roll a summary onto it (Phase 6). */
    public static Citation citeProfile(Id profileId) {
        Citation c = build(profileId, [
            SELECT Id, Name, Document_Type__c, Source__c, Confidence__c, Provenance__c,
                   LastModifiedDate, Content_Document_Id__c, Extraction_Status__c, Document_Status__c
            FROM OA_Knowledge_Document__c
            WHERE Company_Profile__c = :profileId
              AND Extraction_Status__c = 'Extracted'
              AND (Document_Status__c = null OR Document_Status__c IN ('Original','Revision','Amendment'))
            ORDER BY Confidence__c, LastModifiedDate DESC
        ]);
        Boolean hasCapStmt = false;
        for (DocRef d : c.documents) if (d.documentType == 'Capability Statement') hasCapStmt = true;
        update new OA_Company_Profile__c(
            Id = profileId,
            Evidence_Document_Count__c = c.evidenceCount,
            Evidence_Summary__c = c.summary.abbreviate(32000),
            Has_Capability_Statement__c = hasCapStmt
        );
        return c;
    }

    /** Read-only citation (no write) — for engines that only need to explain a recommendation. */
    public static Citation explain(Id signalId) {
        return build(signalId, [
            SELECT Id, Name, Document_Type__c, Source__c, Confidence__c, Provenance__c,
                   LastModifiedDate, Content_Document_Id__c, Extraction_Status__c, Document_Status__c
            FROM OA_Knowledge_Document__c
            WHERE Opportunity_Signal__c = :signalId AND Extraction_Status__c = 'Extracted'
              AND (Document_Status__c = null OR Document_Status__c IN ('Original','Revision','Amendment'))
            ORDER BY Confidence__c, LastModifiedDate DESC
        ]);
    }

    // ----- internals -----
    private static Citation build(Id recordId, List<OA_Knowledge_Document__c> docs) {
        Citation c = new Citation();
        c.recordId = recordId;
        c.evidenceCount = docs.size();
        c.evidenceBacked = !docs.isEmpty();
        Integer best = 99;
        List<String> lines = new List<String>();
        for (OA_Knowledge_Document__c d : docs) {
            DocRef r = new DocRef();
            r.evidenceId = d.Id; r.name = d.Name; r.documentType = d.Document_Type__c;
            r.source = d.Source__c; r.confidence = d.Confidence__c; r.provenance = d.Provenance__c;
            r.extractedDate = d.LastModifiedDate; r.contentDocumentId = d.Content_Document_Id__c;
            c.documents.add(r);
            Integer rank = rankOf(d.Confidence__c);
            if (rank < best) best = rank;
            lines.add('[' + (String.isBlank(d.Confidence__c) ? 'LOW' : d.Confidence__c) + '] ' + d.Name
                + ' (' + d.Document_Type__c + ', ' + d.Source__c + ')'
                + ' - extracted ' + (d.LastModifiedDate == null ? '' : d.LastModifiedDate.format('yyyy-MM-dd'))
                + ' - ' + abbreviateProvenance(d.Provenance__c));
        }
        c.highestConfidence = (best == 1 ? 'HIGH' : best == 2 ? 'MEDIUM' : best == 3 ? 'LOW' : 'None');
        c.summary = lines.isEmpty()
            ? 'No supporting evidence on file. Recommendation is UNSUPPORTED until documents are ingested and extracted.'
            : ('Evidence-backed (' + docs.size() + ' document(s), highest confidence ' + c.highestConfidence + '):\n' + String.join(lines, '\n'));
        return c;
    }

    private static Integer rankOf(String conf) {
        if (conf == 'HIGH') return 1;
        if (conf == 'MEDIUM') return 2;
        if (conf == 'LOW') return 3;
        return 4;
    }
    private static String abbreviateProvenance(String p) {
        if (String.isBlank(p)) return 'no provenance';
        return p.abbreviate(180);
    }
    private static Datetime latestDate(Citation c) {
        Datetime latest;
        for (DocRef d : c.documents) if (d.extractedDate != null && (latest == null || d.extractedDate > latest)) latest = d.extractedDate;
        return latest;
    }
}
