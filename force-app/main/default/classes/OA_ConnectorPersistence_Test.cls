/**
 * OA_ConnectorPersistence_Test — proves idempotent staging persistence.
 *
 * All records are created inside the test transaction and rolled back automatically;
 * NO real production data is touched. The staging DML runs as a freshly-created test
 * user assigned the OA_Connector_Staging permission set (so the new Dedupe_Key__c
 * field is accessible) — NO real user is assigned the permission set.
 *
 * Proves: save once -> one row; re-run same key -> still one row (updated, not
 * duplicated); Review_Status__c stays 'Pending'; zero Lead writes; safe no-op on
 * empty/null input.
 */
@isTest
private class OA_ConnectorPersistence_Test {

    private static final Schema.SObjectField DEDUPE = OA_USASpending_Staging__c.Dedupe_Key__c;

    // A test-only user granted the OA_Connector_Staging permission set. Never a real user.
    private static User connectorUser() {
        User u = new User(
            Alias = 'oaconn',
            Email = 'oa.connector.test@example.com.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ConnectorTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = 'oa.connector.' + UserInfo.getOrganizationId() + '@example.com.invalid'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'OA_Connector_Staging' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    private static OA_USASpending_Staging__c stagingRow(String dedupeKey, String awardId, Decimal amount) {
        return new OA_USASpending_Staging__c(
            Dedupe_Key__c   = dedupeKey,
            Award_ID__c     = awardId,
            Award_Amount__c = amount,
            Review_Status__c = 'Pending'
        );
    }

    private static String awardsJson(Integer count) {
        List<Object> rows = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Map<String, Object>{
                'Award ID'       => 'CONT_AWD_' + i,
                'Recipient Name' => 'ACME ' + i,
                'Award Amount'   => 1000 + i
            });
        }
        return JSON.serialize(new Map<String, Object>{ 'results' => rows });
    }

    @isTest
    static void testSaveOnceThenIdempotentRerun() {
        User u = connectorUser();
        OA_ConnectorPersistence svc = new OA_ConnectorPersistence();

        System.runAs(u) {
            Integer leadsBefore = [SELECT COUNT() FROM Lead];

            Test.startTest();
            OA_ConnectorPersistence.PersistResult r1 = svc.upsertStaging(new List<SObject>{
                stagingRow('RUN1|AWD_A', 'AWD_A', 100),
                stagingRow('RUN1|AWD_B', 'AWD_B', 200)
            }, DEDUPE);

            OA_ConnectorPersistence.PersistResult r2 = svc.upsertStaging(new List<SObject>{
                stagingRow('RUN1|AWD_A', 'AWD_A', 150),
                stagingRow('RUN1|AWD_B', 'AWD_B', 250)
            }, DEDUPE);
            Test.stopTest();

            System.assertEquals(2, r1.upserted, 'First run saves two rows');
            System.assertEquals(2, r2.upserted, 'Second run upserts two rows (no error)');

            List<OA_USASpending_Staging__c> rows = [
                SELECT Dedupe_Key__c, Award_Amount__c, Review_Status__c
                FROM OA_USASpending_Staging__c ORDER BY Dedupe_Key__c];
            System.assertEquals(2, rows.size(), 'Still exactly two rows — no duplicates on re-run');
            System.assertEquals(150, rows[0].Award_Amount__c, 'Row A updated in place');
            System.assertEquals(250, rows[1].Award_Amount__c, 'Row B updated in place');
            for (OA_USASpending_Staging__c row : rows) {
                System.assertEquals('Pending', row.Review_Status__c, 'Review gate preserved');
            }
            System.assertEquals(leadsBefore, [SELECT COUNT() FROM Lead], 'No Lead records were created/updated');
        }
    }

    @isTest
    static void testEmptyAndNullNoOp() {
        User u = connectorUser();
        OA_ConnectorPersistence svc = new OA_ConnectorPersistence();

        System.runAs(u) {
            Test.startTest();
            OA_ConnectorPersistence.PersistResult rEmpty = svc.upsertStaging(new List<SObject>(), DEDUPE);
            OA_ConnectorPersistence.PersistResult rNull  = svc.upsertStaging(null, DEDUPE);
            Test.stopTest();

            System.assertEquals(0, rEmpty.upserted, 'Empty list is a safe no-op');
            System.assertEquals(0, rNull.upserted, 'Null list is a safe no-op');
            System.assertEquals(0, [SELECT COUNT() FROM OA_USASpending_Staging__c], 'No rows written');
        }
    }

    @isTest
    static void testNullExternalIdFieldThrows() {
        User u = connectorUser();
        System.runAs(u) {
            Boolean threw = false;
            try {
                new OA_ConnectorPersistence().upsertStaging(
                    new List<SObject>{ stagingRow('K1', 'A1', 1) }, null);
            } catch (OA_ConnectorException e) {
                threw = true;
            }
            System.assert(threw, 'A null External Id field is rejected');
        }
    }

    @isTest
    static void testConnectorToPersistIntegration() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, awardsJson(2)));

        System.runAs(u) {
            Integer leadsBefore = [SELECT COUNT() FROM Lead];

            Test.startTest();
            OA_ConnectorRunResult run1 = new OA_ConnectorEngine().run(
                new OA_USASpendingConnector(), new OA_ConnectorContext('RUNX'), new List<Object>{ 'ACME' });
            OA_ConnectorPersistence svc = new OA_ConnectorPersistence();
            svc.upsertStaging(run1.stagingRecords, DEDUPE);

            OA_ConnectorRunResult run2 = new OA_ConnectorEngine().run(
                new OA_USASpendingConnector(), new OA_ConnectorContext('RUNX'), new List<Object>{ 'ACME' });
            svc.upsertStaging(run2.stagingRecords, DEDUPE);
            Test.stopTest();

            System.assertEquals(2, [SELECT COUNT() FROM OA_USASpending_Staging__c],
                'Two award rows saved; re-run with same run id did not duplicate');
            for (OA_USASpending_Staging__c row : [SELECT Review_Status__c, Dedupe_Key__c FROM OA_USASpending_Staging__c]) {
                System.assertEquals('Pending', row.Review_Status__c, 'Review gate preserved');
                System.assert(row.Dedupe_Key__c.startsWith('RUNX|'), 'Dedupe key stamped by mapper');
            }
            System.assertEquals(leadsBefore, [SELECT COUNT() FROM Lead], 'No Lead records touched');
        }
    }
}
