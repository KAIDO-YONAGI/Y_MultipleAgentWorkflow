[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$WorkflowRootName = 'Y_MultipleAgentWorkflow',
    [switch]$Apply
)

$scriptPath = Join-Path $PSScriptRoot '..\src\skills\multiple-agent-workflow-config\scripts\Update-WorkflowInstance.ps1'
& $scriptPath @PSBoundParameters
exit $LASTEXITCODE
