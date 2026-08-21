[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepositoryUrl,
    [switch]$SkipClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MAW.Common.ps1')

function Reset-OwnedDirectory {
    param([string]$RepositoryRoot, [string]$Path)
    if (-not (Test-MawPathWithin $RepositoryRoot $Path)) {
        throw "Refusing to reset path outside repository: '$Path'."
    }
    if ([IO.Directory]::Exists($Path)) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    [void][IO.Directory]::CreateDirectory($Path)
}

function Copy-SkillLayout {
    param([string]$SkillSource, [string]$LayoutRoot, [string]$ManifestSource, [string]$ManifestDirectory)
    [void][IO.Directory]::CreateDirectory((Join-Path $LayoutRoot 'skills'))
    Copy-Item -LiteralPath $SkillSource -Destination (Join-Path $LayoutRoot 'skills\multiple-agent-workflow-config') -Recurse
    [void][IO.Directory]::CreateDirectory((Join-Path $LayoutRoot $ManifestDirectory))
    Copy-Item -LiteralPath $ManifestSource -Destination (Join-Path $LayoutRoot "$ManifestDirectory\plugin.json")
}

try {
    $root = Get-MawRepositoryRoot
    $manifestPath = Join-Path $root 'distribution-manifest.json'
    $manifest = Read-MawJson $manifestPath
    $version = [string]$manifest.packageVersion
    $skillSource = Resolve-MawSkillSource $root
    $layoutRoot = Join-Path $root 'release-layout'
    $distRoot = Join-Path $root 'dist'
    $stageRoot = Join-Path $root '.tmp\distribution'

    if (-not $SkipClean) {
        Reset-OwnedDirectory $root $layoutRoot
        Reset-OwnedDirectory $root $distRoot
        Reset-OwnedDirectory $root $stageRoot
    }
    else {
        foreach ($path in @($layoutRoot, $distRoot, $stageRoot)) {
            [void][IO.Directory]::CreateDirectory($path)
        }
    }

    foreach ($client in @(
        @{ Name = 'codex'; Manifest = 'packaging\codex\plugin.json'; Directory = '.codex-plugin' },
        @{ Name = 'claude'; Manifest = 'packaging\claude\plugin.json'; Directory = '.claude-plugin' },
        @{ Name = 'zcode'; Manifest = 'packaging\zcode\plugin.json'; Directory = '.zcode-plugin' }
    )) {
        $layout = Join-Path $layoutRoot $client.Name
        [void][IO.Directory]::CreateDirectory($layout)
        Copy-SkillLayout $skillSource $layout (Join-Path $root $client.Manifest) $client.Directory
        $zip = Join-Path $distRoot "Y_MultipleAgentWorkflow-$version-$($client.Name).zip"
        Compress-Archive -Path (Join-Path $layout '*') -DestinationPath $zip -CompressionLevel Optimal
    }

    $offline = Join-Path $stageRoot 'offline'
    [void][IO.Directory]::CreateDirectory((Join-Path $offline 'skills'))
    Copy-Item -LiteralPath $skillSource -Destination (Join-Path $offline 'skills\multiple-agent-workflow-config') -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination (Join-Path $offline 'scripts') -Recurse
    Copy-Item -LiteralPath $manifestPath -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $offline
    $offlineZip = Join-Path $distRoot "Y_MultipleAgentWorkflow-$version-offline.zip"
    Compress-Archive -Path (Join-Path $offline '*') -DestinationPath $offlineZip -CompressionLevel Optimal

    $repository = if ([string]::IsNullOrWhiteSpace($RepositoryUrl)) {
        [string]$manifest.repository
    } else { $RepositoryUrl }
    if (-not [string]::IsNullOrWhiteSpace($repository)) {
        $manifest.repository = $repository
        Write-MawJson $manifestPath $manifest
        $claudeMarketplace = [IO.File]::ReadAllText(
            (Join-Path $root 'packaging\claude\marketplace.json')
        ).Replace('{{REPOSITORY_URL}}', $repository)
        [IO.File]::WriteAllText(
            (Join-Path $layoutRoot 'claude\.claude-plugin\marketplace.json'),
            $claudeMarketplace,
            $script:MawUtf8NoBom
        )
    }

    $zcodeZip = Join-Path $distRoot "Y_MultipleAgentWorkflow-$version-zcode.zip"
    $zcodeHash = Get-MawFileHash $zcodeZip
    $zcodeUrl = if ([string]::IsNullOrWhiteSpace($repository)) {
        "Y_MultipleAgentWorkflow-$version-zcode.zip"
    } else {
        "$repository/releases/download/v$version/Y_MultipleAgentWorkflow-$version-zcode.zip"
    }
    $zcodeMarketplace = [IO.File]::ReadAllText(
        (Join-Path $root 'packaging\zcode\marketplace.json')
    ).Replace('{{ZCODE_PACKAGE_URL}}', $zcodeUrl).Replace('{{ZCODE_PACKAGE_SHA256}}', $zcodeHash)
    [IO.File]::WriteAllText(
        (Join-Path $distRoot 'zcode-marketplace.json'),
        $zcodeMarketplace,
        $script:MawUtf8NoBom
    )
    if (-not [string]::IsNullOrWhiteSpace($repository)) {
        Copy-Item -LiteralPath (
            Join-Path $layoutRoot 'claude\.claude-plugin\marketplace.json'
        ) -Destination (Join-Path $distRoot 'claude-marketplace.json')
    }

    $checksumLines = @(
        Get-ChildItem -LiteralPath $distRoot -File |
            Where-Object Name -ne 'SHA256SUMS' |
            Sort-Object Name |
            ForEach-Object { "$(Get-MawFileHash $_.FullName)  $($_.Name)" }
    )
    [IO.File]::WriteAllLines(
        (Join-Path $distRoot 'SHA256SUMS'),
        $checksumLines,
        $script:MawUtf8NoBom
    )
    [ordered]@{
        success = $true
        version = $version
        repository = $repository
        assets = @(Get-ChildItem -LiteralPath $distRoot -File | Select-Object -ExpandProperty FullName)
    } | ConvertTo-Json -Depth 6
}
catch {
    [ordered]@{ success = $false; errors = @($_.Exception.Message) } | ConvertTo-Json -Depth 5
    exit 1
}
