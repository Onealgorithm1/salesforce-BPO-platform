@IsTest
private class OA_SendGovernor_Test {

    @TestSetup
    static void setup() {
        insert new OA_Campaign_Settings__c(
            SetupOwnerId      = UserInfo.getOrganizationId(),
            Daily_Send_Cap__c = 10,
            Sends_Today__c    = 0,
            Cap_Reset_Date__c = Date.today()
        );
    }

    // Helper: fetch the org-defaults record so update calls have an Id
    private static OA_Campaign_Settings__c getCfg() {
        return OA_Campaign_Settings__c.getOrgDefaults();
    }

    @IsTest
    static void testCheckAndReserveHappyPath() {
        Integer reserved = OA_SendGovernor.checkAndReserve(5);
        System.assertEquals(5, reserved, 'Should reserve exactly 5');
        OA_Campaign_Settings__c cfg = getCfg();
        System.assertEquals(5, (Integer) cfg.Sends_Today__c, 'Counter should be 5');
    }

    @IsTest
    static void testCheckAndReservePartialGrant() {
        OA_Campaign_Settings__c cfg = getCfg();
        cfg.Sends_Today__c = 8;
        update cfg;
        Integer reserved = OA_SendGovernor.checkAndReserve(5);
        System.assertEquals(2, reserved, 'Only 2 remain of 10 cap; should return 2');
    }

    @IsTest
    static void testRemainingTodayReflectsCounter() {
        OA_Campaign_Settings__c cfg = getCfg();
        cfg.Sends_Today__c = 4;
        update cfg;
        System.assertEquals(6, OA_SendGovernor.remainingToday(), 'Remaining capacity should be cap minus used');
    }

    @IsTest
    static void testCheckAndReserveCapExceeded() {
        OA_Campaign_Settings__c cfg = getCfg();
        cfg.Sends_Today__c = 10;
        update cfg;
        Boolean threw = false;
        try {
            OA_SendGovernor.checkAndReserve(1);
        } catch (OA_SendGovernor.CapExceededException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw CapExceededException when cap fully consumed');
    }

    @IsTest
    static void testAutoResetOnNewDay() {
        OA_Campaign_Settings__c cfg = getCfg();
        cfg.Sends_Today__c    = 10;
        cfg.Cap_Reset_Date__c = Date.today().addDays(-1);
        update cfg;
        Integer reserved = OA_SendGovernor.checkAndReserve(3);
        System.assertEquals(3, reserved, 'Counter should reset on new day and allow 3 sends');
    }

    @IsTest
    static void testResetDailyCounter() {
        OA_Campaign_Settings__c cfg = getCfg();
        cfg.Sends_Today__c = 9;
        update cfg;
        OA_SendGovernor.resetDailyCounter();
        cfg = getCfg();
        System.assertEquals(0, (Integer) cfg.Sends_Today__c, 'Counter should be 0 after reset');
        System.assertEquals(Date.today(), cfg.Cap_Reset_Date__c, 'Reset date should be today');
    }

    @IsTest
    static void testFederalHolidaysFixed() {
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  1,  1), 'Friday'),   'New Years Day');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  6, 19), 'Saturday'), 'Juneteenth');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  7,  4), 'Sunday'),   'Independence Day');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027, 11, 11), 'Thursday'), 'Veterans Day');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027, 12, 25), 'Saturday'), 'Christmas');
    }

    @IsTest
    static void testFederalHolidaysFloating() {
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  1, 18), 'Monday'),   'MLK Day 2027');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  2, 15), 'Monday'),   'Presidents Day 2027');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  5, 31), 'Monday'),   'Memorial Day 2027');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  9,  6), 'Monday'),   'Labor Day 2027');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027, 10, 11), 'Monday'),   'Columbus Day 2027');
        System.assert(OA_SendGovernor.isFederalHoliday(Date.newInstance(2027, 11, 25), 'Thursday'), 'Thanksgiving 2027');
    }

    @IsTest
    static void testNonHolidayNotFlagged() {
        System.assert(!OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  3, 15), 'Monday'),   'Mar 15 is not a holiday');
        System.assert(!OA_SendGovernor.isFederalHoliday(Date.newInstance(2027,  8, 12), 'Thursday'), 'Aug 12 is not a holiday');
    }

    @IsTest
    static void testIsBusinessDayRunsWithoutError() {
        Boolean result = OA_SendGovernor.isBusinessDay();
        System.assertNotEquals(null, result, 'isBusinessDay should return true or false');
    }

    @IsTest
    static void testGetOrCreateMakesRecordWhenMissing() {
        delete [SELECT Id FROM OA_Campaign_Settings__c];
        Integer reserved = OA_SendGovernor.checkAndReserve(1);
        System.assertEquals(1, reserved, 'Should auto-create settings and reserve 1');
    }
}
