# Multi-Agent Workflow Guide

## Maintenance rules

Update this guide when routing, classification, context reading, or maintenance
behavior changes; keep its contents links and related Router entries current.
Increment a business count only for a successful task that materially affects it.
Do not count failures, cancellation, lease bookkeeping, read-only investigation, or
pure documentation maintenance. At `5/5`, review evidence and actual project state,
update authorities or record `reviewed-no-change`, then reset.

Do not automatically truncate `DeveloperLog.md` history. Remove an entry only
after the user explicitly confirms it is redundant or outdated; otherwise keep
all entries in place.

## Contents

- [Routing](#routing)
- [Reading project context](#reading-project-context)
- [Business roots](#business-roots)
- [Depth](#depth)
- [Concurrency resources](#concurrency-resources)

Read these contents first, then only the sections relevant to the task.

## Routing

Route by task terms, target paths, runtime resources, and expected outputs. Task
descriptions locate the category; operating behavior comes from its Guide/Design.
Cross-business tasks enter every affected business root.

## Reading project context

Every Guide has a local table of contents linking to its headings. Start there and
read the relevant sections, rather than loading the whole Guide. Update those
links when headings change.

Prefer the relevant Guide for current state. When task history is needed, locate
only relevant log entries from the last one or two days by date, heading, or task
terms, then extract those entries. Never load an entire DeveloperLog into context.
If recent entries do not answer the question, use the Guide; read older entries
only for a task that requires targeted historical investigation. Reading limits
do not change log retention.

## Business roots

Reuse an existing category before creating one. New top-level categories and
workspace-wide rules require user confirmation. Each business root contains at least
`Router.md` and `DeveloperLog.md`.

## Depth

Allow no more than five directory levels below the workflow root. Before a sixth
level, promote an independent child, merge repeated layers, or use Router tags.

## Concurrency resources

Use `workflow:<business-root>` only during Router/Log writes and `workflow:root` only
during root structure changes.
