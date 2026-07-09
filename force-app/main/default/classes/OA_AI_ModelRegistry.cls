/**
 * OA_AI_ModelRegistry — dynamic model discovery + routing recommendation over OpenRouter.
 *
 * Uses the PUBLIC OpenRouter /models endpoint (no secret) to discover the live catalog (340+ models,
 * pricing, context) — NO hardcoded catalog. Provides a data-driven routing RECOMMENDATION per workload
 * (cheapest model meeting a minimum context) — recommendation only; it never switches production routing
 * (that stays in OA_AI_Model__mdt, human-approved). Reuses OA_OpenRouter Named Credential.
 */
public with sharing class OA_AI_ModelRegistry {

    public class ModelInfo {
        public String id;
        public String provider;          // vendor prefix (openai, google, anthropic, x-ai, ...)
        public Integer contextLength;
        public Decimal promptPrice;      // USD per token
        public Decimal completionPrice;  // USD per token
    }

    /** Discover the live OpenRouter catalog. Public endpoint — no auth/secret required. */
    public static List<ModelInfo> discover() {
        List<ModelInfo> out = new List<ModelInfo>();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OA_OpenRouter/models'); req.setMethod('GET'); req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) { return out; }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> data = (List<Object>) root.get('data');
        if (data == null) return out;
        for (Object o : data) {
            Map<String, Object> m = (Map<String, Object>) o;
            ModelInfo mi = new ModelInfo();
            mi.id = (String) m.get('id');
            mi.provider = (mi.id != null && mi.id.contains('/')) ? mi.id.substringBefore('/') : null;
            if (m.get('context_length') != null) mi.contextLength = Integer.valueOf(m.get('context_length'));
            Map<String, Object> pricing = (Map<String, Object>) m.get('pricing');
            if (pricing != null) {
                mi.promptPrice = decOf(pricing.get('prompt'));
                mi.completionPrice = decOf(pricing.get('completion'));
            }
            out.add(mi);
        }
        return out;
    }

    /**
     * Data-driven RECOMMENDATION for a workload: cheapest model (by prompt+completion price) whose context
     * meets minContext. Recommendation only — does NOT change OA_AI_Model__mdt (human approval required).
     */
    public static ModelInfo recommend(Integer minContext) {
        ModelInfo best;
        for (ModelInfo mi : discover()) {
            if (mi.promptPrice == null || mi.completionPrice == null) continue;
            if (mi.promptPrice < 0 || mi.completionPrice < 0) continue;   // skip variable/auto pricing (-1)
            if (mi.contextLength != null && minContext != null && mi.contextLength < minContext) continue;
            Decimal cost = mi.promptPrice + mi.completionPrice;
            if (best == null || cost < (best.promptPrice + best.completionPrice)) best = mi;
        }
        return best;
    }

    private static Decimal decOf(Object o) {
        if (o == null) return null;
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
    }
}
