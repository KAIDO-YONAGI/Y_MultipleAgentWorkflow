[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectRoot,

    [string]$WorkflowRootName = 'Y_MultipleAgentWorkflow',

    [switch]$RunWorkingAgentTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Checks = [Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [ValidateSet('pass', 'warning', 'error')]
        [string]$Level,
        [string]$Name,
        [string]$Message
    )
    $script:Checks.Add([ordered]@{
        level = $Level
        name = $Name
        message = $Message
    })
}

function Test-File {
    param([string]$Path, [string]$Name)
    if ([IO.File]::Exists($Path)) {
        Add-Check pass $Name $Path
    }
    else {
        Add-Check error $Name "Missing: $Path"
    }
}

try {
    $project = [IO.Path]::GetFullPath($ProjectRoot)
    $workflowRoot = Join-Path $project $WorkflowRootName
    if (-not [IO.Directory]::Exists($workflowRoot)) {
        throw "Workflow root does not exist: '$workflowRoot'."
    }

    foreach ($required in @(
        'Router.md',
        'DeveloperLog.md',
        'Workflow_Configuration_Guide.md',
        'WorkingAgent\README.md',
        'Workflow\Router.md',
        'Workflow\DeveloperLog.md',
        'Workflow\Workflow_Guide.md',
        'Workflow\Concurrency_Guide.md',
        'Workflow\WorkflowInstance.json',
        'Workflow\Scripts\WorkingAgent.ps1',
        'Workflow\Scripts\Test-WorkingAgent.ps1'
    )) {
        Test-File (Join-Path $workflowRoot $required) "required:$required"
    }

    $instancePath = Join-Path $workflowRoot 'Workflow\WorkflowInstance.json'
    if ([IO.File]::Exists($instancePath)) {
        try {
            $instance = [IO.File]::ReadAllText($instancePath) | ConvertFrom-Json
            if ([int]$instance.schemaVersion -eq 1) {
                Add-Check pass 'workflow-instance-schema' 'WorkflowInstance schemaVersion is 1.'
            }
            else {
                Add-Check error 'workflow-instance-schema' 'Unsupported WorkflowInstance schemaVersion.'
            }
            foreach ($managed in @($instance.managedFiles)) {
                $managedPath = Join-Path $workflowRoot (
                    ([string]$managed.path) -replace '/', '\'
                )
                if (-not [IO.File]::Exists($managedPath)) {
                    Add-Check error "managed-file:$($managed.path)" 'Managed file is missing.'
                    continue
                }
                $currentHash = (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($currentHash -eq [string]$managed.installedHash) {
                    Add-Check pass "managed-file:$($managed.path)" 'Managed file matches its installed hash.'
                }
                else {
                    Add-Check warning "managed-file:$($managed.path)" 'Managed file has project drift and will not be overwritten.'
                }
            }
        }
        catch {
            Add-Check error 'workflow-instance-json' $_.Exception.Message
        }
    }

    $allDirectories = @(
        Get-ChildItem -LiteralPath $workflowRoot -Directory -Recurse -Force
    )
    $maxDepth = 0
    foreach ($directory in $allDirectories) {
        $relative = [IO.Path]::GetRelativePath($workflowRoot, $directory.FullName)
        $depth = @($relative -split '[\\/]').Count
        if ($depth -gt $maxDepth) {
            $maxDepth = $depth
        }
    }
    if ($maxDepth -le 5) {
        Add-Check pass 'directory-depth' "Maximum depth is $maxDepth."
    }
    else {
        Add-Check error 'directory-depth' "Maximum depth $maxDepth exceeds five."
    }

    $businessDirectories = @(
        $allDirectories | Where-Object {
            $relative = [IO.Path]::GetRelativePath($workflowRoot, $_.FullName)
            $relative -ne 'WorkingAgent' -and
            $relative -notin @('Workflow\Templates', 'Workflow\Scripts')
        }
    )
    foreach ($directory in $businessDirectories) {
        $relative = [IO.Path]::GetRelativePath($workflowRoot, $directory.FullName)
        Test-File (Join-Path $directory.FullName 'Router.md') "business-router:$relative"
        Test-File (Join-Path $directory.FullName 'DeveloperLog.md') "business-log:$relative"
    }

    foreach ($directory in $businessDirectories) {
        if ($directory.FullName.Equals(
            (Join-Path $workflowRoot 'Workflow'),
            [StringComparison]::OrdinalIgnoreCase
        )) {
            continue
        }
        $parentRouter = if ($directory.Parent.FullName.Equals(
            $workflowRoot,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            Join-Path $workflowRoot 'Router.md'
        }
        else {
            Join-Path $directory.Parent.FullName 'Router.md'
        }
        if ([IO.File]::Exists($parentRouter)) {
            $text = [IO.File]::ReadAllText($parentRouter)
            $expected = "$($directory.Name)\Router.md"
            if ($text.IndexOf($expected, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Add-Check pass "parent-route:$($directory.Name)" $parentRouter
            }
            else {
                Add-Check warning "parent-route:$($directory.Name)" `
                    "Parent Router does not mention '$expected': $parentRouter"
            }
        }
    }

    $proposalFiles = @(
        Get-ChildItem -LiteralPath $workflowRoot -File -Recurse -Filter '*Proposal*.md'
    )
    foreach ($proposal in $proposalFiles) {
        $text = [IO.File]::ReadAllText($proposal.FullName)
        if ($text -match '(?im)(?:status|状态)\s*[:：]\s*`?Proposal`?') {
            Add-Check pass "proposal:$($proposal.Name)" 'Proposal status is explicit.'
        }
        else {
            Add-Check error "proposal:$($proposal.Name)" `
                "Proposal filename lacks explicit Proposal status: $($proposal.FullName)"
        }
    }

    $rootRouter = Join-Path $workflowRoot 'Router.md'
    if ([IO.File]::Exists($rootRouter)) {
        $routerLines = [IO.File]::ReadAllLines($rootRouter)
        $indexHeaderSeen = $false
        foreach ($line in $routerLines) {
            if ($line -match '^\|\s*文档 ID\s*\|\s*路径\s*\|') {
                $indexHeaderSeen = $true
                continue
            }
            if (-not $indexHeaderSeen) {
                continue
            }
            if ($line -notmatch '^\|') {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    break
                }
                continue
            }
            $columns = @($line.Trim().Trim('|').Split('|') | ForEach-Object Trim)
            if ($columns.Count -lt 2 -or $columns[0] -match '^-+$') {
                continue
            }
            $candidate = $columns[1].Trim('`')
            if ($candidate -notmatch '\.(?:md|txt)$') {
                continue
            }
            if ([IO.Path]::IsPathRooted($candidate)) {
                continue
            }
            $workflowCandidate = [IO.Path]::GetFullPath(
                (Join-Path $workflowRoot $candidate)
            )
            $projectCandidate = [IO.Path]::GetFullPath(
                (Join-Path $project $candidate)
            )
            $resolved = if ([IO.File]::Exists($workflowCandidate)) {
                $workflowCandidate
            }
            else {
                $projectCandidate
            }
            if ([IO.File]::Exists($resolved)) {
                Add-Check pass "index:$candidate" $resolved
            }
            else {
                Add-Check warning "index:$candidate" "Indexed Markdown path is unresolved."
            }
        }
    }

    $projectValidationGuide = Join-Path $workflowRoot `
        'Workflow\Project_Validation_Guide.md'
    if ([IO.File]::Exists($projectValidationGuide)) {
        $rootRouterText = [IO.File]::ReadAllText($rootRouter)
        if ($rootRouterText -match [regex]::Escape(
            'Workflow\Project_Validation_Guide.md'
        )) {
            Add-Check pass 'project-validation-guide' `
                'Optional project validation guide is present and indexed.'
        }
        else {
            Add-Check error 'project-validation-guide' `
                'Project validation guide exists but is not indexed by the root Router.'
        }
    }
    else {
        Add-Check pass 'project-validation-guide' `
            'No project-specific validation guide is configured.'
    }

    $localIgnorePath = Join-Path $workflowRoot 'WorkingAgent\.gitignore'
    $rootIgnorePath = Join-Path $project '.gitignore'
    $ignorePath = if ([IO.File]::Exists($localIgnorePath)) {
        $localIgnorePath
    }
    elseif ([IO.File]::Exists($rootIgnorePath)) {
        $rootIgnorePath
    }
    else {
        $null
    }
    if ($null -ne $ignorePath) {
        $ignore = [IO.File]::ReadAllText($ignorePath)
        foreach ($pattern in @('*.txt', '_registry.lock', '*.tmp', '!README.md')) {
            $localPattern = $ignore -match [regex]::Escape($pattern)
            $rootPattern = switch ($pattern) {
                '*.txt' { $ignore -match 'WorkingAgent[/\\]\*\.txt' }
                '_registry.lock' { $ignore -match 'WorkingAgent[/\\]_registry\.lock' }
                '*.tmp' { $ignore -match 'WorkingAgent[/\\]\*\.tmp' }
                '!README.md' {
                    $ignore -match '!.*WorkingAgent[/\\]README\.md' -or
                    (
                        $ignorePath -eq $rootIgnorePath -and
                        $ignore -notmatch '(?m)^\s*/?Y_MultipleAgentWorkflow/WorkingAgent/?\s*$'
                    )
                }
            }
            if ($localPattern -or $rootPattern) {
                Add-Check pass "working-agent-ignore:$pattern" $ignorePath
            }
            else {
                Add-Check error "working-agent-ignore:$pattern" "Missing pattern '$pattern'."
            }
        }
    }
    else {
        Add-Check error 'working-agent-ignore' `
            'Neither WorkingAgent\.gitignore nor project .gitignore exists.'
    }

    foreach ($scriptPath in @(
        (Join-Path $workflowRoot 'Workflow\Scripts\WorkingAgent.ps1'),
        (Join-Path $workflowRoot 'Workflow\Scripts\Test-WorkingAgent.ps1')
    )) {
        if (-not [IO.File]::Exists($scriptPath)) {
            continue
        }
        $tokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        if (@($parseErrors).Count -eq 0) {
            Add-Check pass "powershell-parser:$([IO.Path]::GetFileName($scriptPath))" `
                'No parser errors.'
        }
        else {
            Add-Check error "powershell-parser:$([IO.Path]::GetFileName($scriptPath))" `
                ((@($parseErrors | ForEach-Object Message)) -join '; ')
        }
    }

    if ($RunWorkingAgentTests) {
        $testScript = Join-Path $workflowRoot 'Workflow\Scripts\Test-WorkingAgent.ps1'
        if ([IO.File]::Exists($testScript)) {
            $pwsh = (Get-Process -Id $PID).Path
            $output = @(& $pwsh -NoLogo -NoProfile -File $testScript 2>&1)
            $exitCode = $LASTEXITCODE
            $text = $output -join [Environment]::NewLine
            if ($exitCode -eq 0 -and $text -match 'PASS SUMMARY 12/12') {
                Add-Check pass 'working-agent-regression' 'PASS SUMMARY 12/12'
            }
            else {
                Add-Check error 'working-agent-regression' `
                    "Exit=$exitCode Output=$text"
            }
        }
    }

    $errors = @($script:Checks | Where-Object level -eq 'error').Count
    $warnings = @($script:Checks | Where-Object level -eq 'warning').Count
    $passes = @($script:Checks | Where-Object level -eq 'pass').Count
    [ordered]@{
        success = $errors -eq 0
        projectRoot = $project
        workflowRoot = $workflowRoot
        summary = [ordered]@{
            pass = $passes
            warning = $warnings
            error = $errors
        }
        checks = @($script:Checks)
    } | ConvertTo-Json -Depth 8
    if ($errors -gt 0) {
        exit 1
    }
}
catch {
    [ordered]@{
        success = $false
        summary = [ordered]@{ pass = 0; warning = 0; error = 1 }
        checks = @([ordered]@{
            level = 'error'
            name = 'configuration'
            message = $_.Exception.Message
        })
    } | ConvertTo-Json -Depth 6
    exit 1
}
