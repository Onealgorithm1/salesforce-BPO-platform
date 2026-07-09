/**
 * OA_AI_Gateway_Test — mocked provider callouts; validates routing, fallback, token capture, and logging.
 * No live callouts. Uses the deployed OA_AI_Model__mdt 'Default' (OpenRouter -> Anthropic fallback).
 */
@isTest
private class OA_AI_Gateway_Test {

    @testSetup
    static void seed() { /* config injected per-test via configOverride */ }

    private static void injectConfig() {
        OA_AI_Gateway.configOverride = new Map<String, OA_AI_Gateway.ModelConfig>{
            'Default' => new OA_AI_Gateway.ModelConfig('OpenRouter', 'openai/gpt-4o-mini', 'Anthropic', 'claude-sonnet-4-6', 256)
        };
    }

    private class Mock implements HttpCalloutMock {
        Integer openRouterStatus;
        Mock(Integer orStatus) { this.openRouterStatus = orStatus; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse(); res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('OA_OpenRouter')) {
                res.setStatusCode(openRouterStatus);
                res.setBody(openRouterStatus == 200
                    ? '{"choices":[{"message":{"content":"OpenRouter says hi"}}],"usage":{"prompt_tokens":5,"completion_tokens":3,"total_tokens":8}}'
                    : '{"error":"upstream"}');
            } else { // Anthropic
                res.setStatusCode(200);
                res.setBody('{"content":[{"type":"text","text":"Anthropic fallback hi"}],"usage":{"input_tokens":4,"output_tokens":2}}');
            }
            return res;
        }
    }

    @isTest static void testPrimaryOpenRouter() {
        injectConfig(); Test.setMock(HttpCalloutMock.class, new Mock(200));
        Test.startTest();
        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Default', 'hello', 'unit-test', null);
        Test.stopTest();
        System.assertEquals(true, r.success);
        System.assertEquals('OpenRouter', r.provider);
        System.assertEquals('OpenRouter says hi', r.text);
        System.assertEquals(8, r.totalTokens);
        System.assertEquals(0, r.retryCount);
        System.assertEquals(1, [SELECT COUNT() FROM OA_AI_Request_Log__c WHERE Provider__c='OpenRouter']);
    }

    @isTest static void testFallbackToAnthropic() {
        injectConfig(); Test.setMock(HttpCalloutMock.class, new Mock(500));   // OpenRouter fails
        Test.startTest();
        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Default', 'hello', 'unit-test', null);
        Test.stopTest();
        System.assertEquals(true, r.success, 'should succeed via Anthropic fallback');
        System.assertEquals('Anthropic', r.provider);
        System.assertEquals('Anthropic fallback hi', r.text);
        System.assertEquals(1, r.retryCount);
        System.assert(r.promptTokens > 0);
        System.assertEquals(1, [SELECT COUNT() FROM OA_AI_Request_Log__c WHERE Provider__c='Anthropic' AND Retry_Count__c=1]);
    }

    @isTest static void testConvenienceOverload() {
        injectConfig(); Test.setMock(HttpCalloutMock.class, new Mock(200));
        Test.startTest();
        OA_AI_Gateway.GatewayResult r = OA_AI_Gateway.complete('Default', 'hi');
        Test.stopTest();
        System.assertEquals(true, r.success);
    }
}