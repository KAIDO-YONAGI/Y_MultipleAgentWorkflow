# {{PROJECT_NAME}} Multi-Agent Workflow Router

Document ID: `ROOT-ROUTER`  
Status: `Active`  
Last updated: `{{DATE}}`

## Maintenance rules

Successful tasks that materially affect a business increment its `0/5` count.
Failures, cancellation, lease bookkeeping, read-only investigation, and pure
documentation maintenance do not count. At `5/5`, review task evidence and actual
project state, update authorities or record `reviewed-no-change`, then reset.
Update root routing when categories or shared entry points change; detailed
document indexes stay in the relevant business Router.

This directory is the authoritative project documentation entry. Agents may perform
light read-only discovery before routing, but must acquire a WorkingAgent lease before
detailed work, subagents, mutation, or state-changing tools.

## Working method

1. Route through this file.
2. Read `Workflow\Concurrency_Guide.md`.
3. Acquire a precise lease with `Workflow\Scripts\WorkingAgent.ps1`.
4. If the lease status shows an overlapping task and the client supports native
   Agent communication, such as Codex task messaging, notify that task before
   editing.
5. Read the routed Guide's local contents and relevant sections first. If task
   history is needed, locate only relevant log entries from the last one or two
   days. Never load an entire log; read older entries only for a targeted historical
   investigation.
6. Release the lease on success, failure, or cancellation; notify waiting tasks
   after the release when the client supports native communication.

## Authority order

1. The user's latest explicit request.
2. Actual code, resources, runtime results, and reproducible tests.
3. The relevant Guide or Design.
4. The relevant business Router.
5. DeveloperLog and Proposal.
6. Model entry files and Skills.

{{PROJECT_VALIDATION_SECTION}}

## Business routing

| Trigger or goal | Read |
|---|---|
| Workflow configuration, categories, model entry integration | `Workflow_Configuration_Guide.md` |
| Routing, classification, documentation maintenance | `Workflow\Workflow_Guide.md` |
| Leases, conflicts, waiting, heartbeat | `Workflow\Concurrency_Guide.md` |

Add confirmed business task triggers and their required Guide/Design paths here.

## Business navigation

| Business root | Router |
|---|---|
{{CATEGORY_ROWS}}

## Current implementation entry points

Record only the few verified code, resource, or runtime entry points needed to
start common tasks. Detailed document indexes belong in each business Router.
