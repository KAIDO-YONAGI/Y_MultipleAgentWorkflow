[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ProjectRoot,

    [string]$WorkflowRootName = 'Y_MultipleAgentWorkflow',

    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot 'WorkflowTemplate.ps1')
$templateExtractionRoot = $null

function Find-DistributionRoot {
    param([string]$StartPath)
    $current = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($StartPath))
    while ($null -ne $current) {
        if ([IO.File]::Exists((Join-Path $current.FullName 'distribution-manifest.json'))) {
            return $current.FullName
        }
        $current = $current.Parent
    }
    throw 'distribution-manifest.json was not found above the installed Skill.'
}

try {
    $project = [IO.Path]::GetFullPath($ProjectRoot)
    $workflowRoot = Join-Path $project $WorkflowRootName
    $instancePath = Join-Path $workflowRoot 'Workflow\WorkflowInstance.json'
    if (-not [IO.File]::Exists($instancePath)) {
        throw "Workflow instance manifest is missing: '$instancePath'."
    }

    $distributionRoot = Find-DistributionRoot (Join-Path $PSScriptRoot '..')
    $distribution = [IO.File]::ReadAllText(
        (Join-Path $distributionRoot 'distribution-manifest.json')
    ) | ConvertFrom-Json
    $template = Resolve-WorkflowTemplate $PSScriptRoot
    $assetRoot = [string]$template.AssetRoot
    $templateExtractionRoot = [string]$template.TemporaryRoot
    $instance = [IO.File]::ReadAllText($instancePath) | ConvertFrom-Json
    $results = [Collections.Generic.List[object]]::new()

    foreach ($managed in @($instance.managedFiles)) {
        $relative = [string]$managed.path
        $source = Join-Path $assetRoot ($relative -replace '/', '\')
        $destination = Join-Path $workflowRoot ($relative -replace '/', '\')
        if (-not [IO.File]::Exists($source)) {
            $results.Add([ordered]@{ path = $relative; status = 'source-missing' })
            continue
        }

        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationExists = [IO.File]::Exists($destination)
        $currentHash = if ($destinationExists) {
            (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        } else { $null }

        if ($destinationExists -and $currentHash -ne [string]$managed.installedHash) {
            $results.Add([ordered]@{
                path = $relative
                status = 'drifted'
                installedHash = [string]$managed.installedHash
                currentHash = $currentHash
                availableHash = $sourceHash
            })
            continue
        }

        $status = if ($currentHash -eq $sourceHash) { 'current' } else { 'update-available' }
        if ($Apply -and $status -eq 'update-available' -and
            $PSCmdlet.ShouldProcess($destination, 'Update managed workflow file')) {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
            [IO.File]::Copy($source, $destination, $true)
            $status = 'updated'
        }
        if ($Apply -and $status -in @('current', 'updated')) {
            $managed.installedHash = $sourceHash
        }
        $results.Add([ordered]@{
            path = $relative
            status = $status
            installedHash = [string]$managed.installedHash
            availableHash = $sourceHash
        })
    }

    if ($Apply -and -not $WhatIfPreference) {
        $instance.packageVersion = [string]$distribution.packageVersion
        $instance.skillVersion = [string]$distribution.skillVersion
        $instance.workflowTemplateVersion = [string]$distribution.workflowTemplateVersion
        $instance.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
        $temporary = "$instancePath.$([Guid]::NewGuid().ToString('N')).tmp"
        [IO.File]::WriteAllText(
            $temporary,
            ($instance | ConvertTo-Json -Depth 10),
            $utf8NoBom
        )
        if ([IO.File]::Exists($instancePath)) {
            $backup = "$instancePath.$([Guid]::NewGuid().ToString('N')).bak"
            [IO.File]::Replace($temporary, $instancePath, $backup)
            if ([IO.File]::Exists($backup)) {
                [IO.File]::Delete($backup)
            }
        }
        else {
            [IO.File]::Move($temporary, $instancePath)
        }
    }

    $drifted = @($results | Where-Object status -eq 'drifted').Count
    [ordered]@{
        success = $true
        action = if ($WhatIfPreference -or -not $Apply) { 'Preview' } else { 'Update' }
        packageVersion = [string]$distribution.packageVersion
        drifted = $drifted
        results = @($results)
        projectOwnedFilesChanged = $false
    } | ConvertTo-Json -Depth 10
}
catch {
    [ordered]@{
        success = $false
        action = 'UpdateWorkflowInstance'
        errors = @($_.Exception.Message)
    } | ConvertTo-Json -Depth 6
    exit 1
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($templateExtractionRoot) -and
        [IO.Directory]::Exists($templateExtractionRoot)) {
        Remove-Item -LiteralPath $templateExtractionRoot -Recurse -Force
    }
}
