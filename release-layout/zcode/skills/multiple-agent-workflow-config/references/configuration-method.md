# Generic Configuration Method

Use this reference after inspecting the target project. It defines the reusable
decisions; it does not contain project-specific build or business rules.

## Authority boundary

- The global Skill owns classification, initialization, and validation mechanics.
- The project's root Router owns navigation and precedence.
- Project Guide/Design files own implemented business behavior.
- DeveloperLog records evidence but is not the primary operating authority.
- Proposal is never treated as implemented capability.

## Classification

Choose top-level roots by stable responsibility, such as Workflow, GUI, Resources,
Data, Runtime, Build, or Deployment. Add a root only when it can evolve and be routed
independently.

Choose subcategories by repeated task stage or objective. For example, one resource
domain may separate Load, MatchClean, and StateSupport because their triggers,
authorities, and conflict resources differ.

Create a business root when at least one strong reason exists:

- repeated and discriminating task triggers;
- an independent authoritative Guide/Design;
- a distinct write path or named concurrency resource;
- an independent maintenance cadence.

Prefer an index entry, tag, log item, or Proposal when content is a one-off note,
single evidence document, one step of an existing workflow, or an unimplemented idea.

## Routing and depth

Match from the root Router using task terms, target paths, runtime resources, and
expected outputs. Reuse an existing category before proliferating a new one.

Count directories below the workflow root. Before a sixth level appears, promote an
independent category, merge repeated layers, or replace a directory with Router tags.

Cross-business work reads every relevant Router and records evidence/counts in each
affected business root.

## Resource declarations

Use precise path resources and project-defined named resources:

```text
path:<owned-path>
workflow:<business-root>
runtime:<shared-runtime>
config:<shared-config>
pipeline:BuildPublishRun
git:index
```

The conventional build barrier name is `pipeline:BuildPublishRun`. A target project
may define additional resources, but its actual commands must come from that project.

## Model entry integration

Initialization never edits entries. Inspect existing `AGENTS.md`, `CLAUDE.md`,
project Skills, and user-level Skill links first. Ask the user to select either:

1. preserve rules and add an idempotent Router navigation block; or
2. replace the file with a thin Router-only entry.

Keep `EntryMode=None` until the user chooses. Never copy the same Skill into several
client roots when a single canonical directory plus Junctions is available.

## Project validation integration

Initialization must obtain a separate user choice:

1. `None`: create no project validation guide and impose no build/run requirement.
2. `Guide`: create and index `Workflow\Project_Validation_Guide.md`.

Selecting `Guide` does not authorize guessed commands. Confirm triggers, command
order, processes, barriers, success criteria, and environment handling with the user.
Keep procedure details out of the root Router; it only routes to the guide.

## Validation

Require root Router/DeveloperLog, Workflow guides and scripts, per-business
Router/DeveloperLog, five-level compliance, valid Proposal states, resolvable indexed
Markdown paths, ignored runtime leases, PowerShell parser success, and WorkingAgent
regression success.
