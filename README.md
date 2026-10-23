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

## Layout

```text
src/skills/multiple-agent-workflow-config/   Skill source, template, references
packaging/                                   Codex, Claude, ZCode client manifests
tools/install/                               Install, update, uninstall
tools/build/                                 Release packaging
tools/test/                                  Distribution regression and Skill metadata
tools/lib/                                   Shared PowerShell helpers
docs/                                        Release process and asset composition
LICENSE                                      MIT License
```

## Installation

```powershell
& '.\tools\install\Install-MAW.ps1' `
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
& '.\tools\test\Test-Distribution.ps1'
& '.\tools\build\Build-Distribution.ps1'
```

Release assets are written to `dist/` together with `SHA256SUMS`. Client layouts are
staged only under `.tmp/` during a build and are not tracked as duplicate Skill
sources.

## Supported clients and license

The release build currently provides Codex, Claude, and ZCode packages. The project
is licensed under the MIT License; see the root `LICENSE` file for the terms.
