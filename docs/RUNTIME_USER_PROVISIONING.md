# Runtime User Provisioning Package — Program 025E

**Purpose:** provision the dedicated least-privilege runtime identity that replaces `oauser` (System Admin / Modify All Data) for all platform automation. Org `00Dbn00000plgUfEAI`.

## ★ License finding (verified 2026-07-10)
**A compatible license is available at no cost.** Live `UserLicense` inventory:

| License | Total | Used | Free |
|---|---|---|---|
| **Salesforce Integration** | 5 | 0 | **5** ✅ |
| Salesforce (full) | 2 | 2 | 0 |
| Identity | 100 | 0 | 100 (unsuitable — limited object/Apex) |
| Salesforce Limited Access – Free | 100 | 0 | 100 (unsuitable — read-mostly) |

**Recommendation: use a Salesforce Integration License** (free, API-only, runs Apex, accesses custom + standard objects via permission sets). **No purchase required.** A full Salesforce license is *not* required for an automation runner (no UI login needed).

> Verify one constraint at assignment: Salesforce Integration users can only be granted permission sets whose **User License = "Salesforce Integration"** or that are license-agnostic. If any `OA_Runtime_Operations` component permset is tied to a different user license, clone it as Integration-compatible (additive, reversible). Confirm Lead read/create/edit is grantable to the Integration user (it is, via permission sets, for automated processes).

## Identity
- Display name: **OA Runtime**; username `oa.runtime@onealgorithm.com.bpo` (or org convention); alias `oaruntime`; email = a monitored service mailbox (not a personal address); purpose = unattended platform automation; owner = Louis; backup owner = designated admin.

## License / Profile
- **License:** Salesforce Integration (free). Alternative: full Salesforce (only if Integration proves insufficient for a required object — unlikely).
- **Profile:** the **"Salesforce API Only System Integrations"** profile (ships with Integration licenses; no UI, no admin). API Enabled = yes. Login hours/IP restrictions per policy; session timeout tightened; MFA per org policy (integration users typically use IP allow-listing + no interactive login); connected-app access only as required for callouts.

## Permissions
- Assign the **`OA_Runtime_Operations`** permission set group (deployed, unassigned; deploy `0AfPn0000023yGDKAY`).
- Grant Named Credential **principal access** for `OA_OpenRouter`, `OA_USASpending` (and others as activated) — no secrets exposed.
- **Excluded (must remain absent):** Modify All Data, View All Data, Customize Application, Author Apex, Modify Metadata, Manage Users, Lead/Opportunity delete, campaign-send, portal.

## Governance
- **Job ownership:** all scheduled Apex reassigned to run as OA Runtime (once approved).
- **Break-glass:** temporary admin elevation is Louis-approved, time-boxed, logged, reverted.
- **Credential rotation:** Setup-gated; smoke-test 2xx after rotation; no secrets in source/logs.
- **Periodic access review:** monthly PSG-vs-effective-permission diff.
- **Deactivation:** reassign/suspend owned jobs first, then deactivate in Setup.
- **Incident response:** see `OPERATIONAL_KILL_SWITCHES.md`.

## Exact Setup steps (Louis — RED: user creation)
1. Setup → Users → New User. License = **Salesforce Integration**; Profile = **Salesforce API Only System Integrations**. Name/alias/email as above. API Enabled = checked. Save (no email invite needed for integration user).
2. Setup → Permission Set Groups → `OA Runtime Operations` → Manage Assignments → add **OA Runtime**. *(If a component permset rejects the Integration license, clone it Integration-compatible first.)*
3. Setup → Named Credentials → for each activated credential → Principals → grant the OA Runtime user principal access.
4. (Later, on scheduling approval) reassign scheduled jobs to run as OA Runtime.
5. Notify Claude → run the canary package (`RUNTIME_CANARY_PLAN.md`).

**Claude will not create the user or assign the license** (RED). Everything else (PSG deploy, canary scripts) is ready.
