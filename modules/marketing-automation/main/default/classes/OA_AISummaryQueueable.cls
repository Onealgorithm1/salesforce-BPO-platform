public class OA_AISummaryQueueable implements Queueable {

    private Id leadId;

    public OA_AISummaryQueueable(Id leadId) {
        this.leadId = leadId;
    }

    // Bridges the @future-to-@future callout restriction.
    // OA_ArtifactPoller.processArtifacts is @future and cannot directly invoke
    // OA_AISummaryService.summarize (also @future). Enqueueing this Queueable from
    // processArtifacts is allowed; a Queueable may call a @future method.
    public void execute(QueueableContext ctx) {
        OA_AISummaryService.summarize(leadId);
    }
}
