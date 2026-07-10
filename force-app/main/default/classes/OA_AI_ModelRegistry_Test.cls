@isTest
private class OA_AI_ModelRegistry_Test {
    private class Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200); r.setHeader('Content-Type','application/json');
            r.setBody('{"data":[' +
              '{"id":"openai/gpt-4o-mini","context_length":128000,"pricing":{"prompt":"0.0000002","completion":"0.0000006"}},' +
              '{"id":"anthropic/claude-opus-4-8","context_length":200000,"pricing":{"prompt":"0.000015","completion":"0.000075"}}]}');
            return r;
        }
    }
    @isTest static void testDiscoverAndRecommend() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        List<OA_AI_ModelRegistry.ModelInfo> models = OA_AI_ModelRegistry.discover();
        OA_AI_ModelRegistry.ModelInfo rec = OA_AI_ModelRegistry.recommend(100000);
        Test.stopTest();
        System.assertEquals(2, models.size());
        System.assertEquals('openai', models[0].provider);
        System.assertEquals(128000, models[0].contextLength);
        System.assertEquals('openai/gpt-4o-mini', rec.id, 'cheapest meeting context');
    }
}