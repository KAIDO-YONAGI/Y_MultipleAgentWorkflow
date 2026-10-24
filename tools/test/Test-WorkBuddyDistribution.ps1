[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $RepositoryRoot 'tools\lib\MAW.Common.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if (-not $Condition) {
        throw "Assertion failed: $Name"
    }
}

$manifest = Read-MawJson (Join-Path $RepositoryRoot 'distribution-manifest.json')
$package = if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    Join-Path $RepositoryRoot "dist\Y_MultipleAgentWorkflow-$($manifest.packageVersion)-workbuddy.zip"
}
else {
    [IO.Path]::GetFullPath($PackagePath)
}
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "maw-workbuddy-test-$([Guid]::NewGuid().ToString('N'))"

try {
    Assert-True ([IO.File]::Exists($package)) 'workbuddy-package-exists'
    [void][IO.Directory]::CreateDirectory($temporaryRoot)
    Expand-Archive -LiteralPath $package -DestinationPath $temporaryRoot

    $topLevel = @(Get-ChildItem -LiteralPath $temporaryRoot -Force)
    Assert-True (
        $topLevel.Count -eq 1 -and
        $topLevel[0].PSIsContainer -and
        $topLevel[0].Name -eq [string]$manifest.skillName
    ) 'workbuddy-package-root'

    $skillRoot = $topLevel[0].FullName
    $frontmatter = [IO.File]::ReadAllText((Join-Path $skillRoot 'SKILL.md'))
    Assert-True (
        $frontmatter -match '(?m)^description_zh:\s*.+$' -and
        $frontmatter -match '(?m)^description_en:\s*.+$' -and
        $frontmatter -match "(?m)^version:\s*['`"]?$([regex]::Escape([string]$manifest.skillVersion))['`"]?\s*$" -and
        $frontmatter -match '(?m)^author:\s*.+$'
    ) 'workbuddy-required-frontmatter'
    Assert-True (
        $frontmatter.Contains('@references/configuration-method.md') -and
        $frontmatter.Contains('@references/doc-maintenance.md') -and
        $frontmatter.Contains('templates/workflow-template.zip') -and
        -not $frontmatter.Contains('assets/workflow-template') -and
        $frontmatter.Contains('cooperative protocol')
    ) 'workbuddy-reference-syntax'

    $outerFiles = @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File)
    $tooDeep = @($outerFiles | Where-Object {
        $relative = $_.FullName.Substring($skillRoot.Length + 1)
        ($relative -split '[\\/]').Count -gt 2
    })
    Assert-True ($tooDeep.Count -eq 0) 'workbuddy-outer-zip-depth-limit'

    foreach ($relativePath in @(
        'LICENSE',
        'distribution-manifest.json',
        'references\configuration-method.md',
        'references\doc-maintenance.md',
        'references\distribution.md',
        'scripts\Initialize-Workflow.ps1',
        'scripts\Test-WorkflowConfiguration.ps1',
        'scripts\Update-WorkflowInstance.ps1',
        'scripts\WorkflowTemplate.ps1',
        'templates\workflow-template.zip'
    )) {
        Assert-True ([IO.File]::Exists((Join-Path $skillRoot $relativePath))) `
            "workbuddy-file:$relativePath"
    }
    $packagedManifest = Read-MawJson (Join-Path $skillRoot 'distribution-manifest.json')
    Assert-True (
        [string]$packagedManifest.packageVersion -eq [string]$manifest.packageVersion -and
        [string]$packagedManifest.skillVersion -eq [string]$manifest.skillVersion -and
        [string]$packagedManifest.skillName -eq [string]$manifest.skillName
    ) 'workbuddy-packaged-manifest'

    $templateRoot = Join-Path $temporaryRoot 'embedded-template'
    Expand-Archive -LiteralPath (Join-Path $skillRoot 'templates\workflow-template.zip') `
        -DestinationPath $templateRoot
    Assert-True (
        [IO.File]::Exists((Join-Path $templateRoot 'Workflow\Scripts\WorkingAgent.ps1')) -and
        [IO.File]::Exists((Join-Path $templateRoot 'WorkingAgent\.gitignore'))
    ) 'workbuddy-embedded-template-layout'
    Assert-True (
        (Get-MawFileHash (Join-Path $skillRoot 'LICENSE')) -eq
        (Get-MawFileHash (Join-Path $RepositoryRoot 'LICENSE'))
    ) 'workbuddy-license-matches-repository'
    Assert-True (
        -not [IO.Directory]::Exists((Join-Path $skillRoot 'assets')) -and
        -not [IO.Directory]::Exists((Join-Path $skillRoot 'agents'))
    ) 'workbuddy-excludes-nonstandard-layout'

    $projectRoot = Join-Path $temporaryRoot 'smoke-project'
    [void][IO.Directory]::CreateDirectory($projectRoot)
    $tempRoot = [IO.Path]::GetTempPath()
    $templateTempsBefore = @(
        Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'maw-template-*' |
            Select-Object -ExpandProperty FullName
    )
    $initializer = Join-Path $skillRoot 'scripts\Initialize-Workflow.ps1'
    $initOutput = @(& $initializer `
        -ProjectRoot $projectRoot `
        -Categories @('Workflow') `
        -ProjectValidationMode None 2>&1)
    $initResult = ($initOutput -join [Environment]::NewLine) | ConvertFrom-Json
    Assert-True ($initResult.success) 'workbuddy-packaged-initializer'
    Assert-True (
        [IO.File]::Exists((Join-Path $projectRoot 'Y_MultipleAgentWorkflow\Workflow\Scripts\WorkingAgent.ps1'))
    ) 'workbuddy-packaged-template-resolution'

    $updater = Join-Path $skillRoot 'scripts\Update-WorkflowInstance.ps1'
    $updateOutput = @(& $updater -ProjectRoot $projectRoot 2>&1)
    $updateResult = ($updateOutput -join [Environment]::NewLine) | ConvertFrom-Json
    Assert-True ($updateResult.success) 'workbuddy-packaged-updater'
    $templateTempsAfter = @(
        Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'maw-template-*' |
            Select-Object -ExpandProperty FullName
    )
    Assert-True (
        @($templateTempsAfter | Where-Object { $_ -notin $templateTempsBefore }).Count -eq 0
    ) 'workbuddy-template-temp-cleanup'

    [ordered]@{
        success = $true
        summary = 'PASS WorkBuddy distribution'
        package = [IO.Path]::GetFileName($package)
    } | ConvertTo-Json -Depth 4
}
finally {
    if ([IO.Directory]::Exists($temporaryRoot)) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
