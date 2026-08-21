# {{PROJECT_NAME}} Multi-Agent Workflow Router

Document ID: `ROOT-ROUTER`  
Status: `Active`  
Last updated: `{{DATE}}`

This directory is the authoritative project documentation entry. Agents may perform
light read-only discovery before routing, but must acquire a WorkingAgent lease before
detailed work, subagents, mutation, or state-changing tools.

## Authority order

1. The user's latest explicit request.
2. Actual code, resources, runtime results, and reproducible tests.
3. The relevant Guide or Design.
4. The relevant business Router.
5. DeveloperLog and Proposal.
6. Model entry files and Skills.

## Business routing

| Business root | Router |
|---|---|
{{CATEGORY_ROWS}}

## Required start

1. Route through this file.
2. Read `Workflow\Concurrency_Guide.md`.
3. Acquire a precise lease with `Workflow\Scripts\WorkingAgent.ps1`.
4. Read only the routed Guide/Design, Router, and necessary evidence.
5. Release the lease on success, failure, or cancellation.

{{PROJECT_VALIDATION_SECTION}}

## Document index

| Document ID | Path | Status |
|---|---|---|
| `WF-CONFIG-METHOD` | `Workflow_Configuration_Guide.md` | Active |
{{PROJECT_VALIDATION_INDEX}}

## Maintenance

Successful tasks that materially affect a business increment its `0/5` count. At
`5/5`, review task evidence and actual project state, update authorities or record
`reviewed-no-change`, then reset the count.
