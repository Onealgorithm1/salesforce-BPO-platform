# Deploy contract — campaign statuses (data, not metadata)

`CampaignMemberStatus` is **data**, not a Metadata API type, so it cannot live in `force-app` as
source and is **not** covered by `scripts/drift-check.ps1`. A sandbox refresh or org rebuild loses
it silently. Some P1 code **throws at runtime** if a required status is missing, so the statuses
below are a hard deploy prerequisite — treat them as part of the deploy, not optional config.

## Required statuses — EDWOSB Teaming Outreach `701Pn00001ZOyj8IAD`

| Label | HasResponded | Why it must exist |
|---|---|---|
| `Reply - Unverified` | **false** | Set by the P1 domain-fallback in `OA_ReplyStatusService` and `OA_BookingPoller` on a single domain-only match. It is a stop status (halts the sequence) but an *unconfirmed* guess, so `HasResponded=false` keeps `NumberOfResponses` honest. **If this status is absent, the P1 `update` throws** (`bad value for restricted picklist` / rollback) and the member is not stopped. |

The full status set as of 2026-07-23 (for reference): `Day 1 Sent` (default), `Day 3 Sent`,
`Day 5 Sent`, `Day 10 Sent`, `Meeting Booked`, `Replied`, `Interested`, `Not Interested`,
`Unsubscribed`, `Call Completed`, `Removed - Out of ICP`, `Reply - Unverified`.

## Ensure-statuses (idempotent) — run before/after any P1 deploy or org refresh

Run as anonymous Apex against the target org (verify Org Id `00Dbn00000plgUfEAI` first). It only
inserts what is missing, so it is safe to re-run.

```apex
Id campaignId = '701Pn00001ZOyj8IAD';
Map<String, Boolean> required = new Map<String, Boolean>{
    'Reply - Unverified' => false   // label => HasResponded
};
Set<String> existing = new Set<String>();
for (CampaignMemberStatus s : [SELECT Label FROM CampaignMemberStatus WHERE CampaignId = :campaignId]) {
    existing.add(s.Label);
}
List<CampaignMemberStatus> toAdd = new List<CampaignMemberStatus>();
Integer sort = [SELECT COUNT() FROM CampaignMemberStatus WHERE CampaignId = :campaignId] + 1;
for (String label : required.keySet()) {
    if (!existing.contains(label)) {
        toAdd.add(new CampaignMemberStatus(
            CampaignId = campaignId, Label = label,
            HasResponded = required.get(label), IsDefault = false, SortOrder = sort++
        ));
    }
}
if (!toAdd.isEmpty()) { insert toAdd; System.debug('Inserted: ' + toAdd); }
else { System.debug('All required statuses already present.'); }
```

**Applied to prod 2026-07-23:** `Reply - Unverified` created (`01YPn000007HnTJMA0`, HasResponded=false);
`NumberOfResponses` unchanged at 10.
