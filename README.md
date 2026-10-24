# Y_MultipleAgentWorkflow

Versioned distribution source for a Skill that turns project experience into
routable, maintainable work knowledge reusable across sessions. When multiple
Agents share a workspace, leases coordinate concurrent modifications. Leases are
cooperative protocol, not filesystem locks; they cannot prevent manual edits or
changes by non-participating Agents.

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
packaging/                                   Client manifests and WorkBuddy metadata
tools/install/                               Install, update, uninstall
tools/build/                                 Release packaging
tools/test/                                  Distribution regression and Skill metadata
tools/lib/                                   Shared PowerShell helpers
docs/                                        Release process and asset composition
LICENSE                                      MIT License
THIRD_PARTY_NOTICES.md                       Third-party dependency notices
requirements-dev.txt                         Python development dependencies
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

The release build provides Codex, Claude, and ZCode client ZIPs, a WorkBuddy Skill
ZIP, and an offline package. WorkBuddy imports its ZIP through its Skill workflow;
the local installer targets Codex, Claude, and ZCode only. The WorkBuddy adapter and
bundled scripts are Windows-only. Windows PowerShell 5.1 is sufficient; PowerShell 7
or later is also supported. The WorkBuddy ZIP keeps the project template in a nested
ZIP because its upload parser rejects Skill files more than two path segments below
the Skill root; the initializer and updater validate and extract that archive in a
temporary directory. ZIP import and marketplace listing are separate; this project
is intended for free, open-source distribution, not a paid listing.

There are no third-party runtime modules. Python 3 and PyYAML are needed only for
development metadata validation. Git is used when cloning the repository; Git and
GitHub CLI (`gh`) are optional paths for explicit updates. The offline package
includes the compliance guide and third-party notices; see
[`docs/Open_Source_Compliance.md`](docs/Open_Source_Compliance.md).
