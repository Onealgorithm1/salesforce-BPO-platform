@isTest
private class OA_ConfidenceEvaluator_Test {

    @isTest
    static void testBands() {
        System.assertEquals('HIGH', OA_ConfidenceEvaluator.evaluate(true, false, 0).band, 'Exact id -> HIGH');
        System.assertEquals('MEDIUM', OA_ConfidenceEvaluator.evaluate(false, true, 0.9).band, 'Name+state above thr -> MEDIUM');
        System.assertEquals('LOW', OA_ConfidenceEvaluator.evaluate(false, false, 0.4).band, 'Weak name -> LOW');
        System.assertEquals('NONE', OA_ConfidenceEvaluator.evaluate(false, false, 0).band, 'No signal -> NONE');
        // name+state but below threshold falls through to LOW
        System.assertEquals('LOW', OA_ConfidenceEvaluator.evaluate(false, true, 0.5, 0.85).band, 'Below MEDIUM thr -> LOW');
    }

    @isTest
    static void testScoresAndNullHandling() {
        System.assertEquals(100, OA_ConfidenceEvaluator.evaluate(true, false, null).score, 'HIGH = 100');
        System.assertEquals(0, OA_ConfidenceEvaluator.evaluate(null, null, null).score, 'Nulls -> NONE 0');
        System.assert(OA_ConfidenceEvaluator.evaluate(false, true, 1, null).score > 50, 'MEDIUM score scaled');
    }

    @isTest
    static void testFloorAndRank() {
        System.assert(OA_ConfidenceEvaluator.meetsFloor('HIGH', 'HIGH'), 'HIGH meets HIGH');
        System.assert(OA_ConfidenceEvaluator.meetsFloor('HIGH', 'MEDIUM'), 'HIGH meets MEDIUM');
        System.assert(!OA_ConfidenceEvaluator.meetsFloor('MEDIUM', 'HIGH'), 'MEDIUM below HIGH');
        // Null floor defaults to HIGH, so LOW does NOT meet it.
        System.assert(!OA_ConfidenceEvaluator.meetsFloor('LOW', null), 'Null floor defaults HIGH; LOW fails');
        System.assert(OA_ConfidenceEvaluator.meetsFloor('HIGH', null), 'Null floor defaults HIGH; HIGH passes');
        System.assertEquals(3, OA_ConfidenceEvaluator.rank('high'), 'rank case-insensitive');
        System.assertEquals(0, OA_ConfidenceEvaluator.rank('bogus'), 'unknown rank 0');
        System.assert(OA_ConfidenceEvaluator.isHigh('HIGH'), 'isHigh');
        System.assert(!OA_ConfidenceEvaluator.isHigh('LOW'), 'not high');
    }
}
