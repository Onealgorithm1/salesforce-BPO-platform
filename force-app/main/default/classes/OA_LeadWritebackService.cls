/**
 * OA_LeadWritebackService — governed, manual/admin-invoked Lead write-back engine (v1).
 *
 * Promotes reviewed + APPROVED OA_USASpending_Staging__c rows into the 16 deployed
 * Lead write-back fields. A plain static service (NO trigger, flow, invocable,
 * scheduler, queueable, or batch surface) intended to be called deliberately by an
 * admin (e.g. anonymous Apex, or later a screen-flow button).
 *
 * SAFETY (per approved design):
 *   - Processes ONLY the explicit stagingIds supplied by the caller. No query-all-approved.
 *   - commitWrites=false => PREVIEW: gating + matching + mapping + snapshot simulation +
 *     run summary. NO Lead DML, NO staging DML.
 *   - commitWrites=true is fully coded but is only to be used later, after explicit
 *     approval + the OA_Lead_Writeback_Automation permission set is (temporarily) assigned.
 *   - Eligibility requires Review_Status__c = 'Approved', a deterministic Lead__c target,
 *     no prior write-back, and the required source fields. NO fuzzy / name / auto-UEI match.
 *   - Snapshot-first: the current Lead values are persisted into Before_Snapshot__c BEFORE
 *     any Lead update. A Lead is written only if its snapshot persisted => a record written
 *     without a snapshot is impossible by construction (tripwire must remain 0).
 *   - Idempotent: rows already 'Written Back' / with Written_Back_Date__c, or whose source
 *     run already sits on the Lead, are skipped.
 *   - FLS-enforced: reads use WITH USER_MODE; the Lead write is passed through
 *     Security.stripInaccessible(UPDATABLE, ...) — if the running user lacks edit FLS on the
 *     write-back fields the batch is blocked, never silently bypassed.
 *   - Row-independent: one bad row never aborts the run (Database DML allOrNone=false).
 *   - Hard 200-record clamp; default 5 when no limit supplied.
 *   - Never invokes the connector, makes no callouts, and never assigns a permission set.
 */
public with sharing class OA_LeadWritebackService {

    public static final Integer DEFAULT_LIMIT = 5;
    public static final Integer MAX_LIMIT = 200;

    private static final String STATUS_APPROVED  = 'Approved';
    private static final String STATUS_WRITTEN   = 'Written Back';
    private static final String STATUS_EXCEPTION = 'Exception / Needs Review';
    private static final String VERIFIED         = 'Verified';

    // The 16 deployed Lead write-back target fields.
    private static final List<String> LEAD_TARGET_FIELDS = new List<String>{
        'UEI_Verification_Status__c','UEI_Verification_Source__c','UEI_Verified_Date__c',
        'UEI_Verified_By__c','UEI_Verification_Evidence__c','UEI_Verification_Run_ID__c',
        'USASpending_Latest_Award_Amount__c','USASpending_Latest_Award_ID__c',
        'USASpending_Latest_Award_Desc__c','USASpending_Awarding_Agency__c',
        'USASpending_Awarding_Sub_Agency__c','USASpending_Contract_Type__c',
        'USASpending_Performance_State__c','USASpending_Last_Enriched__c',
        'USASpending_Source_Run_ID__c','USASpending_UEI__c'
    };

    /** Per-row result. */
    public class RowOutcome {
        public Id stagingId;
        public Id leadId;
        public String status;   // PREVIEW_OK | WRITTEN | SKIPPED | FAILED
        public String gate;     // ELIGIBILITY | MATCH | DATA | IDEMPOTENCY | DEDUPE | FLS | SNAPSHOT | DML
        public String reason;
        public Boolean snapshotCaptured = false;
    }

    /** Structured run summary. All KPI hard-stop tripwires are computable from this. */
    public class RunSummary {
        public String runId;
        public Integer requestedLimit;
        public Integer effectiveLimit;
        public Boolean commitWrites;
        public Datetime startedAt;
        public Datetime endedAt;
        public Integer attempted = 0;
        public Integer succeeded = 0;
        public Integer failed = 0;
        public Integer skipped = 0;
        public Integer idempotencySkips = 0;
        public Integer duplicateWritePrevention = 0;
        public Integer dedupedSameLead = 0;   // extra Approved rows for a Lead deferred so ONE update writes
        public Integer snapshotCaptured = 0;
        public Integer rollbackReady = 0;
        // Tripwires — MUST always be 0:
        public Integer recordsWrittenWithoutSnapshot = 0;
        public Integer recordsWrittenWithoutApproval = 0;
        public Integer recordsWrittenWithoutRunId = 0;
        public Integer fuzzyMatchUsedCount = 0;   // engine never fuzzy-matches
        public Integer unauthorizedRunAttempts = 0;
        public Boolean batchClampApplied = false;
        public List<RowOutcome> rows = new List<RowOutcome>();
    }

    /** Per-row rollback result. */
    public class RollbackOutcome {
        public Id stagingId;
        public Id leadId;
        public String status;   // RESTORED | SKIPPED | FAILED
        public String gate;     // SNAPSHOT_MISSING | SNAPSHOT_INVALID | LEAD_MISMATCH | FLS | DML
        public String reason;
    }

    /** Structured rollback summary with per-row outcomes. */
    public class RollbackSummary {
        public String runId;
        public Integer attempted = 0;
        public Integer succeeded = 0;
        public Integer failed = 0;
        public Integer skipped = 0;
        public Integer rollbackFailures = 0;
        public List<RollbackOutcome> rows = new List<RollbackOutcome>();
    }

    /**
     * Manual/admin-invoked write-back.
     * @param stagingIds     explicit staging record ids (required; no query-all)
     * @param requestedLimit caller cap; clamped to [0, 200]; null => DEFAULT_LIMIT
     * @param commitWrites   false = preview (no DML); true = commit (later, gated)
     */
    public static RunSummary writeBack(List<Id> stagingIds, Integer requestedLimit, Boolean commitWrites) {
        RunSummary s = new RunSummary();
        s.startedAt = System.now();
        s.commitWrites = (commitWrites == true);
        s.requestedLimit = requestedLimit;
        s.runId = 'WB-' + UserInfo.getUserId() + '-' + String.valueOf(System.now().getTime());

        // --- clamp ---
        Integer eff = (requestedLimit == null) ? DEFAULT_LIMIT : requestedLimit;
        if (eff > MAX_LIMIT) { eff = MAX_LIMIT; s.batchClampApplied = true; }
        if (eff < 0) { eff = 0; }
        s.effectiveLimit = eff;

        if (stagingIds == null || stagingIds.isEmpty() || eff == 0) {
            s.endedAt = System.now();
            return s;
        }

        List<Id> idsToProcess = new List<Id>();
        for (Id sid : stagingIds) {
            if (idsToProcess.size() >= eff) break;
            if (sid != null) idsToProcess.add(sid);
        }

        // --- read staging (FLS/CRUD/sharing enforced) ---
        List<OA_USASpending_Staging__c> rows;
        try {
            rows = [
                SELECT Id, Review_Status__c, Lead__c, Recipient_UEI__c, Award_ID__c, Award_Amount__c,
                       Award_Description__c, Awarding_Agency__c, Awarding_Sub_Agency__c, Contract_Type__c,
                       Performance_State__c, Enrichment_Run_ID__c, Query_Date__c, Auto_Verified_Date__c,
                       Auto_Verification_Method__c, Gate_Results__c, Written_Back_Date__c, Before_Snapshot__c
                FROM OA_USASpending_Staging__c
                WHERE Id IN :idsToProcess
                WITH USER_MODE
            ];
        } catch (Exception e) {
            s.unauthorizedRunAttempts = 1;
            for (Id sid : idsToProcess) {
                s.rows.add(fail(sid, null, 'FLS', 'Staging read access denied: ' + e.getMessage()));
                s.failed++;
            }
            s.endedAt = System.now();
            return s;
        }

        // --- gate each row (in memory) ---
        Map<Id, OA_USASpending_Staging__c> eligible = new Map<Id, OA_USASpending_Staging__c>();
        Map<Id, RowOutcome> outcome = new Map<Id, RowOutcome>();
        Set<Id> leadIds = new Set<Id>();

        for (OA_USASpending_Staging__c row : rows) {
            RowOutcome ro = new RowOutcome();
            ro.stagingId = row.Id;
            ro.leadId = row.Lead__c;
            outcome.put(row.Id, ro);
            s.rows.add(ro);

            if (row.Review_Status__c == STATUS_WRITTEN || row.Written_Back_Date__c != null) {
                mark(ro, 'SKIPPED', 'IDEMPOTENCY', 'Already written back');
                s.skipped++; s.idempotencySkips++; s.duplicateWritePrevention++;
                continue;
            }
            if (row.Review_Status__c != STATUS_APPROVED) {
                mark(ro, 'FAILED', 'ELIGIBILITY', 'Review_Status__c != Approved');
                s.failed++; continue;
            }
            if (row.Lead__c == null) {
                mark(ro, 'FAILED', 'MATCH', 'Missing deterministic Lead__c');
                s.failed++; continue;
            }
            if (String.isBlank(row.Recipient_UEI__c) || String.isBlank(row.Award_ID__c)
                || row.Award_Amount__c == null || String.isBlank(row.Awarding_Agency__c)
                || String.isBlank(row.Enrichment_Run_ID__c)) {
                mark(ro, 'FAILED', 'DATA', 'Missing required source data');
                s.failed++; continue;
            }
            eligible.put(row.Id, row);
            leadIds.add(row.Lead__c);
        }

        s.attempted = eligible.size();
        if (eligible.isEmpty()) { s.endedAt = System.now(); return s; }

        // --- current Lead values (snapshot source + idempotency drift) ---
        Map<Id, Lead> currentLeads;
        try {
            currentLeads = new Map<Id, Lead>([
                SELECT Id, UEI_Verification_Status__c, UEI_Verification_Source__c, UEI_Verified_Date__c,
                       UEI_Verified_By__c, UEI_Verification_Evidence__c, UEI_Verification_Run_ID__c,
                       USASpending_Latest_Award_Amount__c, USASpending_Latest_Award_ID__c,
                       USASpending_Latest_Award_Desc__c, USASpending_Awarding_Agency__c,
                       USASpending_Awarding_Sub_Agency__c, USASpending_Contract_Type__c,
                       USASpending_Performance_State__c, USASpending_Last_Enriched__c,
                       USASpending_Source_Run_ID__c, USASpending_UEI__c
                FROM Lead WHERE Id IN :leadIds WITH USER_MODE
            ]);
        } catch (Exception e) {
            s.unauthorizedRunAttempts = 1;
            for (Id sid : eligible.keySet()) {
                mark(outcome.get(sid), 'FAILED', 'FLS', 'Lead read access denied: ' + e.getMessage());
                s.failed++;
            }
            s.attempted = 0;
            s.endedAt = System.now();
            return s;
        }

        // --- idempotency: same source run already applied on the Lead ---
        List<Id> stillEligible = new List<Id>();
        for (Id sid : eligible.keySet()) {
            OA_USASpending_Staging__c row = eligible.get(sid);
            RowOutcome ro = outcome.get(sid);
            Lead cur = currentLeads.get(row.Lead__c);
            if (cur == null) {
                mark(ro, 'FAILED', 'MATCH', 'Lead not visible / not found');
                s.failed++; s.attempted--; continue;
            }
            if (cur.USASpending_Source_Run_ID__c != null
                && cur.USASpending_Source_Run_ID__c == row.Enrichment_Run_ID__c) {
                mark(ro, 'SKIPPED', 'IDEMPOTENCY', 'Source run already applied to Lead');
                s.skipped++; s.idempotencySkips++; s.duplicateWritePrevention++;
                s.attempted--; continue;
            }
            stillEligible.add(sid);
        }
        if (stillEligible.isEmpty()) { s.endedAt = System.now(); return s; }

        // --- de-duplicate: at most ONE update per Lead --------------------------------------
        // The engine builds one Lead update per staging row. If two eligible rows target the
        // SAME Lead they collide into a single Database.update as duplicate Ids, which throws an
        // uncaught System.ListException ("Duplicate id in list") and rolls the whole batch back
        // (verified: thrown pre-DML even with allOrNone=false). Instead, elect ONE winner per
        // Lead deterministically — the HIGHEST Award_Amount__c (the flagship award represents the
        // Lead), tie-broken by the row the caller listed FIRST (lowest position) — and defer the
        // rest as SKIPPED/DEDUPE, left Approved so a later batch can process them. One update per
        // Lead => a duplicate Id can never reach the DML. (Eligible rows always have a non-null
        // Award_Amount__c — the DATA gate above requires it.)
        Map<Id, Integer> callerPos = new Map<Id, Integer>();
        for (Integer i = 0; i < idsToProcess.size(); i++) {
            if (!callerPos.containsKey(idsToProcess[i])) { callerPos.put(idsToProcess[i], i); }
        }
        Map<Id, Id> winnerByLead = new Map<Id, Id>();   // Lead Id -> winning staging Id (highest amount, then caller-first)
        for (Id sid : stillEligible) {
            Id leadId = eligible.get(sid).Lead__c;
            Id cur = winnerByLead.get(leadId);
            if (cur == null) { winnerByLead.put(leadId, sid); continue; }
            Decimal candAmt = eligible.get(sid).Award_Amount__c;
            Decimal winAmt  = eligible.get(cur).Award_Amount__c;
            Boolean candWins = (candAmt > winAmt)
                || (candAmt == winAmt && callerPos.get(sid) < callerPos.get(cur));
            if (candWins) { winnerByLead.put(leadId, sid); }
        }
        List<Id> dedupedEligible = new List<Id>();
        for (Id sid : stillEligible) {
            Id leadId = eligible.get(sid).Lead__c;
            if (winnerByLead.get(leadId) == sid) {
                dedupedEligible.add(sid);
            } else {
                mark(outcome.get(sid), 'SKIPPED', 'DEDUPE',
                    'Another Approved row for this Lead is being written this batch (staging '
                    + winnerByLead.get(leadId) + '); deferred to prevent a duplicate Lead write');
                s.skipped++; s.dedupedSameLead++; s.attempted--;
            }
        }
        stillEligible = dedupedEligible;   // exactly one winner per Lead; never empty here

        // --- PREVIEW: no DML ---
        if (!s.commitWrites) {
            for (Id sid : stillEligible) {
                RowOutcome ro = outcome.get(sid);
                mark(ro, 'PREVIEW_OK', null, 'Eligible; would write (preview only, no DML)');
                ro.snapshotCaptured = false; // simulated only
            }
            s.endedAt = System.now();
            return s;
        }

        // --- COMMIT ---
        List<Lead> leadUpdates = new List<Lead>();
        Map<Id, Id> leadToStaging = new Map<Id, Id>();
        Map<Id, OA_USASpending_Staging__c> snapshots = new Map<Id, OA_USASpending_Staging__c>();

        for (Id sid : stillEligible) {
            OA_USASpending_Staging__c row = eligible.get(sid);
            leadUpdates.add(buildLeadUpdate(row));
            leadToStaging.put(row.Lead__c, sid);
            OA_USASpending_Staging__c snap = new OA_USASpending_Staging__c(Id = sid);
            snap.Before_Snapshot__c = buildSnapshot(currentLeads.get(row.Lead__c), s.runId);
            snapshots.put(sid, snap);
        }

        // FLS gate on the Lead write.
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, leadUpdates);
        Set<String> removed = decision.getRemovedFields().get('Lead');
        Boolean flsBlocked = false;
        if (removed != null) {
            for (String f : LEAD_TARGET_FIELDS) {
                if (removed.contains(f)) { flsBlocked = true; break; }
            }
        }
        if (flsBlocked) {
            s.unauthorizedRunAttempts = 1;
            for (Id sid : stillEligible) {
                mark(outcome.get(sid), 'FAILED', 'FLS',
                     'Running user lacks edit FLS on Lead write-back fields (needs OA_Lead_Writeback_Automation)');
                s.failed++;
            }
            s.attempted = 0;
            s.endedAt = System.now();
            return s;
        }

        // 1) Persist snapshots FIRST (before any Lead DML).
        Map<Id, Boolean> snapOk = new Map<Id, Boolean>();
        List<OA_USASpending_Staging__c> snapList = snapshots.values();
        Database.SaveResult[] snapRes = Database.update(snapList, false);
        for (Integer i = 0; i < snapList.size(); i++) {
            Id sid = snapList[i].Id;
            RowOutcome ro = outcome.get(sid);
            if (snapRes[i].isSuccess()) {
                snapOk.put(sid, true);
                ro.snapshotCaptured = true;
                s.snapshotCaptured++; s.rollbackReady++;
            } else {
                snapOk.put(sid, false);
                mark(ro, 'FAILED', 'SNAPSHOT', 'Snapshot persist failed: ' + firstError(snapRes[i]));
                s.failed++; s.attempted--;
            }
        }

        // 2) Update ONLY Leads whose snapshot persisted.
        List<Lead> strippedLeads = (List<Lead>) decision.getRecords();
        List<Lead> leadsToWrite = new List<Lead>();
        for (Lead ld : strippedLeads) {
            Id sid = leadToStaging.get(ld.Id);
            if (sid != null && snapOk.get(sid) == true) leadsToWrite.add(ld);
        }
        Map<Id, Boolean> leadWritten = new Map<Id, Boolean>();
        if (!leadsToWrite.isEmpty()) {
            Database.SaveResult[] leadRes = Database.update(leadsToWrite, false);
            for (Integer i = 0; i < leadsToWrite.size(); i++) {
                Id lid = leadsToWrite[i].Id;
                Id sid = leadToStaging.get(lid);
                RowOutcome ro = outcome.get(sid);
                if (leadRes[i].isSuccess()) {
                    leadWritten.put(sid, true);
                    ro.status = 'WRITTEN'; ro.leadId = lid; ro.gate = null; ro.reason = 'Written back';
                    s.succeeded++;
                    // defensive tripwires (must stay 0):
                    if (ro.snapshotCaptured != true) s.recordsWrittenWithoutSnapshot++;
                    if (eligible.get(sid).Review_Status__c != STATUS_APPROVED) s.recordsWrittenWithoutApproval++;
                    if (String.isBlank(s.runId)) s.recordsWrittenWithoutRunId++;
                } else {
                    leadWritten.put(sid, false);
                    mark(ro, 'FAILED', 'DML', 'Lead update failed: ' + firstError(leadRes[i]));
                    s.failed++; s.attempted--;
                }
            }
        }

        // 3) Stamp audit fields on successfully-written staging rows.
        List<OA_USASpending_Staging__c> stampList = new List<OA_USASpending_Staging__c>();
        for (Id sid : leadWritten.keySet()) {
            if (leadWritten.get(sid) == true) {
                OA_USASpending_Staging__c stamp = new OA_USASpending_Staging__c(Id = sid);
                stamp.Written_Back_By__c = UserInfo.getUserId();
                stamp.Written_Back_Date__c = System.now();
                stamp.Review_Status__c = STATUS_WRITTEN;
                stamp.Gate_Results__c = 'Write-back OK; runId=' + s.runId + '; at=' + System.now().format();
                stampList.add(stamp);
            }
        }
        if (!stampList.isEmpty()) {
            Database.update(stampList, false); // best-effort audit stamp
        }

        s.endedAt = System.now();
        return s;
    }

    // ---- helpers ----

    private static Lead buildLeadUpdate(OA_USASpending_Staging__c row) {
        Lead ld = new Lead(Id = row.Lead__c);
        ld.USASpending_Latest_Award_Amount__c = row.Award_Amount__c;
        ld.USASpending_Latest_Award_ID__c     = row.Award_ID__c;
        ld.USASpending_Latest_Award_Desc__c   = row.Award_Description__c;
        ld.USASpending_Awarding_Agency__c     = row.Awarding_Agency__c;
        ld.USASpending_Awarding_Sub_Agency__c = row.Awarding_Sub_Agency__c;
        ld.USASpending_Contract_Type__c       = row.Contract_Type__c;
        ld.USASpending_Performance_State__c   = row.Performance_State__c;
        ld.USASpending_UEI__c                 = row.Recipient_UEI__c;
        ld.USASpending_Source_Run_ID__c       = row.Enrichment_Run_ID__c;
        ld.USASpending_Last_Enriched__c       = row.Query_Date__c;
        ld.UEI_Verification_Run_ID__c         = row.Enrichment_Run_ID__c;
        ld.UEI_Verified_Date__c               = (row.Auto_Verified_Date__c != null) ? row.Auto_Verified_Date__c : System.now();
        ld.UEI_Verification_Source__c         = String.isNotBlank(row.Auto_Verification_Method__c) ? row.Auto_Verification_Method__c : 'USASpending';
        ld.UEI_Verification_Evidence__c       = row.Gate_Results__c;
        ld.UEI_Verified_By__c                 = UserInfo.getUserId();
        ld.UEI_Verification_Status__c         = VERIFIED;
        return ld;
    }

    private static String buildSnapshot(Lead cur, String runId) {
        if (cur == null) return null;
        Map<String, Object> fields = new Map<String, Object>();
        for (String f : LEAD_TARGET_FIELDS) {
            fields.put(f, cur.get(f));
        }
        Map<String, Object> snap = new Map<String, Object>{
            'leadId' => cur.Id,
            'capturedAt' => System.now().format(),
            'writeBackRunId' => runId,
            'fields' => fields
        };
        return JSON.serialize(snap);
    }

    private static void mark(RowOutcome ro, String status, String gate, String reason) {
        ro.status = status; ro.gate = gate; ro.reason = reason;
    }

    private static RowOutcome fail(Id stagingId, Id leadId, String gate, String reason) {
        RowOutcome ro = new RowOutcome();
        ro.stagingId = stagingId; ro.leadId = leadId;
        ro.status = 'FAILED'; ro.gate = gate; ro.reason = reason;
        return ro;
    }

    private static String firstError(Database.SaveResult sr) {
        if (sr.getErrors() != null && !sr.getErrors().isEmpty()) {
            return sr.getErrors()[0].getMessage();
        }
        return 'Unknown error';
    }

    // ============================ ROLLBACK ============================

    /**
     * Restore the 16 Lead write-back fields from Before_Snapshot__c for the given staging rows,
     * then reset the staging row (Review_Status__c -> Approved, clear write markers, audit note).
     *
     * SAFETY: explicit stagingIds only (no query-all); snapshot-driven (only the Lead named in the
     * snapshot is touched); FLS-enforced (WITH USER_MODE read + stripInaccessible write); blocks a row
     * if its snapshot is null, invalid JSON, or its snapshot leadId does not match staging Lead__c;
     * row-independent partial success; no connector, no callouts, no permission-set assignment.
     * Before_Snapshot__c is KEPT for audit (not cleared).
     */
    public static RollbackSummary rollback(List<Id> stagingIds) {
        RollbackSummary s = new RollbackSummary();
        s.runId = 'RB-' + UserInfo.getUserId() + '-' + String.valueOf(System.now().getTime());
        if (stagingIds == null || stagingIds.isEmpty()) return s;

        List<Id> ids = new List<Id>();
        for (Id sid : stagingIds) {
            if (ids.size() >= MAX_LIMIT) break;
            if (sid != null) ids.add(sid);
        }

        List<OA_USASpending_Staging__c> rows;
        try {
            rows = [
                SELECT Id, Lead__c, Review_Status__c, Written_Back_Date__c, Before_Snapshot__c, Gate_Results__c
                FROM OA_USASpending_Staging__c WHERE Id IN :ids WITH USER_MODE
            ];
        } catch (Exception e) {
            for (Id sid : ids) { s.rows.add(rbFail(sid, null, 'FLS', 'Staging read denied: ' + e.getMessage())); s.failed++; }
            return s;
        }

        Map<Id, Lead> restores = new Map<Id, Lead>();
        Map<Id, Id> leadToStaging = new Map<Id, Id>();
        Map<Id, RollbackOutcome> byStaging = new Map<Id, RollbackOutcome>();

        for (OA_USASpending_Staging__c row : rows) {
            RollbackOutcome ro = new RollbackOutcome();
            ro.stagingId = row.Id; ro.leadId = row.Lead__c;
            byStaging.put(row.Id, ro); s.rows.add(ro);

            if (String.isBlank(row.Before_Snapshot__c)) {
                rbMark(ro, 'SKIPPED', 'SNAPSHOT_MISSING', 'No snapshot to roll back'); s.skipped++; continue;
            }
            Map<String, Object> snap;
            try { snap = (Map<String, Object>) JSON.deserializeUntyped(row.Before_Snapshot__c); }
            catch (Exception e) { rbMark(ro, 'FAILED', 'SNAPSHOT_INVALID', 'Invalid snapshot JSON'); s.failed++; continue; }

            Object snapLeadId = snap.get('leadId');
            Object fieldsObj = snap.get('fields');
            if (snapLeadId == null || !(fieldsObj instanceof Map<String, Object>)) {
                rbMark(ro, 'FAILED', 'SNAPSHOT_INVALID', 'Snapshot missing leadId/fields'); s.failed++; continue;
            }
            Id snapLid;
            try { snapLid = (Id) String.valueOf(snapLeadId); }
            catch (Exception e) { rbMark(ro, 'FAILED', 'SNAPSHOT_INVALID', 'Snapshot leadId not a valid Id'); s.failed++; continue; }
            if (row.Lead__c == null || snapLid != row.Lead__c) {
                rbMark(ro, 'FAILED', 'LEAD_MISMATCH', 'Snapshot leadId does not match staging Lead__c'); s.failed++; continue;
            }
            restores.put(row.Lead__c, buildRestore(row.Lead__c, (Map<String, Object>) fieldsObj));
            leadToStaging.put(row.Lead__c, row.Id);
        }

        if (restores.isEmpty()) return s;

        // FLS gate on the restore write.
        List<Lead> restoreList = restores.values();
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, restoreList);
        Set<String> removed = decision.getRemovedFields().get('Lead');
        Boolean flsBlocked = false;
        if (removed != null) { for (String f : LEAD_TARGET_FIELDS) { if (removed.contains(f)) { flsBlocked = true; break; } } }
        if (flsBlocked) {
            for (Id lid : leadToStaging.keySet()) {
                rbMark(byStaging.get(leadToStaging.get(lid)), 'FAILED', 'FLS',
                       'Running user lacks edit FLS to restore Lead fields'); s.failed++;
            }
            return s;
        }

        List<Lead> stripped = (List<Lead>) decision.getRecords();
        s.attempted = stripped.size();
        Database.SaveResult[] res = Database.update(stripped, false);
        Set<Id> restoredStaging = new Set<Id>();
        for (Integer i = 0; i < stripped.size(); i++) {
            Id sid = leadToStaging.get(stripped[i].Id);
            RollbackOutcome ro = byStaging.get(sid);
            if (res[i].isSuccess()) {
                rbMark(ro, 'RESTORED', null, 'Lead restored from snapshot'); s.succeeded++; restoredStaging.add(sid);
            } else {
                rbMark(ro, 'FAILED', 'DML', 'Lead restore failed: ' + firstError(res[i])); s.failed++; s.rollbackFailures++;
            }
        }

        // Reset staging for restored rows (Approved; clear write markers; append audit note). Snapshot KEPT.
        List<OA_USASpending_Staging__c> stamps = new List<OA_USASpending_Staging__c>();
        for (OA_USASpending_Staging__c row : rows) {
            if (restoredStaging.contains(row.Id)) {
                OA_USASpending_Staging__c st = new OA_USASpending_Staging__c(Id = row.Id);
                st.Review_Status__c = STATUS_APPROVED;
                st.Written_Back_Date__c = null;
                st.Written_Back_By__c = null;
                String note = 'Rolled back; runId=' + s.runId + '; at=' + System.now().format();
                st.Gate_Results__c = String.isBlank(row.Gate_Results__c) ? note : (row.Gate_Results__c + '\n' + note);
                stamps.add(st);
            }
        }
        if (!stamps.isEmpty()) Database.update(stamps, false);

        return s;
    }

    private static Lead buildRestore(Id leadId, Map<String, Object> f) {
        Lead ld = new Lead(Id = leadId);
        ld.UEI_Verification_Status__c         = rbStr(f, 'UEI_Verification_Status__c');
        ld.UEI_Verification_Source__c         = rbStr(f, 'UEI_Verification_Source__c');
        ld.UEI_Verification_Evidence__c       = rbStr(f, 'UEI_Verification_Evidence__c');
        ld.UEI_Verification_Run_ID__c         = rbStr(f, 'UEI_Verification_Run_ID__c');
        ld.USASpending_Latest_Award_ID__c     = rbStr(f, 'USASpending_Latest_Award_ID__c');
        ld.USASpending_Latest_Award_Desc__c   = rbStr(f, 'USASpending_Latest_Award_Desc__c');
        ld.USASpending_Awarding_Agency__c     = rbStr(f, 'USASpending_Awarding_Agency__c');
        ld.USASpending_Awarding_Sub_Agency__c = rbStr(f, 'USASpending_Awarding_Sub_Agency__c');
        ld.USASpending_Contract_Type__c       = rbStr(f, 'USASpending_Contract_Type__c');
        ld.USASpending_Performance_State__c   = rbStr(f, 'USASpending_Performance_State__c');
        ld.USASpending_Source_Run_ID__c       = rbStr(f, 'USASpending_Source_Run_ID__c');
        ld.USASpending_UEI__c                 = rbStr(f, 'USASpending_UEI__c');
        ld.UEI_Verified_Date__c               = rbDateTime(f, 'UEI_Verified_Date__c');
        ld.USASpending_Last_Enriched__c       = rbDate(f, 'USASpending_Last_Enriched__c');
        ld.USASpending_Latest_Award_Amount__c = rbDecimal(f, 'USASpending_Latest_Award_Amount__c');
        ld.UEI_Verified_By__c                 = rbId(f, 'UEI_Verified_By__c');
        return ld;
    }

    private static String rbStr(Map<String, Object> f, String k) {
        Object o = f.get(k); return o == null ? null : String.valueOf(o);
    }
    private static Datetime rbDateTime(Map<String, Object> f, String k) {
        Object o = f.get(k); if (o == null) return null;
        return (o instanceof Datetime) ? (Datetime) o : (Datetime) JSON.deserialize(JSON.serialize(o), Datetime.class);
    }
    private static Date rbDate(Map<String, Object> f, String k) {
        Object o = f.get(k); if (o == null) return null;
        return (o instanceof Date) ? (Date) o : (Date) JSON.deserialize(JSON.serialize(o), Date.class);
    }
    private static Decimal rbDecimal(Map<String, Object> f, String k) {
        Object o = f.get(k); if (o == null) return null;
        if (o instanceof Decimal) return (Decimal) o;
        if (o instanceof Double)  return Decimal.valueOf((Double) o);
        if (o instanceof Integer) return Decimal.valueOf((Integer) o);
        return (Decimal) JSON.deserialize(JSON.serialize(o), Decimal.class);
    }
    private static Id rbId(Map<String, Object> f, String k) {
        Object o = f.get(k); return o == null ? null : (Id) String.valueOf(o);
    }

    private static void rbMark(RollbackOutcome ro, String status, String gate, String reason) {
        ro.status = status; ro.gate = gate; ro.reason = reason;
    }
    private static RollbackOutcome rbFail(Id stagingId, Id leadId, String gate, String reason) {
        RollbackOutcome ro = new RollbackOutcome();
        ro.stagingId = stagingId; ro.leadId = leadId; ro.status = 'FAILED'; ro.gate = gate; ro.reason = reason;
        return ro;
    }
}