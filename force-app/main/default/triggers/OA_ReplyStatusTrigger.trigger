/**
 * Flags EDWOSB campaign members as 'Replied' on inbound email — see OA_ReplyStatusService.
 */
trigger OA_ReplyStatusTrigger on EmailMessage (after insert) {
    OA_ReplyStatusService.markReplied(Trigger.new);
}
