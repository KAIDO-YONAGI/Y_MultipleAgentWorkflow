[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepositoryUrl,
    [switch]$SkipClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\MAW.Common.ps1')

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

function Expand-DistributionTemplate {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Tokens
    )

    $text = [IO.File]::ReadAllText($Path)
    foreach ($key in $Tokens.Keys) {
        $text = $text.Replace("{{$key}}", [string]$Tokens[$key])
    }
    $text
}

function Copy-SkillLayout {
    param(
        [string]$SkillSource,
        [string]$LayoutRoot,
        [string]$LicenseSource,
        [string]$ManifestSource,
        [string]$ManifestDirectory,
        [hashtable]$Tokens
    )

    [void][IO.Directory]::CreateDirectory((Join-Path $LayoutRoot 'skills'))
    Copy-Item -LiteralPath $SkillSource -Destination (Join-Path $LayoutRoot 'skills\multiple-agent-workflow-config') -Recurse
    Copy-Item -LiteralPath $LicenseSource -Destination (Join-Path $LayoutRoot 'LICENSE')
    [void][IO.Directory]::CreateDirectory((Join-Path $LayoutRoot $ManifestDirectory))
    [IO.File]::WriteAllText(
        (Join-Path $LayoutRoot "$ManifestDirectory\plugin.json"),
        (Expand-DistributionTemplate $ManifestSource $Tokens),
        $script:MawUtf8NoBom
    )
}

function Build-WorkBuddyPackage {
    param(
        [string]$RepositoryRoot,
        [string]$SkillSource,
        [string]$StageRoot,
        [string]$DistributionRoot,
        [string]$Version,
        [Parameter(Mandatory)]$Manifest
    )

    $skillName = [string]$Manifest.skillName
    $packageRoot = Join-Path $StageRoot 'workbuddy'
    Reset-OwnedDirectory $RepositoryRoot $packageRoot
    $skillRoot = Join-Path $packageRoot $skillName
    [void][IO.Directory]::CreateDirectory($skillRoot)

    foreach ($directory in @('references', 'scripts')) {
        Copy-Item -LiteralPath (Join-Path $SkillSource $directory) `
            -Destination $skillRoot -Recurse
    }
    $templatesRoot = Join-Path $skillRoot 'templates'
    [void][IO.Directory]::CreateDirectory($templatesRoot)
    [void](Add-Type -AssemblyName System.IO.Compression.FileSystem)
    [IO.Compression.ZipFile]::CreateFromDirectory(
        (Join-Path $SkillSource 'assets\workflow-template'),
        (Join-Path $templatesRoot 'workflow-template.zip'),
        [IO.Compression.CompressionLevel]::Optimal,
        $false
    )
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'LICENSE') `
        -Destination (Join-Path $skillRoot 'LICENSE')
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'distribution-manifest.json') `
        -Destination (Join-Path $skillRoot 'distribution-manifest.json')

    $canonicalSkill = [IO.File]::ReadAllText((Join-Path $SkillSource 'SKILL.md'))
    $canonicalFrontmatter = [regex]::Match(
        $canonicalSkill,
        '\A---\r?\n.*?\r?\n---(?:\r?\n|\Z)',
        [Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $canonicalFrontmatter.Success) {
        throw 'Canonical SKILL.md has no valid YAML frontmatter block.'
    }
    $body = $canonicalSkill.Substring($canonicalFrontmatter.Length).TrimStart("`r", "`n")
    $body = $body.Replace(
        'The reusable scaffold is in [assets/workflow-template](assets/workflow-template).',
        'The reusable scaffold is bundled in [templates/workflow-template.zip](templates/workflow-template.zip). The initializer and updater extract it to a temporary directory when needed.'
    )
    $heading = [regex]::Match($body, '\A# Multiple Agent Workflow Configuration\r?\n')
    if (-not $heading.Success) {
        throw 'Canonical SKILL.md has no expected title heading.'
    }
    $adapter = [IO.File]::ReadAllText(
        (Join-Path $RepositoryRoot 'packaging\workbuddy\skill-adapter.md')
    ).Trim()
    $body = $body.Substring(0, $heading.Length) + "`r`n" + $adapter + "`r`n`r`n" +
        $body.Substring($heading.Length)
    $metadata = Expand-DistributionTemplate `
        (Join-Path $RepositoryRoot 'packaging\workbuddy\metadata.yaml') @{
            PACKAGE_VERSION = $Version
        }
    [IO.File]::WriteAllText(
        (Join-Path $skillRoot 'SKILL.md'),
        $metadata + "`r`n" + $body,
        $script:MawUtf8NoBom
    )

    $package = Join-Path $DistributionRoot "Y_MultipleAgentWorkflow-$Version-workbuddy.zip"
    Compress-Archive -Path $skillRoot -DestinationPath $package `
        -CompressionLevel Optimal -Force
    $package
}

try {
    $root = Get-MawRepositoryRoot
    $manifestPath = Join-Path $root 'distribution-manifest.json'
    $manifest = Read-MawJson $manifestPath
    $version = [string]$manifest.packageVersion
    $skillSource = Resolve-MawSkillSource $root
    $distRoot = Join-Path $root 'dist'
    $stageRoot = Join-Path $root '.tmp\distribution'
    $clientStageRoot = Join-Path $stageRoot 'clients'
    $tokens = @{
        PACKAGE_VERSION = $version
    }

    if (-not $SkipClean) {
        Reset-OwnedDirectory $root $distRoot
        Reset-OwnedDirectory $root $stageRoot
    }
    else {
        foreach ($path in @($distRoot, $stageRoot, $clientStageRoot)) {
            [void][IO.Directory]::CreateDirectory($path)
        }
    }
    [void][IO.Directory]::CreateDirectory($clientStageRoot)

    foreach ($client in @(
        @{ Name = 'codex'; Manifest = 'packaging\codex\plugin.json'; Directory = '.codex-plugin' },
        @{ Name = 'claude'; Manifest = 'packaging\claude\plugin.json'; Directory = '.claude-plugin' },
        @{ Name = 'zcode'; Manifest = 'packaging\zcode\plugin.json'; Directory = '.zcode-plugin' }
    )) {
        $layout = Join-Path $clientStageRoot $client.Name
        [void][IO.Directory]::CreateDirectory($layout)
        Copy-SkillLayout $skillSource $layout (Join-Path $root 'LICENSE') `
            (Join-Path $root $client.Manifest) `
            $client.Directory $tokens
        $zip = Join-Path $distRoot "Y_MultipleAgentWorkflow-$version-$($client.Name).zip"
        Compress-Archive -Path (Join-Path $layout '*') -DestinationPath $zip -CompressionLevel Optimal
    }

    $offline = Join-Path $stageRoot 'offline'
    [void][IO.Directory]::CreateDirectory((Join-Path $offline 'skills'))
    Copy-Item -LiteralPath $skillSource -Destination (Join-Path $offline 'skills\multiple-agent-workflow-config') -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'tools') -Destination (Join-Path $offline 'tools') -Recurse
    Copy-Item -LiteralPath $manifestPath -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'README.cn.md') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'requirements-dev.txt') -Destination $offline
    Copy-Item -LiteralPath (Join-Path $root 'docs') -Destination (Join-Path $offline 'docs') -Recurse
    $offlineZip = Join-Path $distRoot "Y_MultipleAgentWorkflow-$version-offline.zip"
    Compress-Archive -Path (Join-Path $offline '*') -DestinationPath $offlineZip -CompressionLevel Optimal

    $workbuddyZip = Build-WorkBuddyPackage `
        -RepositoryRoot $root `
        -SkillSource $skillSource `
        -StageRoot $clientStageRoot `
        -DistributionRoot $distRoot `
        -Version ([string]$manifest.skillVersion) `
        -Manifest $manifest

    $repository = if ([string]::IsNullOrWhiteSpace($RepositoryUrl)) {
        [string]$manifest.repository
    } else { $RepositoryUrl }
    if (-not [string]::IsNullOrWhiteSpace($repository)) {
        $claudeMarketplace = Expand-DistributionTemplate `
            (Join-Path $root 'packaging\claude\marketplace.json') @{
                REPOSITORY_URL = $repository
                PACKAGE_VERSION = $version
            }
        [IO.File]::WriteAllText(
            (Join-Path $distRoot 'claude-marketplace.json'),
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
    $zcodeMarketplace = Expand-DistributionTemplate `
        (Join-Path $root 'packaging\zcode\marketplace.json') @{
            ZCODE_PACKAGE_URL = $zcodeUrl
            ZCODE_PACKAGE_SHA256 = $zcodeHash
            PACKAGE_VERSION = $version
        }
    [IO.File]::WriteAllText(
        (Join-Path $distRoot 'zcode-marketplace.json'),
        $zcodeMarketplace,
        $script:MawUtf8NoBom
    )

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
