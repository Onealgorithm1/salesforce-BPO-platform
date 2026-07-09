/**
 * OA_FederalAcquisitionScheduler — dormant cloud-execution wrapper (Program 024).
 * Enables PC-off scheduled federal intake. DEPLOYED DORMANT — NOT scheduled (scheduling requires
 * explicit Louis approval per governance). Runs the free Grants.gov intake (capped, human-gated).
 */
public with sharing class OA_FederalAcquisitionScheduler implements Schedulable {
    public String keyword;
    public OA_FederalAcquisitionScheduler() { this.keyword = null; }
    public OA_FederalAcquisitionScheduler(String kw) { this.keyword = kw; }
    public void execute(SchedulableContext sc) {
        OA_FederalOpportunityAcquisition.Result r = OA_FederalOpportunityAcquisition.grantsGov(keyword, 10);
        System.debug('[ACQ-SCHED] Grants.gov fetched=' + r.fetched + ' inserted=' + r.inserted + ' dup=' + r.duplicates + ' err=' + r.error);
    }
}
