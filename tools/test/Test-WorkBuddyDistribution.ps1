[CmdletBinding()]
param(
    [string]$RepositoryRoot
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
$package = Join-Path $RepositoryRoot "dist\Y_MultipleAgentWorkflow-$($manifest.packageVersion)-workbuddy.zip"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "maw-workbuddy-test-$([Guid]::NewGuid().ToString('N'))"

try {
    Assert-True ([IO.File]::Exists($package)) 'workbuddy-package-exists'
    [void][IO.Directory]::CreateDirectory($temporaryRoot)
    Expand-Archive -LiteralPath $package -DestinationPath $temporaryRoot

    $topLevel = @(Get-ChildItem -LiteralPath $temporaryRoot -Force)
    Assert-True (
        $topLevel.Count -eq 1 -and
        $topLevel[0].PSIsContainer -and
        $topLevel[0].Name -eq 'multiple-agent-workflow-config'
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
        $frontmatter.Contains('@references/doc-maintenance.md')
    ) 'workbuddy-reference-syntax'

    foreach ($relativePath in @(
        'LICENSE',
        'references\configuration-method.md',
        'references\doc-maintenance.md',
        'references\distribution.md',
        'scripts\Initialize-Workflow.ps1',
        'scripts\Test-WorkflowConfiguration.ps1',
        'scripts\Update-WorkflowInstance.ps1',
        'templates\workflow-template\Workflow\Scripts\WorkingAgent.ps1'
    )) {
        Assert-True ([IO.File]::Exists((Join-Path $skillRoot $relativePath))) `
            "workbuddy-file:$relativePath"
    }
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
