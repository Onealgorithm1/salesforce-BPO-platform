# drift-check.ps1 — org vs repo drift detector for the governed component list.
#
# Retrieves the governed components from production into the working tree, classifies
# every difference against HEAD (content vs formatting noise), then RESTORES the tree.
# Run from the repo root on a CLEAN working tree, on main (or the branch you are
# auditing against). Read-only with respect to the org; the local tree is restored.
#
# Exit code 1 = content drift found (reconcile before the next deploy).
# Method proven in the 2026-07-16 integrity audit.

# 'Continue', not 'Stop': on Windows/PS 5.1 both git and sf write benign notices to stderr
# (git's LF->CRLF warning, sf's "update available"), and under 'Stop' PowerShell turns the
# first such NativeCommandError into a terminating error and aborts mid-run — before the tree
# is restored. We guard the one call that must succeed (the retrieve) with $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$org = 'oauser@pboedition.com'

if (git status --porcelain) { Write-Error 'Working tree not clean — commit or stash first.'; exit 2 }

# Governed component list — extend as the platform grows.
$mdArgs = @(
    '--metadata','ApexClass:OA_DripScheduler',
    '--metadata','ApexClass:OA_DripScheduler_Test',
    '--metadata','ApexClass:OA_FollowUpScheduler',
    '--metadata','ApexClass:OA_FollowUpScheduler_Test',
    '--metadata','ApexClass:OA_ReplyStatusService',
    '--metadata','ApexClass:OA_ReplyStatusService_Test',
    '--metadata','ApexTrigger:OA_ReplyStatusTrigger',
    '--metadata','ApexClass:OA_EnrichmentOrchestrator',
    '--metadata','ApexClass:OA_LeadWritebackService',
    '--metadata','ApexClass:OA_USASpendingMapper',
    '--metadata','ApexClass:OA_EnrichmentWriter',
    '--metadata','EmailTemplate:my_templates/EDWOSB_Sub_Prospect_Email_1',
    '--metadata','EmailTemplate:my_templates/Follow_Up_Day3',
    '--metadata','EmailTemplate:my_templates/Follow_Up_Day5',
    '--metadata','EmailTemplate:my_templates/Follow_Up_Day10',
    '--metadata','CustomMetadata:OA_Connector_Registry.*',
    '--metadata','CustomMetadata:OA_Graph_Config.*',
    '--metadata','CustomMetadata:OA_Enrichment_Pipeline.*',
    '--metadata','CustomMetadata:OA_Field_Write_Policy.*',
    # Added 2026-07-23: booking automation, protected flows, 5th template, P1 reply/booking
    # fallback + alert channel, outbound path, and send-cap governor. The booking poller was
    # missed before, which let a package-dir duplicate diverge unseen.
    '--metadata','ApexClass:OA_BookingPoller',
    '--metadata','ApexClass:OA_BookingPoller_Test',
    '--metadata','ApexClass:OA_MatchFallback',
    '--metadata','ApexClass:OA_MatchFallback_Test',
    '--metadata','ApexClass:OA_AlertService',
    '--metadata','ApexClass:OA_AlertService_Test',
    '--metadata','ApexClass:OA_EmailSender',
    '--metadata','ApexClass:OA_SendGovernor',
    '--metadata','Flow:OA_EDWOSB_Outreach_Sequence',
    '--metadata','Flow:OA_PostMeeting_Nurture',
    '--metadata','Flow:OA_Reply_Detection',
    '--metadata','EmailTemplate:my_templates/Teaming_Partner_Email_1',
    '--metadata','CustomNotificationType:OA_Pipeline_Alert'
)
sf project retrieve start @mdArgs --target-org $org --json | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error 'sf retrieve failed — aborting drift check.'; exit 2 }

$drift = @()
foreach ($line in (git status --porcelain)) {
    $f = ($line -replace '^...','').Trim()
    if ($line -match '^\?\?') {
        # Untracked: check every packageDirectory before calling it org-only
        # (2026-07-16 lesson: OA_Graph_Config.Default lives in modules/, not force-app).
        $base = Split-Path $f -Leaf
        $elsewhere = git ls-files "*/$base"
        if ($elsewhere) { continue }   # tracked in another package dir → formatting duplicate
        $drift += "ORG-ONLY: $f"
        continue
    }
    # Modified: normalize custom metadata (field order + numeric formatting) and
    # ignore pure whitespace/EOL/trailing-newline changes.
    if ($f -like '*.md-meta.xml') {
        $old = (git show ("HEAD:" + $f)) -join "`n"
        $new = [System.IO.File]::ReadAllText($f)
        $norm = { param($s) ([regex]::Matches($s, '<field>(.*?)</field>\s*<value[^>]*>(.*?)</value>') |
            ForEach-Object { $_.Groups[1].Value + '=' + (($_.Groups[2].Value) -replace '\.0$','') } | Sort-Object) -join ';' }
        if ((& $norm $old) -ne (& $norm $new)) { $drift += "VALUE-DIFF: $f" }
    } else {
        if (git diff --ignore-all-space --numstat -- $f) {
            # non-whitespace change — but a bare trailing-newline diff shows as 1/1; inspect
            $body = git diff --ignore-all-space -- $f | Where-Object { $_ -match '^[+-][^+-]' }
            $real = $body | Where-Object { $_.Trim() -notin @('+}','-}') }
            if ($real) { $drift += "CONTENT-DIFF: $f" }
        }
    }
}

git checkout -- . 2>$null
git clean -fd force-app modules 2>$null | Out-Null

if ($drift) { $drift | ForEach-Object { Write-Warning $_ }; Write-Error 'DRIFT FOUND — reconcile before deploying.'; exit 1 }
Write-Output 'NO DRIFT: production matches the repo for the governed component list.'
