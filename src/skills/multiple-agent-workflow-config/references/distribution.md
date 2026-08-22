# Distribution Boundary

The version-controlled distribution repository is the only generic Skill source.
Codex, Claude, and ZCode adapters are generated from that source.

- Client package layouts exist only in the ignored build staging directory. They are
  not maintained or versioned as additional Skill copies.
- `Copy` is the default release installation mode.
- `Junction` is for a development machine that intentionally follows a local source
  checkout.
- Installing a Skill never modifies project `AGENTS.md`, `CLAUDE.md`, or equivalent
  entries.
- Network access occurs only during an explicitly invoked update or release command.
- A project workflow is a copied instance, not a Junction or submodule.
- `Workflow/WorkflowInstance.json` records managed file hashes.
- Instance updates may replace only unchanged managed files. Routers, logs, Guides,
  Designs, and Proposals remain project-owned.
- Project validation remains the initialization choice `None` or `Guide`; a
  distribution tool must not infer build, publish, run, deployment, or process
  commands.
