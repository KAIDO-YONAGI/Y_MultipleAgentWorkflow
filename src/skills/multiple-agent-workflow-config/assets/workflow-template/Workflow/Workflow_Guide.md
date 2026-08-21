# Multi-Agent Workflow Guide

## Routing

Route by task terms, target paths, runtime resources, and expected outputs. Task
descriptions locate the category; operating behavior comes from its Guide/Design.
Cross-business tasks enter every affected business root.

## Business roots

Reuse an existing category before creating one. New top-level categories and
workspace-wide rules require user confirmation. Each business root contains at least
`Router.md` and `DeveloperLog.md`.

## Depth

Allow no more than five directory levels below the workflow root. Before a sixth
level, promote an independent child, merge repeated layers, or use Router tags.

## Maintenance

Increment a business count only for a successful task that materially affects it.
Do not count failures, cancellation, lease bookkeeping, read-only investigation, or
pure documentation maintenance. At `5/5`, review evidence and actual project state,
update authorities or record `reviewed-no-change`, then reset.

Use `workflow:<business-root>` only during Router/Log writes and `workflow:root` only
during root structure changes.
