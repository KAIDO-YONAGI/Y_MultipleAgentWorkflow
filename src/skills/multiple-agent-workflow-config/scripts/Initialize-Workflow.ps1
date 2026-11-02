[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ProjectRoot,

    [string]$WorkflowRootName = 'Y_MultipleAgentWorkflow',

    [string[]]$Categories = @('Workflow'),

    [Parameter(Mandatory)]
    [ValidateSet('None', 'Guide')]
    [string]$ProjectValidationMode,

    [switch]$Merge
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WorkflowTemplate.ps1')
$script:Utf8NoBom = [Text.UTF8Encoding]::new($false)
$script:AssetRoot = $null
$script:TemplateExtractionRoot = $null
$script:ConfigurationMethod = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\references\configuration-method.md')
)
$script:Created = [Collections.Generic.List[string]]::new()
$script:Planned = [Collections.Generic.List[string]]::new()
$script:Skipped = [Collections.Generic.List[string]]::new()
$script:Warnings = [Collections.Generic.List[string]]::new()
$script:ManagedFiles = @(
    'Workflow/Scripts/WorkingAgent.ps1',
    'Workflow/Scripts/Test-WorkingAgent.ps1',
    'Workflow/Templates/BusinessRouter.template.md',
    'Workflow/Templates/DeveloperLog.template.md',
    'WorkingAgent/.gitignore'
)

function Expand-Values {
    param([string[]]$Values)

    $result = [Collections.Generic.List[string]]::new()
    foreach ($value in @($Values)) {
        foreach ($part in ([string]$value -split ',')) {
            $trimmed = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $result.Add($trimmed)
            }
        }
    }
    @($result | Select-Object -Unique)
}

function Get-CategoryPrefixes {
    param([string[]]$Values)

    $prefixes = [Collections.Generic.List[string]]::new()
    foreach ($category in (Expand-Values $Values)) {
        $segments = @($category -split '\.')
        if ($segments.Count -gt 5) {
            throw "Category '$category' exceeds the five-level limit."
        }
        foreach ($segment in $segments) {
            if ($segment -notmatch '^[A-Za-z0-9_-]+$') {
                throw "Invalid category segment '$segment' in '$category'."
            }
        }
        for ($i = 1; $i -le $segments.Count; $i++) {
            $prefix = ($segments[0..($i - 1)] -join '.')
            if (-not $prefixes.Contains($prefix)) {
                $prefixes.Add($prefix)
            }
        }
    }
    if (-not $prefixes.Contains('Workflow')) {
        $prefixes.Insert(0, 'Workflow')
    }
    @($prefixes)
}

function Convert-Template {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][hashtable]$Tokens
    )

    $text = [IO.File]::ReadAllText($Source)
    foreach ($key in $Tokens.Keys) {
        $text = $text.Replace("{{$key}}", [string]$Tokens[$key])
    }
    $text
}

function Install-Text {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Content
    )

    if ([IO.File]::Exists($Destination)) {
        $script:Skipped.Add($Destination)
        return
    }

    $script:Planned.Add($Destination)
    if (-not $PSCmdlet.ShouldProcess($Destination, 'Create workflow file')) {
        return
    }

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination))
    [IO.File]::WriteAllText($Destination, $Content, $script:Utf8NoBom)
    $script:Created.Add($Destination)
}

function Install-Asset {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Destination,
        [hashtable]$Tokens = @{}
    )

    $source = Join-Path $script:AssetRoot $RelativePath
    if (-not [IO.File]::Exists($source)) {
        throw "Missing workflow asset '$source'."
    }
    Install-Text $Destination (Convert-Template $source $Tokens)
}

function Get-DistributionManifest {
    $current = [IO.DirectoryInfo]::new(
        [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    )
    while ($null -ne $current) {
        $candidate = Join-Path $current.FullName 'distribution-manifest.json'
        if ([IO.File]::Exists($candidate)) {
            return [IO.File]::ReadAllText($candidate) | ConvertFrom-Json
        }
        $current = $current.Parent
    }
    [pscustomobject]@{
        packageVersion = 'development'
        skillVersion = 'development'
        workflowTemplateVersion = 'development'
    }
}

function Get-ManagedFileRecords {
    param([string]$WorkflowRoot)

    @($script:ManagedFiles | ForEach-Object {
        $relative = $_
        $destination = Join-Path $WorkflowRoot ($relative -replace '/', '\')
        $source = Join-Path $script:AssetRoot ($relative -replace '/', '\')
        $hashPath = if ([IO.File]::Exists($destination)) { $destination } else { $source }
        [ordered]@{
            path = $relative
            installedHash = (Get-FileHash -LiteralPath $hashPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

function New-BusinessRouter {
    param(
        [string]$Category,
        [string[]]$AllCategories,
        [string]$Date
    )

    $segments = @($Category -split '\.')
    $leaf = $segments[-1]
    $children = @(
        $AllCategories |
            Where-Object {
                $_.StartsWith("$Category.", [StringComparison]::OrdinalIgnoreCase) -and
                (@($_ -split '\.').Count -eq $segments.Count + 1)
            } |
            Sort-Object
    )
    $childRows = if ($children.Count -eq 0) {
        '| None | None |'
    }
    else {
        @($children | ForEach-Object {
            $childLeaf = (@($_ -split '\.'))[-1]
            "| ``$childLeaf`` | ``$childLeaf\Router.md`` |"
        }) -join [Environment]::NewLine
    }
    $documentId = 'BUS-' + ($Category.ToUpperInvariant() -replace '\.', '-')

    @"
# $Category Router

Document ID: ``$documentId``  
Status: ``Active``  
Maintenance count: ``0/5``  
Last updated: ``$Date``

## Maintenance rules

Update this Router when business routes, authorities, or capability boundaries
change. Count only successful tasks that materially affect this business; failures,
cancellation, read-only analysis, leases, and pure documentation maintenance do not
count. At 5/5, review actual implementation and task evidence, update authorities
or record reviewed-no-change, then reset. Store evidence in this business log and
maintain its detailed document index here.

## Task routing

| Trigger | Authority |
|---|---|
| ``$leaf`` related work | Register the confirmed Guide/Design here |

## Child routing

| Child | Router |
|---|---|
$childRows

## Concurrency resources

- ``workflow:$Category``
- Add confirmed path/runtime/config resources after project inspection.

## Capability boundary

Record Active capabilities, Proposal documents, and user-confirmed constraints here.
"@
}

try {
    $template = Resolve-WorkflowTemplate $PSScriptRoot
    $script:AssetRoot = [string]$template.AssetRoot
    $script:TemplateExtractionRoot = [string]$template.TemporaryRoot

    $project = [IO.Path]::GetFullPath($ProjectRoot)
    if (-not [IO.Directory]::Exists($project)) {
        throw "ProjectRoot does not exist: '$project'."
    }
    if ([IO.Path]::IsPathRooted($WorkflowRootName) -or
        $WorkflowRootName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $WorkflowRootName.Contains('\') -or $WorkflowRootName.Contains('/')) {
        throw 'WorkflowRootName must be one valid directory name.'
    }

    $workflowRoot = Join-Path $project $WorkflowRootName
    if ([IO.Directory]::Exists($workflowRoot) -and -not $Merge) {
        throw "Workflow root already exists. Use -Merge to create only missing files: '$workflowRoot'."
    }

    $date = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
    $projectName = [IO.Path]::GetFileName($project.TrimEnd('\', '/'))
    $categoryList = @(Get-CategoryPrefixes $Categories)
    $topCategories = @($categoryList | Where-Object { $_ -notmatch '\.' } | Sort-Object)
    $categoryRows = @($topCategories | ForEach-Object {
        "| ``$_`` | ``$_\Router.md`` |"
    }) -join [Environment]::NewLine
    $projectValidationSection = if ($ProjectValidationMode -eq 'Guide') {
@"
## Project validation

Project-specific validation is routed to
``Workflow\Project_Validation_Guide.md``. The guide must contain only commands and
state changes confirmed for this project.
"@
    }
    else {
@"
## Project validation

No project-specific build, publish, run, deployment, process, or environment
procedure is configured. This workflow does not impose one.
"@
    }
    $tokens = @{
        PROJECT_NAME = $projectName
        CATEGORY_ROWS = $categoryRows
        PROJECT_VALIDATION_MODE = $ProjectValidationMode
        PROJECT_VALIDATION_SECTION = $projectValidationSection
        DATE = $date
    }

    Install-Asset 'Router.md' (Join-Path $workflowRoot 'Router.md') $tokens
    Install-Asset 'DeveloperLog.md' (Join-Path $workflowRoot 'DeveloperLog.md') $tokens
    if (-not [IO.File]::Exists($script:ConfigurationMethod)) {
        throw "Missing configuration method '$script:ConfigurationMethod'."
    }
    Install-Text (Join-Path $workflowRoot 'Workflow_Configuration_Guide.md') `
        (Convert-Template $script:ConfigurationMethod $tokens)
    Install-Asset 'WorkingAgent\README.md' `
        (Join-Path $workflowRoot 'WorkingAgent\README.md') $tokens
    Install-Asset 'WorkingAgent\.gitignore' `
        (Join-Path $workflowRoot 'WorkingAgent\.gitignore') $tokens

    foreach ($relative in @(
        'Workflow\Router.md',
        'Workflow\DeveloperLog.md',
        'Workflow\Workflow_Guide.md',
        'Workflow\Concurrency_Guide.md',
        'Workflow\Templates\BusinessRouter.template.md',
        'Workflow\Templates\DeveloperLog.template.md',
        'Workflow\Scripts\WorkingAgent.ps1',
        'Workflow\Scripts\Test-WorkingAgent.ps1'
    )) {
        Install-Asset $relative (Join-Path $workflowRoot $relative) $tokens
    }
    if ($ProjectValidationMode -eq 'Guide') {
        Install-Asset 'Workflow\Project_Validation_Guide.md' `
            (Join-Path $workflowRoot 'Workflow\Project_Validation_Guide.md') $tokens
    }

    foreach ($category in $categoryList) {
        if ($category.Equals('Workflow', [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $categoryPath = Join-Path $workflowRoot (($category -split '\.') -join '\')
        Install-Text (Join-Path $categoryPath 'Router.md') `
            (New-BusinessRouter $category $categoryList $date)
        Install-Text (Join-Path $categoryPath 'DeveloperLog.md') @"
# $category Developer Log

## Maintenance rules

Append dated task evidence, affected files/resources, validation, conclusions, and
maintenance count changes; keep current conclusions in the relevant Guide. Read
the Guide first. For recent history, locate only relevant entries from the last
one or two days, never the entire log. Read older entries only for a targeted
historical investigation. Preserve stored history unless the user explicitly
approves removing specific entries.
"@
    }

    $instancePath = Join-Path $workflowRoot 'Workflow\WorkflowInstance.json'
    if (-not [IO.File]::Exists($instancePath)) {
        $distribution = Get-DistributionManifest
        $instance = [ordered]@{
            schemaVersion = 1
            distributionName = 'Y_MultipleAgentWorkflow'
            packageVersion = [string]$distribution.packageVersion
            skillVersion = [string]$distribution.skillVersion
            workflowTemplateVersion = [string]$distribution.workflowTemplateVersion
            workflowRootName = $WorkflowRootName
            projectValidationMode = $ProjectValidationMode
            categories = $categoryList
            installedAtUtc = [DateTime]::UtcNow.ToString('o')
            updatedAtUtc = [DateTime]::UtcNow.ToString('o')
            managedFiles = @(Get-ManagedFileRecords $workflowRoot)
        }
        Install-Text $instancePath ($instance | ConvertTo-Json -Depth 8)
    }
    else {
        $script:Skipped.Add($instancePath)
    }

    if ($Merge -and $script:Skipped.Count -gt 0) {
        $script:Warnings.Add(
            'Merge did not rewrite existing Router indexes. Validate and update missing navigation manually.'
        )
    }

    [ordered]@{
        success = $true
        action = if ($WhatIfPreference) { 'Preview' } else { 'Initialize' }
        projectRoot = $project
        workflowRoot = $workflowRoot
        categories = $categoryList
        entryMode = 'None'
        projectValidationMode = $ProjectValidationMode
        created = @($script:Created)
        planned = @($script:Planned)
        skipped = @($script:Skipped)
        warnings = @($script:Warnings)
    } | ConvertTo-Json -Depth 8
}
catch {
    [ordered]@{
        success = $false
        action = 'Initialize'
        errors = @($_.Exception.Message)
    } | ConvertTo-Json -Depth 6
    exit 1
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($script:TemplateExtractionRoot) -and
        [IO.Directory]::Exists($script:TemplateExtractionRoot)) {
        Remove-Item -LiteralPath $script:TemplateExtractionRoot -Recurse -Force
    }
}
