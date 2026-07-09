/**
 * OA_LeadCreationService — governed Candidate -> Lead creation (BLO Phase 5).
 *
 * Creates NEW Leads from human-approved candidates (OA_Discovered_Organization__c) with strict gates:
 *   ELIGIBILITY  — only APPROVED / LEAD_READY candidates (human-approved) are eligible.
 *   IDEMPOTENCY  — candidates already CONVERTED or already linked (Matched_Lead__c) are skipped.
 *   MATCH (dedup)— if an existing Lead shares the candidate's UEI or CAGE, NO new Lead is created;
 *                  the candidate is linked to the existing Lead instead (never overwrite existing Leads).
 *   VALIDATION   — insert runs in USER_MODE with allOrNone=false; org validation rules (e.g.
 *                  Require_Email_Or_Contact_Person_Email) are NEVER bypassed. Failures are reported,
 *                  the candidate is left unchanged.
 *
 * Provenance is preserved WITHOUT duplicating metadata: the created Lead links back via
 * candidate.Matched_Lead__c, and a TYPE_CREATE OA_ChangeLogService row records source/confidence/
 * canonical key (reuse of the existing audit + rollback engine). Preview (commitWrites=false) = 0 DML.
 * Manual invocation only — no trigger/flow/schedule.
 */
public with sharing class OA_LeadCreationService {

    public class RowOutcome {
        public Id candidateId;
        public Id leadId;              // created or matched
        public String status;          // PREVIEW_OK | CREATED | SKIPPED | FAILED
        public String gate;            // ELIGIBILITY | IDEMPOTENCY | MATCH | VALIDATION | DATA | OK
        public String reason;
    }

    public class RunSummary {
        public Boolean committed = false;
        public Integer attempted = 0;
        public Integer created = 0;
        public Integer skipped = 0;
        public Integer duplicates = 0;
        public Integer failed = 0;
        public Integer dmlRows = 0;
        public List<Id> createdLeadIds = new List<Id>();
        public List<RowOutcome> rows = new List<RowOutcome>();
    }

    /**
     * @param candidateIds            candidates to convert
     * @param contactEmailByCandidate optional contact email per candidate (future contact-discovery feeds this;
     *                                required for the org validation rule — the service never fabricates one)
     * @param commitWrites            false = preview (0 DML); true = insert Leads
     */
    public static RunSummary create(List<Id> candidateIds, Map<Id, String> contactEmailByCandidate, Boolean commitWrites) {
        RunSummary sum = new RunSummary();
        sum.committed = (commitWrites == true);
        if (candidateIds == null || candidateIds.isEmpty()) { return sum; }
        Map<Id, String> emails = (contactEmailByCandidate == null) ? new Map<Id, String>() : contactEmailByCandidate;

        List<OA_Discovered_Organization__c> cands = [
            SELECT Id, Organization_Name__c, Normalized_Name__c, UEI__c, CAGE_Code__c, CIK__c, EIN__c, NAICS__c,
                   Address__c, City__c, State__c, Postal_Code__c, Website__c, Phone__c, Source_System__c,
                   Source_Confidence__c, Confidence_Score__c, Canonical_Key__c, Qualification_Status__c,
                   Matched_Lead__c, Connector_Run__c, Reviewed_Contact_Email__c
            FROM OA_Discovered_Organization__c
            WHERE Id IN :candidateIds
        ];

        // Bulk dedup: existing Leads sharing UEI or CAGE with any candidate in scope.
        Set<String> ueis = new Set<String>();
        Set<String> cages = new Set<String>();
        Set<String> ciks = new Set<String>();
        for (OA_Discovered_Organization__c c : cands) {
            if (String.isNotBlank(c.UEI__c)) { ueis.add(c.UEI__c); }
            if (String.isNotBlank(c.CAGE_Code__c)) { cages.add(c.CAGE_Code__c); }
            if (String.isNotBlank(c.CIK__c)) { ciks.add(c.CIK__c); }
        }
        Map<String, Id> leadByUei = new Map<String, Id>();
        Map<String, Id> leadByCage = new Map<String, Id>();
        Map<String, Id> leadByCik = new Map<String, Id>();   // CIK-aware dedup for SEC-origin candidates
        if (!ueis.isEmpty() || !cages.isEmpty() || !ciks.isEmpty()) {
            for (Lead l : [SELECT Id, UEI__c, CAGE_Code__c, CIK__c FROM Lead
                           WHERE UEI__c IN :ueis OR CAGE_Code__c IN :cages OR CIK__c IN :ciks]) {
                if (String.isNotBlank(l.UEI__c) && !leadByUei.containsKey(l.UEI__c)) { leadByUei.put(l.UEI__c, l.Id); }
                if (String.isNotBlank(l.CAGE_Code__c) && !leadByCage.containsKey(l.CAGE_Code__c)) { leadByCage.put(l.CAGE_Code__c, l.Id); }
                if (String.isNotBlank(l.CIK__c) && !leadByCik.containsKey(l.CIK__c)) { leadByCik.put(l.CIK__c, l.Id); }
            }
        }

        List<Lead> toInsert = new List<Lead>();
        List<OA_Discovered_Organization__c> insertCands = new List<OA_Discovered_Organization__c>();  // aligned with toInsert
        List<OA_Discovered_Organization__c> linkUpdates = new List<OA_Discovered_Organization__c>();

        for (OA_Discovered_Organization__c c : cands) {
            sum.attempted++;
            RowOutcome o = new RowOutcome();
            o.candidateId = c.Id;

            // IDEMPOTENCY
            if (OA_LifecycleStates.CONVERTED.equals(c.Qualification_Status__c) || c.Matched_Lead__c != null) {
                o.status = 'SKIPPED'; o.gate = 'IDEMPOTENCY'; o.leadId = c.Matched_Lead__c;
                o.reason = 'Already converted/linked.'; sum.skipped++; sum.rows.add(o); continue;
            }
            // ELIGIBILITY (human-approved states only)
            if (!OA_LifecycleStates.CREATION_ELIGIBLE.contains(OA_LifecycleStates.effective(c.Qualification_Status__c))) {
                o.status = 'SKIPPED'; o.gate = 'ELIGIBILITY';
                o.reason = 'Candidate not human-approved (status=' + c.Qualification_Status__c + ').';
                sum.skipped++; sum.rows.add(o); continue;
            }
            // MATCH (dedup vs existing Leads) — link, never create/overwrite
            Id matchLead = (String.isNotBlank(c.UEI__c) ? leadByUei.get(c.UEI__c) : null);
            if (matchLead == null && String.isNotBlank(c.CAGE_Code__c)) { matchLead = leadByCage.get(c.CAGE_Code__c); }
            if (matchLead == null && String.isNotBlank(c.CIK__c)) { matchLead = leadByCik.get(c.CIK__c); }
            if (matchLead != null) {
                o.status = 'SKIPPED'; o.gate = 'MATCH'; o.leadId = matchLead;
                o.reason = 'Existing Lead matches UEI/CAGE; linked (no new Lead).';
                sum.duplicates++;
                if (commitWrites == true) {
                    linkUpdates.add(new OA_Discovered_Organization__c(Id = c.Id, Matched_Lead__c = matchLead));
                }
                sum.rows.add(o); continue;
            }
            // DATA gate: must have a name
            if (String.isBlank(c.Organization_Name__c)) {
                o.status = 'FAILED'; o.gate = 'DATA'; o.reason = 'Missing Organization_Name__c.';
                sum.failed++; sum.rows.add(o); continue;
            }

            // Reviewed contact email: explicit map param overrides; else the reviewer-supplied field on the
            // candidate. NEVER fabricated. Absence => the org validation rule will (correctly) block creation.
            String resolvedEmail = String.isNotBlank(emails.get(c.Id)) ? emails.get(c.Id) : c.Reviewed_Contact_Email__c;
            Lead l = buildLead(c, resolvedEmail);
            if (commitWrites != true) {
                o.status = 'PREVIEW_OK'; o.gate = 'OK';
                o.reason = String.isBlank(resolvedEmail)
                    ? 'Would attempt (WARN: NOT Lead Ready — no reviewed contact email; org rule will block until a reviewer supplies one).'
                    : 'Would create (Lead Ready: reviewed contact email present).';
                sum.rows.add(o); continue;
            }
            toInsert.add(l);
            insertCands.add(c);
            sum.rows.add(o);   // finalized after DML
        }

        if (commitWrites == true) {
            List<OA_Enrichment_Change_Log__c> logs = new List<OA_Enrichment_Change_Log__c>();
            List<OA_Discovered_Organization__c> convertUpdates = new List<OA_Discovered_Organization__c>();
            if (!toInsert.isEmpty()) {
                Database.SaveResult[] srs = Database.insert(toInsert, false, AccessLevel.USER_MODE);
                for (Integer i = 0; i < srs.size(); i++) {
                    OA_Discovered_Organization__c c = insertCands[i];
                    RowOutcome o = outcomeFor(sum, c.Id);
                    if (srs[i].isSuccess()) {
                        Id leadId = srs[i].getId();
                        o.status = 'CREATED'; o.gate = 'OK'; o.leadId = leadId; o.reason = 'Lead created.';
                        sum.created++; sum.createdLeadIds.add(leadId);
                        convertUpdates.add(new OA_Discovered_Organization__c(
                            Id = c.Id, Matched_Lead__c = leadId, Qualification_Status__c = OA_LifecycleStates.CONVERTED));
                        logs.add(OA_ChangeLogService.buildLog('Lead', leadId, '(create)',
                            null, c.Canonical_Key__c, c.Source_System__c, 'Overwrite',
                            c.Source_Confidence__c, c.Connector_Run__c, null, OA_ChangeLogService.TYPE_CREATE));
                    } else {
                        o.status = 'FAILED'; o.gate = 'VALIDATION';
                        o.reason = firstError(srs[i]);
                        sum.failed++;
                    }
                }
            }
            List<OA_Discovered_Organization__c> allCandUpdates = new List<OA_Discovered_Organization__c>();
            allCandUpdates.addAll(convertUpdates);
            allCandUpdates.addAll(linkUpdates);
            if (!allCandUpdates.isEmpty()) { Database.update(allCandUpdates, false, AccessLevel.USER_MODE); }
            if (!logs.isEmpty()) { OA_ChangeLogService.commitLogs(logs); }
            sum.dmlRows = toInsert.size() + allCandUpdates.size();
        }
        return sum;
    }

    /** Convenience preview. */
    public static RunSummary preview(List<Id> candidateIds) {
        return create(candidateIds, null, false);
    }

    /**
     * Rollback created Leads: delete them, reset their candidates to LEAD_READY (clearing the link), and
     * record TYPE_ROLLBACK audit rows. Explicit, caller-invoked only.
     */
    public static Integer rollbackCreated(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) { return 0; }
        List<OA_Discovered_Organization__c> cands = [
            SELECT Id, Matched_Lead__c, Source_System__c, Source_Confidence__c, Connector_Run__c, Canonical_Key__c
            FROM OA_Discovered_Organization__c WHERE Matched_Lead__c IN :leadIds];
        List<OA_Discovered_Organization__c> resets = new List<OA_Discovered_Organization__c>();
        List<OA_Enrichment_Change_Log__c> logs = new List<OA_Enrichment_Change_Log__c>();
        for (OA_Discovered_Organization__c c : cands) {
            resets.add(new OA_Discovered_Organization__c(
                Id = c.Id, Matched_Lead__c = null, Qualification_Status__c = OA_LifecycleStates.LEAD_READY));
            logs.add(OA_ChangeLogService.buildLog('Lead', c.Matched_Lead__c, '(create)',
                c.Canonical_Key__c, null, c.Source_System__c, 'Overwrite',
                c.Source_Confidence__c, c.Connector_Run__c, null, OA_ChangeLogService.TYPE_ROLLBACK));
        }
        Database.delete(leadIds, false);
        if (!resets.isEmpty()) { Database.update(resets, false, AccessLevel.USER_MODE); }
        if (!logs.isEmpty()) { OA_ChangeLogService.commitLogs(logs); }
        return leadIds.size();
    }

    /** Map candidate -> new Lead. Provenance stays on the candidate + audit log (no invented Lead fields). */
    @TestVisible
    private static Lead buildLead(OA_Discovered_Organization__c c, String contactEmail) {
        Lead l = new Lead();
        l.Company    = c.Organization_Name__c.abbreviate(255);
        l.LastName   = c.Organization_Name__c.abbreviate(80);   // org-based lead; required std field
        l.Company_Name__c = c.Organization_Name__c;
        l.UEI__c     = c.UEI__c;
        l.CAGE_Code__c = c.CAGE_Code__c;
        l.CIK__c     = c.CIK__c;
        l.EIN__c     = c.EIN__c;
        l.Primary_NAICS_code__c = c.NAICS__c;
        l.Address_line_1__c = c.Address__c;
        l.City__c    = c.City__c;
        l.State__c   = c.State__c;
        l.Website__c = c.Website__c;
        l.Compatibility_Score__c = c.Confidence_Score__c;
        if (String.isNotBlank(contactEmail)) { l.Contact_Person_s_Email__c = contactEmail; }
        return l;
    }

    private static RowOutcome outcomeFor(RunSummary sum, Id candidateId) {
        for (RowOutcome o : sum.rows) { if (o.candidateId == candidateId && o.status == null) { return o; } }
        RowOutcome n = new RowOutcome(); n.candidateId = candidateId; sum.rows.add(n); return n;
    }

    private static String firstError(Database.SaveResult sr) {
        if (sr.getErrors() != null && !sr.getErrors().isEmpty()) {
            return sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();
        }
        return 'Unknown insert error';
    }
}
