---
name: multiple-agent-workflow-config
description: Configure or migrate a project to a reusable multi-agent and multi-model workflow with hierarchical routing, maintained project guides, and WorkingAgent concurrency leases. Use when users ask to design, initialize, generalize, validate, or repair a Y_MultipleAgentWorkflow-style setup. Do not modify model entry files or migrate existing authoritative documents before explicit user confirmation.
---

# Multiple Agent Workflow Configuration

Build a project-specific workflow from project evidence. The Skill owns the generic
method; each project's Router and Guide/Design files own project-specific behavior.

## Required sequence

1. Inspect the project root, documentation indexes, model entry files, build/run
   commands, ignored evidence stores, and existing Skill/Junction layout.
2. Read [references/configuration-method.md](references/configuration-method.md).
3. Propose:
   - stable top-level knowledge domains;
   - repeated task-stage subcategories;
   - authoritative documents to migrate or index;
   - path, workflow, runtime, config, pipeline, and git resources;
   - documents that remain Proposal, Reference, External, or Archived.
   Ask separately whether project-specific validation should be `None` or `Guide`.
   Do not infer build, publish, run, deployment, process, or environment commands.
4. Wait for explicit user confirmation before:
   - creating a new top-level category;
   - migrating or deleting an existing authority;
   - changing workspace-wide rules;
   - modifying `AGENTS.md`, `CLAUDE.md`, project Skills, or equivalent entries.
5. After category confirmation, preview initialization:

```powershell
$skillRoot = '<resolved-absolute-skill-directory>'
& "$skillRoot\scripts\Initialize-Workflow.ps1" `
  -ProjectRoot '<project-root>' `
  -Categories @('Workflow', 'GUI', 'Resources.Load') `
  -ProjectValidationMode None `
  -WhatIf
```

6. Run the initializer without `-WhatIf`. Existing workflow roots are refused unless
   `-Merge` is explicit; merge only creates missing files and does not rewrite
   existing content.
7. Handle model entry integration separately. Scan existing content and ask the user
   to choose:
   - preserve existing rules and add a maintained Router navigation block; or
   - replace the entry with a thin Router-only entry.
   The default is `EntryMode=None`, which changes nothing.
8. Validate:

```powershell
& "$skillRoot\scripts\Test-WorkflowConfiguration.ps1" `
  -ProjectRoot '<project-root>' `
  -RunWorkingAgentTests
```

9. When `ProjectValidationMode=Guide`, fill the separately indexed
   `Workflow\Project_Validation_Guide.md` only with user-confirmed project commands.
   Record categories, resources, evidence paths, results, and maintenance counts in
   their corresponding project documents.

## Classification constraints

- Classify first by stable knowledge domain, then by repeated task stage or processing
  objective.
- Do not classify by model, Agent, language, extension, or source tree shape alone.
- Create a business root only when triggers, authority, concurrency resources, or
  maintenance cadence justify it.
- Keep indexes at five directory levels or fewer.
- Use Router indexes for isolated evidence; use `Proposal` for unimplemented designs.
- Cross-business tasks route to and count against every affected business root.

## Concurrency and safety

- Light read-only discovery may precede a lease. Acquire a precise lease before
  detailed work, subagents, mutation, or state-changing tools.
- Keep Router/Log resources short-lived and use `workflow:root` only for root
  structure changes.
- Never infer another project's build/publish/run commands from the bundled example.
- The bundled WorkingAgent implementation targets Windows with PowerShell 7.
- Do not create duplicate Skill copies across clients. Determine one canonical Skill
  directory and use directory Junctions only after checking existing links.

The reusable scaffold is in [assets/workflow-template](assets/workflow-template).
Distribution, installation, and explicit update behavior are summarized in
[references/distribution.md](references/distribution.md).
