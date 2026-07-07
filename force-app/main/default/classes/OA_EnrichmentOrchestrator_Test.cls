/**
 * Tests for the Sprint 17 operational execution layer: OA_ProposalAdapter, OA_EnrichmentOrchestrator
 * (batch + shared core), and OA_EnrichmentQueueable. No live callouts — the connector runner is driven
 * dormant (disabled registry -> Skipped) or via a forced RunOutcome, so the platform engines
 * (adapter -> writer -> policy -> telemetry) are exercised deterministically.
 */
@isTest
private class OA_EnrichmentOrchestrator_Test {

    private static Integer seq = 0;
    private static Lead newLead(String company) {
        seq++;
        return new Lead(LastName = 'T', Company = company, Status = 'Open - Not Contacted',
                        Email = 'orch.test.' + seq + '@example.invalid');
    }

    private static List<OA_Connector_Registry__mdt> disabledSam() {
        return new List<OA_Connector_Registry__mdt>{
            new OA_Connector_Registry__mdt(
                Source_System__c = 'SAM', Enabled__c = false, Connector_Class__c = 'OA_SAM_Connector')
        };
    }

    private static OA_CanonicalOrg samOrg() {
        OA_CanonicalOrg org = new OA_CanonicalOrg();
        org.uei = 'ORCHUEI0001';
        org.cageCode = '9ZZZ9';
        org.sourceConfidence = 'HIGH';
        org.attributes.put('Registration_Status', 'Active');
        org.attributes.put('Business_Types', 'Woman Owned Small Business');
        return org;
    }

    @isTest static void adapter_resolves_every_source() {
        OA_CanonicalOrg org = samOrg();
        System.assert(!OA_ProposalAdapter.toLeadProposals('SAM', org).isEmpty(), 'SAM maps proposals');
        for (String s : new List<String>{ 'USASPENDING', 'CENSUS', 'IRS', 'SEC', 'STATEREGISTRY', 'STATE' }) {
            System.assertNotEquals(null, OA_ProposalAdapter.toLeadProposals(s, org), s + ' returns a list');
        }
        System.assert(OA_ProposalAdapter.toLeadProposals('SAM', null).isEmpty(), 'null org -> empty');
        System.assert(OA_ProposalAdapter.toLeadProposals(null, org).isEmpty(), 'null source -> empty');
        System.assert(OA_ProposalAdapter.toLeadProposals('MYSTERY', org).isEmpty(), 'unknown source -> empty');
    }

    @isTest static void batch_runs_dormant_and_records_telemetry() {
        OA_ConnectorRunner.registryOverride = disabledSam();
        insert new List<Lead>{ newLead('Acme LLC'), newLead('Beta Inc') };
        Test.startTest();
        Id jobId = OA_EnrichmentOrchestrator.enqueueBatch('SAM', null, null, false, 10);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'batch enqueued');
        Integer runs = [SELECT COUNT() FROM OA_Connector_Run__c WHERE Initiated_By__c = :UserInfo.getUserId()];
        System.assert(runs >= 1, 'at least the run summary persisted (dormant, no writes)');
    }

    @isTest static void core_write_path_preview_then_commit() {
        Lead ld = newLead('Gamma Corp');
        insert ld;
        ld = [SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead WHERE Id = :ld.Id];

        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner.RunOutcome();
        o.status = OA_ConnectorRunner.STATUS_SUCCEEDED;
        o.recordsQualified = 1;
        o.httpErrors = 0;
        o.organizations = new List<OA_CanonicalOrg>{ samOrg() };
        o.runRecord = new OA_Connector_Run__c(Run_ID__c = 'X-1', Source_System__c = 'SAM');
        OA_EnrichmentOrchestrator.runOutcomeOverride = o;

        List<OA_Connector_Run__c> tele = new List<OA_Connector_Run__c>();
        // preview: no DML to the Lead, but the platform still evaluates + counts
        OA_EnrichmentOrchestrator.Metrics mp =
            OA_EnrichmentOrchestrator.processScope(new List<Lead>{ ld }, 'SAM', null, false, 1, tele);
        System.assertEquals(1, mp.leadsProcessed, 'one lead processed');
        System.assertEquals(false, mp.committed, 'preview not committed');
        System.assert(tele.size() >= 1, 'telemetry captured');

        // commit: opt-in write path
        OA_EnrichmentOrchestrator.Metrics mc =
            OA_EnrichmentOrchestrator.processScope(new List<Lead>{ ld }, 'SAM', 'Federal EDWOSB', true, 1, null);
        System.assertEquals(1, mc.leadsProcessed, 'one lead processed on commit');
        System.assertEquals(true, mc.committed, 'commit flag set');
    }

    @isTest static void unrecoverable_failure_aborts_run() {
        insert new List<Lead>{ newLead('A Co'), newLead('B Co') };
        List<Lead> ql = [SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead ORDER BY Company];

        OA_ConnectorRunner.RunOutcome o = new OA_ConnectorRunner.RunOutcome();
        o.status = OA_ConnectorRunner.STATUS_FAILED;
        o.organizations = new List<OA_CanonicalOrg>();
        OA_EnrichmentOrchestrator.runOutcomeOverride = o;

        OA_EnrichmentOrchestrator.Metrics m =
            OA_EnrichmentOrchestrator.processScope(ql, 'SAM', null, false, 1, null);
        System.assert(m.aborted, 'run aborts on unrecoverable failure');
        System.assertEquals(1, m.leadsProcessed, 'stops after the first failing record');
    }

    @isTest static void blank_input_is_skipped() {
        Lead ghost = new Lead(LastName = 'Ghost');   // no Company, no UEI -> no connector input
        OA_EnrichmentOrchestrator.Metrics m =
            OA_EnrichmentOrchestrator.processScope(new List<Lead>{ ghost }, 'SAM', null, false, 1, null);
        System.assertEquals(0, m.leadsProcessed, 'blank input skipped');
        // empty scope is a no-op
        System.assertEquals(0,
            OA_EnrichmentOrchestrator.processScope(new List<Lead>(), 'SAM', null, false, 1, null).leadsProcessed);
    }

    @isTest static void queueable_processes_explicit_ids() {
        OA_ConnectorRunner.registryOverride = disabledSam();
        Lead ld = newLead('Delta LLC');
        insert ld;
        Test.startTest();
        System.enqueueJob(new OA_EnrichmentQueueable(new List<Id>{ ld.Id }, 'SAM', null, false));
        Test.stopTest();
        Integer runs = [SELECT COUNT() FROM OA_Connector_Run__c
                        WHERE Source_System__c = 'SAM' AND Initiated_By__c = :UserInfo.getUserId()];
        System.assert(runs >= 1, 'queueable persisted a run summary');
        // empty-id queueable is a safe no-op
        System.enqueueJob(new OA_EnrichmentQueueable(new List<Id>(), 'SAM', null, false));
    }
}
