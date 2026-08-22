# Y_MultipleAgentWorkflow

Versioned distribution source for the reusable multi-agent workflow configuration
Skill and its project workflow template.

Chinese primary manual: [`README.cn.md`](README.cn.md)

## Authority boundary

- `src/skills/multiple-agent-workflow-config/` is the single generic Skill source.
- A project's `Y_MultipleAgentWorkflow/` is a project-owned instance.
- Project Routers, logs, Guides, Designs, and Proposals are never overwritten by an
  automatic update.
- Project-specific build, publish, run, deployment, process, and environment rules
  are configured only when initialization explicitly selects
  `ProjectValidationMode=Guide`.

## Development installation

```powershell
& '.\scripts\Install-MAW.ps1' `
  -Clients Codex,Claude,ZCode `
  -Mode Junction `
  -SourceRoot $PWD `
  -Replace `
  -WhatIf
```

Remove `-WhatIf` after reviewing the exact targets. Ordinary release users should
use `-Mode Copy` with the offline package.

## Project initialization

Resolve the installed Skill directory, then run:

```powershell
& '<skill-root>\scripts\Initialize-Workflow.ps1' `
  -ProjectRoot 'D:\ExampleProject' `
  -Categories Workflow,GUI,Resources.Load `
  -ProjectValidationMode None
```

The initializer does not modify `AGENTS.md`, `CLAUDE.md`, or client-specific project
entries.

## Build a release

```powershell
& '.\scripts\Test-Distribution.ps1'
& '.\scripts\Build-Distribution.ps1'
```

Release assets are written to `dist/` together with `SHA256SUMS`.
The release also includes standalone private Marketplace metadata for Claude and
ZCode. Access to packages and explicit updates requires authorization to the private
GitHub repository.

Client layouts are staged only under `.tmp/` during a build. They are generated
artifacts and are not tracked as duplicate Skill sources.
