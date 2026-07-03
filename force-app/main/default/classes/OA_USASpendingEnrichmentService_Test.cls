/**
 * OA_USASpendingEnrichmentService_Test — fully mocked (HttpCalloutMock); NO live callout.
 *
 * Staging DML runs as a throwaway test user assigned OA_Connector_Staging (so the
 * Dedupe_Key__c field is accessible) — NO real user is assigned. All records roll back.
 * Proves: persist true/false behavior, idempotency (no duplicates), error paths,
 * limit clamping, and that NO Lead / Campaign / CampaignMember records change.
 */
@isTest
private class OA_USASpendingEnrichmentService_Test {

    private static User connectorUser() {
        User u = new User(
            Alias = 'oaenr', Email = 'oa.enrich.test@example.com.invalid',
            EmailEncodingKey = 'UTF-8', LastName = 'EnrichTest',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(), TimeZoneSidKey = 'America/New_York',
            Username = 'oa.enrich.' + UserInfo.getOrganizationId() + '@example.com.invalid'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'OA_Connector_Staging' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    private static String awardsJson(Integer count) {
        List<Object> rows = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Map<String, Object>{
                'Award ID' => 'CONT_AWD_' + i, 'Recipient Name' => 'ACME ' + i, 'Award Amount' => 1000 + i
            });
        }
        return JSON.serialize(new Map<String, Object>{ 'results' => rows });
    }

    @isTest
    static void testPersistTrueWritesPendingRows() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, awardsJson(2)));
        System.runAs(u) {
            Integer leads = [SELECT COUNT() FROM Lead];
            Integer cms = [SELECT COUNT() FROM CampaignMember];

            Test.startTest();
            OA_USASpendingEnrichmentService.Result r =
                OA_USASpendingEnrichmentService.enrich('ACME DEFENSE', 5, true);
            Test.stopTest();

            System.assertEquals(2, r.parsed, 'Two rows parsed');
            System.assertEquals(2, r.mapped, 'Two staging records mapped');
            System.assertEquals(2, r.persisted, 'Two staging records upserted');
            System.assert(r.persistAttempted, 'Persist was attempted');

            List<OA_USASpending_Staging__c> rows = [SELECT Review_Status__c, Dedupe_Key__c FROM OA_USASpending_Staging__c];
            System.assertEquals(2, rows.size(), 'Two staging rows saved');
            for (OA_USASpending_Staging__c row : rows) {
                System.assertEquals('Pending', row.Review_Status__c, 'Saved as Pending (review gate)');
                System.assert(row.Dedupe_Key__c.startsWith('USASP-ACME DEFENSE'), 'Deterministic run id used');
            }
            System.assertEquals(leads, [SELECT COUNT() FROM Lead], 'No Lead records changed');
            System.assertEquals(cms, [SELECT COUNT() FROM CampaignMember], 'No CampaignMember records changed');
        }
    }

    @isTest
    static void testPersistFalseWritesNothing() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, awardsJson(3)));
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.Result r =
                OA_USASpendingEnrichmentService.enrich('ACME', 5, false);
            Test.stopTest();

            System.assertEquals(3, r.mapped, 'Rows mapped in memory');
            System.assertEquals(0, r.persisted, 'Nothing persisted');
            System.assert(!r.persistAttempted, 'Persist not attempted');
            System.assertEquals(0, [SELECT COUNT() FROM OA_USASpending_Staging__c], 'No staging rows written');
        }
    }

    @isTest
    static void testIdempotentReRunNoDuplicates() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, awardsJson(2)));
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.enrich('BOEING', 5, true); // same recipient
            OA_USASpendingEnrichmentService.enrich('BOEING', 5, true); // -> same run id -> upsert
            Test.stopTest();

            System.assertEquals(2, [SELECT COUNT() FROM OA_USASpending_Staging__c],
                'Re-running same recipient did not duplicate rows');
        }
    }

    @isTest
    static void testEmptyResponse() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, '{"results":[]}'));
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.Result r = OA_USASpendingEnrichmentService.enrich('NoMatchCo', 5, true);
            Test.stopTest();
            System.assertEquals(0, r.mapped, 'Nothing mapped');
            System.assertEquals(0, r.persisted, 'Nothing persisted');
            System.assertEquals(0, [SELECT COUNT() FROM OA_USASpending_Staging__c], 'No rows');
        }
    }

    @isTest
    static void testNon200RecordedNoRows() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(500, '{"detail":"err"}'));
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.Result r = OA_USASpendingEnrichmentService.enrich('ACME', 5, true);
            Test.stopTest();
            System.assertEquals(1, r.httpErrors, 'HTTP error recorded');
            System.assertEquals(0, r.persisted, 'Nothing persisted on non-200');
            System.assertEquals(0, [SELECT COUNT() FROM OA_USASpending_Staging__c], 'No rows');
        }
    }

    @isTest
    static void testMalformedResponseRecorded() {
        User u = connectorUser();
        Test.setMock(HttpCalloutMock.class, new OA_ConnectorMock(200, 'not-json'));
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.Result r = OA_USASpendingEnrichmentService.enrich('ACME', 5, true);
            Test.stopTest();
            System.assertEquals(1, r.parseErrors, 'Parse error recorded, not thrown');
            System.assertEquals(0, r.persisted, 'Nothing persisted');
        }
    }

    @isTest
    static void testBlankRecipientThrows() {
        Boolean threw = false;
        try {
            OA_USASpendingEnrichmentService.enrich('   ', 5, false);
        } catch (OA_ConnectorException e) {
            threw = true;
        }
        System.assert(threw, 'Blank recipient rejected');
    }

    @isTest
    static void testLimitClampedToMax() {
        User u = connectorUser();
        OA_ConnectorMock mock = new OA_ConnectorMock(200, awardsJson(1));
        Test.setMock(HttpCalloutMock.class, mock);
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.enrich('ACME', 1000, false); // over MAX_LIMIT
            Test.stopTest();
            System.assert(mock.lastRequest.getBody().contains('"limit":' + OA_USASpendingEnrichmentService.MAX_LIMIT),
                'Requested limit clamped to MAX_LIMIT (' + OA_USASpendingEnrichmentService.MAX_LIMIT + ')');
        }
    }

    @isTest
    static void testNullLimitDefaults() {
        User u = connectorUser();
        OA_ConnectorMock mock = new OA_ConnectorMock(200, awardsJson(1));
        Test.setMock(HttpCalloutMock.class, mock);
        System.runAs(u) {
            Test.startTest();
            OA_USASpendingEnrichmentService.enrich('ACME', null, false);
            Test.stopTest();
            System.assert(mock.lastRequest.getBody().contains('"limit":' + OA_USASpendingEnrichmentService.DEFAULT_LIMIT),
                'Null limit defaults to DEFAULT_LIMIT');
        }
    }
}
