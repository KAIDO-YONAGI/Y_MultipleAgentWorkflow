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
- `Y_MultipleAgentWorkflow-<version>-offline.zip`;
- `SHA256SUMS`;
- `claude-marketplace.json` and `zcode-marketplace.json`.

## Package composition

- Client ZIPs contain the client plugin manifest plus one copy of
  `skills/multiple-agent-workflow-config/`, generated from `src/`.
- The offline ZIP contains `tools/`, `skills/`, `distribution-manifest.json`,
  `VERSION`, `README.md`, and `README.cn.md`.

## Marketplace metadata

The Claude Marketplace entry references the tagged canonical Skill source directly.
The ZCode Marketplace entry uses the versioned ZIP URL and its SHA-256.

## Source of truth

`src/skills/multiple-agent-workflow-config/` is the only maintained Skill tree.
`packaging/` holds client manifest templates rendered at build time. Downloads are
served from the tagged GitHub Release; `gh` requires an authenticated account.
