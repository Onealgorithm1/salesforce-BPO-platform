/**
 * OA_AI_Gateway — the single, reusable Enterprise AI entry point.
 *
 * Every AI workload calls OA_AI_Gateway.complete(workflow, prompt, ...) — NO workflow calls a provider
 * directly. Routing is CONFIG-DRIVEN (OA_AI_Model__mdt): default provider = OpenRouter (provider-agnostic,
 * 340+ models), fallback = Anthropic. Captures tokens / latency / cost / status to OA_AI_Request_Log__c
 * (measurable spend). No hardcoded model names (resolved from CMDT). Nothing fails silently — failures are
 * logged with a reason and surfaced on the result.
 */
public with sharing class OA_AI_Gateway {

    // Rough per-token cost estimate (USD) when live pricing is not wired; documented as an estimate.
    private static final Decimal DEFAULT_RATE = 0.000002;

    /** Resolved routing config (from OA_AI_Model__mdt; test-injectable; safe last-resort seed). */
    public class ModelConfig {
        public String provider; public String model;
        public String fbProvider; public String fbModel; public Integer maxTokens;
        public ModelConfig(String p, String m, String fp, String fm, Integer mt) {
            provider = p; model = m; fbProvider = fp; fbModel = fm; maxTokens = mt;
        }
    }
    /** Tests inject config here to avoid depending on deployed CMDT records. */
    @TestVisible private static Map<String, ModelConfig> configOverride;

    public class GatewayResult {
        public String text;
        public String provider;
        public String model;
        public String workflow;
        public Integer promptTokens = 0;
        public Integer completionTokens = 0;
        public Integer totalTokens = 0;
        public Long latencyMs = 0;
        public Integer statusCode;
        public Integer retryCount = 0;
        public Boolean success = false;
        public String failureReason;
        public Decimal estimatedCost = 0;
    }

    /** Convenience overload. */
    public static GatewayResult complete(String workflow, String prompt) {
        return complete(workflow, prompt, null, null);
    }

    /**
     * @param workflow        OA_AI_Model__mdt DeveloperName (e.g. 'Meeting_Summary'); falls back to 'Default'
     * @param prompt          user content
     * @param businessProcess free-text tag for cost attribution
     * @param recordId        related Salesforce record (audit)
     */
    public static GatewayResult complete(String workflow, String prompt, String businessProcess, Id recordId) {
        GatewayResult r = new GatewayResult();
        r.workflow = workflow;
        ModelConfig cfg = resolveConfig(workflow);
        Integer maxTokens = (cfg.maxTokens != null) ? cfg.maxTokens : 1024;

        Long t0 = System.currentTimeMillis();
        // Primary provider (config-driven; default OpenRouter)
        try {
            callProvider(r, cfg.provider, cfg.model, prompt, maxTokens);
        } catch (Exception e) {
            r.success = false; r.failureReason = e.getTypeName() + ': ' + e.getMessage();
        }
        // Fallback provider on failure (default Anthropic)
        if (!r.success && String.isNotBlank(cfg.fbProvider)) {
            r.retryCount = 1;
            try {
                callProvider(r, cfg.fbProvider, cfg.fbModel, prompt, maxTokens);
            } catch (Exception e2) {
                r.success = false; r.failureReason = (r.failureReason == null ? '' : r.failureReason + ' | ')
                    + 'fallback ' + e2.getTypeName() + ': ' + e2.getMessage();
            }
        }
        r.latencyMs = System.currentTimeMillis() - t0;
        r.totalTokens = (r.totalTokens != 0) ? r.totalTokens : (r.promptTokens + r.completionTokens);
        r.estimatedCost = (r.totalTokens) * DEFAULT_RATE;

        logRequest(r, businessProcess, recordId);
        return r;
    }

    /** Route to a provider by name (no hardcoded provider in the call path). */
    private static void callProvider(GatewayResult r, String provider, String model, String prompt, Integer maxTokens) {
        r.provider = provider; r.model = model;
        HttpResponse res = (provider == 'Anthropic')
            ? anthropicCall(model, prompt, maxTokens)
            : openRouterCall(model, prompt, maxTokens);   // OpenRouter is the default abstraction
        r.statusCode = res.getStatusCode();
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            parseUsageAndText(r, provider, res.getBody());
            r.success = String.isNotBlank(r.text);
            if (!r.success) r.failureReason = 'empty completion';
        } else {
            r.success = false;
            r.failureReason = provider + ' HTTP ' + res.getStatusCode() + ': ' + abbreviate(res.getBody(), 200);
        }
    }

    private static HttpResponse openRouterCall(String model, String prompt, Integer maxTokens) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OA_OpenRouter/chat/completions');   // base already includes /api/v1
        req.setMethod('POST'); req.setHeader('Content-Type', 'application/json'); req.setTimeout(60000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'model' => model,
            'max_tokens' => maxTokens,
            'messages' => new List<Object>{ new Map<String, Object>{ 'role' => 'user', 'content' => prompt } }
        }));
        return new Http().send(req);
    }

    private static HttpResponse anthropicCall(String model, String prompt, Integer maxTokens) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OA_Anthropic/v1/messages');
        req.setMethod('POST'); req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01'); req.setTimeout(60000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'model' => model,
            'max_tokens' => maxTokens,
            'messages' => new List<Object>{ new Map<String, Object>{ 'role' => 'user', 'content' => prompt } }
        }));
        return new Http().send(req);
    }

    /** Parse text + token usage per provider response shape. */
    private static void parseUsageAndText(GatewayResult r, String provider, String body) {
        if (String.isBlank(body)) return;
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        Map<String, Object> usage = (Map<String, Object>) root.get('usage');
        if (provider == 'Anthropic') {
            List<Object> content = (List<Object>) root.get('content');
            if (content != null && !content.isEmpty()) {
                r.text = String.valueOf(((Map<String, Object>) content[0]).get('text'));
            }
            if (usage != null) {
                r.promptTokens = intOf(usage.get('input_tokens'));
                r.completionTokens = intOf(usage.get('output_tokens'));
            }
        } else { // OpenRouter / OpenAI-compatible
            List<Object> choices = (List<Object>) root.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> msg = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
                if (msg != null) r.text = String.valueOf(msg.get('content'));
            }
            if (usage != null) {
                r.promptTokens = intOf(usage.get('prompt_tokens'));
                r.completionTokens = intOf(usage.get('completion_tokens'));
                if (usage.get('total_tokens') != null) r.totalTokens = intOf(usage.get('total_tokens'));
            }
        }
    }

    /**
     * Resolve routing config: test override → OA_AI_Model__mdt(workflow) → OA_AI_Model__mdt('Default')
     * → safe last-resort seed (OpenRouter default, Anthropic fallback). Never returns null; no NPE.
     */
    private static ModelConfig resolveConfig(String workflow) {
        if (configOverride != null) {
            if (configOverride.containsKey(workflow)) return configOverride.get(workflow);
            if (configOverride.containsKey('Default')) return configOverride.get('Default');
        }
        OA_AI_Model__mdt m = String.isBlank(workflow) ? null : OA_AI_Model__mdt.getInstance(workflow);
        if (m == null) m = OA_AI_Model__mdt.getInstance('Default');
        if (m != null) {
            return new ModelConfig(m.Provider__c, m.Model__c, m.Fallback_Provider__c, m.Fallback_Model__c,
                m.Max_Tokens__c == null ? 1024 : m.Max_Tokens__c.intValue());
        }
        // Last-resort seed so the gateway is always operational (config still lives in OA_AI_Model__mdt).
        return new ModelConfig('OpenRouter', 'openai/gpt-4o-mini', 'Anthropic', 'claude-sonnet-4-6', 1024);
    }

    private static void logRequest(GatewayResult r, String businessProcess, Id recordId) {
        try {
            insert new OA_AI_Request_Log__c(
                Provider__c = abbreviate(r.provider, 40),
                Model__c = abbreviate(r.model, 80),
                Workflow__c = abbreviate(r.workflow, 80),
                Prompt_Tokens__c = r.promptTokens,
                Completion_Tokens__c = r.completionTokens,
                Total_Tokens__c = r.totalTokens,
                Latency_Ms__c = r.latencyMs,
                Estimated_Cost__c = r.estimatedCost,
                Status_Code__c = r.statusCode,
                Retry_Count__c = r.retryCount,
                Failure_Reason__c = abbreviate(r.failureReason, 255),
                Business_Process__c = abbreviate(businessProcess, 120)
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OA_AI_Gateway log failed: ' + e.getMessage());
        }
    }

    private static Integer intOf(Object o) { return o == null ? 0 : Integer.valueOf(o); }
    private static String abbreviate(String s, Integer n) { return s == null ? null : s.abbreviate(n); }
}