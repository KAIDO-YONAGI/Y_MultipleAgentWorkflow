[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'Claude', 'ZCode')]
    [string[]]$Clients = @('Codex', 'Claude', 'ZCode')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MAW.Common.ps1')

$results = [Collections.Generic.List[object]]::new()

try {
    foreach ($client in @($Clients | Select-Object -Unique)) {
        $recordPath = Get-MawRecordPath $client
        if (-not [IO.File]::Exists($recordPath)) {
            throw "No MAW installation record exists for $client."
        }
        $record = Read-MawJson $recordPath
        $expectedTarget = [IO.Path]::GetFullPath((Get-MawClientTarget $client))
        $recordTarget = [IO.Path]::GetFullPath([string]$record.target)
        if (-not $recordTarget.Equals($expectedTarget, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Recorded target is not the known $client Skill target."
        }
        if (-not [IO.Directory]::Exists($recordTarget)) {
            throw "Recorded target no longer exists: '$recordTarget'."
        }

        if ([string]$record.mode -eq 'Junction') {
            $actualTarget = Get-MawLinkTarget $recordTarget
            if ($null -eq $actualTarget -or
                -not $actualTarget.Equals(
                    [IO.Path]::GetFullPath([string]$record.source),
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                throw "Junction target no longer matches the MAW installation record."
            }
        }
        else {
            $markerPath = Join-Path $recordTarget '.maw-installation.json'
            if (-not [IO.File]::Exists($markerPath)) {
                throw "Copied installation marker is missing: '$markerPath'."
            }
            $marker = Read-MawJson $markerPath
            if ([string]$marker.installationId -ne [string]$record.installationId) {
                throw 'Copied installation ownership marker does not match.'
            }
        }

        if ($PSCmdlet.ShouldProcess($recordTarget, "Uninstall $client Skill")) {
            if ([string]$record.mode -eq 'Junction') {
                Remove-Item -LiteralPath $recordTarget -Force
            }
            else {
                Remove-Item -LiteralPath $recordTarget -Recurse -Force
            }
            Remove-Item -LiteralPath $recordPath -Force
        }
        $results.Add([ordered]@{
            client = $client
            target = $recordTarget
            changed = -not $WhatIfPreference
        })
    }

    [ordered]@{
        success = $true
        action = if ($WhatIfPreference) { 'PreviewUninstall' } else { 'Uninstall' }
        results = @($results)
    } | ConvertTo-Json -Depth 6
}
catch {
    [ordered]@{
        success = $false
        action = 'Uninstall'
        errors = @($_.Exception.Message)
    } | ConvertTo-Json -Depth 6
    exit 1
}
