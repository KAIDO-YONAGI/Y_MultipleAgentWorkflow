[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'Claude', 'ZCode')]
    [string[]]$Clients = @('Codex', 'Claude', 'ZCode'),
    [string]$PackagePath,
    [string]$Repository,
    [string]$ExpectedSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MAW.Common.ps1')

$temporaryRoot = $null
$verifyRoot = $null
try {
    $records = @($Clients | Select-Object -Unique | ForEach-Object {
        $path = Get-MawRecordPath $_
        if (-not [IO.File]::Exists($path)) { throw "No MAW installation record exists for $_." }
        Read-MawJson $path
    })

    $junctionSources = @($records | Where-Object mode -eq 'Junction' | Select-Object -ExpandProperty source -Unique)
    if ($junctionSources.Count -gt 0) {
        foreach ($source in $junctionSources) {
            $repo = Find-MawDistributionRoot $source
            if ($null -eq $repo -or -not [IO.Directory]::Exists((Join-Path $repo '.git'))) {
                throw "Junction source is not inside a Git distribution repository: '$source'."
            }
            if ($PSCmdlet.ShouldProcess($repo, 'Run explicit git pull --ff-only')) {
                $pullOutput = @(& git -C $repo pull --ff-only 2>&1)
                if ($LASTEXITCODE -ne 0) { throw "git pull failed for '$repo'." }
            }
        }
    }

    $copyClients = @($records | Where-Object mode -eq 'Copy' | Select-Object -ExpandProperty client)
    if ($copyClients.Count -gt 0) {
        if ([string]::IsNullOrWhiteSpace($PackagePath)) {
            if ([string]::IsNullOrWhiteSpace($Repository)) {
                $rootManifest = Read-MawJson (Join-Path (Get-MawRepositoryRoot) 'distribution-manifest.json')
                $Repository = [string]$rootManifest.repository
            }
            if ([string]::IsNullOrWhiteSpace($Repository)) {
                throw 'Repository is required when updating copied installations without PackagePath.'
            }
            if ($PSCmdlet.ShouldProcess($Repository, 'Download latest private release with gh')) {
                $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "maw-update-$([Guid]::NewGuid().ToString('N'))"
                [void][IO.Directory]::CreateDirectory($temporaryRoot)
                & gh release download --repo $Repository --pattern '*-offline.zip' --pattern 'SHA256SUMS' --dir $temporaryRoot --clobber
                if ($LASTEXITCODE -ne 0) { throw 'gh release download failed.' }
                $PackagePath = @(Get-ChildItem -LiteralPath $temporaryRoot -File -Filter '*-offline.zip')[0].FullName
                $sumFile = Join-Path $temporaryRoot 'SHA256SUMS'
                $sumLine = @(
                    [IO.File]::ReadAllLines($sumFile) |
                        Where-Object { $_ -match [regex]::Escape([IO.Path]::GetFileName($PackagePath)) }
                )
                if ($sumLine.Count -ne 1 -or $sumLine[0] -notmatch '^([a-fA-F0-9]{64})\s{2}') {
                    throw 'Downloaded SHA256SUMS does not contain one valid offline package entry.'
                }
                $ExpectedSha256 = $Matches[1]
            }
        }
        $PackagePath = [IO.Path]::GetFullPath($PackagePath)
        if (-not [IO.File]::Exists($PackagePath)) {
            throw "Offline package does not exist: '$PackagePath'."
        }
        $actualHash = Get-MawFileHash $PackagePath
        if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256) -and
            $actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
            throw "Offline package SHA-256 mismatch. Expected $ExpectedSha256, received $actualHash."
        }
        $verifyRoot = Join-Path ([IO.Path]::GetTempPath()) "maw-verify-$([Guid]::NewGuid().ToString('N'))"
        [void][IO.Directory]::CreateDirectory($verifyRoot)
        Expand-Archive -LiteralPath $PackagePath -DestinationPath $verifyRoot
        $packageManifestPath = Join-Path $verifyRoot 'distribution-manifest.json'
        if (-not [IO.File]::Exists($packageManifestPath)) {
            throw 'Offline package has no distribution-manifest.json.'
        }
        $packageManifest = Read-MawJson $packageManifestPath
        if ([string]$packageManifest.name -ne 'Y_MultipleAgentWorkflow' -or
            [string]$packageManifest.packageVersion -notmatch '^\d+\.\d+\.\d+(?:[-+].+)?$') {
            throw 'Offline package identity or semantic version is invalid.'
        }
        if (-not $WhatIfPreference) {
            $installOutput = @(& (Join-Path $PSScriptRoot 'Install-MAW.ps1') `
                -Clients $copyClients -Mode Copy -PackagePath $PackagePath -Replace
            )
            if ($LASTEXITCODE -ne 0) { throw 'Copy installation update failed.' }
        }
    }

    [ordered]@{
        success = $true
        action = if ($WhatIfPreference) { 'PreviewUpdate' } else { 'Update' }
        junctionSources = $junctionSources
        copyClients = $copyClients
    } | ConvertTo-Json -Depth 6
}
catch {
    [ordered]@{ success = $false; action = 'Update'; errors = @($_.Exception.Message) } | ConvertTo-Json -Depth 5
    exit 1
}
finally {
    if ($null -ne $temporaryRoot -and [IO.Directory]::Exists($temporaryRoot) -and
        (Test-MawPathWithin ([IO.Path]::GetTempPath()) $temporaryRoot)) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
    if ($null -ne $verifyRoot -and [IO.Directory]::Exists($verifyRoot) -and
        (Test-MawPathWithin ([IO.Path]::GetTempPath()) $verifyRoot)) {
        Remove-Item -LiteralPath $verifyRoot -Recurse -Force
    }
}
