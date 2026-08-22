# Distribution Guide

`Y_MultipleAgentWorkflow` uses one source repository and two ownership layers.

## Generic layer

The Skill, workflow assets, installation scripts, tests, and client manifests are
versioned here. Codex, Claude, and ZCode packages are generated from the same Skill
tree.

`src/skills/multiple-agent-workflow-config/` is the only maintained Skill tree.
Client layouts are staged under `.tmp/` only while packaging; `dist/` contains the
rebuildable release assets. Neither directory is versioned.

## Project layer

Initialization copies a workflow instance into the target project. The project owns
its Routers, logs, Guides, Designs, Proposals, categories, validation commands, and
maintenance counts.

## Installation modes

- `Copy`: default release installation. Each selected client receives a managed
  copy and an installation record.
- `Junction`: source-development installation. Client skill directories point to
  the version-controlled source tree.

Installation records are stored below
`%USERPROFILE%\.maw\installations\multiple-agent-workflow-config\`. Uninstall and
replacement operations require a matching record or an explicit replacement of a
known client target.

## Upgrade policy

Skill installation updates are explicit. No background network request is made.

Project workflow updates compare each managed file with the hash recorded at the
previous installation:

- unchanged managed files may be updated;
- locally changed managed files are reported as drifted and are not overwritten;
- project-owned documents are never updated automatically.

## Release contents

Each release contains Codex, Claude, ZCode, and offline ZIP packages plus
`SHA256SUMS`. Private GitHub downloads require an authenticated `gh` command.

The Claude Marketplace entry uses the tagged canonical Skill source directly.
ZCode uses the versioned ZIP URL and its SHA-256. The offline package contains the
install/update scripts and both README files.
