/**
 * OA_CustomerSnapshotController_Test — all callouts mocked; no live vault access.
 */
@IsTest
private class OA_CustomerSnapshotController_Test {

    private static final String UID = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

    private class VaultMock implements HttpCalloutMock {
        Integer status;
        String body;
        VaultMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/customer/' + UID),
                'Callout targets the record UID via the Named Credential');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    private static Id makeRef(String uid) {
        OA_Customer_Reference__c ref = new OA_Customer_Reference__c(Customer_UID__c = uid);
        insert ref;
        return ref.Id;
    }

    @IsTest
    static void returnsSnapshotOn200() {
        Id refId = makeRef(UID);
        Test.setMock(HttpCalloutMock.class, new VaultMock(200,
            '{"customer_uid":"' + UID + '","first_name":"Ava","last_name":"Ramirez","company":"TEST-Harborline Logistics","is_test":1}'));

        Test.startTest();
        Map<String, Object> snap = OA_CustomerSnapshotController.getSnapshot(refId);
        Test.stopTest();

        System.assertEquals('Ava', snap.get('first_name'), 'Snapshot fields pass through');
        System.assertEquals(UID, snap.get('customer_uid'), 'UID round-trips');
    }

    @IsTest
    static void throwsOn404() {
        Id refId = makeRef(UID);
        Test.setMock(HttpCalloutMock.class, new VaultMock(404, '{"error":"not found"}'));

        Test.startTest();
        try {
            OA_CustomerSnapshotController.getSnapshot(refId);
            System.assert(false, 'Expected AuraHandledException for 404');
        } catch (AuraHandledException e) {
            // expected — unknown UID in the vault
        }
        Test.stopTest();
    }

    @IsTest
    static void throwsOnAuthFailure() {
        Id refId = makeRef(UID);
        Test.setMock(HttpCalloutMock.class, new VaultMock(401, '{"error":"unauthorized"}'));

        Test.startTest();
        try {
            OA_CustomerSnapshotController.getSnapshot(refId);
            System.assert(false, 'Expected AuraHandledException for 401');
        } catch (AuraHandledException e) {
            // expected — key gate not configured or key mismatch
        }
        Test.stopTest();
    }
}
