trigger OA_UnsubscribeRequestTrigger on OA_Unsubscribe_Request__e (after insert) {
    // Phase 1: infrastructure verification only. No unsubscribe business logic.
    OA_UnsubscribeEventHandler.handle(Trigger.new);
}