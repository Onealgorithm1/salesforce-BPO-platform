# drift-check.ps1 — org vs repo drift detector for the governed component list.
#
# Retrieves the governed components from production into the working tree, classifies
# every difference against HEAD (content vs formatting noise), then RESTORES the tree.
# Run from the repo root on a CLEAN working tree, on main (or the branch you are
# auditing against). Read-only with respect to the org; the local tree is restored.
#
# Exit code 1 = content drift found (reconcile before the next deploy).
# Method proven in the 2026-07-16 integrity audit.

$ErrorActionPreference = 'Stop'
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
    '--metadata','CustomMetadata:OA_Field_Write_Policy.*'
)
sf project retrieve start @mdArgs --target-org $org --json | Out-Null

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
