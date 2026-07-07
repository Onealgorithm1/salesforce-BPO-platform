/**
 * OA_EnrichmentQueueable — Queueable sibling of OA_EnrichmentOrchestrator for manual / small-set /
 * on-demand runs (e.g. a controlled canary, an ad-hoc re-enrichment of specific Leads).
 *
 * Shares the exact same execution core (OA_EnrichmentOrchestrator.processScope) so behaviour is
 * identical to the batch path — it just processes an explicit list of Lead Ids in one async
 * transaction. SAFE BY DEFAULT: commitWrites defaults to false. Nothing here schedules itself.
 */
public with sharing class OA_EnrichmentQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> leadIds;
    private String source;
    private String ruleset;
    private Boolean commitWrites;
    private String runId;

    public OA_EnrichmentQueueable(List<Id> leadIds, String source, String ruleset, Boolean commitWrites) {
        this.leadIds = leadIds;
        this.source = source;
        this.ruleset = ruleset;
        this.commitWrites = (commitWrites == true);
        this.runId = ('ORCHQ-' + source + '-' + String.valueOf(Datetime.now().getTime())).abbreviate(80);
    }

    public void execute(QueueableContext ctx) {
        Datetime startedAt = Datetime.now();
        List<Lead> leads = (leadIds == null || leadIds.isEmpty())
            ? new List<Lead>()
            : [SELECT Id, Company, UEI__c, Website, Phone, State FROM Lead WHERE Id IN :leadIds];

        List<OA_Connector_Run__c> telemetry = new List<OA_Connector_Run__c>();
        OA_EnrichmentOrchestrator.Metrics m =
            OA_EnrichmentOrchestrator.processScope(leads, source, ruleset, commitWrites, 1, telemetry);

        if (!telemetry.isEmpty()) {
            Database.insert(telemetry, false, AccessLevel.USER_MODE);
        }
        Database.insert(
            new List<OA_Connector_Run__c>{ OA_EnrichmentOrchestrator.buildSummary(runId, source, startedAt, m) },
            false, AccessLevel.USER_MODE);
    }
}
