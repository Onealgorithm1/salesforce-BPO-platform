/**
 * OA_CustomerSnapshotController — live, view-only customer snapshot (PoC).
 *
 * Reads the opaque Customer_UID__c from an OA_Customer_Reference__c record and fetches
 * that ONE customer from the external vault via
 * 'callout:OA_Customer_Snapshot/customer/{uid}' (Cloudflare Worker, GET-only).
 * The X-API-Key header is injected by the OA_Customer_Snapshot External Credential —
 * no secret ever appears in this class, the repo, or logs.
 *
 * Retention contract: the snapshot is returned to the LWC for display only. This class
 * performs no DML and is deliberately NOT cacheable, so neither server nor Lightning
 * client keeps a copy after the page is closed.
 */
public with sharing class OA_CustomerSnapshotController {

    @AuraEnabled
    public static Map<String, Object> getSnapshot(Id recordId) {
        List<OA_Customer_Reference__c> refs = [
            SELECT Customer_UID__c
            FROM OA_Customer_Reference__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
        if (refs.isEmpty() || String.isBlank(refs[0].Customer_UID__c)) {
            throw new AuraHandledException('No Customer UID on this record.');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OA_Customer_Snapshot/customer/'
            + EncodingUtil.urlEncode(refs[0].Customer_UID__c.trim(), 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        Integer status = res.getStatusCode();
        if (status == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        }
        if (status == 404) {
            throw new AuraHandledException('No customer found in the vault for this ID.');
        }
        // 401 = key gate not configured / key mismatch; anything else = vault trouble.
        throw new AuraHandledException('Vault lookup failed (HTTP ' + status + ').');
    }
}
