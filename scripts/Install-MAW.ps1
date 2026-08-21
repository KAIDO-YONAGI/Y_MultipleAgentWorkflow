[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'Claude', 'ZCode')]
    [string[]]$Clients = @('Codex', 'Claude', 'ZCode'),

    [ValidateSet('Copy', 'Junction')]
    [string]$Mode = 'Copy',

    [string]$SourceRoot,

    [string]$PackagePath,

    [switch]$Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MAW.Common.ps1')

$temporaryRoot = $null
$results = [Collections.Generic.List[object]]::new()

try {
    if (-not [string]::IsNullOrWhiteSpace($PackagePath)) {
        if ($Mode -eq 'Junction') {
            throw 'Junction mode requires SourceRoot, not a temporary package.'
        }
        $package = [IO.Path]::GetFullPath($PackagePath)
        if (-not [IO.File]::Exists($package)) {
            throw "Package does not exist: '$package'."
        }
        $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "maw-install-$([Guid]::NewGuid().ToString('N'))"
        [void][IO.Directory]::CreateDirectory($temporaryRoot)
        Expand-Archive -LiteralPath $package -DestinationPath $temporaryRoot
        $SourceRoot = $temporaryRoot
    }
    elseif ([string]::IsNullOrWhiteSpace($SourceRoot)) {
        $SourceRoot = Get-MawRepositoryRoot
    }

    $skillSource = Resolve-MawSkillSource $SourceRoot
    $sourceRootPath = [IO.Path]::GetFullPath($SourceRoot)
    $version = Get-MawPackageVersion $sourceRootPath

    foreach ($client in @($Clients | Select-Object -Unique)) {
        $target = Get-MawClientTarget $client
        $recordPath = Get-MawRecordPath $client
        $backup = $null

        if ([IO.Directory]::Exists($target) -or [IO.File]::Exists($target)) {
            if (-not $Replace) {
                throw "Target already exists. Use -Replace after reviewing it: '$target'."
            }
            $backupRoot = Get-MawBackupRoot
            $backup = Join-Path $backupRoot $client
            if ($PSCmdlet.ShouldProcess($target, "Move existing target to '$backup'")) {
                [void][IO.Directory]::CreateDirectory($backupRoot)
                Move-Item -LiteralPath $target -Destination $backup
            }
        }

        if ($PSCmdlet.ShouldProcess($target, "Install $client Skill using $Mode")) {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
            if ($Mode -eq 'Junction') {
                [void](New-Item -ItemType Junction -Path $target -Target $skillSource)
            }
            else {
                Copy-Item -LiteralPath $skillSource -Destination $target -Recurse
            }

            $installationId = [Guid]::NewGuid().ToString()
            $record = New-MawInstallationRecord `
                -Client $client `
                -Mode $Mode `
                -Target $target `
                -Source $skillSource `
                -Version $version `
                -InstallationId $installationId
            Write-MawJson $recordPath $record
            if ($Mode -eq 'Copy') {
                Write-MawJson (Join-Path $target '.maw-installation.json') $record
            }
        }

        $results.Add([ordered]@{
            client = $client
            target = $target
            mode = $Mode
            backup = $backup
            changed = -not $WhatIfPreference
        })
    }

    [ordered]@{
        success = $true
        action = if ($WhatIfPreference) { 'PreviewInstall' } else { 'Install' }
        version = $version
        source = $skillSource
        results = @($results)
    } | ConvertTo-Json -Depth 8
}
catch {
    [ordered]@{
        success = $false
        action = 'Install'
        errors = @($_.Exception.Message)
    } | ConvertTo-Json -Depth 6
    exit 1
}
finally {
    if ($null -ne $temporaryRoot -and [IO.Directory]::Exists($temporaryRoot)) {
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (Test-MawPathWithin $tempBase $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}
