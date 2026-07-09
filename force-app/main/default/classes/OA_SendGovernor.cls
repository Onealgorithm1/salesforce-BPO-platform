public class OA_SendGovernor {

    public class CapExceededException extends Exception {}

    private static final Integer DEFAULT_CAP = 200;

    /**
     * Reserves up to `requested` send slots against today's cap.
     * Returns the number actually reserved (may be less than requested if near cap).
     * Throws CapExceededException if the cap is already fully consumed.
     */
    public static Integer checkAndReserve(Integer requested) {
        OA_Campaign_Settings__c cfg = getOrCreate();
        maybeReset(cfg);

        Integer cap   = cfg.Daily_Send_Cap__c != null ? (Integer) cfg.Daily_Send_Cap__c : DEFAULT_CAP;
        Integer used  = cfg.Sends_Today__c    != null ? (Integer) cfg.Sends_Today__c    : 0;
        Integer avail = cap - used;

        if (avail <= 0) {
            throw new CapExceededException(
                '[OA_SendGovernor] Daily cap of ' + cap + ' reached (' + used + ' sent today).');
        }

        Integer toSend = Math.min(requested, avail);
        cfg.Sends_Today__c = used + toSend;
        upsert cfg;
        return toSend;
    }

    public static Integer remainingToday() {
        OA_Campaign_Settings__c cfg = getOrCreate();
        maybeReset(cfg);

        Integer cap  = cfg.Daily_Send_Cap__c != null ? (Integer) cfg.Daily_Send_Cap__c : DEFAULT_CAP;
        Integer used = cfg.Sends_Today__c    != null ? (Integer) cfg.Sends_Today__c    : 0;
        return Math.max(0, cap - used);
    }

    public static void resetDailyCounter() {
        OA_Campaign_Settings__c cfg = getOrCreate();
        cfg.Sends_Today__c    = 0;
        cfg.Cap_Reset_Date__c = Date.today();
        upsert cfg;
    }

    public static Boolean isBusinessDay() {
        Date   today = Date.today();
        String dow   = DateTime.newInstance(today, Time.newInstance(12, 0, 0, 0)).format('EEEE');
        if (dow == 'Saturday' || dow == 'Sunday') return false;
        return !isFederalHoliday(today, dow);
    }

    @TestVisible
    private static Boolean isFederalHoliday(Date d, String dow) {
        Integer mo  = d.month();
        Integer dy  = d.day();

        // Fixed-date US federal holidays
        if (mo ==  1 && dy ==  1) return true;  // New Year's Day
        if (mo ==  6 && dy == 19) return true;  // Juneteenth
        if (mo ==  7 && dy ==  4) return true;  // Independence Day
        if (mo == 11 && dy == 11) return true;  // Veterans Day
        if (mo == 12 && dy == 25) return true;  // Christmas

        // Floating holidays
        Integer week     = ((dy - 1) / 7) + 1;
        Boolean lastWeek = (d.addDays(7).month() != mo);

        if (mo ==  1 && dow == 'Monday'   && week == 3)  return true;  // MLK Day
        if (mo ==  2 && dow == 'Monday'   && week == 3)  return true;  // Presidents Day
        if (mo ==  5 && dow == 'Monday'   && lastWeek)   return true;  // Memorial Day
        if (mo ==  9 && dow == 'Monday'   && week == 1)  return true;  // Labor Day
        if (mo == 10 && dow == 'Monday'   && week == 2)  return true;  // Columbus Day
        if (mo == 11 && dow == 'Thursday' && week == 4)  return true;  // Thanksgiving

        return false;
    }

    private static void maybeReset(OA_Campaign_Settings__c cfg) {
        if (cfg.Cap_Reset_Date__c == null || cfg.Cap_Reset_Date__c != Date.today()) {
            cfg.Sends_Today__c    = 0;
            cfg.Cap_Reset_Date__c = Date.today();
        }
    }

    private static OA_Campaign_Settings__c getOrCreate() {
        // getOrgDefaults() returns the record with its Id, required for upsert to UPDATE not INSERT.
        OA_Campaign_Settings__c s = OA_Campaign_Settings__c.getOrgDefaults();
        if (s == null) {
            s = new OA_Campaign_Settings__c(
                SetupOwnerId      = UserInfo.getOrganizationId(),
                Daily_Send_Cap__c = DEFAULT_CAP,
                Sends_Today__c    = 0,
                Cap_Reset_Date__c = Date.today()
            );
            insert s;
        }
        return s;
    }
}