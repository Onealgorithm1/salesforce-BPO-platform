/**
 * Platform Event subscriber for OA_Unsubscribe_Request__e.
 *
 * Runs in the subscriber (Automated Process) system context — verified in Phase 1.
 * Delegates each event to the existing Communication Preference service using the
 * token HASH carried in the event payload (the raw token is never transmitted).
 *
 * Idempotency, audit, and state changes are owned by OA_CommPreferenceService.
 * Only genuinely transient failures are retried; deterministic outcomes
 * (invalid/expired/revoked tokens) are recorded as Rejected audits and consumed.
 */
public with sharing class OA_UnsubscribeEventHandler {

    @TestVisible
    private static Boolean executed = false;
    @TestVisible
    private static List<OA_CommPreferenceService.UnsubscribeResult> lastResults;

    public class HandlerException extends Exception {}

    public static void handle(List<OA_Unsubscribe_Request__e> events) {
        executed = true;
        lastResults = new List<OA_CommPreferenceService.UnsubscribeResult>();
        for (OA_Unsubscribe_Request__e e : events) {
            try {
                lastResults.add(
                    OA_CommPreferenceService.unsubscribeByHash(e.Token_Hash__c, buildMetadata(e))
                );
            } catch (Exception ex) {
                handleFailure(e, ex);
            }
        }
    }

    @TestVisible
    private static void handleFailure(OA_Unsubscribe_Request__e e, Exception ex) {
        if (isTransient(ex)) {
            throw new EventBus.RetryableException(
                'Transient failure processing unsubscribe: ' + ex.getMessage()
            );
        }
        System.debug(LoggingLevel.ERROR,
            'OA_UNSUB_HANDLER|UNEXPECTED|corr=' + e.Correlation_Id__c + '|' + ex.getMessage());
    }

    @TestVisible
    private static String buildMetadata(OA_Unsubscribe_Request__e e) {
        Map<String, Object> meta = new Map<String, Object>{
            'source' => 'public-site-rest',
            'channel' => 'platform-event',
            'correlationId' => e.Correlation_Id__c,
            'publishedById' => e.CreatedById
        };
        if (String.isNotBlank(e.Request_Metadata__c)) {
            meta.put('request', e.Request_Metadata__c);
        }
        return JSON.serialize(meta);
    }

    @TestVisible
    private static Boolean isTransient(Exception ex) {
        String m = ex.getMessage();
        return m != null && (
            m.contains('UNABLE_TO_LOCK_ROW') ||
            m.contains('QUERY_TIMEOUT')
        );
    }
}
