# Distribution Guide

Release process and asset composition for this repository. Installation and upgrade
boundaries are owned by
`src/skills/multiple-agent-workflow-config/references/distribution.md`.

## Build and verification

```powershell
& '.\tools\test\Test-Distribution.ps1'
& '.\tools\build\Build-Distribution.ps1'
```

`Test-Distribution.ps1` covers initialization, lease regression, installation,
upgrade, and packaging. `Build-Distribution.ps1` writes release assets to `dist/` and
regenerates `SHA256SUMS`. Client layouts are staged under `.tmp/` only while
packaging; neither directory is versioned.

## Release assets

Each release contains:

- `Y_MultipleAgentWorkflow-<version>-codex.zip`, `-claude.zip`, `-zcode.zip`;
- `Y_MultipleAgentWorkflow-<version>-workbuddy.zip`;
- `Y_MultipleAgentWorkflow-<version>-offline.zip`;
- `SHA256SUMS`;
- `claude-marketplace.json` and `zcode-marketplace.json`.

## Package composition

- Client ZIPs contain the client plugin manifest plus one copy of
  `skills/multiple-agent-workflow-config/`, generated from `src/`, and the root
  `LICENSE`.
- The WorkBuddy ZIP contains one top-level
  `multiple-agent-workflow-config/` Skill directory, bilingual metadata, references,
  scripts, a `templates/workflow-template/` copy, and `LICENSE`. It excludes
  `agents/openai.yaml` and the source-only `assets/` layout.
- The offline ZIP contains `tools/`, `skills/`, `distribution-manifest.json`,
  `VERSION`, `LICENSE`, both READMEs, `docs/`, `THIRD_PARTY_NOTICES.md`, and
  `requirements-dev.txt`. The development dependency itself is not bundled.

## Marketplace metadata

The Claude Marketplace entry references the tagged canonical Skill source directly.
The ZCode Marketplace entry uses the versioned ZIP URL and its SHA-256.

The root `LICENSE` contains the project's MIT License and is included in every
client, WorkBuddy, and offline ZIP. The repository and offline package also carry
the open-source distribution checklist and third-party dependency notices.

The bundled scripts target Windows and support Windows PowerShell 5.1 or PowerShell
7 or later; PowerShell 7 is not required. WorkBuddy invokes executable Skill tools
through Bash, so its adapter calls `powershell.exe` on the same Windows host. This
does not make the scripts portable to a Bash-only or non-Windows environment.

There are no third-party runtime modules. Python 3 and PyYAML are development-only
requirements for metadata validation. Git is used to clone the source; Git and
GitHub CLI (`gh`) are only needed for their respective explicit update paths. The
local installer does not install WorkBuddy; import its ZIP through WorkBuddy's own
Skill workflow.

The MIT license permits free redistribution subject to its terms, but it does not
establish that a marketplace listing can be published for free. WorkBuddy's
monetization documentation describes both a free option and a current paid-only
limitation. Confirm the live publishing workflow before making a free-listing
claim; the locally built ZIP is not uploaded by this repository's build process.

## Source of truth

`src/skills/multiple-agent-workflow-config/` is the only maintained Skill tree.
`packaging/` holds client manifest templates rendered at build time. Downloads are
served from the tagged GitHub Release. GitHub CLI authentication may be needed
depending on the user's local CLI configuration.
