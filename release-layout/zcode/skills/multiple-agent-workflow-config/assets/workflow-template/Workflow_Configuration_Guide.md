# Project Workflow Configuration

Document ID: `WF-CONFIG-METHOD`  
Status: `Active`  
Last updated: `{{DATE}}`

This file records the target project's categories, evidence paths, named resources,
entry integration choice, and validation results. The global
`multiple-agent-workflow-config` Skill owns the generic method.

## Classification

Top-level roots represent stable knowledge domains. Subcategories represent repeated
task stages or processing objectives. Do not mirror models, Agents, languages, file
extensions, or the source tree without a routing reason.

Create a business root only when it has independent triggers, authority, concurrency
scope, or maintenance cadence. Use Router indexes or Proposal documents for isolated
evidence and unimplemented ideas.

## Entry integration

Current mode: `None`

Do not modify model entry files until the user selects one:

1. preserve existing rules and add a Router navigation block;
2. replace with a thin Router-only entry.

## Project validation integration

Selected mode: `{{PROJECT_VALIDATION_MODE}}`

`None` means this workflow imposes no project-specific build, publish, run, or
deployment process. `Guide` means an independently indexed
`Workflow\Project_Validation_Guide.md` was created and still requires confirmed
project commands.

## Project decisions

Record confirmed categories, shared resources, external evidence, validation-guide
choice, and migration decisions here after inspecting this project.
