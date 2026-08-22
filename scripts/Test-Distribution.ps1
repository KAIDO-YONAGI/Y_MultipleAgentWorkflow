[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MAW.Common.ps1')

$root = Get-MawRepositoryRoot
$testRoot = Join-Path $root ".tmp\tests\$([Guid]::NewGuid().ToString('N'))"
$testHome = Join-Path $testRoot 'home'
$project = Join-Path $testRoot 'project'
$checks = [Collections.Generic.List[object]]::new()

function Add-Pass {
    param([string]$Name)
    $checks.Add([ordered]@{ name = $Name; status = 'pass' })
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if (-not $Condition) { throw "Assertion failed: $Name" }
    Add-Pass $Name
}

function Assert-DirectoryContentEqual {
    param(
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Actual,
        [Parameter(Mandatory)][string]$Name
    )

    $expectedRoot = [IO.Path]::GetFullPath($Expected).TrimEnd('\')
    $actualRoot = [IO.Path]::GetFullPath($Actual).TrimEnd('\')
    $expectedFiles = @(
        Get-ChildItem -LiteralPath $expectedRoot -Recurse -File |
            ForEach-Object { $_.FullName.Substring($expectedRoot.Length + 1).Replace('\', '/') } |
            Sort-Object
    )
    $actualFiles = @(
        Get-ChildItem -LiteralPath $actualRoot -Recurse -File |
            ForEach-Object { $_.FullName.Substring($actualRoot.Length + 1).Replace('\', '/') } |
            Sort-Object
    )
    if (($expectedFiles -join "`n") -ne ($actualFiles -join "`n")) {
        throw "Assertion failed: $Name file lists differ."
    }
    foreach ($relative in $expectedFiles) {
        $expectedHash = Get-MawFileHash (Join-Path $expectedRoot ($relative -replace '/', '\'))
        $actualHash = Get-MawFileHash (Join-Path $actualRoot ($relative -replace '/', '\'))
        if ($expectedHash -ne $actualHash) {
            throw "Assertion failed: $Name hash differs for '$relative'."
        }
    }
    Add-Pass $Name
}

function Invoke-JsonScript {
    param([string]$Path, [hashtable]$Arguments)
    $global:LASTEXITCODE = 0
    $output = @(& $Path @Arguments 2>&1)
    $code = $LASTEXITCODE
    $json = ($output -join [Environment]::NewLine) | ConvertFrom-Json
    [pscustomobject]@{ Code = $code; Json = $json; Text = ($output -join "`n") }
}

try {
    [void][IO.Directory]::CreateDirectory($testHome)
    [void][IO.Directory]::CreateDirectory($project)
    $env:MAW_HOME = $testHome

    foreach ($jsonFile in @(
        'distribution-manifest.json',
        'packaging\codex\plugin.json',
        'packaging\claude\plugin.json',
        'packaging\claude\marketplace.json',
        'packaging\zcode\plugin.json',
        'packaging\zcode\marketplace.json'
    )) {
        $null = Read-MawJson (Join-Path $root $jsonFile)
    }
    Add-Pass 'json-manifests'

    $scripts = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1')
    foreach ($file in $scripts) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors
        )
        if (@($errors).Count -gt 0) {
            throw "Parser errors in '$($file.FullName)': $(@($errors.Message) -join '; ')"
        }
    }
    Add-Pass 'powershell-parser'

    $initializer = Join-Path $root 'src\skills\multiple-agent-workflow-config\scripts\Initialize-Workflow.ps1'
    $validator = Join-Path $root 'src\skills\multiple-agent-workflow-config\scripts\Test-WorkflowConfiguration.ps1'
    $init = Invoke-JsonScript $initializer @{
        ProjectRoot = $project
        Categories = @('Workflow', 'GUI', 'Resources.Load')
        ProjectValidationMode = 'None'
    }
    Assert-True ($init.Code -eq 0 -and $init.Json.success) 'initialize-nested-categories'
    Assert-True ([IO.File]::Exists((Join-Path $project 'Y_MultipleAgentWorkflow\Workflow\WorkflowInstance.json'))) 'workflow-instance-manifest'

    $duplicate = Invoke-JsonScript $initializer @{
        ProjectRoot = $project
        Categories = @('Workflow')
        ProjectValidationMode = 'None'
    }
    Assert-True ($duplicate.Code -ne 0 -and -not $duplicate.Json.success) 'initialize-refuses-overwrite'

    $merge = Invoke-JsonScript $initializer @{
        ProjectRoot = $project
        Categories = @('Workflow')
        ProjectValidationMode = 'None'
        Merge = $true
    }
    Assert-True ($merge.Code -eq 0 -and $merge.Json.success) 'initialize-merge'

    $previewProject = Join-Path $testRoot 'preview'
    [void][IO.Directory]::CreateDirectory($previewProject)
    $preview = Invoke-JsonScript $initializer @{
        ProjectRoot = $previewProject
        Categories = @('Workflow')
        ProjectValidationMode = 'None'
        WhatIf = $true
    }
    Assert-True ($preview.Code -eq 0 -and -not [IO.Directory]::Exists((Join-Path $previewProject 'Y_MultipleAgentWorkflow'))) 'initialize-whatif'

    $tooDeep = Invoke-JsonScript $initializer @{
        ProjectRoot = $previewProject
        Categories = @('A.B.C.D.E.F')
        ProjectValidationMode = 'None'
    }
    Assert-True ($tooDeep.Code -ne 0) 'initialize-five-level-limit'

    $validation = Invoke-JsonScript $validator @{
        ProjectRoot = $project
        RunWorkingAgentTests = $true
    }
    Assert-True ($validation.Code -eq 0 -and $validation.Json.success) 'workflow-validation-and-working-agent-12-of-12'

    $install = Join-Path $root 'scripts\Install-MAW.ps1'
    $uninstall = Join-Path $root 'scripts\Uninstall-MAW.ps1'
    $copy = Invoke-JsonScript $install @{
        Clients = @('Codex')
        Mode = 'Copy'
        SourceRoot = $root
    }
    Assert-True ($copy.Code -eq 0 -and $copy.Json.success) 'copy-install'
    $repeat = Invoke-JsonScript $install @{
        Clients = @('Codex')
        Mode = 'Copy'
        SourceRoot = $root
    }
    Assert-True ($repeat.Code -ne 0) 'repeat-install-refused'
    $replace = Invoke-JsonScript $install @{
        Clients = @('Codex')
        Mode = 'Copy'
        SourceRoot = $root
        Replace = $true
    }
    Assert-True ($replace.Code -eq 0) 'copy-replace'
    $removeCopy = Invoke-JsonScript $uninstall @{ Clients = @('Codex') }
    Assert-True ($removeCopy.Code -eq 0) 'copy-uninstall'

    $junction = Invoke-JsonScript $install @{
        Clients = @('Claude', 'ZCode')
        Mode = 'Junction'
        SourceRoot = $root
    }
    Assert-True ($junction.Code -eq 0) 'junction-install'
    foreach ($client in @('Claude', 'ZCode')) {
        $target = Get-MawClientTarget $client
        Assert-True ((Get-MawLinkTarget $target) -eq (Resolve-MawSkillSource $root)) "junction-target-$client"
    }
    $removeJunctions = Invoke-JsonScript $uninstall @{ Clients = @('Claude', 'ZCode') }
    Assert-True ($removeJunctions.Code -eq 0) 'junction-uninstall'

    & (Join-Path $root 'scripts\Build-Distribution.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Build-Distribution failed.' }
    Add-Pass 'build-distribution'
    Assert-True (-not [IO.Directory]::Exists((Join-Path $root 'release-layout'))) `
        'build-does-not-create-release-layout'
    $manifest = Read-MawJson (Join-Path $root 'distribution-manifest.json')
    $claudeMarketplace = Read-MawJson (Join-Path $root 'dist\claude-marketplace.json')
    $zcodeMarketplace = Read-MawJson (Join-Path $root 'dist\zcode-marketplace.json')
    Add-Pass 'release-marketplace-metadata'
    Assert-True (
        [string]$claudeMarketplace.plugins[0].source.path -eq
            'src/skills/multiple-agent-workflow-config' -and
        [string]$claudeMarketplace.plugins[0].source.ref -eq
            "v$($manifest.packageVersion)" -and
        $claudeMarketplace.plugins[0].strict -eq $false -and
        [string]$claudeMarketplace.plugins[0].skills[0] -eq './'
    ) 'claude-marketplace-uses-canonical-source'
    $offline = Join-Path $root "dist\Y_MultipleAgentWorkflow-$($manifest.packageVersion)-offline.zip"
    Assert-True ([IO.File]::Exists($offline)) 'offline-package'
    $skillSource = Resolve-MawSkillSource $root
    foreach ($client in @('codex', 'claude', 'zcode')) {
        $package = Join-Path $root "dist\Y_MultipleAgentWorkflow-$($manifest.packageVersion)-$client.zip"
        $extract = Join-Path $testRoot "extract-$client"
        Expand-Archive -LiteralPath $package -DestinationPath $extract
        $pluginDirectory = ".$client-plugin"
        $plugin = Read-MawJson (Join-Path $extract "$pluginDirectory\plugin.json")
        Assert-True (
            [IO.File]::Exists((Join-Path $extract 'skills\multiple-agent-workflow-config\SKILL.md')) -and
            [string]$plugin.version -eq [string]$manifest.packageVersion
        ) "extract-$client-package"
        Assert-DirectoryContentEqual $skillSource `
            (Join-Path $extract 'skills\multiple-agent-workflow-config') `
            "package-$client-matches-canonical-skill"
        if ($client -eq 'zcode') {
            Assert-True (
                -not [IO.File]::Exists((Join-Path $extract '.zcode-plugin\marketplace.json'))
            ) 'zcode-package-excludes-self-referential-marketplace'
            Assert-True (
                [string]$zcodeMarketplace.plugins[0].source.sha256 -eq (Get-MawFileHash $package)
            ) 'zcode-marketplace-package-hash'
        }
    }
    $offlineExtract = Join-Path $testRoot 'extract-offline'
    Expand-Archive -LiteralPath $offline -DestinationPath $offlineExtract
    Assert-True (
        [IO.File]::Exists((Join-Path $offlineExtract 'scripts\Install-MAW.ps1')) -and
        [IO.File]::Exists((Join-Path $offlineExtract 'distribution-manifest.json')) -and
        [IO.File]::Exists((Join-Path $offlineExtract 'README.cn.md'))
    ) 'extract-offline-package'

    $offlineInstall = Invoke-JsonScript $install @{
        Clients = @('Codex')
        Mode = 'Copy'
        PackagePath = $offline
    }
    Assert-True ($offlineInstall.Code -eq 0 -and $offlineInstall.Json.version -eq [string]$manifest.packageVersion) 'offline-copy-install'
    $offlineHash = Get-MawFileHash $offline
    $badUpdate = Invoke-JsonScript (Join-Path $root 'scripts\Update-MAW.ps1') @{
        Clients = @('Codex')
        PackagePath = $offline
        ExpectedSha256 = ('0' * 64)
    }
    Assert-True ($badUpdate.Code -ne 0) 'offline-update-rejects-bad-sha256'
    $goodUpdate = Invoke-JsonScript (Join-Path $root 'scripts\Update-MAW.ps1') @{
        Clients = @('Codex')
        PackagePath = $offline
        ExpectedSha256 = $offlineHash
    }
    Assert-True ($goodUpdate.Code -eq 0 -and $goodUpdate.Json.success) 'offline-update-verifies-and-replaces'
    $null = Invoke-JsonScript $uninstall @{ Clients = @('Codex') }

    $workflowRoot = Join-Path $project 'Y_MultipleAgentWorkflow'
    $managedPath = Join-Path $workflowRoot 'Workflow\Templates\BusinessRouter.template.md'
    [IO.File]::AppendAllText($managedPath, "`nproject drift")
    $projectRouter = Join-Path $workflowRoot 'Router.md'
    $routerHash = Get-MawFileHash $projectRouter
    $update = Invoke-JsonScript (Join-Path $root 'scripts\Update-WorkflowInstance.ps1') @{
        ProjectRoot = $project
        Apply = $true
    }
    Assert-True ($update.Code -eq 0 -and $update.Json.drifted -eq 1) 'managed-drift-preserved'
    Assert-True ((Get-MawFileHash $projectRouter) -eq $routerHash) 'project-owned-router-preserved'

    [ordered]@{
        success = $true
        summary = "PASS $($checks.Count)/$($checks.Count)"
        checks = @($checks)
    } | ConvertTo-Json -Depth 8
}
catch {
    [ordered]@{
        success = $false
        completed = @($checks)
        errors = @($_.Exception.Message)
    } | ConvertTo-Json -Depth 8
    exit 1
}
finally {
    Remove-Item Env:\MAW_HOME -ErrorAction SilentlyContinue
}
