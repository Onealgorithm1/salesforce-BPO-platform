/**
 * OA_CandidateDiscoveryQueueable — reusable async execution for Candidate Discovery (capability only; NOT scheduled).
 *
 * Runs OA_CandidateDiscovery.run() for one or more inputs asynchronously, then CHAINS itself for any remaining inputs.
 * Because each chained job runs in its own transaction, processing ONE input per execution (batchSize=1) naturally
 * SPACES connector callouts across transactions — mitigating burst rate-limits (e.g. SEC EDGAR) without any scheduler.
 *
 * Connector-independent (delegates to the generic driver). Preserves preview mode (commitWrites=false -> 0 DML),
 * commit mode, identity resolution, source fusion, completeness, and audit — all via OA_CandidateDiscovery /
 * OA_CandidateDiscoveryService. Creates NO schedule and enables NO automation: it does nothing until a caller
 * explicitly System.enqueueJob()s it (a future, gated operational action). Writes ONLY the Candidate object.
 */
public with sharing class OA_CandidateDiscoveryQueueable implements Queueable, Database.AllowsCallouts {

    private final String connectorName;
    private final List<String> inputs;
    private final Boolean commitWrites;
    private final Integer maxResults;
    private final Integer batchSize;

    public OA_CandidateDiscoveryQueueable(String connectorName, List<String> inputs, Boolean commitWrites, Integer maxResults, Integer batchSize) {
        this.connectorName = connectorName;
        this.inputs = (inputs == null) ? new List<String>() : inputs;
        this.commitWrites = (commitWrites == true);
        this.maxResults = maxResults;
        this.batchSize = (batchSize == null || batchSize < 1) ? 1 : batchSize;
    }

    public void execute(QueueableContext ctx) {
        if (inputs.isEmpty()) { return; }

        Integer sliceEnd = Math.min(batchSize, inputs.size());
        List<String> slice = new List<String>();
        for (Integer i = 0; i < sliceEnd; i++) { slice.add(inputs[i]); }
        List<String> remaining = new List<String>();
        for (Integer i = sliceEnd; i < inputs.size(); i++) { remaining.add(inputs[i]); }

        for (String input : slice) {
            OA_CandidateDiscovery.Result r = OA_CandidateDiscovery.run(connectorName, input, commitWrites, maxResults);
            // One bounded, connector-agnostic retry on a transient HTTP failure.
            if (r != null && r.httpErrors != null && r.httpErrors > 0) {
                r = OA_CandidateDiscovery.run(connectorName, input, commitWrites, maxResults);
            }
            Integer fused = (r != null && r.candidates != null) ? r.candidates.fused : 0;
            Integer inserted = (r != null && r.candidates != null) ? r.candidates.inserted : 0;
            System.debug(LoggingLevel.INFO, 'OACDQ ' + connectorName + ' input=' + input
                + ' status=' + (r == null ? null : r.lastStatus) + ' fused=' + fused + ' inserted=' + inserted);
        }

        // Chain for the remainder -> next transaction -> spaces callouts. No scheduler; not chained in tests.
        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new OA_CandidateDiscoveryQueueable(connectorName, remaining, commitWrites, maxResults, batchSize));
        }
    }
}